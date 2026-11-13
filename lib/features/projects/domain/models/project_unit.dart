import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import 'project.dart';

class ProjectUnit {
  final String id;
  final String projectId;
  final String name; // e.g. 'شباك 1', 'واجهة 1'
  final String location; // e.g. 'الدور الأرضي - واجهة غربية'
  final double widthCm;
  final double heightCm;
  final int quantity;
  final String unitType; // 'window' or 'facade' (or dynamic itemTypeId)
  final String glazingMode; // 'single' or 'double'
  final String sharhOption; // 'none', 'one_side', 'two_sides'
  final int sashCount; // typically 2
  final int screenCount; // typically 1 or 0
  final bool hasScreen;
  final String profileSystemId; // e.g. 'system_2000_beaded'
  final String color; // 'white', 'black', 'champagne', 'bronze', 'grey', 'wood'
  final String rollerType; // 'slider', 'modified_2000', 'milled'
  final String glassType; // 'clear', 'frosted', 'reflective', 'smoked'
  final double glassThicknessMm;
  final bool hasCorners;
  final bool hasGasket;
  final String brushColor; // 'أسود', 'بني', 'رمادي', 'أبيض'
  final String glassRollerType; // '', 'roller_2000_single', 'roller_2000_double'
  final int glassRollerCount; // even count, e.g. 2, 4, 6
  final String frameGasketType; // 'frame_gasket', 'none'
  final String screenCornerType; // 'screen_corner', 'none'
  final int puttyQtyPerUnit;
  final String meshType; // 'fiber' or 'aluminum'
  final int meshRollWidthCm; // 0 = auto least-waste
  final List<String> ruleVersionIdsUsed;

