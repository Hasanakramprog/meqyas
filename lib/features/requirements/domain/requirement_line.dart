import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

class RequirementLine {
  final String id;
  final String? itemId;
  final String engineItemCode;
  final String nameArabic;
  final String category;
  final double requiredQty;
  final double inStockQty;
  final double toBuyQty;
  final bool isToBuyOverridden;
  final bool needsReviewAfterRegen;
  final String unit;
  final String note;
  final String source; // 'auto' | 'manual'
  final bool dismissed;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RequirementLine({
    required this.id,
    this.itemId,
    this.engineItemCode = '',
    required this.nameArabic,
    this.category = 'aluminum',
    required this.requiredQty,
    this.inStockQty = 0.0,
    required this.toBuyQty,
    this.isToBuyOverridden = false,
    this.needsReviewAfterRegen = false,
    this.unit = 'bar',
    this.note = '',
    this.source = 'auto',
    this.dismissed = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAuto => source == 'auto';
  bool get isManual => source == 'manual';
  bool get isCoveredInWorkshop => toBuyQty <= 0;

  static double computeDefaultToBuy(double requiredQty, double inStockQty) {
    final diff = math.max(0.0, requiredQty - inStockQty);
    return double.parse(diff.toStringAsFixed(2));
  }

  String get unitArabic => unitLabelArabic(unit);

  static String unitLabelArabic(String unitCode) {
    switch (unitCode) {
      case 'bar':
        return 'قضيب (6.6م)';
      case 'roll':
        return 'لفة';
      case 'piece':
        return 'حبة';
      case 'm2':
        return 'م²';
      case 'm':
        return 'متر';
      case 'cm':
        return 'سم';
      case 'mm':
        return 'ملم';
      case 'box':
        return 'علبة';
      case 'kg':
        return 'كغ';
      default:
        return unitCode;
    }
  }

  String get categoryArabic => categoryLabelArabic(category);

  static String categoryLabelArabic(String categoryId) {
    switch (categoryId) {
      case 'aluminum':
        return 'مقاطع ألمنيوم (قضبان 660 سم)';
      case 'glass':
        return 'ألواح ومساحات الزجاج';
      case 'accessories':
        return 'إكسسوارات ولوازم';
      case 'fiber':
        return 'شبك منخل وفراشة (باللفة)';
      case 'plastic':
        return 'بلاستيك وربر (كاسكيت)';
      case 'tools':
        return 'براغي ومواد تثبيت';
      default:
        return categoryId;
    }
  }

  static int categorySortOrder(String categoryId) {
    switch (categoryId) {
      case 'aluminum':
        return 0;
      case 'glass':
        return 1;
      case 'accessories':
        return 2;
      case 'fiber':
        return 3;
      case 'plastic':
        return 4;
      case 'tools':
        return 5;
      default:
        return 6;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'engineItemCode': engineItemCode,
      'nameArabic': nameArabic,
      'category': category,
      'requiredQty': requiredQty,
      'inStockQty': inStockQty,
      'toBuyQty': toBuyQty,
      'isToBuyOverridden': isToBuyOverridden,
      'needsReviewAfterRegen': needsReviewAfterRegen,
      'unit': unit,
      'note': note,
      'source': source,
      'dismissed': dismissed,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory RequirementLine.fromMap(
    Map<String, dynamic> map, {
    required String docId,
  }) {
    final req = (map['requiredQty'] as num?)?.toDouble() ?? 0.0;
    final stock = (map['inStockQty'] as num?)?.toDouble() ?? 0.0;
    final toBuy =
        (map['toBuyQty'] as num?)?.toDouble() ?? computeDefaultToBuy(req, stock);

    return RequirementLine(
      id: docId,
      itemId: map['itemId'] as String?,
      engineItemCode: map['engineItemCode'] as String? ?? '',
      nameArabic: map['nameArabic'] as String? ?? '',
      category: map['category'] as String? ?? 'aluminum',
      requiredQty: req,
      inStockQty: stock,
      toBuyQty: toBuy,
      isToBuyOverridden: map['isToBuyOverridden'] as bool? ?? false,
      needsReviewAfterRegen: map['needsReviewAfterRegen'] as bool? ?? false,
      unit: map['unit'] as String? ?? 'bar',
      note: map['note'] as String? ?? '',
      source: map['source'] as String? ?? 'auto',
      dismissed: map['dismissed'] as bool? ?? false,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  static DateTime _parseDate(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    return DateTime.now();
  }

  RequirementLine copyWith({
    String? id,
    String? itemId,
    String? engineItemCode,
    String? nameArabic,
    String? category,
    double? requiredQty,
    double? inStockQty,
    double? toBuyQty,
    bool? isToBuyOverridden,
    bool? needsReviewAfterRegen,
    String? unit,
    String? note,
    String? source,
    bool? dismissed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RequirementLine(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      engineItemCode: engineItemCode ?? this.engineItemCode,
      nameArabic: nameArabic ?? this.nameArabic,
      category: category ?? this.category,
      requiredQty: requiredQty ?? this.requiredQty,
      inStockQty: inStockQty ?? this.inStockQty,
      toBuyQty: toBuyQty ?? this.toBuyQty,
      isToBuyOverridden: isToBuyOverridden ?? this.isToBuyOverridden,
      needsReviewAfterRegen:
          needsReviewAfterRegen ?? this.needsReviewAfterRegen,
      unit: unit ?? this.unit,
      note: note ?? this.note,
      source: source ?? this.source,
      dismissed: dismissed ?? this.dismissed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

