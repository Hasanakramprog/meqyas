import 'package:cloud_firestore/cloud_firestore.dart';

class CatalogCategory {
  final String id;
  final String nameArabic;

  const CatalogCategory({required this.id, required this.nameArabic});

  static const List<CatalogCategory> all = [
    CatalogCategory(id: 'aluminum', nameArabic: 'مقاطع ألمنيوم'),
    CatalogCategory(id: 'accessories', nameArabic: 'إكسسوارات'),
    CatalogCategory(id: 'glass', nameArabic: 'زجاج'),
    CatalogCategory(id: 'fiber', nameArabic: 'شبك منخل وفرش (فراشة)'),
    CatalogCategory(id: 'plastic', nameArabic: 'بلاستيك وربر وجوان'),
    CatalogCategory(id: 'tools', nameArabic: 'براغي وتثبيت'),
  ];

  static String arabicLabel(String categoryId) {
    for (final c in all) {
      if (c.id == categoryId) return c.nameArabic;
    }
    return categoryId;
  }

  /// Spec §8.7 & §16.5: Commercial pricing/stock/sale unit for brush and mesh is the ROLL only.
  static bool requiresRollUnit(String categoryId) {
    return categoryId == 'fiber' || categoryId == 'brush';
  }
}

class CatalogUnit {
  final String code;
  final String nameArabic;

  const CatalogUnit({required this.code, required this.nameArabic});

  static const List<CatalogUnit> all = [
    CatalogUnit(code: 'bar', nameArabic: 'قضيب (6.6م)'),
    CatalogUnit(code: 'roll', nameArabic: 'لفة (Roll)'),
    CatalogUnit(code: 'piece', nameArabic: 'قطعة'),
    CatalogUnit(code: 'pair', nameArabic: 'زوج (طقم)'),
    CatalogUnit(code: 'm2', nameArabic: 'متر مربع (م²)'),
    CatalogUnit(code: 'm', nameArabic: 'متر طولي'),
    CatalogUnit(code: 'cm', nameArabic: 'سم'),
    CatalogUnit(code: 'mm', nameArabic: 'ملم'),
  ];

  static String arabicLabel(String unitCode) {
    for (final u in all) {
      if (u.code == unitCode) return u.nameArabic;
    }
    return unitCode;
  }
}

class CatalogItem {
  final String id;
  final String code;
  final String engineItemCode;
  final String arabicName;
  final String categoryId;
  final String unit;
  final String color;
  final String thickness;
  final String status; // 'active' | 'inactive'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CatalogItem({
    required this.id,
    required this.code,
    this.engineItemCode = '',
    required this.arabicName,
    required this.categoryId,
    required this.unit,
    this.color = '',
    this.thickness = '',
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == 'active';

  /// Validates commercial rules (including Spec §8.7 roll-only rule for fiber/brush).
  String? validate() {
    if (code.trim().isEmpty) {
      return 'كود الصنف مطلوب';
    }
    if (arabicName.trim().isEmpty) {
      return 'الاسم بالعربية مطلوب';
    }
    if (CatalogCategory.requiresRollUnit(categoryId) && unit != 'roll') {
      return 'حسب مواصفات النظام (§8.7): وحدة البيع والتسعير والمخزون للشبك والفراشة يجب أن تكون باللفة (roll) فقط وليس بالمتر';
    }
    return null;
  }

