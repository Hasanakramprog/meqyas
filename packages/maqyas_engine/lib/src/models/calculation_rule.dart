enum RuleStatus {
  approved,
  draft,
  archived,
}

class CalculationRule {
  final String id;
  final String itemCode;
  final String profileSystemId;
  final RuleStatus status;
  final int priority;
  final int version;
  final DateTime effectiveAt;
  final List<String> conditions;
  final String quantityFormula;
  final String lengthFormula;
  final List<String> dependsOn; // intermediate variables or other item length codes

  // Display & manufacturing metadata
  final String nameArabic;
  final String outputKind; // 'profile', 'glass_height', 'glass_width', 'intermediate'
  final String profileType; // 'track', 'jamb', 'sash', 'screen', 'bead', 'other'
  final double cutAngleLeft; // e.g. 90.0, 45.0
  final double cutAngleRight; // e.g. 90.0, 45.0
  final String? notes;
  final String? createdBy;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CalculationRule({
    required this.id,
    required this.itemCode,
    required this.profileSystemId,
    this.status = RuleStatus.approved,
    this.priority = 0,
    this.version = 1,
    required this.effectiveAt,
    this.conditions = const [],
    required this.quantityFormula,
    required this.lengthFormula,
    this.dependsOn = const [],
    this.nameArabic = '',
    this.outputKind = 'profile',
    this.profileType = 'profile',
    this.cutAngleLeft = 90.0,
    this.cutAngleRight = 90.0,
    this.notes,
    this.createdBy,
    this.approvedBy,
    this.approvedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isApproved => status == RuleStatus.approved;
  bool get isDraft => status == RuleStatus.draft;
  bool get isArchived => status == RuleStatus.archived;

  String get ruleKey => '$profileSystemId:$itemCode';

  CalculationRule copyWith({
    String? id,
    String? itemCode,
    String? profileSystemId,
    RuleStatus? status,
    int? priority,
    int? version,
    DateTime? effectiveAt,
    List<String>? conditions,
    String? quantityFormula,
    String? lengthFormula,
    List<String>? dependsOn,
    String? nameArabic,
    String? outputKind,
    String? profileType,
    double? cutAngleLeft,
    double? cutAngleRight,
    String? notes,
    String? createdBy,
    String? approvedBy,
    DateTime? approvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CalculationRule(
      id: id ?? this.id,
      itemCode: itemCode ?? this.itemCode,
      profileSystemId: profileSystemId ?? this.profileSystemId,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      version: version ?? this.version,
      effectiveAt: effectiveAt ?? this.effectiveAt,
      conditions: conditions ?? this.conditions,
      quantityFormula: quantityFormula ?? this.quantityFormula,
      lengthFormula: lengthFormula ?? this.lengthFormula,
      dependsOn: dependsOn ?? this.dependsOn,
      nameArabic: nameArabic ?? this.nameArabic,
      outputKind: outputKind ?? this.outputKind,
      profileType: profileType ?? this.profileType,
      cutAngleLeft: cutAngleLeft ?? this.cutAngleLeft,
      cutAngleRight: cutAngleRight ?? this.cutAngleRight,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ruleKey': ruleKey,
      'itemCode': itemCode,
      'profileSystemId': profileSystemId,
      'status': status.name,
      'priority': priority,
      'version': version,
      'effectiveAt': effectiveAt.toIso8601String(),
      'conditions': conditions,
      'quantityFormula': quantityFormula,
      'lengthFormula': lengthFormula,
      'dependsOn': dependsOn,
      'nameArabic': nameArabic,
      'outputKind': outputKind,
      'profileType': profileType,
      'cutAngleLeft': cutAngleLeft,
      'cutAngleRight': cutAngleRight,
      if (notes != null) 'notes': notes,
      if (createdBy != null) 'createdBy': createdBy,
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  factory CalculationRule.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val == null) return fallback;
      if (val is DateTime) return val;
      if (val is String) {
        return DateTime.tryParse(val) ?? fallback;
      }
      return fallback;
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String) {
        return DateTime.tryParse(val);
      }
      return null;
    }

    RuleStatus parseStatus(dynamic val) {
      if (val is String) {
        for (final s in RuleStatus.values) {
          if (s.name == val) return s;
        }
      }
      return RuleStatus.approved;
    }

    return CalculationRule(
      id: docId ?? (map['id'] as String? ?? ''),
      itemCode: map['itemCode'] as String? ?? '',
      profileSystemId: map['profileSystemId'] as String? ?? '',
      status: parseStatus(map['status']),
      priority: (map['priority'] as num?)?.toInt() ?? 0,
      version: (map['version'] as num?)?.toInt() ?? 1,
      effectiveAt: parseDate(map['effectiveAt'], DateTime(2026, 1, 1)),
      conditions: (map['conditions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      quantityFormula: map['quantityFormula'] as String? ?? '0',
      lengthFormula: map['lengthFormula'] as String? ?? '0',
      dependsOn: (map['dependsOn'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      nameArabic: map['nameArabic'] as String? ?? '',
      outputKind: map['outputKind'] as String? ?? 'profile',
      profileType: map['profileType'] as String? ?? 'profile',
      cutAngleLeft: (map['cutAngleLeft'] as num?)?.toDouble() ?? 90.0,
      cutAngleRight: (map['cutAngleRight'] as num?)?.toDouble() ?? 90.0,
      notes: map['notes'] as String?,
      createdBy: map['createdBy'] as String?,
      approvedBy: map['approvedBy'] as String?,
      approvedAt: parseNullableDate(map['approvedAt']),
      createdAt: parseNullableDate(map['createdAt']),
      updatedAt: parseNullableDate(map['updatedAt']),
    );
  }
}
