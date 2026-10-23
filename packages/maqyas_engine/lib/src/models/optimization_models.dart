/// Represents a leftover aluminum piece available on the workshop shelf.
/// Pure Dart — no Firebase imports. The repository layer maps Firestore docs to this.
class RemnantStock {
  final String id; // Firestore document ID
  final String itemCode;
  final String nameArabic;
  final String color;
  final double lengthCm;
  final String sourceProjectName;

  const RemnantStock({
    required this.id,
    required this.itemCode,
    required this.nameArabic,
    required this.color,
    required this.lengthCm,
    required this.sourceProjectName,
  });
}

/// Whether a bar slot was opened from a new full bar or a workshop remnant.
enum BarSourceKind { fullBar, remnant }

class PlannedCut {
  final String itemCode;
  final String nameArabic;
  final double lengthCm;
  final int pieceIndex; // index in overall plan
  final String? unitTag; // e.g. "W1", "شباك 1"

  /// Non-null when this cut was sourced from a workshop remnant (not a new bar).
  final String? fromRemnantId;

  const PlannedCut({
    required this.itemCode,
    required this.nameArabic,
    required this.lengthCm,
    required this.pieceIndex,
    this.unitTag,
    this.fromRemnantId,
  });

  bool get isFromRemnant => fromRemnantId != null;
}

class BarCuttingPlan {
  final int barNumber;
  final String itemCode;
  final String color;

  /// 660 for new bar; the remnant's original length for remnant-sourced bars.
  final double totalBarLengthCm;

  /// 4 cm for new full bars (2cm per end); 0 for remnant bars (already trimmed).
  final double trimLossCm;
  final double kerfPerCutCm;
  final List<PlannedCut> cuts;
  final double totalCutsLengthCm;
  final double totalKerfLossCm;
  final double remainingLengthCm;
  final bool isRemnantUseful; // remaining >= minRemnantCm

  /// Whether this bar slot came from a new full bar or an existing shelf remnant.
  final BarSourceKind sourceKind;

  /// Populated when [sourceKind] == [BarSourceKind.remnant].
  final String? sourceRemnantId;
  final double? sourceRemnantLengthCm;
  final String? sourceRemnantProjectName;

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
    this.sourceKind = BarSourceKind.fullBar,
    this.sourceRemnantId,
    this.sourceRemnantLengthCm,
    this.sourceRemnantProjectName,
  });

  bool get isFromRemnant => sourceKind == BarSourceKind.remnant;

  /// Pure waste: trim loss + kerf + scrap under threshold
  double get scrapWasteCm =>
      trimLossCm + totalKerfLossCm + (isRemnantUseful ? 0.0 : remainingLengthCm);

  /// Useful offcut length if >= minRemnantCm, else 0
  double get reusableRemnantCm => isRemnantUseful ? remainingLengthCm : 0.0;
}

class OptimizationSummary {
  final int totalBarsNeeded; // new full bars opened
  final int remnantsReused; // shelf remnants consumed
  final double totalCutLengthCm;
  final double totalTrimLossCm;
  final double totalKerfLossCm;
  final double totalScrapCm;
  final double totalReusableRemnantsCm;
  final double scrapPercentage;
  final double barsSavedByRemnants; // equivalent full bars saved

  const OptimizationSummary({
    required this.totalBarsNeeded,
    this.remnantsReused = 0,
    required this.totalCutLengthCm,
    required this.totalTrimLossCm,
    required this.totalKerfLossCm,
    required this.totalScrapCm,
    required this.totalReusableRemnantsCm,
    required this.scrapPercentage,
    this.barsSavedByRemnants = 0,
  });
}

class OptimizationResult {
  final List<BarCuttingPlan> barPlans;
  final OptimizationSummary summary;
  final List<PlannedCut> oversizedCuts;

  /// IDs of remnants consumed in this plan — mark them 'used' when plan is saved.
  final List<String> consumedRemnantIds;

  const OptimizationResult({
    required this.barPlans,
    required this.summary,
    this.oversizedCuts = const [],
    this.consumedRemnantIds = const [],
  });

  bool get hasOversizedCuts => oversizedCuts.isNotEmpty;
  bool get usedRemnants => consumedRemnantIds.isNotEmpty;
}
