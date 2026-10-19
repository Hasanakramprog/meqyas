class PlannedCut {
  final String itemCode;
  final String nameArabic;
  final double lengthCm;
  final int pieceIndex; // index in overall plan

  const PlannedCut({
    required this.itemCode,
    required this.nameArabic,
    required this.lengthCm,
    required this.pieceIndex,
  });
}

class BarCuttingPlan {
  final int barNumber;
  final String itemCode;
  final String color;
  final double totalBarLengthCm; // default 660 cm
  final double trimLossCm; // default 4 cm (2cm per end)
  final double kerfPerCutCm; // default 0.5 cm
  final List<PlannedCut> cuts;
  final double totalCutsLengthCm;
  final double totalKerfLossCm;
  final double remainingLengthCm;
  final bool isRemnantUseful; // >= 50 cm

  const BarCuttingPlan({
    required this.barNumber,
    required this.itemCode,
    required this.color,
    required this.totalBarLengthCm,
    required this.trimLossCm,
    required this.kerfPerCutCm,
    required this.cuts,
    required this.totalCutsLengthCm,
    required this.totalKerfLossCm,
    required this.remainingLengthCm,
    required this.isRemnantUseful,
  });

  /// The length categorized as pure waste (trim + kerf + scrap remnant < 50cm)
  double get scrapWasteCm =>
      trimLossCm + totalKerfLossCm + (isRemnantUseful ? 0.0 : remainingLengthCm);

  /// Useful offcut length if >= 50 cm, else 0
  double get reusableRemnantCm => isRemnantUseful ? remainingLengthCm : 0.0;
}

class OptimizationSummary {
  final int totalBarsNeeded;
  final double totalCutLengthCm;
  final double totalTrimLossCm;
  final double totalKerfLossCm;
  final double totalScrapCm;
  final double totalReusableRemnantsCm;
  final double scrapPercentage; // scrap / (totalBarsNeeded * 660) * 100

  const OptimizationSummary({
    required this.totalBarsNeeded,
    required this.totalCutLengthCm,
    required this.totalTrimLossCm,
    required this.totalKerfLossCm,
    required this.totalScrapCm,
    required this.totalReusableRemnantsCm,
    required this.scrapPercentage,
  });
}

class OptimizationResult {
  final List<BarCuttingPlan> barPlans;
  final OptimizationSummary summary;
  final List<PlannedCut> oversizedCuts;

  const OptimizationResult({
    required this.barPlans,
    required this.summary,
    this.oversizedCuts = const [],
  });

  bool get hasOversizedCuts => oversizedCuts.isNotEmpty;
}