  CatalogItem copyWith({
    String? id,
    String? code,
    String? engineItemCode,
    String? arabicName,
    String? categoryId,
    String? unit,
    String? color,
    String? thickness,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CatalogItem(
      id: id ?? this.id,
      code: code ?? this.code,
      engineItemCode: engineItemCode ?? this.engineItemCode,
      arabicName: arabicName ?? this.arabicName,
      categoryId: categoryId ?? this.categoryId,
      unit: unit ?? this.unit,
      color: color ?? this.color,
      thickness: thickness ?? this.thickness,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code.trim().toUpperCase(),
      'engineItemCode': engineItemCode.trim(),
      'arabicName': arabicName.trim(),
      'categoryId': categoryId,
      'unit': unit,
      'color': color.trim(),
      'thickness': thickness.trim(),
      'status': status,
    };
  }

  factory CatalogItem.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return CatalogItem(
      id: docId ?? (map['id'] as String? ?? ''),
      code: (map['code'] as String? ?? '').toUpperCase(),
      engineItemCode: map['engineItemCode'] as String? ?? '',
      arabicName: map['arabicName'] as String? ?? '',
      categoryId: map['categoryId'] as String? ?? 'aluminum',
      unit: map['unit'] as String? ?? 'piece',
      color: map['color'] as String? ?? '',
      thickness: map['thickness'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}

/// Built-in default catalog items matching System 2000 Beaded & Spec §8.4–8.7.
class SeedCatalog {
  static List<CatalogItem> getDefaultCatalogItems() {
    return const [
      // 1. Aluminum Profiles (System 2000 Beaded)
      CatalogItem(
        id: 'cat_al_track_2000',
        code: 'AL-TRK-2000',
        engineItemCode: 'track',
        arabicName: 'سكة 2000 بحاجب (قضيب 6.6م)',
        categoryId: 'aluminum',
        unit: 'bar',
        color: 'أبيض',
        thickness: '1.3 مم',
        status: 'active',
      ),
      CatalogItem(
        id: 'cat_al_u_2000',
        code: 'AL-UPR-2000',
        engineItemCode: 'u_profile',
        arabicName: 'يو 2000 جانبي (قضيب 6.6م)',
        categoryId: 'aluminum',
        unit: 'bar',
        color: 'أبيض',
        thickness: '1.2 مم',
        status: 'active',
      ),
      CatalogItem(
        id: 'cat_al_kaab_2000',
        code: 'AL-KAB-2000',
        engineItemCode: 'kaab',
        arabicName: 'كعب 2000 مفرد (قضيب 6.6م)',
        categoryId: 'aluminum',
        unit: 'bar',
        color: 'أبيض',
        thickness: '1.3 مم',
        status: 'active',
      ),
      CatalogItem(
        id: 'cat_al_scr_vert_2000',
        code: 'AL-SCV-2000',
        engineItemCode: 'screen_vertical',
        arabicName: 'درفة منخل عامودي 2000 (قضيب 6.6م)',
        categoryId: 'aluminum',
        unit: 'bar',
        color: 'أبيض',
        thickness: '1.1 مم',
        status: 'active',
      ),
      CatalogItem(
        id: 'cat_al_scr_horiz_2000',
        code: 'AL-SCH-2000',
        engineItemCode: 'screen_horizontal',
        arabicName: 'درفة منخل أفقي 2000 (قضيب 6.6م)',
        categoryId: 'aluminum',
        unit: 'bar',
        color: 'أبيض',
        thickness: '1.1 مم',
        status: 'active',
      ),

      // 2. Glass Types (Spec §8.5)
      CatalogItem(
        id: 'cat_gl_clear_6mm',
        code: 'GL-CLR-06',
        engineItemCode: 'glass_pane',
        arabicName: 'زجاج شفاف 6 ملم',
        categoryId: 'glass',
        unit: 'm2',
        color: 'شفاف',
        thickness: '6 مم',
        status: 'active',
      ),
      CatalogItem(
        id: 'cat_gl_refl_6mm',
        code: 'GL-RFL-06',
        engineItemCode: 'glass_reflective',
        arabicName: 'زجاج عاكس 6 ملم',
        categoryId: 'glass',
        unit: 'm2',
        color: 'عاكس',
        thickness: '6 مم',
        status: 'active',
      ),

      // 3. Accessories (Spec §8.6)
      CatalogItem(
        id: 'cat_acc_glass_handle',
        code: 'AC-HND-GLS',
        engineItemCode: 'glass_handle',
        arabicName: 'مسكة درفة زجاج 2000',
        categoryId: 'accessories',
        unit: 'piece',
        color: 'أبيض',
        status: 'active',
      ),
      CatalogItem(
        id: 'cat_acc_screen_handle',
        code: 'AC-HND-SCR',
        engineItemCode: 'screen_handle',
        arabicName: 'مسكة درفة منخل',
        categoryId: 'accessories',
        unit: 'piece',
        color: 'أبيض',
        status: 'active',
      ),
      CatalogItem(
        id: 'cat_acc_glass_rollers',
        code: 'AC-RLR-GLS',
        engineItemCode: 'glass_rollers',
        arabicName: 'عجلات درف الزجاج 2000',
        categoryId: 'accessories',
        unit: 'pair',
        status: 'active',
      ),
      CatalogItem(
        id: 'cat_acc_screen_rollers',
        code: 'AC-RLR-SCR',
        engineItemCode: 'screen_rollers',
        arabicName: 'عجلات درفة المنخل',
        categoryId: 'accessories',
        unit: 'pair',
        status: 'active',
      ),
      CatalogItem(
        id: 'cat_acc_corners',
        code: 'AC-CRN-2000',
        engineItemCode: 'corners',
        arabicName: 'زوايا تجميع ألمنيوم',
        categoryId: 'accessories',
        unit: 'piece',
        status: 'active',
      ),

      // 4. Plastic & Plugs
      CatalogItem(
        id: 'cat_pl_shankal_plug',
        code: 'PL-PLG-SHK',
        engineItemCode: 'shankal_plug',
        arabicName: 'طبة شنكل',
        categoryId: 'plastic',
        unit: 'piece',
        color: 'أسود',
        status: 'active',
      ),
      CatalogItem(
        id: 'cat_pl_water_plug',
        code: 'PL-PLG-WTR',
        engineItemCode: 'water_plug',
        arabicName: 'طبة ماء لتصريف السكة',
        categoryId: 'plastic',
        unit: 'piece',
        color: 'أسود',
        status: 'active',
      ),
      CatalogItem(
        id: 'cat_pl_rakilaj_plug',
        code: 'PL-PLG-RKL',
        engineItemCode: 'rakilaj_plug',
        arabicName: 'طبة مسكة ركلاج',
        categoryId: 'plastic',
        unit: 'piece',
        color: 'أسود',
        status: 'active',
      ),
      CatalogItem(
        id: 'cat_pl_fixed_plug',
        code: 'PL-PLG-FXD',
        engineItemCode: 'fixed_plug',
        arabicName: 'طبة مسكة ثابت',
        categoryId: 'plastic',
        unit: 'piece',
        color: 'أسود',
        status: 'active',
      ),
      CatalogItem(
        id: 'cat_pl_gasket',
        code: 'PL-GSK-2000',
        engineItemCode: 'gasket',
        arabicName: 'جوان إحكام عازل للزجاج',
        categoryId: 'plastic',
        unit: 'piece',
        color: 'أسود',
        status: 'active',
      ),

      // 5. Fiber Mesh & Brush Rolls (Spec §8.7: strictly ROLL unit)
      CatalogItem(
        id: 'cat_fb_mesh_120',
        code: 'FB-MSH-120',
        engineItemCode: 'fiber_mesh_roll',
        arabicName: 'لفة شبك منخل فيبر عرض 120 سم × 20 م',
        categoryId: 'fiber',
        unit: 'roll',
        color: 'رمادي',
        status: 'active',
      ),
      CatalogItem(
        id: 'cat_fb_brush_450',
        code: 'FB-BRS-450',
        engineItemCode: 'brush_450_roll',
        arabicName: 'لفة فراشة منخل 450',
        categoryId: 'fiber',
        unit: 'roll',
        color: 'رمادي',
        status: 'active',
      ),

      // 6. Fasteners & Screws
      CatalogItem(
        id: 'cat_tl_short_screws',
        code: 'TL-SCR-415',
        engineItemCode: 'short_screws',
        arabicName: 'براغي قصيرة 4mm×1.5cm',
        categoryId: 'tools',
        unit: 'piece',
        status: 'active',
      ),
      CatalogItem(
        id: 'cat_tl_long_screws',
        code: 'TL-SCR-430',
        engineItemCode: 'long_screws',
        arabicName: 'براغي طويلة 4mm×3cm',
        categoryId: 'tools',
        unit: 'piece',
        status: 'active',
      ),
    ];
  }
}

