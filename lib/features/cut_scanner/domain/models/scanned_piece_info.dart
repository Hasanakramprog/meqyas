class ScannedPieceInfo {
  final String projectId;
  final String unitTag;
  final String itemCode;
  final String nameArabic;
  final double lengthCm;
  final int barNumber;
  final String color;
  final bool isFromRemnant;
  final String cutAngleLeft;
  final String cutAngleRight;
  final String rawPayload;

  const ScannedPieceInfo({
    required this.projectId,
    required this.unitTag,
    required this.itemCode,
    required this.nameArabic,
    required this.lengthCm,
    required this.barNumber,
    this.color = 'white',
    this.isFromRemnant = false,
    this.cutAngleLeft = '45°',
    this.cutAngleRight = '45°',
    this.rawPayload = '',
  });

  /// Factory from decoded map
  factory ScannedPieceInfo.fromMap(Map<String, dynamic> map, {String raw = ''}) {
    final projectId = (map['p'] ?? map['projectId'] ?? '').toString();
    final unitTag = (map['u'] ?? map['unitTag'] ?? '').toString();
    final itemCode = (map['i'] ?? map['itemCode'] ?? '').toString();
    final lengthCm = (map['l'] as num?)?.toDouble() ??
        (map['lengthCm'] as num?)?.toDouble() ??
        0.0;
    final barNumber = (map['b'] as num?)?.toInt() ??
        (map['barNumber'] as num?)?.toInt() ??
        1;
    final color = (map['c'] ?? map['color'] ?? 'white').toString();
    final isFromRemnant = (map['r'] == true) || (map['isFromRemnant'] == true);
    final nameArabic = (map['n'] ?? map['nameArabic'] ?? '').toString();

    return ScannedPieceInfo(
      projectId: projectId,
      unitTag: unitTag,
      itemCode: itemCode,
      nameArabic: nameArabic,
      lengthCm: lengthCm,
      barNumber: barNumber,
      color: color,
      isFromRemnant: isFromRemnant,
      rawPayload: raw,
    );
  }

  ScannedPieceInfo copyWith({
    String? projectId,
    String? unitTag,
    String? itemCode,
    String? nameArabic,
    double? lengthCm,
    int? barNumber,
    String? color,
    bool? isFromRemnant,
    String? cutAngleLeft,
    String? cutAngleRight,
    String? rawPayload,
  }) {
    return ScannedPieceInfo(
      projectId: projectId ?? this.projectId,
      unitTag: unitTag ?? this.unitTag,
      itemCode: itemCode ?? this.itemCode,
      nameArabic: nameArabic ?? this.nameArabic,
      lengthCm: lengthCm ?? this.lengthCm,
      barNumber: barNumber ?? this.barNumber,
      color: color ?? this.color,
      isFromRemnant: isFromRemnant ?? this.isFromRemnant,
      cutAngleLeft: cutAngleLeft ?? this.cutAngleLeft,
      cutAngleRight: cutAngleRight ?? this.cutAngleRight,
      rawPayload: rawPayload ?? this.rawPayload,
    );
  }
}
