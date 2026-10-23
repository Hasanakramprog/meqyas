import '../models/calculation_result.dart';
import '../models/optimization_models.dart';

class CutOptimizer {
  final double barLengthCm;
  final double trimLossCm; // total trim on both ends (e.g. 2 + 2 = 4 cm)
  final double kerfPerCutCm; // saw kerf per cut (0.5 cm)
  final double minRemnantCm; // threshold for useful remnant (50 cm)

  const CutOptimizer({
    this.barLengthCm = 660.0,
    this.trimLossCm = 4.0,
    this.kerfPerCutCm = 0.5,
    this.minRemnantCm = 50.0,
  });

  double get usableBarLengthCm => barLengthCm - trimLossCm;

  /// Optimize cut pieces, optionally reusing shelf remnants first.
  ///
  /// [availableRemnants] — remnants from the workshop stock shelf.
  /// For each item group, the largest fitting remnant is used before
  /// opening a new full bar (remnant-first strategy).
  OptimizationResult optimize({
    required List<CutPiece> pieces,
    String defaultColor = 'white',
    List<RemnantStock> availableRemnants = const [],
  }) {
    if (pieces.isEmpty) {
      return const OptimizationResult(
        barPlans: [],
        summary: OptimizationSummary(
          totalBarsNeeded: 0,
          totalCutLengthCm: 0,
          totalTrimLossCm: 0,
          totalKerfLossCm: 0,
          totalScrapCm: 0,
          totalReusableRemnantsCm: 0,
          scrapPercentage: 0,
        ),
      );
    }

    // 1. Group pieces by itemCode
    final grouped = <String, List<CutPiece>>{};
    for (final p in pieces) {
      grouped.putIfAbsent(p.itemCode, () => []).add(p);
    }

    // 2. Group available remnants by itemCode
    final remnantsByItem = <String, List<RemnantStock>>{};
    for (final r in availableRemnants) {
      remnantsByItem.putIfAbsent(r.itemCode, () => []).add(r);
    }
    // Sort each group: longest remnant first
    for (final list in remnantsByItem.values) {
      list.sort((a, b) => b.lengthCm.compareTo(a.lengthCm));
    }

    final allBarPlans = <BarCuttingPlan>[];
    final allOversizedCuts = <PlannedCut>[];
    final consumedRemnantIds = <String>[];
    var globalBarIndex = 1;

    for (final entry in grouped.entries) {
      final itemCode = entry.key;
      final groupPieces = entry.value;

      // Expand pieces by quantity into individual cuts
      final individualCuts = <PlannedCut>[];
      var cutIdx = 1;
      for (final p in groupPieces) {
        for (var i = 0; i < p.quantity; i++) {
          individualCuts.add(
            PlannedCut(
              itemCode: p.itemCode,
              nameArabic: p.nameArabic,
              lengthCm: p.lengthCm,
              pieceIndex: cutIdx++,
              unitTag: p.unitTag,
            ),
          );
        }
      }

      // Sort descending (First-Fit Decreasing)
      individualCuts.sort((a, b) => b.lengthCm.compareTo(a.lengthCm));

      // Available remnants for this item (mutable working copy)
      final workingRemnants = List<RemnantStock>.from(
        remnantsByItem[itemCode] ?? [],
      );
      // Track which remnant each bar slot uses
      final remnantBarSlots = <String, _MutableBar>{}; // remnantId → bar slot

      final unassignedCuts = <PlannedCut>[];

      // --- Phase A: Remnant-first assignment ---
      for (final cut in individualCuts) {
        if (cut.lengthCm > usableBarLengthCm) {
          // Oversized — can't fit even in a full bar
          allOversizedCuts.add(cut);
          continue;
        }

        // Find best fitting remnant (smallest remnant that fits — best-fit)
        RemnantStock? bestRemnant;
        _MutableBar? existingRemnantBar;

        // First check if an already-opened remnant bar has space
        for (final r in workingRemnants) {
          final openBar = remnantBarSlots[r.id];
          if (openBar != null && openBar.canFit(cut.lengthCm, kerfPerCutCm)) {
            bestRemnant = r;
            existingRemnantBar = openBar;
            break;
          }
        }

        if (bestRemnant == null) {
          // Try to open a new remnant bar
          for (final r in workingRemnants) {
            if (remnantBarSlots.containsKey(r.id)) continue; // already opened
            // Remnant has no trim loss (already trimmed) — usable = full length
            final usable = r.lengthCm;
            if (usable >= cut.lengthCm + kerfPerCutCm) {
              bestRemnant = r;
              break;
            }
          }
        }

        if (bestRemnant != null) {
          // Use this remnant
          if (existingRemnantBar != null) {
            existingRemnantBar.addCut(
              PlannedCut(
                itemCode: cut.itemCode,
                nameArabic: cut.nameArabic,
                lengthCm: cut.lengthCm,
                pieceIndex: cut.pieceIndex,
                unitTag: cut.unitTag,
                fromRemnantId: bestRemnant.id,
              ),
              kerfPerCutCm,
            );
          } else {
            // Open new remnant bar slot
            final remnantBar = _MutableBar(
              barNumber: globalBarIndex++,
              itemCode: itemCode,
              color: defaultColor,
              usableLength: bestRemnant.lengthCm, // no trim for remnants
              sourceKind: BarSourceKind.remnant,
              sourceRemnantId: bestRemnant.id,
              sourceRemnantLengthCm: bestRemnant.lengthCm,
              sourceRemnantProjectName: bestRemnant.sourceProjectName,
            );
            remnantBar.addCut(
              PlannedCut(
                itemCode: cut.itemCode,
                nameArabic: cut.nameArabic,
                lengthCm: cut.lengthCm,
                pieceIndex: cut.pieceIndex,
                unitTag: cut.unitTag,
                fromRemnantId: bestRemnant.id,
              ),
              kerfPerCutCm,
            );
            remnantBarSlots[bestRemnant.id] = remnantBar;
            if (!consumedRemnantIds.contains(bestRemnant.id)) {
              consumedRemnantIds.add(bestRemnant.id);
            }
          }
        } else {
          // No remnant available — queue for standard FFD
          unassignedCuts.add(cut);
        }
      }

      // --- Phase B: Standard First-Fit-Decreasing on full bars ---
      final fullBarsForGroup = <_MutableBar>[];

      for (final cut in unassignedCuts) {
        _MutableBar? targetBar;
        for (final bar in fullBarsForGroup) {
          if (bar.canFit(cut.lengthCm, kerfPerCutCm)) {
            targetBar = bar;
            break;
          }
        }
        if (targetBar == null) {
          targetBar = _MutableBar(
            barNumber: globalBarIndex++,
            itemCode: itemCode,
            color: defaultColor,
            usableLength: usableBarLengthCm,
          );
          fullBarsForGroup.add(targetBar);
        }
        targetBar.addCut(cut, kerfPerCutCm);
      }

      // Convert remnant bars → BarCuttingPlan
      for (final entry in remnantBarSlots.entries) {
        final b = entry.value;
        allBarPlans.add(_buildPlan(b, minRemnantCm, kerfPerCutCm, trimLoss: 0));
      }

      // Convert full bars → BarCuttingPlan
      for (final b in fullBarsForGroup) {
        allBarPlans.add(_buildPlan(b, minRemnantCm, kerfPerCutCm, trimLoss: trimLossCm));
      }
    }

    // Sort bar plans by barNumber for a clean display order
    allBarPlans.sort((a, b) => a.barNumber.compareTo(b.barNumber));

    // Compute summary
    var totalCutLength = 0.0;
    var totalKerf = 0.0;
    var totalTrim = 0.0;
    var totalScrap = 0.0;
    var totalRemnants = 0.0;
    var fullBarsCount = 0;

    for (final plan in allBarPlans) {
      totalCutLength += plan.totalCutsLengthCm;
      totalKerf += plan.totalKerfLossCm;
      totalTrim += plan.trimLossCm;
      totalScrap += plan.scrapWasteCm;
      totalRemnants += plan.reusableRemnantCm;
      if (!plan.isFromRemnant) fullBarsCount++;
    }

    final totalRawLength = fullBarsCount * barLengthCm;
    final scrapPercentage =
        totalRawLength > 0 ? (totalScrap / totalRawLength) * 100.0 : 0.0;
    final remnantsReused = consumedRemnantIds.length;
    // Approximate bars saved: total cuts length that came from remnants / usable bar length
    final remnantsBarPlans = allBarPlans.where((p) => p.isFromRemnant);
    final totalCutsFromRemnants = remnantsBarPlans.fold<double>(
        0.0, (acc, p) => acc + p.totalCutsLengthCm);
    final barsSaved = usableBarLengthCm > 0
        ? totalCutsFromRemnants / usableBarLengthCm
        : 0.0;

    return OptimizationResult(
      barPlans: allBarPlans,
      summary: OptimizationSummary(
        totalBarsNeeded: fullBarsCount,
        remnantsReused: remnantsReused,
        totalCutLengthCm: totalCutLength,
        totalTrimLossCm: totalTrim,
        totalKerfLossCm: totalKerf,
        totalScrapCm: totalScrap,
        totalReusableRemnantsCm: totalRemnants,
        scrapPercentage: scrapPercentage,
        barsSavedByRemnants: barsSaved,
      ),
      oversizedCuts: allOversizedCuts,
      consumedRemnantIds: consumedRemnantIds,
    );
  }

