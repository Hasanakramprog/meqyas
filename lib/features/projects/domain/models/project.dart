import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maqyas_engine/maqyas_engine.dart';

/// Project-level general properties ("الخصائص العامة للمشروع") applied by default
/// to all units in the project unless overridden on a specific unit.
class ProjectDefaults {
  /// "ألمنيوم الورشة" — Profile system ID (e.g., 'system_2000_beaded')
  final String profileSystemId;

  /// "ألمنيوم الورشة (دبل / مفرد)" — 'double' (دبل) or 'single' (مفرد / عادي)
  final String glazingMode;

  /// "لون الورشة · الافتراضي للوحدات" — e.g. 'white', 'black', 'champagne', 'bronze', 'grey', 'wood'
  final String color;

  /// "نوع زجاج المشروع" — 'clear', 'frosted', 'reflective', 'smoked'
  final String glassType;

  /// "سماكة زجاج المشروع" — e.g. 6.0, 4.0, 8.0, 10.0, 18.0, 24.0
  final double glassThicknessMm;

  /// "الزبون يدك كوتشوك الزجاج" — false = "لا · لا تضف الكوتشوك للطلبية", true = "نعم · أضف الكوتشوك للطلبية"
  final bool hasGasket;

  /// Project-level formula deduction overrides ("تعديل التخسيمات")
  /// Key: ruleKey, Value: {'lengthFormula': '...', 'quantityFormula': '...'}
  final Map<String, Map<String, String>> ruleOverrides;

  const ProjectDefaults({
    this.profileSystemId = SeedRules.system2000Beaded,
    this.glazingMode = 'double',
    this.color = 'white',
    this.glassType = 'clear',
    this.glassThicknessMm = 6.0,
    this.hasGasket = false,
    this.ruleOverrides = const {},
  });

  bool get hasRuleOverrides => ruleOverrides.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'profileSystemId': profileSystemId,
      'glazingMode': glazingMode,
      'color': color,
      'glassType': glassType,
      'glassThicknessMm': glassThicknessMm,
      'hasGasket': hasGasket,
      'ruleOverrides': ruleOverrides,
    };
  }

  factory ProjectDefaults.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ProjectDefaults();
    final rawRuleOverrides = map['ruleOverrides'] as Map<String, dynamic>?;
    final parsedOverrides = <String, Map<String, String>>{};
    if (rawRuleOverrides != null) {
      for (final entry in rawRuleOverrides.entries) {
        final val = entry.value;
        if (val is Map) {
          parsedOverrides[entry.key] = val.map(
            (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
          );
        }
      }
    }

    return ProjectDefaults(
      profileSystemId:
          map['profileSystemId'] as String? ?? SeedRules.system2000Beaded,
      glazingMode: map['glazingMode'] as String? ?? 'double',
      color: map['color'] as String? ?? 'white',
      glassType: map['glassType'] as String? ?? 'clear',
      glassThicknessMm: (map['glassThicknessMm'] as num?)?.toDouble() ?? 6.0,
      hasGasket: map['hasGasket'] as bool? ?? false,
      ruleOverrides: parsedOverrides,
    );
  }

  ProjectDefaults copyWith({
    String? profileSystemId,
    String? glazingMode,
    String? color,
    String? glassType,
    double? glassThicknessMm,
    bool? hasGasket,
    Map<String, Map<String, String>>? ruleOverrides,
  }) {
    return ProjectDefaults(
      profileSystemId: profileSystemId ?? this.profileSystemId,
      glazingMode: glazingMode ?? this.glazingMode,
      color: color ?? this.color,
      glassType: glassType ?? this.glassType,
      glassThicknessMm: glassThicknessMm ?? this.glassThicknessMm,
      hasGasket: hasGasket ?? this.hasGasket,
      ruleOverrides: ruleOverrides ?? this.ruleOverrides,
    );
  }

  static String colorLabelAr(String colorCode) {
    switch (colorCode) {
      case 'white':
        return 'أبيض';
      case 'black':
        return 'أسود مطفي';
      case 'champagne':
        return 'شامبين';
      case 'bronze':
        return 'برونز';
      case 'grey':
        return 'رمادي (أنتراسيت)';
      case 'wood':
        return 'خشبي';
      default:
        return colorCode;
    }
  }

  static String glassTypeLabelAr(String glassType) {
    switch (glassType) {
      case 'clear':
        return 'شفاف';
      case 'frosted':
        return 'مثلج (Frosted)';
      case 'reflective':
        return 'عاكس (Reflective)';
      case 'smoked':
        return 'مدخن (فيميه)';
      default:
        return glassType;
    }
  }

  static String glazingModeLabelAr(String glazingMode) {
    switch (glazingMode) {
      case 'double':
        return 'دبل';
      case 'single':
        return 'عادي (مفرد)';
      default:
        return glazingMode;
    }
  }
}

class Project {
  final String id;
  final String workshopId;
  final String name;
  final String clientName;
  final String clientPhone;
  final String location;
  final String status; // 'draft', 'in_progress', 'completed'
  final int unitCount;
  final ProjectDefaults defaults;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? requirementsGeneratedAt;

  const Project({
    required this.id,
    required this.workshopId,
    required this.name,
    this.clientName = '',
    this.clientPhone = '',
    this.location = '',
    this.status = 'draft',
    this.unitCount = 0,
    this.defaults = const ProjectDefaults(),
    required this.createdAt,
    required this.updatedAt,
    this.requirementsGeneratedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'workshopId': workshopId,
      'name': name,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'location': location,
      'status': status,
      'unitCount': unitCount,
      'defaults': defaults.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (requirementsGeneratedAt != null)
        'requirementsGeneratedAt': Timestamp.fromDate(requirementsGeneratedAt!),
    };
  }

  factory Project.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Project(
      id: doc.id,
      workshopId: data['workshopId'] as String? ?? '',
      name: data['name'] as String? ?? 'مشروع بدون اسم',
      clientName: data['clientName'] as String? ?? '',
      clientPhone: data['clientPhone'] as String? ?? '',
      location: data['location'] as String? ?? '',
      status: data['status'] as String? ?? 'draft',
      unitCount: (data['unitCount'] as num?)?.toInt() ?? 0,
      defaults: ProjectDefaults.fromMap(
        data['defaults'] as Map<String, dynamic>?,
      ),
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      requirementsGeneratedAt: data['requirementsGeneratedAt'] != null
          ? _parseDate(data['requirementsGeneratedAt'])
          : null,
    );
  }

  static DateTime _parseDate(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    return DateTime.now();
  }

  Project copyWith({
    String? id,
    String? workshopId,
    String? name,
    String? clientName,
    String? clientPhone,
    String? location,
    String? status,
    int? unitCount,
    ProjectDefaults? defaults,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? requirementsGeneratedAt,
  }) {
    return Project(
      id: id ?? this.id,
      workshopId: workshopId ?? this.workshopId,
      name: name ?? this.name,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      location: location ?? this.location,
      status: status ?? this.status,
      unitCount: unitCount ?? this.unitCount,
      defaults: defaults ?? this.defaults,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      requirementsGeneratedAt:
          requirementsGeneratedAt ?? this.requirementsGeneratedAt,
    );
  }
}
