import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import 'package:meqyas/app/theme/app_colors.dart';
import 'package:meqyas/features/auth/presentation/controllers/auth_controller.dart';
import '../data/rules_repository.dart';

class WorkshopRulesScreen extends ConsumerStatefulWidget {
  final String? initialWorkshopId;

  const WorkshopRulesScreen({super.key, this.initialWorkshopId});

  @override
  ConsumerState<WorkshopRulesScreen> createState() => _WorkshopRulesScreenState();
}

class _WorkshopRulesScreenState extends ConsumerState<WorkshopRulesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _selectedWorkshopId;
  String? _selectedProfileSystemId;
  bool _isDetailedRulesExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedWorkshopId = widget.initialWorkshopId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider).value;
    final ownerUid = currentUser?.uid ?? '';

    final workshops = ref.watch(ownerWorkshopsProvider(ownerUid)).value ?? [];
    final activeIdFromProvider = ref.watch(activeWorkshopIdProvider);

    final currentWorkshopId = _selectedWorkshopId ??
        widget.initialWorkshopId ??
        activeIdFromProvider ??
        (workshops.isNotEmpty ? workshops.first.id : (currentUser?.workshopId ?? ''));

    final currentWorkshop = workshops.where((w) => w.id == currentWorkshopId).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentWorkshop != null ? 'إعدادات ${currentWorkshop.name}' : 'إعدادات وقواعد ورشتي'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.amberPrimary,
          labelColor: AppColors.amberPrimary,
          unselectedLabelColor: isDark ? AppColors.slate400 : AppColors.slate600,
          tabs: const [
            Tab(icon: Icon(Icons.tune_rounded, size: 20), text: 'قواعد التقطيع والمعادلات'),
            Tab(icon: Icon(Icons.straighten_rounded, size: 20), text: 'المنشار وقضبان 660سم'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (workshops.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.storefront_rounded, size: 20, color: AppColors.amberPrimary),
                  const SizedBox(width: 10),
                  const Text('الورشة المختارة: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: workshops.any((w) => w.id == currentWorkshopId) ? currentWorkshopId : workshops.first.id,
                        items: workshops.map((w) {
                          return DropdownMenuItem(
                            value: w.id,
                            child: Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (newId) {
                          if (newId != null) {
                            setState(() => _selectedWorkshopId = newId);
                            ref.read(activeWorkshopIdProvider.notifier).setWorkshopId(newId);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRulesTab(context, currentWorkshopId, isDark),
                _buildCuttingOptimizerTab(context, currentWorkshopId, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: Rules & Custom Overrides
  // ===========================================================================
  Widget _buildRulesTab(BuildContext context, String workshopId, bool isDark) {
    final effectiveRulesAsync = ref.watch(effectiveRulesProvider(workshopId));
    final overridesAsync = ref.watch(workshopOverridesProvider(workshopId));
    final engine = ref.watch(calculatorEngineProvider(workshopId));

    return effectiveRulesAsync.when(
      data: (rules) {
        final overrides = overridesAsync.value ?? const {};

        // 1. Group rules by Profile System
        final systemIds = rules
            .map((r) => r.profileSystemId)
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();

        if (systemIds.isEmpty) {
          systemIds.add(SeedRules.system2000Beaded);
        }

        final currentSystemId = (_selectedProfileSystemId != null && systemIds.contains(_selectedProfileSystemId))
            ? _selectedProfileSystemId!
            : systemIds.first;

        final systemRules = rules.where((r) => r.profileSystemId == currentSystemId).toList();

        // 2. Compute Engineering Preview for Reference Window (120 x 150 cm)
        const sampleW = 120.0;
        const sampleH = 150.0;
        final spec = UnitSpecification(
          widthCm: sampleW,
          heightCm: sampleH,
          quantity: 1,
          sashCount: 2,
          screenCount: 1,
          hasScreen: true,
          profileSystemId: currentSystemId,
        );

        final calcResult = engine.calculate(spec);

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Workshop Specific Disclaimer
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.amberPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.info_outline_rounded, color: AppColors.amberPrimary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'تطبق هذه القواعد ومعادلات التقطيع حصرياً على هذه الورشة. يمكنك تعديل أي معادلة بما يناسب معداتك، واستعادة القواعد الأصلية بضغطة زر دون التأثير على أي ورشة أخرى.',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Profile System Selector
            _buildProfileSystemSelector(context, systemIds, currentSystemId, isDark),
            const SizedBox(height: 20),

            // Engineering Preview Table (Matches the Screenshot)
            _buildEngineeringPreviewTable(
              context,
              workshopId,
              currentSystemId,
              systemRules,
              calcResult,
              overrides,
              isDark,
            ),
            const SizedBox(height: 24),

            // Collapsible Detailed Rules & Formulas List
            _buildDetailedRulesSection(
              context,
              workshopId,
              currentSystemId,
              systemRules,
              overrides,
              isDark,
            ),
            const SizedBox(height: 32),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('خطأ في تحميل القواعد: $err')),
    );
  }

  Widget _buildProfileSystemSelector(
    BuildContext context,
    List<String> systemIds,
    String currentSystemId,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.category_rounded, size: 18, color: AppColors.amberPrimary),
              const SizedBox(width: 8),
              Text(
                'نظام القطاع الهندسي (Profile System):',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.amberPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${systemIds.length} نظام متاح',
                  style: const TextStyle(fontSize: 11, color: AppColors.amberLight, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: systemIds.map((sysId) {
              final isSelected = sysId == currentSystemId;
              return ChoiceChip(
                label: Text(_getSystemDisplayName(sysId)),
                selected: isSelected,
                selectedColor: AppColors.amberPrimary.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.amberPrimary : null,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedProfileSystemId = sysId);
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineeringPreviewTable(
    BuildContext context,
    String workshopId,
    String currentSystemId,
    List<CalculationRule> systemRules,
    CalculationResult calcResult,
    Map<String, dynamic> overrides,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    // Build Rows for the Table
    final rows = <_EngineeringPreviewRowData>[];

    // Helper to find rule
    CalculationRule? findRule(String itemCode) {
      return systemRules.where((r) => r.itemCode == itemCode).firstOrNull;
    }

    // 1. Track (سكة 2000 بحاجب)
    final trackRule = findRule('track');
    final trackPiece = calcResult.pieces.where((p) => p.itemCode == 'track').firstOrNull;
    rows.add(_EngineeringPreviewRowData(
      titleArabic: 'سكة 2000 بحاجب',
      codeEnglish: 'Track',
      quantity: trackPiece?.quantity ?? 2,
      formula: trackRule?.lengthFormula ?? 'W - 3',
      formattedResult: (trackPiece?.lengthCm ?? 117.0).toStringAsFixed(1),
      rule: trackRule,
      isOverridden: trackRule != null && overrides.containsKey(trackRule.ruleKey),
    ));

    // 2. U-Profile (يو 2000)
    final uRule = findRule('u_profile');
    final uPiece = calcResult.pieces.where((p) => p.itemCode == 'u_profile').firstOrNull;
    rows.add(_EngineeringPreviewRowData(
      titleArabic: 'يو 2000',
      codeEnglish: 'U-Profile',
      quantity: uPiece?.quantity ?? 2,
      formula: uRule?.lengthFormula ?? 'H - 3.3',
      formattedResult: (uPiece?.lengthCm ?? 146.7).toStringAsFixed(1),
      rule: uRule,
      isOverridden: uRule != null && overrides.containsKey(uRule.ruleKey),
    ));

    // 3. Kaab (كعب 2000 مفرد)
    final kaabRule = findRule('kaab');
    final kaabPiece = calcResult.pieces.where((p) => p.itemCode == 'kaab').firstOrNull;
    rows.add(_EngineeringPreviewRowData(
      titleArabic: 'كعب 2000 مفرد',
      codeEnglish: 'Kaab',
      quantity: kaabPiece?.quantity ?? 4,
      formula: kaabRule?.lengthFormula ?? '(W - 2.5) / 2',
      formattedResult: (kaabPiece?.lengthCm ?? 58.75).toStringAsFixed(2),
      rule: kaabRule,
      isOverridden: kaabRule != null && overrides.containsKey(kaabRule.ruleKey),
    ));

    // 4. Screen Vertical (درفة منخل عامودي)
    final svRule = findRule('screen_vertical');
    final svPiece = calcResult.pieces.where((p) => p.itemCode == 'screen_vertical').firstOrNull;
    rows.add(_EngineeringPreviewRowData(
      titleArabic: 'درفة منخل عامودي',
      codeEnglish: '.Screen Vert',
      quantity: svPiece?.quantity ?? 2,
      formula: svRule?.lengthFormula ?? 'H - 4.1',
      formattedResult: (svPiece?.lengthCm ?? 145.9).toStringAsFixed(1),
      rule: svRule,
      isOverridden: svRule != null && overrides.containsKey(svRule.ruleKey),
    ));

    // 5. Screen Horizontal (درفة منخل أفقي)
    final shRule = findRule('screen_horizontal');
    final shPiece = calcResult.pieces.where((p) => p.itemCode == 'screen_horizontal').firstOrNull;
    rows.add(_EngineeringPreviewRowData(
      titleArabic: 'درفة منخل أفقي',
      codeEnglish: '.Screen Horiz',
      quantity: shPiece?.quantity ?? 2,
      formula: shRule?.lengthFormula ?? 'kaab_len + 2',
      formattedResult: (shPiece?.lengthCm ?? 60.75).toStringAsFixed(2),
      rule: shRule,
      isOverridden: shRule != null && overrides.containsKey(shRule.ruleKey),
    ));

    // 6. Glass Height (ارتفاع الزجاج)
    final ghRule = findRule('glass_height');
    rows.add(_EngineeringPreviewRowData(
      titleArabic: 'ارتفاع الزجاج',
      codeEnglish: 'Glass Height',
      quantity: calcResult.glass.quantity > 0 ? calcResult.glass.quantity : 2,
      formula: ghRule?.lengthFormula ?? 'H - 14',
      formattedResult: calcResult.glass.paneHeightCm > 0
          ? calcResult.glass.paneHeightCm.toStringAsFixed(1)
          : '136.0',
      rule: ghRule,
      isOverridden: ghRule != null && overrides.containsKey(ghRule.ruleKey),
    ));

    // 7. Glass Width (عرض الزجاج للدرفة)
    final gwRule = findRule('glass_width');
    rows.add(_EngineeringPreviewRowData(
      titleArabic: 'عرض الزجاج للدرفة',
      codeEnglish: 'Glass Width',
      quantity: calcResult.glass.quantity > 0 ? calcResult.glass.quantity : 2,
      formula: gwRule?.lengthFormula ?? '(W - 16.2) / 2',
      formattedResult: calcResult.glass.paneWidthCm > 0
          ? calcResult.glass.paneWidthCm.toStringAsFixed(1)
          : '51.9',
      rule: gwRule,
      isOverridden: gwRule != null && overrides.containsKey(gwRule.ruleKey),
    ));

    // 8. Pane Area (مساحة اللوح)
    final paneWidthStr = calcResult.glass.paneWidthCm > 0 ? calcResult.glass.paneWidthCm.toStringAsFixed(1) : '51.9';
    final paneHeightStr = calcResult.glass.paneHeightCm > 0 ? calcResult.glass.paneHeightCm.toStringAsFixed(0) : '136';
    final areaVal = calcResult.glass.singlePaneAreaM2 > 0
        ? calcResult.glass.singlePaneAreaM2
        : (51.9 * 136.0 / 10000.0);
    rows.add(_EngineeringPreviewRowData(
      titleArabic: 'مساحة اللوح',
      codeEnglish: 'Pane Area',
      quantity: calcResult.glass.quantity > 0 ? calcResult.glass.quantity : 2,
      formula: '$paneWidthStr × $paneHeightStr /\n10000',
      formattedResult: areaVal.toStringAsFixed(5),
      unit: 'م²',
      rule: null,
      isOverridden: false,
    ));

    // Any other dynamic pieces in future systems
    for (final piece in calcResult.pieces) {
      if (['track', 'u_profile', 'kaab', 'screen_vertical', 'screen_horizontal'].contains(piece.itemCode)) {
        continue;
      }
      final r = findRule(piece.itemCode);
      rows.add(_EngineeringPreviewRowData(
        titleArabic: piece.nameArabic.isNotEmpty ? piece.nameArabic : (r?.nameArabic ?? piece.itemCode),
        codeEnglish: piece.itemCode,
        quantity: piece.quantity,
        formula: r?.lengthFormula ?? '-',
        formattedResult: piece.lengthCm.toStringAsFixed(1),
        rule: r,
        isOverridden: r != null && overrides.containsKey(r.ruleKey),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title & Subtitle Matching Screenshot
        Center(
          child: Column(
            children: [
              Text(
                'المعاينة الهندسية لـ ${_getSystemDisplayName(currentSystemId)}',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                '(شباك 120 × 150 سم)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.amberPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'عينة من أبعاد التقطيع والزجاج المعتمدة وفقاً لمعايير وثيقة المواصفات',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.slate400),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Engineering Table Card
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkBackground.withValues(alpha: 0.6)
                      : AppColors.lightBackground,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'العنصر / المقاس',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate400),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Center(
                        child: Text(
                          'الكمية',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate400),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: Center(
                        child: Text(
                          'معادلة القطاع',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate400),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'الناتج الدقيق',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate400),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Table Rows
              ...rows.asMap().entries.map((entry) {
                final idx = entry.key;
                final row = entry.value;
                final isLast = idx == rows.length - 1;

                return Column(
                  children: [
                    InkWell(
                      borderRadius: isLast
                          ? const BorderRadius.vertical(bottom: Radius.circular(16))
                          : null,
                      onTap: row.rule != null
                          ? () => _openEditRuleDialog(context, row.rule!, workshopId)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            // 1. Title & Code
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          row.titleArabic,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                        ),
                                      ),
                                      if (row.isOverridden) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppColors.amberPrimary.withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'مخصص',
                                            style: TextStyle(color: AppColors.amberLight, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '(${row.codeEnglish})',
                                    style: const TextStyle(
                                      color: AppColors.slate400,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 2. Qty Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.amberPrimary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${row.quantity}x',
                                style: const TextStyle(
                                  color: AppColors.amberLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // 3. Formula
                            Expanded(
                              flex: 4,
                              child: Center(
                                child: Text(
                                  row.formula,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.slate200 : AppColors.slate700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),

                            // 4. Exact Live Output
                            Expanded(
                              flex: 3,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${row.formattedResult} ${row.unit}',
                                  style: const TextStyle(
                                    color: AppColors.glassBlue,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast) const Divider(height: 1),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedRulesSection(
    BuildContext context,
    String workshopId,
    String currentSystemId,
    List<CalculationRule> systemRules,
    Map<String, dynamic> overrides,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: ExpansionTile(
        initiallyExpanded: _isDetailedRulesExpanded,
        onExpansionChanged: (val) => setState(() => _isDetailedRulesExpanded = val),
        leading: const Icon(Icons.tune_rounded, color: AppColors.amberPrimary),
        title: Text(
          'تعديل وتفاصيل قواعد القطاع (${systemRules.length})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: const Text(
          'عرض زوايا القص، والشروط، واستعادة القيم الافتراضية لكل عنصر على حدة',
          style: TextStyle(fontSize: 11, color: AppColors.slate400),
        ),
        childrenPadding: const EdgeInsets.all(12),
        children: systemRules.map((rule) {
          final isOverridden = overrides.containsKey(rule.ruleKey);
          return _buildRuleCard(context, rule, isOverridden, workshopId, isDark);
        }).toList(),
      ),
    );
  }

  String _getSystemDisplayName(String systemId) {
    switch (systemId) {
      case SeedRules.system2000Beaded:
      case 'system2000Beaded':
        return 'قطاع 2000 بحاجب';
      case 'system2000Plain':
        return 'قطاع 2000 بدون حاجب';
      case 'system40Sliding':
        return 'قطاع سحاب 40 مم';
      case 'systemHinged':
        return 'قطاع مفصلي قياسي';
      default:
        return systemId.isNotEmpty ? systemId : 'نظام عام';
    }
  }

  Widget _buildRuleCard(
    BuildContext context,
    CalculationRule rule,
    bool isOverridden,
    String workshopId,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isOverridden ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOverridden
              ? AppColors.amberPrimary.withValues(alpha: 0.5)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isOverridden ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rule.nameArabic.isNotEmpty ? rule.nameArabic : rule.itemCode,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.slate700.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        rule.itemCode,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isOverridden
                        ? AppColors.amberPrimary.withValues(alpha: 0.15)
                        : AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOverridden ? AppColors.amberPrimary : AppColors.success,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOverridden ? Icons.tune_rounded : Icons.verified_rounded,
                        size: 12,
                        color: isOverridden ? AppColors.amberPrimary : AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOverridden ? 'مخصص للورشة' : 'افتراضي المنصة',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isOverridden ? AppColors.amberPrimary : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 80,
                        child: Text('معادلة الطول:', style: TextStyle(fontSize: 11, color: AppColors.slate400)),
                      ),
                      Expanded(
                        child: Text(
                          rule.lengthFormula,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const SizedBox(
                        width: 80,
                        child: Text('معادلة العدد:', style: TextStyle(fontSize: 11, color: AppColors.slate400)),
                      ),
                      Expanded(
                        child: Text(
                          rule.quantityFormula,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const SizedBox(
                        width: 80,
                        child: Text('زوايا القص:', style: TextStyle(fontSize: 11, color: AppColors.slate400)),
                      ),
                      Expanded(
                        child: Text(
                          'يمين: ${rule.cutAngleRight.toInt()}° • يسار: ${rule.cutAngleLeft.toInt()}°',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              children: [
                if (isOverridden)
                  TextButton.icon(
                    icon: const Icon(Icons.restore_rounded, size: 15, color: AppColors.error),
                    label: const Text('استعادة الافتراضي', style: TextStyle(color: AppColors.error, fontSize: 12)),
                    onPressed: () => _confirmRestoreRule(context, rule, workshopId),
                  ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit_rounded, size: 15),
                  label: Text(isOverridden ? 'تعديل المعادلة' : 'تخصيص للورشة', style: const TextStyle(fontSize: 12)),
                  onPressed: () => _openEditRuleDialog(context, rule, workshopId),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditRuleDialog(
    BuildContext context,
    CalculationRule rule,
    String workshopId,
  ) async {
    final lengthCtrl = TextEditingController(text: rule.lengthFormula);
    final quantityCtrl = TextEditingController(text: rule.quantityFormula);
    String? validationError;

    final repo = ref.read(rulesRepositoryProvider);
    final currentUser = ref.read(currentUserProvider).value;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void validate() {
              final dummy = rule.copyWith(
                lengthFormula: lengthCtrl.text.trim(),
                quantityFormula: quantityCtrl.text.trim(),
              );
              final res = RuleValidator.validate(dummy);
              setDialogState(() {
                validationError = res.isValid ? null : res.errorMessages.join('\n');
              });
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppColors.amberPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تخصيص: ${rule.nameArabic.isNotEmpty ? rule.nameArabic : rule.itemCode}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'هذا التعديل سيطبق فقط على هذه الورشة المحددة دون أي تأثير على باقي الورش.',
                        style: TextStyle(fontSize: 12, color: AppColors.slate400),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: lengthCtrl,
                        decoration: const InputDecoration(
                          labelText: 'معادلة الطول (سم)',
                          hintText: 'مثال: (W / 2) + 0.9',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => validate(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: quantityCtrl,
                        decoration: const InputDecoration(
                          labelText: 'معادلة عدد القطع',
                          hintText: 'مثال: sashCount * 2',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => validate(),
                      ),
                      const SizedBox(height: 12),
                      if (validationError != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  validationError!,
                                  style: const TextStyle(color: AppColors.error, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 16),
                              SizedBox(width: 6),
                              Text('المعادلات صحيحة هندسياً', style: TextStyle(color: AppColors.success, fontSize: 11)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: validationError != null
                      ? null
                      : () async {
                          await repo.saveWorkshopRuleOverride(
                            workshopId: workshopId,
                            ruleKey: rule.ruleKey,
                            lengthFormula: lengthCtrl.text.trim(),
                            quantityFormula: quantityCtrl.text.trim(),
                            baseRuleVersionId: rule.id,
                            updatedBy: currentUser?.uid,
                          );

                          if (context.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم حفظ معادلة الورشة بنجاح')),
                            );
                          }
                        },
                  child: const Text('حفظ التعديل للورشة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmRestoreRule(
    BuildContext context,
    CalculationRule rule,
    String workshopId,
  ) async {
    final repo = ref.read(rulesRepositoryProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('استعادة القاعدة الافتراضية'),
          content: Text('هل ترغب بإلغاء التعديل المخصص لـ "${rule.nameArabic.isNotEmpty ? rule.nameArabic : rule.itemCode}" والعودة إلى القاعدة المعتمدة من إدارة المنصة لهذه الورشة؟'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('استعادة الافتراضي'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      await repo.deleteWorkshopRuleOverride(
        workshopId: workshopId,
        ruleKey: rule.ruleKey,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت استعادة القاعدة الافتراضية بنجاح')),
        );
      }
    }
  }

  // ===========================================================================
  // TAB 2: Cutting Optimizer & Saw Kerf Settings
  // ===========================================================================
  Widget _buildCuttingOptimizerTab(BuildContext context, String workshopId, bool isDark) {
    final optimizerAsync = ref.watch(cuttingOptimizerProvider(workshopId));

    return optimizerAsync.when(
      data: (opt) => _CuttingSettingsForm(workshopId: workshopId, initialOptimizer: opt),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('خطأ في تحميل إعدادات التقطيع: $err')),
    );
  }
}

class _CuttingSettingsForm extends ConsumerStatefulWidget {
  final String workshopId;
  final CutOptimizer initialOptimizer;

  const _CuttingSettingsForm({
    required this.workshopId,
    required this.initialOptimizer,
  });

  @override
  ConsumerState<_CuttingSettingsForm> createState() => _CuttingSettingsFormState();
}

class _CuttingSettingsFormState extends ConsumerState<_CuttingSettingsForm> {
  late final TextEditingController _barLengthCtrl;
  late final TextEditingController _trimLossCtrl;
  late final TextEditingController _kerfCtrl;
  late final TextEditingController _minRemnantCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _barLengthCtrl = TextEditingController(text: widget.initialOptimizer.barLengthCm.toStringAsFixed(1));
    _trimLossCtrl = TextEditingController(text: widget.initialOptimizer.trimLossCm.toStringAsFixed(1));
    _kerfCtrl = TextEditingController(text: widget.initialOptimizer.kerfPerCutCm.toStringAsFixed(2));
    _minRemnantCtrl = TextEditingController(text: widget.initialOptimizer.minRemnantCm.toStringAsFixed(1));
  }

  @override
  void didUpdateWidget(covariant _CuttingSettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workshopId != widget.workshopId || oldWidget.initialOptimizer != widget.initialOptimizer) {
      _barLengthCtrl.text = widget.initialOptimizer.barLengthCm.toStringAsFixed(1);
      _trimLossCtrl.text = widget.initialOptimizer.trimLossCm.toStringAsFixed(1);
      _kerfCtrl.text = widget.initialOptimizer.kerfPerCutCm.toStringAsFixed(2);
      _minRemnantCtrl.text = widget.initialOptimizer.minRemnantCm.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _barLengthCtrl.dispose();
    _trimLossCtrl.dispose();
    _kerfCtrl.dispose();
    _minRemnantCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final barLen = double.tryParse(_barLengthCtrl.text) ?? widget.initialOptimizer.barLengthCm;
    final trimLoss = double.tryParse(_trimLossCtrl.text) ?? widget.initialOptimizer.trimLossCm;
    final kerf = double.tryParse(_kerfCtrl.text) ?? widget.initialOptimizer.kerfPerCutCm;
    final minRemnant = double.tryParse(_minRemnantCtrl.text) ?? widget.initialOptimizer.minRemnantCm;

    final isDefault = (widget.initialOptimizer.barLengthCm == 660.0 &&
        widget.initialOptimizer.trimLossCm == 4.0 &&
        widget.initialOptimizer.kerfPerCutCm == 0.5 &&
        widget.initialOptimizer.minRemnantCm == 50.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.glassBlue.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.straighten_rounded, color: AppColors.glassBlueLight, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'معايير منشار الورشة',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDefault ? AppColors.success.withValues(alpha: 0.15) : AppColors.amberPrimary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isDefault ? 'افتراضي المنصة' : 'مخصص لهذه الورشة',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isDefault ? AppColors.success : AppColors.amberPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'تحدد هذه القيم طريقة توزيع القطع وحساب أقل نسبة هدر خصيصاً لهذه الورشة.',
                            style: TextStyle(fontSize: 11, color: AppColors.slate400),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Visual Bar Illustration
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('مخطط توضيحي لمواصفات القضيب الخام', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 32,
                          color: AppColors.slate700,
                          child: Row(
                            children: [
                              // Trim loss left
                              Container(
                                width: 20,
                                color: AppColors.error,
                                child: const Center(
                                  child: Text('ف', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              // Usable body
                              Expanded(
                                child: Container(
                                  color: AppColors.glassBlue,
                                  child: Center(
                                    child: Text(
                                      'طول التشغيل الفعلي: ${(barLen - trimLoss).toStringAsFixed(1)} سم',
                                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              // Trim loss right
                              Container(
                                width: 20,
                                color: AppColors.error,
                                child: const Center(
                                  child: Text('ف', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text('طول القضيب: $barLen سم', style: const TextStyle(fontSize: 10, color: AppColors.slate400)),
                          Text('فاقد الشفرة: $kerf سم', style: const TextStyle(fontSize: 10, color: AppColors.slate400)),
                          Text('عتبة السكراب: $minRemnant سم', style: const TextStyle(fontSize: 10, color: AppColors.slate400)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Inputs Form (Responsive)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 540;

                      Widget fieldBarLen = TextField(
                        controller: _barLengthCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'طول القضيب الخام (سم)',
                          hintText: '660.0',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.straighten_rounded, size: 20),
                        ),
                        onChanged: (_) => setState(() {}),
                      );

                      Widget fieldTrimLoss = TextField(
                        controller: _trimLossCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'فاقد تسوية الطرفين (سم)',
                          hintText: '4.0',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.content_cut_rounded, size: 20),
                        ),
                        onChanged: (_) => setState(() {}),
                      );

                      Widget fieldKerf = TextField(
                        controller: _kerfCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'سماكة شفرة المنشار (Kerf سم)',
                          hintText: '0.5',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.blur_on_rounded, size: 20),
                        ),
                        onChanged: (_) => setState(() {}),
                      );

                      Widget fieldMinRemnant = TextField(
                        controller: _minRemnantCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'الحد الأدنى لفضلات السكراب (سم)',
                          hintText: '50.0',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.inventory_2_outlined, size: 20),
                        ),
                        onChanged: (_) => setState(() {}),
                      );

                      return Column(
                        children: [
                          if (isNarrow) ...[
                            fieldBarLen,
                            const SizedBox(height: 12),
                            fieldTrimLoss,
                            const SizedBox(height: 12),
                            fieldKerf,
                            const SizedBox(height: 12),
                            fieldMinRemnant,
                          ] else ...[
                            Row(
                              children: [
                                Expanded(child: fieldBarLen),
                                const SizedBox(width: 14),
                                Expanded(child: fieldTrimLoss),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(child: fieldKerf),
                                const SizedBox(width: 14),
                                Expanded(child: fieldMinRemnant),
                              ],
                            ),
                          ],
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            alignment: WrapAlignment.end,
                            children: [
                              if (!isDefault)
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.restore_rounded, size: 15),
                                  label: const Text('استعادة الافتراضي للورشة', style: TextStyle(fontSize: 12)),
                                  onPressed: _isSaving ? null : _restorePlatformDefaults,
                                ),
                              ElevatedButton.icon(
                                icon: _isSaving
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.check_rounded, size: 15),
                                label: const Text('حفظ إعدادات المنشار', style: TextStyle(fontSize: 12)),
                                onPressed: _isSaving ? null : _saveSettings,
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    final barLen = double.tryParse(_barLengthCtrl.text);
    final trimLoss = double.tryParse(_trimLossCtrl.text);
    final kerf = double.tryParse(_kerfCtrl.text);
    final minRemnant = double.tryParse(_minRemnantCtrl.text);

    if (barLen == null || trimLoss == null || kerf == null || minRemnant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى التأكد من إدخال قيم رقمية صحيحة لجميع الحقول')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(rulesRepositoryProvider);

      await repo.saveWorkshopCuttingSettings(
        workshopId: widget.workshopId,
        barLengthCm: barLen,
        trimLossCm: trimLoss,
        kerfPerCutCm: kerf,
        minRemnantCm: minRemnant,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ إعدادات المنشار لهذه الورشة بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _restorePlatformDefaults() async {
    final repo = ref.read(rulesRepositoryProvider);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة إعدادات المنصة'),
        content: const Text('هل ترغب بإلغاء التخصيص والعودة إلى الإعدادات القياسية للمنصة (660 سم، فاقد 4 سم، شفرة 0.5 سم) لهذه الورشة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('استعادة الافتراضي'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isSaving = true);
      try {
        await repo.resetWorkshopCuttingSettings(
          workshopId: widget.workshopId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت استعادة إعدادات المنصة الافتراضية بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }
}

class _EngineeringPreviewRowData {
  final String titleArabic;
  final String codeEnglish;
  final int quantity;
  final String formula;
  final String formattedResult;
  final String unit;
  final CalculationRule? rule;
  final bool isOverridden;

  const _EngineeringPreviewRowData({
    required this.titleArabic,
    required this.codeEnglish,
    required this.quantity,
    required this.formula,
    required this.formattedResult,
    this.unit = 'سم',
    this.rule,
    this.isOverridden = false,
  });
}
