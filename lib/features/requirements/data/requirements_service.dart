import 'package:maqyas_engine/maqyas_engine.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../projects/domain/models/project_unit.dart';
import '../domain/requirement_line.dart';

class RequirementsService {
  const RequirementsService._();

  static String _glassTypeArabic(String glassType) {
    switch (glassType) {
      case 'clear':
        return 'شفاف';
      case 'frosted':
        return 'مصنفر (مرمل)';
      case 'reflective':
        return 'عاكس';
      case 'smoked':
        return 'مدخن (فيميه)';
      default:
        return glassType;
    }
  }

  static String _glazingModeArabic(String glazingMode) {
    switch (glazingMode) {
      case 'double':
        return 'دبل (مزدوج)';
      case 'single':
      default:
        return 'مفرد';
    }
  }

  /// Computes auto-generated [RequirementLine] items from a project's units
  /// and optional saved cut plan [OptimizationResult].
  ///
  /// Rules:
  /// 1. Aluminum bars: counts only new 660 cm bars (`!bar.isFromRemnant`).
  /// 2. Glass: m² area and pane count per glass type.
  /// 3. Accessories: handles, rollers, plugs, screws, corners, gasket (Spec §8.6).
  /// 4. Mesh / brush: commercial `roll` (`لفة`) units only (Spec §8.7).
  static List<RequirementLine> computeProjectRequirements({
    required List<ProjectUnit> units,
    required CalculatorEngine engine,
    required CutOptimizer optimizer,
    required List<CatalogItem> catalogItems,
    OptimizationResult? savedCutPlanResult,
    DateTime? timestamp,
  }) {
    if (units.isEmpty) return const [];
    final now = timestamp ?? DateTime.now();

    CatalogItem? findCatalogByEngineCode(String engineCode) {
      for (final c in catalogItems) {
        if (c.engineItemCode == engineCode) return c;
      }
      if (engineCode.startsWith('screen_rollers')) {
        for (final c in catalogItems) {
          if (c.engineItemCode == 'screen_rollers') return c;
        }
      }
      if (engineCode.startsWith('glass_pane')) {
        for (final c in catalogItems) {
          if (c.engineItemCode == 'glass_pane') return c;
        }
      }
      return null;
    }

    final lines = <RequirementLine>[];
    final allCutPieces = <CutPiece>[];
    final pieceCountByItemCode = <String, int>{};
    final itemArabicNames = <String, String>{};
    final accessoryTotals = <String, int>{};
    final accessoryNames = <String, String>{};
    final accessoryUnits = <String, String>{};

    // Group glass by (glassType, thicknessMm, glazingMode)
    final glassAreaByKey = <String, double>{};
    final glassPanesByKey = <String, int>{};
    final glassLabelByKey = <String, String>{};

    var totalScreenCount = 0;

    for (final unit in units) {
      final calc = engine.calculate(unit.toEngineSpec());
      if (unit.hasScreen && unit.screenCount > 0) {
        totalScreenCount += unit.screenCount * unit.quantity;
      }

      // 1. Collect profile pieces
      for (final piece in calc.pieces) {
        final totalPieceQty = piece.quantity * unit.quantity;
        if (totalPieceQty <= 0) continue;

        itemArabicNames[piece.itemCode] = piece.nameArabic;
        pieceCountByItemCode[piece.itemCode] =
            (pieceCountByItemCode[piece.itemCode] ?? 0) + totalPieceQty;

        allCutPieces.add(
          CutPiece(
            itemCode: piece.itemCode,
            nameArabic: piece.nameArabic,
            lengthCm: piece.lengthCm,
            quantity: totalPieceQty,
            cutAngleLeft: piece.cutAngleLeft,
            cutAngleRight: piece.cutAngleRight,
            profileType: piece.profileType,
            ruleVersionId: piece.ruleVersionId,
            unitTag: unit.name,
          ),
        );
      }

      // 2. Collect glass area & pane counts per glass type
      if (calc.glass.quantity > 0 &&
          calc.glass.paneWidthCm > 0 &&
          calc.glass.paneHeightCm > 0) {
        final panes = calc.glass.quantity * unit.quantity;
        final areaM2 = calc.glass.singlePaneAreaM2 * panes;
        final gType = unit.glassType.isNotEmpty ? unit.glassType : 'clear';
        final gThick = unit.glassThicknessMm.toInt();
        final gMode = unit.glazingMode.isNotEmpty ? unit.glazingMode : 'single';
        final key = 'glass_pane_${gType}_${gThick}mm_$gMode';

        glassPanesByKey[key] = (glassPanesByKey[key] ?? 0) + panes;
        if (areaM2 > 0) {
          glassAreaByKey[key] = (glassAreaByKey[key] ?? 0.0) + areaM2;
        }
        glassLabelByKey[key] =
            'زجاج ${_glassTypeArabic(gType)} $gThick ملم (${_glazingModeArabic(gMode)})';
      }

      // 3. Collect accessories
      for (final acc in calc.accessories) {
        final count = acc.quantity * unit.quantity;
        if (count <= 0) continue;
        accessoryTotals[acc.code] = (accessoryTotals[acc.code] ?? 0) + count;
        accessoryNames[acc.code] = acc.nameArabic;
        accessoryUnits[acc.code] = acc.unit;
      }
    }

    // Compute new 660 cm bars needed per itemCode (excluding shelf remnants)
    final optResult =
        savedCutPlanResult ?? optimizer.optimize(pieces: allCutPieces);
    final barsByItemCode = <String, int>{};
    final remnantsUsedByItemCode = <String, int>{};

    for (final bar in optResult.barPlans) {
      if (bar.isFromRemnant) {
        remnantsUsedByItemCode[bar.itemCode] =
            (remnantsUsedByItemCode[bar.itemCode] ?? 0) + 1;
      } else {
        barsByItemCode[bar.itemCode] = (barsByItemCode[bar.itemCode] ?? 0) + 1;
      }
    }

    // 1. Aluminum Bar RequirementLines
    for (final entry in barsByItemCode.entries) {
      final itemCode = entry.key;
      final barsNeeded = entry.value;
      if (barsNeeded <= 0) continue;

      final cat = findCatalogByEngineCode(itemCode);
      final pieceCount = pieceCountByItemCode[itemCode] ?? 0;
      final remnantsCount = remnantsUsedByItemCode[itemCode] ?? 0;
      final reqQty = barsNeeded.toDouble();

      final noteParts = <String>[];
      if (pieceCount > 0) {
        noteParts.add('إجمالي $pieceCount قطعة مقصوصة');
      }
      if (remnantsCount > 0) {
        noteParts.add('تم استثناء $remnantsCount فضلة مستخدمة من الرف');
      }

      lines.add(
        RequirementLine(
          id: 'auto_al_$itemCode',
          itemId: cat?.id ?? 'cat_al_$itemCode',
          engineItemCode: itemCode,
          nameArabic: cat?.arabicName ??
              '${itemArabicNames[itemCode] ?? itemCode} (قضيب 6.6م)',
          category: 'aluminum',
          requiredQty: reqQty,
          inStockQty: 0,
          toBuyQty: reqQty,
          unit: 'bar',
          note: noteParts.join(' · '),
          source: 'auto',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    // 2. Glass RequirementLines
    for (final entry in glassAreaByKey.entries) {
      final key = entry.key;
      final rawArea = entry.value;
      if (rawArea <= 0) continue;

      final glassCat = findCatalogByEngineCode(key);
      final panes = glassPanesByKey[key] ?? 0;
      final roundedArea = double.parse(rawArea.toStringAsFixed(2));
      final reqQty = roundedArea > 0 ? roundedArea : 0.01;

      lines.add(
        RequirementLine(
          id: 'auto_$key',
          itemId: glassCat?.id ?? 'cat_gl_clear_6mm',
          engineItemCode: key,
          nameArabic: glassLabelByKey[key] ??
              glassCat?.arabicName ??
              'زجاج شفاف 6 ملم',
          category: 'glass',
          requiredQty: reqQty,
          inStockQty: 0,
          toBuyQty: reqQty,
          unit: 'm2',
          note: 'عدد الألواح: $panes لوح',
          source: 'auto',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    // 3. Accessories RequirementLines
    for (final entry in accessoryTotals.entries) {
      final code = entry.key;
      final totalQty = entry.value;
      if (totalQty <= 0) continue;

      final cat = findCatalogByEngineCode(code);
      final reqQty = totalQty.toDouble();
      final categoryId = cat?.categoryId ??
          (code == 'screws_4x16'
              ? 'tools'
              : (code == 'gasket' || code == 'corners' || code == 'water_plug'
                  ? 'plastic'
                  : 'accessories'));

      lines.add(
        RequirementLine(
          id: 'auto_acc_$code',
          itemId: cat?.id ?? 'cat_acc_$code',
          engineItemCode: code,
          nameArabic: cat?.arabicName ?? (accessoryNames[code] ?? code),
          category: categoryId,
          requiredQty: reqQty,
          inStockQty: 0,
          toBuyQty: reqQty,
          unit: cat?.unit ?? (accessoryUnits[code] ?? 'piece'),
          note: '',
          source: 'auto',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    // 4. Mesh & Brush Rolls (Spec §8.7: strictly ROLL unit)
    if (totalScreenCount > 0) {
      final meshCat = findCatalogByEngineCode('fiber_mesh_roll');
      lines.add(
        RequirementLine(
          id: 'auto_fb_fiber_mesh_roll',
          itemId: meshCat?.id ?? 'cat_fb_mesh_120',
          engineItemCode: 'fiber_mesh_roll',
          nameArabic:
              meshCat?.arabicName ?? 'لفة شبك منخل فيبر عرض 120 سم × 20 م',
          category: 'fiber',
          requiredQty: 1,
          inStockQty: 0,
          toBuyQty: 1,
          unit: 'roll',
          note: 'لعدد $totalScreenCount ضلفة منخل · باللفة فقط (Spec §8.7)',
          source: 'auto',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final brushCat = findCatalogByEngineCode('brush_450_roll');
      lines.add(
        RequirementLine(
          id: 'auto_fb_brush_450_roll',
          itemId: brushCat?.id ?? 'cat_fb_brush_450',
          engineItemCode: 'brush_450_roll',
          nameArabic: brushCat?.arabicName ?? 'لفة فراشة منخل 450',
          category: 'fiber',
          requiredQty: 1,
          inStockQty: 0,
          toBuyQty: 1,
          unit: 'roll',
          note: 'لعدد $totalScreenCount ضلفة منخل · باللفة فقط (Spec §8.7)',
          source: 'auto',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    return sortLines(lines);
  }

  /// Merges freshly calculated [freshAutoLines] into [existingLines] following
  /// the safe regeneration rules in Phase 6 §5.4:
  /// - Preserves manual lines (`source == 'manual'`) untouched.
  /// - Preserves `inStockQty`, `dismissed`, and custom `note` on auto lines.
  /// - If `isToBuyOverridden == false`, recomputes `toBuyQty = max(newRequiredQty - inStockQty, 0)`.
  /// - If `isToBuyOverridden == true`, keeps the owner's custom `toBuyQty` and
  ///   sets `needsReviewAfterRegen = true` if `requiredQty` changed.
  static List<RequirementLine> mergeRegeneratedLines({
    required List<RequirementLine> existingLines,
    required List<RequirementLine> freshAutoLines,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    final existingAutoByKey = <String, RequirementLine>{};
    final manualLines = <RequirementLine>[];

    String lineMatchKey(RequirementLine line) {
      if (line.engineItemCode.isNotEmpty) return 'code:${line.engineItemCode}';
      if (line.itemId != null && line.itemId!.isNotEmpty) {
        return 'item:${line.itemId}';
      }
      return 'id:${line.id}';
    }

    for (final line in existingLines) {
      if (line.isManual) {
        manualLines.add(line);
      } else {
        existingAutoByKey[lineMatchKey(line)] = line;
      }
    }

    final merged = <RequirementLine>[];

    for (final fresh in freshAutoLines) {
      final key = lineMatchKey(fresh);
      final prev = existingAutoByKey.remove(key);

      if (prev == null) {
        merged.add(fresh.copyWith(createdAt: now, updatedAt: now));
      } else {
        final reqChanged =
            (prev.requiredQty - fresh.requiredQty).abs() > 0.001;
        final newToBuy = prev.isToBuyOverridden
            ? prev.toBuyQty
            : RequirementLine.computeDefaultToBuy(
                fresh.requiredQty,
                prev.inStockQty,
              );
        final needsReview = prev.isToBuyOverridden
            ? (prev.needsReviewAfterRegen || reqChanged)
            : false;

        merged.add(
          prev.copyWith(
            itemId: fresh.itemId ?? prev.itemId,
            nameArabic: fresh.nameArabic,
            category: fresh.category,
            requiredQty: fresh.requiredQty,
            toBuyQty: newToBuy,
            needsReviewAfterRegen: needsReview,
            unit: fresh.unit,
            note: prev.note.isNotEmpty ? prev.note : fresh.note,
            updatedAt: now,
          ),
        );
      }
    }

    // Keep any previously dismissed auto lines so the owner can still see/restore them if desired,
    // or auto lines that had inStock/override even if their requiredQty dropped to 0.
    for (final leftoverAuto in existingAutoByKey.values) {
      if (leftoverAuto.dismissed) {
        merged.add(
          leftoverAuto.copyWith(
            requiredQty: 0,
            updatedAt: now,
          ),
        );
      }
    }

    merged.addAll(manualLines);
    return sortLines(merged);
  }

  static List<RequirementLine> sortLines(List<RequirementLine> lines) {
    final copy = List<RequirementLine>.from(lines);
    copy.sort((a, b) {
      final catCmp = RequirementLine.categorySortOrder(a.category)
          .compareTo(RequirementLine.categorySortOrder(b.category));
      if (catCmp != 0) return catCmp;
      if (a.isAuto != b.isAuto) return a.isAuto ? -1 : 1;
      return a.nameArabic.compareTo(b.nameArabic);
    });
    return copy;
  }
}
