import '../models/calculation_rule.dart';

class SeedRules {
  static const String system2000Beaded = 'system_2000_beaded';

  static List<CalculationRule> getSystem2000BeadedRules() {
    final now = DateTime(2026, 1, 1);

    return [
      // 1. Track: سكة 2000 بحاجب
      CalculationRule(
        id: 'rule_2000_track_v1',
        itemCode: 'track',
        profileSystemId: system2000Beaded,
        status: RuleStatus.approved,
        priority: 10,
        version: 1,
        effectiveAt: now,
        conditions: ["unitType == 'window' || unitType == 'facade'"],
        quantityFormula: '2',
        lengthFormula: 'W - 3',
        dependsOn: const [],
        nameArabic: 'سكة 2000 بحاجب',
        outputKind: 'profile',
        profileType: 'track',
        cutAngleLeft: 90.0,
        cutAngleRight: 90.0,
      ),

      // 2. U-Profile: يو 2000
      CalculationRule(
        id: 'rule_2000_u_profile_v1',
        itemCode: 'u_profile',
        profileSystemId: system2000Beaded,
        status: RuleStatus.approved,
        priority: 10,
        version: 1,
        effectiveAt: now,
        conditions: ["unitType == 'window' || unitType == 'facade'"],
        quantityFormula: '2',
        lengthFormula: 'H - 3.3',
        dependsOn: const [],
        nameArabic: 'يو 2000',
        outputKind: 'profile',
        profileType: 'jamb',
        cutAngleLeft: 90.0,
        cutAngleRight: 90.0,
      ),

      // 3. Kaab (bottom & top sash horizontals): كعب 2000 مفرد
      CalculationRule(
        id: 'rule_2000_kaab_v1',
        itemCode: 'kaab',
        profileSystemId: system2000Beaded,
        status: RuleStatus.approved,
        priority: 10,
        version: 1,
        effectiveAt: now,
        conditions: ["glazingMode == 'single'"],
        quantityFormula: '2 * sashCount',
        lengthFormula: '(W - 2.5) / 2',
        dependsOn: const [],
        nameArabic: 'كعب 2000 مفرد',
        outputKind: 'profile',
        profileType: 'sash',
        cutAngleLeft: 45.0,
        cutAngleRight: 45.0,
      ),

      // 4. Screen Vertical: درفة منخل عامودي
      CalculationRule(
        id: 'rule_2000_screen_vert_v1',
        itemCode: 'screen_vertical',
        profileSystemId: system2000Beaded,
        status: RuleStatus.approved,
        priority: 10,
        version: 1,
        effectiveAt: now,
        conditions: ['hasScreen == true', 'screenCount > 0'],
        quantityFormula: '2 * screenCount',
        lengthFormula: 'H - 4.1',
        dependsOn: const [],
        nameArabic: 'درفة منخل عامودي',
        outputKind: 'profile',
        profileType: 'screen',
        cutAngleLeft: 45.0,
        cutAngleRight: 45.0,
      ),

      // 5. Screen Horizontal: درفة منخل أفقي (depends on kaab_len)
      CalculationRule(
        id: 'rule_2000_screen_horiz_v1',
        itemCode: 'screen_horizontal',
        profileSystemId: system2000Beaded,
        status: RuleStatus.approved,
        priority: 10,
        version: 1,
        effectiveAt: now,
        conditions: ['hasScreen == true', 'screenCount > 0'],
        quantityFormula: '2 * screenCount',
        lengthFormula: 'kaab_len + 2',
        dependsOn: const ['kaab_len'],
        nameArabic: 'درفة منخل أفقي',
        outputKind: 'profile',
        profileType: 'screen',
        cutAngleLeft: 45.0,
        cutAngleRight: 45.0,
      ),

      // 6. Glass Height
      CalculationRule(
        id: 'rule_2000_glass_height_v1',
        itemCode: 'glass_height',
        profileSystemId: system2000Beaded,
        status: RuleStatus.approved,
        priority: 10,
        version: 1,
        effectiveAt: now,
        conditions: const [],
        quantityFormula: 'sashCount',
        lengthFormula: 'H - 14',
        dependsOn: const [],
        nameArabic: 'ارتفاع الزجاج',
        outputKind: 'glass_height',
        profileType: 'other',
      ),

      // 7. Glass Width per Sash
      CalculationRule(
        id: 'rule_2000_glass_width_v1',
        itemCode: 'glass_width',
        profileSystemId: system2000Beaded,
        status: RuleStatus.approved,
        priority: 10,
        version: 1,
        effectiveAt: now,
        conditions: const [],
        quantityFormula: 'sashCount',
        lengthFormula: '(W - 16.2) / 2',
        dependsOn: const [],
        nameArabic: 'عرض الزجاج للدرفة',
        outputKind: 'glass_width',
        profileType: 'other',
      ),
    ];
  }
}