  /// Sparse map of unit-level customized properties ("تخصيص لعنصر محدد").
  /// Keys present here override [ProjectDefaults]. Removing a key restores the
  /// project default ("استرجاع الافتراضي").
  /// Supported keys:
  /// - 'profileSystemId' (String)
  /// - 'glazingMode' (String)
  /// - 'color' (String)
  /// - 'glassType' (String)
  /// - 'glassThicknessMm' (double)
  /// - 'hasGasket' (bool)
  /// - 'ruleOverrides' (`Map<String, Map<String, String>>`)
  final Map<String, dynamic> overrides;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectUnit({
    required this.id,
    required this.projectId,
    required this.name,
    this.location = '',
    required this.widthCm,
    required this.heightCm,
    this.quantity = 1,
    this.unitType = 'window',
    this.glazingMode = 'double',
    this.sharhOption = 'none',
    this.sashCount = 2,
    this.screenCount = 1,
    this.hasScreen = true,
    this.profileSystemId = SeedRules.system2000Beaded,
    this.color = 'white',
    this.rollerType = 'slider',
    this.glassType = 'clear',
    this.glassThicknessMm = 6.0,
    this.hasCorners = true,
    this.hasGasket = false,
    this.brushColor = 'أسود',
    this.glassRollerType = '',
    this.glassRollerCount = 4,
    this.frameGasketType = 'frame_gasket',
    this.screenCornerType = 'screen_corner',
    this.puttyQtyPerUnit = 0,
    this.meshType = 'fiber',
    this.meshRollWidthCm = 0,
    this.ruleVersionIdsUsed = const [],
    this.overrides = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  bool isFieldOverridden(String key) => overrides.containsKey(key);

  bool get hasAnyOverrides => overrides.isNotEmpty;

  String effectiveProfileSystemId([ProjectDefaults? defaults]) {
    if (overrides.containsKey('profileSystemId')) {
      return overrides['profileSystemId'] as String? ?? profileSystemId;
    }
    return defaults?.profileSystemId ?? profileSystemId;
  }

  String effectiveGlazingMode([ProjectDefaults? defaults]) {
    if (overrides.containsKey('glazingMode')) {
      return overrides['glazingMode'] as String? ?? glazingMode;
    }
    return defaults?.glazingMode ?? glazingMode;
  }

  String effectiveColor([ProjectDefaults? defaults]) {
    if (overrides.containsKey('color')) {
      return overrides['color'] as String? ?? color;
    }
    return defaults?.color ?? color;
  }

  String effectiveGlassType([ProjectDefaults? defaults]) {
    if (overrides.containsKey('glassType')) {
      return overrides['glassType'] as String? ?? glassType;
    }
    return defaults?.glassType ?? glassType;
  }

  double effectiveGlassThicknessMm([ProjectDefaults? defaults]) {
    if (overrides.containsKey('glassThicknessMm')) {
      return (overrides['glassThicknessMm'] as num?)?.toDouble() ??
          glassThicknessMm;
    }
    return defaults?.glassThicknessMm ?? glassThicknessMm;
  }

  bool effectiveHasGasket([ProjectDefaults? defaults]) {
    if (overrides.containsKey('hasGasket')) {
      return overrides['hasGasket'] as bool? ?? hasGasket;
    }
    return defaults?.hasGasket ?? hasGasket;
  }

  Map<String, Map<String, String>> get unitRuleOverrides {
    final raw = overrides['ruleOverrides'];
    if (raw is! Map) return const {};
    final result = <String, Map<String, String>>{};
    for (final entry in raw.entries) {
      if (entry.value is Map) {
        result[entry.key.toString()] = (entry.value as Map).map(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
        );
      }
    }
    return result;
  }

  /// Resolves the effective [UnitSpecification] by merging [ProjectDefaults]
  /// with this unit's sparse [overrides].
  UnitSpecification toEngineSpec([ProjectDefaults? defaults]) {
    final resolvedColor = effectiveColor(defaults);
    return UnitSpecification(
      widthCm: widthCm,
      heightCm: heightCm,
      quantity: quantity,
      unitType: unitType,
      glazingMode: effectiveGlazingMode(defaults),
      sharhOption: sharhOption,
      sashCount: sashCount,
      screenCount: screenCount,
      hasScreen: hasScreen,
      profileSystemId: effectiveProfileSystemId(defaults),
      rollerType: rollerType,
      glassType: effectiveGlassType(defaults),
      glassThicknessMm: effectiveGlassThicknessMm(defaults),
      hasCorners: hasCorners,
      hasGasket: effectiveHasGasket(defaults),
      brushColor: brushColor,
      glassRollerType: glassRollerType,
      glassRollerCount: glassRollerCount,
      frameGasketType: frameGasketType,
      screenCornerType: screenCornerType,
      puttyQtyPerUnit: puttyQtyPerUnit,
      meshType: meshType,
      meshRollWidthCm: meshRollWidthCm,
      customOptions: {'color': resolvedColor},
    );
  }

  /// Applies project-level and unit-level deduction overrides (`ruleOverrides`)
  /// on top of the workshop's effective rules.
  static List<CalculationRule> resolveEffectiveRules(
    List<CalculationRule> workshopRules, {
    ProjectDefaults? projectDefaults,
    Map<String, Map<String, String>>? unitRuleOverrides,
  }) {
    final projMap = projectDefaults?.ruleOverrides ?? const {};
    final unitMap = unitRuleOverrides ?? const {};
    if (projMap.isEmpty && unitMap.isEmpty) return workshopRules;

    return workshopRules.map((rule) {
      final uOverride = unitMap[rule.ruleKey];
      if (uOverride != null) {
        return rule.copyWith(
          lengthFormula: uOverride['lengthFormula']?.isNotEmpty == true
              ? uOverride['lengthFormula']!
              : rule.lengthFormula,
          quantityFormula: uOverride['quantityFormula']?.isNotEmpty == true
              ? uOverride['quantityFormula']!
              : rule.quantityFormula,
          notes: '[مخصص للعنصر] ${rule.notes ?? ""}'.trim(),
        );
      }
      final pOverride = projMap[rule.ruleKey];
      if (pOverride != null) {
        return rule.copyWith(
          lengthFormula: pOverride['lengthFormula']?.isNotEmpty == true
              ? pOverride['lengthFormula']!
              : rule.lengthFormula,
          quantityFormula: pOverride['quantityFormula']?.isNotEmpty == true
              ? pOverride['quantityFormula']!
              : rule.quantityFormula,
          notes: '[مخصص للمشروع] ${rule.notes ?? ""}'.trim(),
        );
      }
      return rule;
    }).toList();
  }

  /// Generates the next sequential Arabic name for a given [unitType] inside a project:
  /// - 1st window -> 'شباك 1', 2nd window -> 'شباك 2'
  /// - 1st facade -> 'واجهة 1', 2nd facade -> 'واجهة 2'
  /// - Any custom itemType -> `'<typeLabel> 1'`, `'<typeLabel> 2'`
  static String nextAutoName(
    String unitType,
    List<ProjectUnit> existingUnits, {
    String? customTypeLabelAr,
  }) {
    final prefix = customTypeLabelAr ?? unitTypeLabelAr(unitType);
    final sameTypeUnits =
        existingUnits.where((u) => u.unitType == unitType).toList();
    var maxNum = sameTypeUnits.length;

    final pattern = RegExp('^${RegExp.escape(prefix)}\\s*(\\d+)\$');
    for (final u in sameTypeUnits) {
      final match = pattern.firstMatch(u.name.trim());
      if (match != null) {
        final parsed = int.tryParse(match.group(1) ?? '');
        if (parsed != null && parsed > maxNum) {
          maxNum = parsed;
        }
      }
    }
    return '$prefix ${maxNum + 1}';
  }

  static String unitTypeLabelAr(String unitType) {
    switch (unitType) {
      case 'window':
        return 'شباك';
      case 'facade':
        return 'واجهة';
      case 'door':
        return 'باب';
      default:
        return unitType;
    }
  }

  /// Returns true if [name] matches an auto-generated default name like "شباك 1" or "واجهة 2".
  static bool isAutoGeneratedName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return true;
    return RegExp(r'^(شباك|واجهة|باب|عنصر)\s*\d*$').hasMatch(trimmed);
  }

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'name': name,
      'location': location,
      'widthCm': widthCm,
      'heightCm': heightCm,
      'quantity': quantity,
      'unitType': unitType,
      'glazingMode': glazingMode,
      'sharhOption': sharhOption,
      'sashCount': sashCount,
      'screenCount': screenCount,
      'hasScreen': hasScreen,
      'profileSystemId': profileSystemId,
      'color': color,
      'rollerType': rollerType,
      'glassType': glassType,
      'glassThicknessMm': glassThicknessMm,
      'hasCorners': hasCorners,
      'hasGasket': hasGasket,
      'brushColor': brushColor,
      'glassRollerType': glassRollerType,
      'glassRollerCount': glassRollerCount,
      'frameGasketType': frameGasketType,
      'screenCornerType': screenCornerType,
      'puttyQtyPerUnit': puttyQtyPerUnit,
      'meshType': meshType,
      'meshRollWidthCm': meshRollWidthCm,
      'ruleVersionIdsUsed': ruleVersionIdsUsed,
      'overrides': overrides,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ProjectUnit.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawOverrides = data['overrides'] as Map<String, dynamic>?;
    return ProjectUnit(
      id: doc.id,
      projectId: data['projectId'] as String? ?? '',
      name: data['name'] as String? ?? 'شباك 1',
      location: data['location'] as String? ?? '',
      widthCm: (data['widthCm'] as num?)?.toDouble() ?? 100.0,
      heightCm: (data['heightCm'] as num?)?.toDouble() ?? 100.0,
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      unitType: data['unitType'] as String? ?? 'window',
      glazingMode: data['glazingMode'] as String? ?? 'double',
      sharhOption: data['sharhOption'] as String? ?? 'none',
      sashCount: (data['sashCount'] as num?)?.toInt() ?? 2,
      screenCount: (data['screenCount'] as num?)?.toInt() ?? 1,
      hasScreen: data['hasScreen'] as bool? ?? true,
      profileSystemId:
          data['profileSystemId'] as String? ?? SeedRules.system2000Beaded,
      color: data['color'] as String? ?? 'white',
      rollerType: data['rollerType'] as String? ?? 'slider',
      glassType: data['glassType'] as String? ?? 'clear',
      glassThicknessMm: (data['glassThicknessMm'] as num?)?.toDouble() ?? 6.0,
      hasCorners: data['hasCorners'] as bool? ?? true,
      hasGasket: data['hasGasket'] as bool? ?? false,
      brushColor: data['brushColor'] as String? ?? 'أسود',
      glassRollerType: data['glassRollerType'] as String? ?? '',
      glassRollerCount: (data['glassRollerCount'] as num?)?.toInt() ?? 4,
      frameGasketType: data['frameGasketType'] as String? ?? 'frame_gasket',
      screenCornerType: data['screenCornerType'] as String? ?? 'screen_corner',
      puttyQtyPerUnit: (data['puttyQtyPerUnit'] as num?)?.toInt() ?? 0,
      meshType: data['meshType'] as String? ?? 'fiber',
      meshRollWidthCm: (data['meshRollWidthCm'] as num?)?.toInt() ?? 0,
      ruleVersionIdsUsed: (data['ruleVersionIdsUsed'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      overrides: rawOverrides != null
          ? Map<String, dynamic>.from(rawOverrides)
          : const {},
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  static DateTime _parseDate(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    return DateTime.now();
  }

  ProjectUnit copyWith({
    String? id,
    String? projectId,
    String? name,
    String? location,
    double? widthCm,
    double? heightCm,
    int? quantity,
    String? unitType,
    String? glazingMode,
    String? sharhOption,
    int? sashCount,
    int? screenCount,
    bool? hasScreen,
    String? profileSystemId,
    String? color,
    String? rollerType,
    String? glassType,
    double? glassThicknessMm,
    bool? hasCorners,
    bool? hasGasket,
    String? brushColor,
    String? glassRollerType,
    int? glassRollerCount,
    String? frameGasketType,
    String? screenCornerType,
    int? puttyQtyPerUnit,
    String? meshType,
    int? meshRollWidthCm,
    List<String>? ruleVersionIdsUsed,
    Map<String, dynamic>? overrides,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectUnit(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      location: location ?? this.location,
      widthCm: widthCm ?? this.widthCm,
      heightCm: heightCm ?? this.heightCm,
      quantity: quantity ?? this.quantity,
      unitType: unitType ?? this.unitType,
      glazingMode: glazingMode ?? this.glazingMode,
      sharhOption: sharhOption ?? this.sharhOption,
      sashCount: sashCount ?? this.sashCount,
      screenCount: screenCount ?? this.screenCount,
      hasScreen: hasScreen ?? this.hasScreen,
      profileSystemId: profileSystemId ?? this.profileSystemId,
      color: color ?? this.color,
      rollerType: rollerType ?? this.rollerType,
      glassType: glassType ?? this.glassType,
      glassThicknessMm: glassThicknessMm ?? this.glassThicknessMm,
      hasCorners: hasCorners ?? this.hasCorners,
      hasGasket: hasGasket ?? this.hasGasket,
      brushColor: brushColor ?? this.brushColor,
      glassRollerType: glassRollerType ?? this.glassRollerType,
      glassRollerCount: glassRollerCount ?? this.glassRollerCount,
      frameGasketType: frameGasketType ?? this.frameGasketType,
      screenCornerType: screenCornerType ?? this.screenCornerType,
      puttyQtyPerUnit: puttyQtyPerUnit ?? this.puttyQtyPerUnit,
      meshType: meshType ?? this.meshType,
      meshRollWidthCm: meshRollWidthCm ?? this.meshRollWidthCm,
      ruleVersionIdsUsed: ruleVersionIdsUsed ?? this.ruleVersionIdsUsed,
      overrides: overrides ?? this.overrides,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
