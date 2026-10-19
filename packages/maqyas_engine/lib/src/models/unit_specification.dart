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
    this.customOptions = const {},
  });

  Map<String, dynamic> toEnvironment() {
    return {
      'W': widthCm,
      'H': heightCm,
      'N': quantity,
      'unitType': unitType,
      'glazingMode': glazingMode,
      'sharhOption': sharhOption,
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
