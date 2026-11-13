import 'package:maqyas_engine/maqyas_engine.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../projects/domain/models/project.dart';
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
    ProjectDefaults? projectDefaults,
    List<CalculationRule>? workshopRules,
    OptimizationResult? savedCutPlanResult,
    List<RemnantStock> availableRemnants = const [],
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
    final pieceCountByItemColor = <String, int>{};
    final itemArabicNames = <String, String>{};

    const coloredAccessoryCodes = {
      'glass_handle',
      'screen_handle',
      'shankal_plug',
      'water_plug',
      'rakilaj_plug',
      'fixed_plug',
    };
    final accessoryTotals = <String, int>{};
    final accessoryCodes = <String, String>{};
    final accessoryColors = <String, String?>{};
    final accessoryNames = <String, String>{};
    final accessoryUnits = <String, String>{};

    // Group glass by (glassType, thicknessMm, glazingMode)
    final glassAreaByKey = <String, double>{};
    final glassPanesByKey = <String, int>{};
    final glassLabelByKey = <String, String>{};

    // Group mesh roll demands by (meshType, rollWidthCm)
    final meshScreensByKey = <String, int>{};
    final meshLengthCmByKey = <String, double>{};
    final meshTypeByKey = <String, String>{};
    final meshWidthByKey = <String, int>{};

    // Group brush roll demands by brushColor
    final brushScreensByColor = <String, int>{};
    final brushSashesByColor = <String, int>{};

    for (final unit in units) {
      final effectiveEngine = workshopRules != null
          ? CalculatorEngine(
              rules: ProjectUnit.resolveEffectiveRules(
                workshopRules,
                projectDefaults: projectDefaults,
                unitRuleOverrides: unit.unitRuleOverrides,
              ),
            )
          : engine;
      final calc = effectiveEngine.calculate(unit.toEngineSpec(projectDefaults));

      final bColor = unit.brushColor.trim().isNotEmpty ? unit.brushColor.trim() : 'أسود';
      brushSashesByColor[bColor] =
          (brushSashesByColor[bColor] ?? 0) + (unit.sashCount * unit.quantity);

      if (unit.hasScreen && unit.screenCount > 0) {
        final unitScreens = unit.screenCount * unit.quantity;
        brushScreensByColor[bColor] =
            (brushScreensByColor[bColor] ?? 0) + unitScreens;

        final svPiece =
            calc.pieces.where((p) => p.itemCode == 'screen_vertical').firstOrNull;
        final shPiece =
            calc.pieces.where((p) => p.itemCode == 'screen_horizontal').firstOrNull;
        final screenH = svPiece?.lengthCm ?? (unit.heightCm - 4.1).clamp(10.0, 400.0);
        final screenW = shPiece?.lengthCm ?? (((unit.widthCm - 2.5) / 2) + 2).clamp(10.0, 400.0);

        final mType = unit.meshType == 'aluminum' ? 'aluminum' : 'fiber';
        final resolvedWidth = unit.meshRollWidthCm > 0
            ? unit.meshRollWidthCm
            : _pickBestMeshRollWidth(mType, screenW, screenH);
        final cutAdvanceCm =
            _advanceAlongRollCm(resolvedWidth.toDouble(), screenW, screenH);
        final meshKey = '${mType}_$resolvedWidth';
        meshTypeByKey[meshKey] = mType;
        meshWidthByKey[meshKey] = resolvedWidth;
        meshScreensByKey[meshKey] = (meshScreensByKey[meshKey] ?? 0) + unitScreens;
        meshLengthCmByKey[meshKey] =
            (meshLengthCmByKey[meshKey] ?? 0.0) + (cutAdvanceCm * unitScreens);
      }

      final unitColor =
          normalizeProfileColor(unit.effectiveColor(projectDefaults));

      // 1. Collect profile pieces
      for (final piece in calc.pieces) {
        final totalPieceQty = piece.quantity * unit.quantity;
        if (totalPieceQty <= 0) continue;

        final pKey = '${piece.itemCode}::$unitColor';
        itemArabicNames[piece.itemCode] = piece.nameArabic;
        pieceCountByItemColor[pKey] =
            (pieceCountByItemColor[pKey] ?? 0) + totalPieceQty;

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
            color: unitColor,
          ),
        );
      }

      // 2. Collect glass area & pane counts per glass type
      if (calc.glass.quantity > 0 &&
          calc.glass.paneWidthCm > 0 &&
          calc.glass.paneHeightCm > 0) {
        final panes = calc.glass.quantity * unit.quantity;
        final areaM2 = calc.glass.singlePaneAreaM2 * panes;
        final effGlassType = unit.effectiveGlassType(projectDefaults);
        final effGlassThick = unit.effectiveGlassThicknessMm(projectDefaults);
        final effGlazingMode = unit.effectiveGlazingMode(projectDefaults);
        final gType = effGlassType.isNotEmpty ? effGlassType : 'clear';
        final gThick = effGlassThick.toInt();
        final gMode = effGlazingMode.isNotEmpty ? effGlazingMode : 'single';
        final key = 'glass_pane_${gType}_${gThick}mm_$gMode';

        glassPanesByKey[key] = (glassPanesByKey[key] ?? 0) + panes;
        if (areaM2 > 0) {
          glassAreaByKey[key] = (glassAreaByKey[key] ?? 0.0) + areaM2;
        }
        glassLabelByKey[key] =
            'زجاج ${_glassTypeArabic(gType)} $gThick ملم (${_glazingModeArabic(gMode)})';
      }

      // 3. Collect accessories (color-matched for visible handles & plugs)
      for (final acc in calc.accessories) {
        final count = acc.quantity * unit.quantity;
        if (count <= 0) continue;
        final isColored = coloredAccessoryCodes.contains(acc.code);
        final accKey = isColored ? '${acc.code}::$unitColor' : acc.code;
        accessoryTotals[accKey] = (accessoryTotals[accKey] ?? 0) + count;
        accessoryCodes[accKey] = acc.code;
        accessoryColors[accKey] = isColored ? unitColor : null;
        accessoryNames[accKey] = acc.nameArabic;
        accessoryUnits[accKey] = acc.unit;
      }
    }

    // Compute new 660 cm bars needed per (itemCode, color) (excluding shelf remnants)
    final optResult = savedCutPlanResult ??
        optimizer.optimize(
          pieces: allCutPieces,
          availableRemnants: availableRemnants,
        );
    final barsByItemColor = <String, int>{};
    final remnantsUsedByItemColor = <String, int>{};
    final barItemCodes = <String, String>{};
    final barColors = <String, String>{};

    for (final bar in optResult.barPlans) {
      final normColor = normalizeProfileColor(bar.color);
      final key = '${bar.itemCode}::$normColor';
      barItemCodes[key] = bar.itemCode;
      barColors[key] = normColor;
      if (bar.isFromRemnant) {
        remnantsUsedByItemColor[key] =
            (remnantsUsedByItemColor[key] ?? 0) + 1;
      } else {
        barsByItemColor[key] = (barsByItemColor[key] ?? 0) + 1;
      }
    }

    // 1. Aluminum Bar RequirementLines (grouped by profile + color)
    for (final entry in barsByItemColor.entries) {
      final key = entry.key;
      final itemCode = barItemCodes[key]!;
      final barColor = barColors[key]!;
      final barsNeeded = entry.value;
      if (barsNeeded <= 0) continue;

      final cat = findCatalogByEngineCode(itemCode);
      final pieceCount = pieceCountByItemColor[key] ?? 0;
      final remnantsCount = remnantsUsedByItemColor[key] ?? 0;
      final reqQty = barsNeeded.toDouble();

      final noteParts = <String>[];
      if (pieceCount > 0) {
        noteParts.add('إجمالي $pieceCount قطعة مقصوصة');
      }
      if (remnantsCount > 0) {
        noteParts.add('تم استثناء $remnantsCount فضلة مستخدمة من الرف');
      }

      final baseName = cat?.arabicName ??
          '${itemArabicNames[itemCode] ?? itemCode} (قضيب 6.6م)';
      final colorLabel = profileColorLabelAr(barColor);

      lines.add(
        RequirementLine(
          id: 'auto_al_${itemCode}_$barColor',
          itemId: cat?.id != null
              ? '${cat!.id}_$barColor'
              : 'cat_al_${itemCode}_$barColor',
          engineItemCode: itemCode,
          nameArabic: '$baseName — $colorLabel',
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
      final accKey = entry.key;
      final code = accessoryCodes[accKey] ?? accKey;
      final accColor = accessoryColors[accKey];
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

      final baseName = cat?.arabicName ?? (accessoryNames[accKey] ?? code);
      final lineName = accColor != null
          ? '$baseName — ${profileColorLabelAr(accColor)}'
          : baseName;
      final lineId =
          accColor != null ? 'auto_acc_${code}_$accColor' : 'auto_acc_$code';
      final lineItemId = cat?.id != null
          ? (accColor != null ? '${cat!.id}_$accColor' : cat!.id)
          : (accColor != null ? 'cat_acc_${code}_$accColor' : 'cat_acc_$code');

      lines.add(
        RequirementLine(
          id: lineId,
          itemId: lineItemId,
          engineItemCode: code,
          nameArabic: lineName,
          category: categoryId,
          requiredQty: reqQty,
          inStockQty: 0,
          toBuyQty: reqQty,
          unit: cat?.unit ?? (accessoryUnits[accKey] ?? 'piece'),
          note: '',
          source: 'auto',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    // 4. Mesh & Brush Rolls (Spec §8.7: strictly ROLL unit)
    for (final entry in meshScreensByKey.entries) {
      final meshKey = entry.key;
      final screensCount = entry.value;
      if (screensCount <= 0) continue;

      final mType = meshTypeByKey[meshKey] ?? 'fiber';
      final widthCm = meshWidthByKey[meshKey] ?? 120;
      final rollLengthMeters = mType == 'aluminum' ? 25 : 20;
      final rollLengthCm = rollLengthMeters * 100.0;
      final totalNeededCm = meshLengthCmByKey[meshKey] ?? 0.0;
      final rollsNeeded =
          totalNeededCm > 0 ? (totalNeededCm / rollLengthCm).ceil().clamp(1, 999) : 1;

      final typeAr = mType == 'aluminum' ? 'ألمنيوم' : 'فيبر';
      final engineCode = mType == 'aluminum' ? 'aluminum_mesh_roll' : 'fiber_mesh_roll';
      final meshCat = findCatalogByEngineCode(engineCode);

      lines.add(
        RequirementLine(
          id: 'auto_fb_${engineCode}_$widthCm',
          itemId: meshCat?.id ?? 'cat_fb_${mType}_$widthCm',
          engineItemCode: engineCode,
          nameArabic:
              'لفة شبك منخل $typeAr عرض $widthCm سم × $rollLengthMeters م',
          category: 'fiber',
          requiredQty: rollsNeeded.toDouble(),
          inStockQty: 0,
          toBuyQty: rollsNeeded.toDouble(),
          unit: 'roll',
          note: 'لعدد $screensCount ضلفة منخل · باللفة فقط (Spec §8.7)',
          source: 'auto',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    for (final entry in brushScreensByColor.entries) {
      final colorLabel = entry.key;
      final screensCount = entry.value;
      if (screensCount <= 0) continue;
      final brushCat = findCatalogByEngineCode('brush_450_roll');
      lines.add(
        RequirementLine(
          id: 'auto_fb_brush_450_$colorLabel',
          itemId: brushCat?.id ?? 'cat_fb_brush_450',
          engineItemCode: 'brush_450_roll',
          nameArabic: 'لفة فراشة منخل 450 ($colorLabel)',
          category: 'fiber',
          requiredQty: 1,
          inStockQty: 0,
          toBuyQty: 1,
          unit: 'roll',
          note: 'لعدد $screensCount ضلفة منخل · باللفة فقط (Spec §8.7)',
          source: 'auto',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    for (final entry in brushSashesByColor.entries) {
      final colorLabel = entry.key;
      final sashesCount = entry.value;
      if (sashesCount <= 0) continue;
      final brush900Cat = findCatalogByEngineCode('brush_900_roll');
      lines.add(
        RequirementLine(
          id: 'auto_fb_brush_900_$colorLabel',
          itemId: brush900Cat?.id ?? 'cat_fb_brush_900',
          engineItemCode: 'brush_900_roll',
          nameArabic: 'لفة فراشة زجاج 900 ($colorLabel)',
          category: 'fiber',
          requiredQty: 1,
          inStockQty: 0,
          toBuyQty: 1,
          unit: 'roll',
          note: 'لعدد $sashesCount درفة زجاج · باللفة فقط (Spec §8.7)',
          source: 'auto',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    return sortLines(lines);
  }

  static int _pickBestMeshRollWidth(
    String meshType,
    double screenW,
    double screenH,
  ) {
    final widths = meshType == 'aluminum'
        ? const [80, 100, 120, 150, 180]
        : const [80, 100, 120, 150, 214, 240];
    final minDim = screenW < screenH ? screenW : screenH;
    final maxDim = screenW > screenH ? screenW : screenH;
    // Prefer fitting the larger dimension into roll width if close, else smaller dimension
    for (final w in widths) {
      if (w >= maxDim) return w;
    }
    for (final w in widths) {
      if (w >= minDim) return w;
    }
    return widths.last;
  }

  static double _advanceAlongRollCm(
    double rollWidthCm,
    double screenW,
    double screenH,
  ) {
    final minDim = screenW < screenH ? screenW : screenH;
    final maxDim = screenW > screenH ? screenW : screenH;
    if (rollWidthCm >= maxDim) return minDim;
    return maxDim;
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
