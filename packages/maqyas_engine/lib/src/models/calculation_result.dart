class CutPiece {
  final String itemCode;
  final String nameArabic;
  final double lengthCm;
  final int quantity;
  final double cutAngleLeft; // e.g. 90.0 or 45.0
  final double cutAngleRight; // e.g. 90.0 or 45.0
  final String profileType; // 'track', 'jamb', 'sash', 'screen', 'bead'
  final String? ruleVersionId;

  const CutPiece({
    required this.itemCode,
    required this.nameArabic,
    required this.lengthCm,
    required this.quantity,
    this.cutAngleLeft = 90.0,
    this.cutAngleRight = 90.0,
    required this.profileType,
    this.ruleVersionId,
  });

  double get totalLengthCm => lengthCm * quantity;

  @override
  String toString() => '$nameArabic ($itemCode): ${lengthCm.toStringAsFixed(2)} cm x $quantity';
}

class GlassSpecification {
  final double paneWidthCm;
  final double paneHeightCm;
  final int quantity; // number of panes
  final String glazingMode; // 'single' or 'double'
  final String glassType; // e.g. 'clear', 'frosted'
  final double thicknessMm; // e.g. 6.0, 8.0, 10.0

  const GlassSpecification({
    required this.paneWidthCm,
    required this.paneHeightCm,
    required this.quantity,
    required this.glazingMode,
    required this.glassType,
    required this.thicknessMm,
  });

  /// Surface area of a single pane in m²
  double get singlePaneAreaM2 => (paneWidthCm * paneHeightCm) / 10000.0;

  /// Total surface area across all panes in m²
  double get totalAreaM2 => singlePaneAreaM2 * quantity;

  /// Approximate glass weight in kg (Formula: Area m² * thickness mm * 2.5 kg/m²/mm)
  double get weightKg {
    const glassDensityFactor = 2.5; // kg per m² per mm of thickness
    final multiplier = glazingMode == 'double' ? 2 : 1;
    return totalAreaM2 * thicknessMm * glassDensityFactor * multiplier;
  }
}

class AccessoryItem {
  final String code;
  final String nameArabic;
  final int quantity;
  final String unit; // 'piece', 'pair', 'set', 'roll', 'meter'

  const AccessoryItem({
    required this.code,
    required this.nameArabic,
    required this.quantity,
    this.unit = 'piece',
  });
}

enum IssueSeverity { warning, error }

class RuleIssue {
  final String itemCode;
  final String message;
  final IssueSeverity severity;

  const RuleIssue({
    required this.itemCode,
    required this.message,
    this.severity = IssueSeverity.error,
  });

  @override
  String toString() => '[$severity] $itemCode: $message';
}

class CalculationResult {
  final List<CutPiece> pieces;
  final GlassSpecification glass;
  final List<AccessoryItem> accessories;
  final List<RuleIssue> issues;
  final List<String> ruleVersionIdsUsed;

  const CalculationResult({
    required this.pieces,
    required this.glass,
    required this.accessories,
    this.issues = const [],
    this.ruleVersionIdsUsed = const [],
  });

  bool get isValid => !issues.any((i) => i.severity == IssueSeverity.error);
}
