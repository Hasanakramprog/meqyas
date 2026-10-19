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

  OptimizationResult optimize({
    required List<CutPiece> pieces,
    String defaultColor = 'white',
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

    final allBarPlans = <BarCuttingPlan>[];
    final allOversizedCuts = <PlannedCut>[];
    var globalBarIndex = 1;

    for (final entry in grouped.entries) {
      final itemCode = entry.key;
      final groupPieces = entry.value;

      // Expand pieces by quantity
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
            ),
          );
        }
      }

      // 2. Sort descending (First-Fit Decreasing)
      individualCuts.sort((a, b) => b.lengthCm.compareTo(a.lengthCm));

      // 3. Pack into bars
      final barsForGroup = <_MutableBar>[];

      for (final cut in individualCuts) {
        if (cut.lengthCm > usableBarLengthCm) {
          allOversizedCuts.add(cut);
          continue;
        }

        // Find first bar that can accommodate this cut
        _MutableBar? targetBar;
        for (final bar in barsForGroup) {
          if (bar.canFit(cut.lengthCm, kerfPerCutCm)) {
            targetBar = bar;
            break;
          }
        }

        if (targetBar == null) {
          // Open a new bar
          targetBar = _MutableBar(
            barNumber: globalBarIndex++,
            itemCode: itemCode,
            color: defaultColor,
            usableLength: usableBarLengthCm,
          );
          barsForGroup.add(targetBar);
        }

        targetBar.addCut(cut, kerfPerCutCm);
      }

      // Convert mutable bars to BarCuttingPlan
      for (final b in barsForGroup) {
        final totalCutsLength = b.cuts.fold<double>(0.0, (acc, c) => acc + c.lengthCm);
        final totalKerf = b.cuts.length * kerfPerCutCm;
        final remaining = usableBarLengthCm - totalCutsLength - totalKerf;
        final normalizedRemaining = remaining < 0.0001 ? 0.0 : remaining;
        final isUseful = normalizedRemaining >= minRemnantCm;

        allBarPlans.add(
          BarCuttingPlan(
            barNumber: b.barNumber,
            itemCode: itemCode,
            color: defaultColor,
            totalBarLengthCm: barLengthCm,
            trimLossCm: trimLossCm,
            kerfPerCutCm: kerfPerCutCm,
            cuts: b.cuts,
            totalCutsLengthCm: totalCutsLength,
            totalKerfLossCm: totalKerf,
            remainingLengthCm: normalizedRemaining,
            isRemnantUseful: isUseful,
          ),
        );
      }
    }

    // 4. Compute comprehensive summary metrics
    var totalCutLength = 0.0;
    var totalKerf = 0.0;
    var totalTrim = 0.0;
    var totalScrap = 0.0;
    var totalRemnants = 0.0;

    for (final plan in allBarPlans) {
      totalCutLength += plan.totalCutsLengthCm;
      totalKerf += plan.totalKerfLossCm;
      totalTrim += plan.trimLossCm;
      totalScrap += plan.scrapWasteCm;
      totalRemnants += plan.reusableRemnantCm;
    }

    final totalRawLength = allBarPlans.length * barLengthCm;
    final scrapPercentage = totalRawLength > 0 ? (totalScrap / totalRawLength) * 100.0 : 0.0;

    final summary = OptimizationSummary(
      totalBarsNeeded: allBarPlans.length,
      totalCutLengthCm: totalCutLength,
      totalTrimLossCm: totalTrim,
      totalKerfLossCm: totalKerf,
      totalScrapCm: totalScrap,
      totalReusableRemnantsCm: totalRemnants,
      scrapPercentage: scrapPercentage,
    );

    return OptimizationResult(
      barPlans: allBarPlans,
      summary: summary,
      oversizedCuts: allOversizedCuts,
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

  _MutableBar({
    required this.barNumber,
    required this.itemCode,
    required this.color,
    required this.usableLength,
  });

  bool canFit(double cutLength, double kerf) {
    // Additional space needed = piece length + kerf loss
    final additionalNeeded = cutLength + kerf;
    return (currentUsed + additionalNeeded) <= usableLength;
  }

  void addCut(PlannedCut cut, double kerf) {
    cuts.add(cut);
    currentUsed += cut.lengthCm + kerf;
  }
}