  BarCuttingPlan _buildPlan(
    _MutableBar b,
    double minRemnantCm,
    double kerfPerCutCm, {
    required double trimLoss,
  }) {
    final totalCutsLength =
        b.cuts.fold<double>(0.0, (acc, c) => acc + c.lengthCm);
    final totalKerf = b.cuts.length * kerfPerCutCm;
    final remaining = b.usableLength - totalCutsLength - totalKerf;
    final normalizedRemaining = remaining < 0.0001 ? 0.0 : remaining;
    final isUseful = normalizedRemaining >= minRemnantCm;

    return BarCuttingPlan(
      barNumber: b.barNumber,
      itemCode: b.itemCode,
      color: b.color,
      totalBarLengthCm:
          b.sourceKind == BarSourceKind.remnant ? b.usableLength : barLengthCm,
      trimLossCm: trimLoss,
      kerfPerCutCm: kerfPerCutCm,
      cuts: b.cuts,
      totalCutsLengthCm: totalCutsLength,
      totalKerfLossCm: totalKerf,
      remainingLengthCm: normalizedRemaining,
      isRemnantUseful: isUseful,
      sourceKind: b.sourceKind,
      sourceRemnantId: b.sourceRemnantId,
      sourceRemnantLengthCm: b.sourceRemnantLengthCm,
      sourceRemnantProjectName: b.sourceRemnantProjectName,
    );
  }
}

class _MutableBar {
  final int barNumber;
  final String itemCode;
  final String color;
  final double usableLength;
  final List<PlannedCut> cuts = [];
  double currentUsed = 0.0;
  final BarSourceKind sourceKind;
  final String? sourceRemnantId;
  final double? sourceRemnantLengthCm;
  final String? sourceRemnantProjectName;

  _MutableBar({
    required this.barNumber,
    required this.itemCode,
    required this.color,
    required this.usableLength,
    this.sourceKind = BarSourceKind.fullBar,
    this.sourceRemnantId,
    this.sourceRemnantLengthCm,
    this.sourceRemnantProjectName,
  });

  bool canFit(double cutLength, double kerf) =>
      (currentUsed + cutLength + kerf) <= usableLength;

  void addCut(PlannedCut cut, double kerf) {
    cuts.add(cut);
    currentUsed += cut.lengthCm + kerf;
  }
}
