import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maqyas_engine/maqyas_engine.dart';

class ProjectUnit {
  final String id;
  final String projectId;
  final String name; // e.g. 'شباك غرفة النوم', 'واجهة الصالون'
  final String location; // e.g. 'الدور الأرضي - واجهة غربية'
  final double widthCm;
  final double heightCm;
  final int quantity;
  final String unitType; // 'window' or 'facade'
  final String glazingMode; // 'single' or 'double'
  final String sharhOption; // 'none', 'one_side', 'two_sides'
  final int sashCount; // typically 2
  final int screenCount; // typically 1 or 0
  final bool hasScreen;
  final String profileSystemId; // e.g. 'system_2000_beaded'
  final String rollerType; // 'slider', 'modified_2000', 'milled'
  final String glassType; // 'clear', 'frosted', 'reflective', 'smoked'
  final double glassThicknessMm;
  final bool hasCorners;
  final bool hasGasket;
  final List<String> ruleVersionIdsUsed;
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
    this.glazingMode = 'single',
    this.sharhOption = 'none',
    this.sashCount = 2,
    this.screenCount = 1,
    this.hasScreen = true,
    this.profileSystemId = SeedRules.system2000Beaded,
    this.rollerType = 'slider',
    this.glassType = 'clear',
    this.glassThicknessMm = 6.0,
    this.hasCorners = true,
    this.hasGasket = true,
    this.ruleVersionIdsUsed = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  UnitSpecification toEngineSpec() {
    return UnitSpecification(
      widthCm: widthCm,
      heightCm: heightCm,
      quantity: quantity,
      unitType: unitType,
      glazingMode: glazingMode,
      sharhOption: sharhOption,
      sashCount: sashCount,
      screenCount: screenCount,
      hasScreen: hasScreen,
      profileSystemId: profileSystemId,
      rollerType: rollerType,
      glassType: glassType,
      glassThicknessMm: glassThicknessMm,
      hasCorners: hasCorners,
      hasGasket: hasGasket,
    );
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
      'rollerType': rollerType,
      'glassType': glassType,
      'glassThicknessMm': glassThicknessMm,
      'hasCorners': hasCorners,
      'hasGasket': hasGasket,
      'ruleVersionIdsUsed': ruleVersionIdsUsed,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ProjectUnit.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ProjectUnit(
      id: doc.id,
      projectId: data['projectId'] as String? ?? '',
      name: data['name'] as String? ?? 'عنصر قياس',
      location: data['location'] as String? ?? '',
      widthCm: (data['widthCm'] as num?)?.toDouble() ?? 100.0,
      heightCm: (data['heightCm'] as num?)?.toDouble() ?? 100.0,
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      unitType: data['unitType'] as String? ?? 'window',
      glazingMode: data['glazingMode'] as String? ?? 'single',
      sharhOption: data['sharhOption'] as String? ?? 'none',
      sashCount: (data['sashCount'] as num?)?.toInt() ?? 2,
      screenCount: (data['screenCount'] as num?)?.toInt() ?? 1,
      hasScreen: data['hasScreen'] as bool? ?? true,
      profileSystemId: data['profileSystemId'] as String? ?? SeedRules.system2000Beaded,
      rollerType: data['rollerType'] as String? ?? 'slider',
      glassType: data['glassType'] as String? ?? 'clear',
      glassThicknessMm: (data['glassThicknessMm'] as num?)?.toDouble() ?? 6.0,
      hasCorners: data['hasCorners'] as bool? ?? true,
      hasGasket: data['hasGasket'] as bool? ?? true,
      ruleVersionIdsUsed: (data['ruleVersionIdsUsed'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
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
    String? rollerType,
    String? glassType,
    double? glassThicknessMm,
    bool? hasCorners,
    bool? hasGasket,
    List<String>? ruleVersionIdsUsed,
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
      rollerType: rollerType ?? this.rollerType,
      glassType: glassType ?? this.glassType,
      glassThicknessMm: glassThicknessMm ?? this.glassThicknessMm,
      hasCorners: hasCorners ?? this.hasCorners,
      hasGasket: hasGasket ?? this.hasGasket,
      ruleVersionIdsUsed: ruleVersionIdsUsed ?? this.ruleVersionIdsUsed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
