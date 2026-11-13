class UnitSpecification {
  final double widthCm; // W
  final double heightCm; // H
  final int quantity; // N
  final String unitType; // 'window' or 'facade'
  final String glazingMode; // 'single' or 'double'
  final String sharhOption; // 'none', 'one_side', 'two_sides'
  final int sashCount; // typically 2
  final int screenCount; // typically 1 or 0
  final bool hasScreen;
  final String profileSystemId; // e.g. 'system_2000_beaded'
  final String rollerType; // 'slider', 'modified_2000', 'milled'
  final String glassType; // 'clear', 'frosted', 'reflective', 'smoked'
  final double glassThicknessMm; // 6, 8, 10
  final bool hasCorners;
  final bool hasGasket;
  final String brushColor; // 'أسود', 'بني', 'رمادي', 'أبيض'
  final String glassRollerType; // '', 'roller_2000_single', 'roller_2000_double'
  final int glassRollerCount; // even count, e.g. 2, 4, 6
  final String frameGasketType; // 'frame_gasket', 'none'
  final String screenCornerType; // 'screen_corner', 'none'
  final int puttyQtyPerUnit; // optional integer >= 0
  final String meshType; // 'fiber' or 'aluminum'
  final int meshRollWidthCm; // 0 = auto least-waste, or 80/100/120/150/180/214/240
  final Map<String, dynamic> customOptions;

  const UnitSpecification({
    required this.widthCm,
    required this.heightCm,
    this.quantity = 1,
    this.unitType = 'window',
    this.glazingMode = 'single',
    this.sharhOption = 'none',
    this.sashCount = 2,
    this.screenCount = 1,
    this.hasScreen = true,
    required this.profileSystemId,
    this.rollerType = 'slider',
    this.glassType = 'clear',
    this.glassThicknessMm = 6.0,
    this.hasCorners = true,
    this.hasGasket = true,
    this.brushColor = 'أسود',
    this.glassRollerType = '',
    this.glassRollerCount = 4,
    this.frameGasketType = 'frame_gasket',
    this.screenCornerType = 'screen_corner',
    this.puttyQtyPerUnit = 0,
    this.meshType = 'fiber',
    this.meshRollWidthCm = 0,
    this.customOptions = const {},
  });

  Map<String, dynamic> toEnvironment() {
    final sharhAllowance = switch (sharhOption) {
      'one_side' => 2.5,
      'two_sides' => 0.0,
      _ => 5.0,
    };
    final sharhDeduction = 5.0 - sharhAllowance;

    return {
      'W': widthCm,
      'H': heightCm,
      'N': quantity,
      'unitType': unitType,
      'glazingMode': glazingMode,
      'sharhOption': sharhOption,
      'sharhAllowance': sharhAllowance,
      'sharhDeduction': sharhDeduction,
      'sashCount': sashCount,
      'screenCount': hasScreen ? screenCount : 0,
      'hasScreen': hasScreen,
      'profileSystemId': profileSystemId,
      'rollerType': rollerType,
      'glassType': glassType,
      'glassThicknessMm': glassThicknessMm,
      'hasCorners': hasCorners,
      'hasGasket': hasGasket,
      ...customOptions,
    };
  }
}
