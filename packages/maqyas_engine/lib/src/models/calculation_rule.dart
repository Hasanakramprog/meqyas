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
  });

  bool get isApproved => status == RuleStatus.approved;

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
    );
  }
}
