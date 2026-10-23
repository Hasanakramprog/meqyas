import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import 'package:meqyas/app/theme/app_colors.dart';
import 'package:meqyas/features/auth/presentation/controllers/auth_controller.dart';
import '../data/rules_repository.dart';

class AdminRulesScreen extends ConsumerStatefulWidget {
  const AdminRulesScreen({super.key});

  @override
  ConsumerState<AdminRulesScreen> createState() => _AdminRulesScreenState();
}

class _AdminRulesScreenState extends ConsumerState<AdminRulesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _selectedStatusFilter = 'all'; // 'all', 'approved', 'draft', 'archived'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة القواعد الهندسية والمنظومة'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.amberPrimary,
          labelColor: AppColors.amberPrimary,
          unselectedLabelColor: isDark ? AppColors.slate400 : AppColors.slate600,
          tabs: const [
            Tab(icon: Icon(Icons.rule_folder_rounded, size: 18), text: 'القواعد والاعتمادات'),
            Tab(icon: Icon(Icons.biotech_rounded, size: 18), text: 'المختبر التجريبي (Sandbox)'),
            Tab(icon: Icon(Icons.settings_suggest_rounded, size: 18), text: 'إعدادات المنصة الافتراضية'),
            Tab(icon: Icon(Icons.history_edu_rounded, size: 18), text: 'سجل التدقيق (Audit Logs)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRulesListTab(context, isDark),
          _buildSandboxTab(context, isDark),
          _buildGlobalSettingsTab(context, isDark),
          _buildAuditLogsTab(context, isDark),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: Rules & Approvals
  // ===========================================================================
  Widget _buildRulesListTab(BuildContext context, bool isDark) {
    final rulesAsync = ref.watch(allAdminRulesProvider);

    return rulesAsync.when(
      data: (allRules) {
        final filteredRules = allRules.where((r) {
          if (_selectedStatusFilter == 'all') return true;
          return r.status.name == _selectedStatusFilter;
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Top action bar
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('الكل (${allRules.length})', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('معتمدة (${allRules.where((r) => r.isApproved).length})', 'approved'),
                        const SizedBox(width: 8),
                        _buildFilterChip('مسودات (${allRules.where((r) => r.isDraft).length})', 'draft'),
                        const SizedBox(width: 8),
                        _buildFilterChip('مؤرشفة (${allRules.where((r) => r.isArchived).length})', 'archived'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.verified_user_outlined, size: 16),
                  label: const Text('فحص التعارضات'),
                  onPressed: () => _runConflictCheck(context, allRules),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('إضافة مسودة قاعدة'),
                  onPressed: () => _openRuleEditorDialog(context, null),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (filteredRules.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('لا توجد قواعد مطابقة لهذا التصنيف حالياً'),
                ),
              )
            else
              ...filteredRules.map((rule) => _buildAdminRuleCard(context, rule, isDark)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('خطأ في تحميل القواعد: $err')),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedStatusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedStatusFilter = value),
      selectedColor: AppColors.amberPrimary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.amberPrimary : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildAdminRuleCard(
    BuildContext context,
    CalculationRule rule,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final repo = ref.read(rulesRepositoryProvider);

    Color statusColor;
    String statusText;
    switch (rule.status) {
      case RuleStatus.approved:
        statusColor = AppColors.success;
        statusText = 'معتمدة v${rule.version}';
        break;
      case RuleStatus.draft:
        statusColor = AppColors.amberPrimary;
        statusText = 'مسودة v${rule.version}';
        break;
      case RuleStatus.archived:
        statusColor = AppColors.slate400;
        statusText = 'مؤرشفة v${rule.version}';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        rule.nameArabic.isNotEmpty ? rule.nameArabic : rule.itemCode,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.slate700.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          rule.itemCode,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${rule.profileSystemId})',
                        style: const TextStyle(fontSize: 11, color: AppColors.slate400),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor, width: 0.8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 90, child: Text('معادلة الطول:', style: TextStyle(fontSize: 12, color: AppColors.slate400))),
                      Expanded(child: Text(rule.lengthFormula, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const SizedBox(width: 90, child: Text('معادلة العدد:', style: TextStyle(fontSize: 12, color: AppColors.slate400))),
                      Expanded(child: Text(rule.quantityFormula, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                    ],
                  ),
                  if (rule.conditions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const SizedBox(width: 90, child: Text('الشروط:', style: TextStyle(fontSize: 12, color: AppColors.slate400))),
                        Expanded(child: Text(rule.conditions.join(' AND '), style: const TextStyle(fontSize: 12, color: AppColors.glassBlueLight, fontFamily: 'monospace'))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (rule.isDraft) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                    label: const Text('حذف المسودة', style: TextStyle(color: AppColors.error)),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('تأكيد حذف المسودة'),
                          content: Text('هل أنت متأكد من حذف مسودة "${rule.nameArabic.isNotEmpty ? rule.nameArabic : rule.itemCode}"؟'),
                          actions: [
                            TextButton(onPressed: () => ctx.pop(false), child: const Text('إلغاء')),
                            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), onPressed: () => ctx.pop(true), child: const Text('حذف')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await repo.deleteDraftRule(rule.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المسودة')));
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('تعديل المسودة'),
                    onPressed: () => _openRuleEditorDialog(context, rule),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    icon: const Icon(Icons.verified_rounded, size: 16),
                    label: const Text('اعتماد ونشر القاعدة'),
                    onPressed: () async {
                      try {
                        await repo.approveRule(rule.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم اعتماد القاعدة ونشرها لجميع الورش بنجاح!')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('فشل الاعتماد: $e')),
                          );
                        }
                      }
                    },
                  ),
                ] else if (rule.isApproved) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.archive_outlined, size: 16),
                    label: const Text('أرشفة'),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('أرشفة القاعدة'),
                          content: const Text('هل ترغب بأرشفة هذه القاعدة؟ لن يتم حذفها، وستبقى المشاريع القديمة قادرة على الرجوع إليها.'),
                          actions: [
                            TextButton(onPressed: () => ctx.pop(false), child: const Text('إلغاء')),
                            ElevatedButton(onPressed: () => ctx.pop(true), child: const Text('أرشفة')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await repo.archiveRule(rule.id);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('إنشاء مسودة لتعديلها'),
                    onPressed: () {
                      final draftCopy = rule.copyWith(
                        id: '',
                        version: rule.version + 1,
                        status: RuleStatus.draft,
                      );
                      _openRuleEditorDialog(context, draftCopy);
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _runConflictCheck(BuildContext context, List<CalculationRule> allRules) {
    final approvedRules = allRules.where((r) => r.isApproved).toList();
    final allConflicts = <RuleConflict>[];

    for (final rule in approvedRules) {
      final res = ConflictDetector.detectConflicts(
        candidateRule: rule,
        approvedRules: approvedRules,
      );
      if (res.hasConflict) {
        allConflicts.addAll(res.conflicts);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              allConflicts.isEmpty ? Icons.verified_rounded : Icons.warning_rounded,
              color: allConflicts.isEmpty ? AppColors.success : AppColors.error,
            ),
            const SizedBox(width: 8),
            Text(allConflicts.isEmpty ? 'فحص التعارضات سليم' : 'تم اكتشاف تعارض في القواعد!'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: allConflicts.isEmpty
              ? const Text(
                  'تهانينا! تم فحص مصفوفة الحالات الكاملة ولم يتم العثور على أي تعارض بين القواعد المعتمدة لنفس النظام ونفس الصنف.',
                  style: TextStyle(height: 1.5),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'القواعد التالية تنطبق على نفس الشروط مما قد يؤدي لتكرار أو غموض في الحساب:',
                        style: TextStyle(color: AppColors.error, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      ...allConflicts.map(
                        (c) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Text(c.message, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Future<void> _openRuleEditorDialog(BuildContext context, CalculationRule? existingRule) async {
    final isNew = existingRule == null || existingRule.id.isEmpty;
    final nameCtrl = TextEditingController(text: existingRule?.nameArabic ?? '');
    final itemCodeCtrl = TextEditingController(text: existingRule?.itemCode ?? 'F-01');
    final systemIdCtrl = TextEditingController(text: existingRule?.profileSystemId ?? SeedRules.system2000Beaded);
    final lengthCtrl = TextEditingController(text: existingRule?.lengthFormula ?? 'H');
    final quantityCtrl = TextEditingController(text: existingRule?.quantityFormula ?? '2');
    final conditionsCtrl = TextEditingController(text: existingRule?.conditions.join(', ') ?? '');
    String outputKind = existingRule?.outputKind ?? 'profile';
    String profileType = existingRule?.profileType ?? 'frame';
    double cutAngleLeft = existingRule?.cutAngleLeft ?? 45.0;
    double cutAngleRight = existingRule?.cutAngleRight ?? 45.0;

    String? validationError;
    final repo = ref.read(rulesRepositoryProvider);
    final currentUser = ref.read(currentUserProvider).value;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          void validate() {
            final conditions = conditionsCtrl.text
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();

            final dummy = CalculationRule(
              id: existingRule?.id ?? 'temp',
              profileSystemId: systemIdCtrl.text.trim(),
              itemCode: itemCodeCtrl.text.trim(),
              nameArabic: nameCtrl.text.trim(),
              outputKind: outputKind,
              profileType: profileType,
              cutAngleLeft: cutAngleLeft,
              cutAngleRight: cutAngleRight,
              lengthFormula: lengthCtrl.text.trim(),
              quantityFormula: quantityCtrl.text.trim(),
              conditions: conditions,
              version: existingRule?.version ?? 1,
              status: RuleStatus.draft,
              effectiveAt: DateTime.now(),
            );

            final res = RuleValidator.validate(dummy);
            setDialogState(() {
              validationError = res.isValid ? null : res.errorMessages.join('\n');
            });
          }

          return AlertDialog(
            title: Text(isNew ? 'إضافة مسودة قاعدة جديدة' : 'تعديل مسودة: ${existingRule.nameArabic.isNotEmpty ? existingRule.nameArabic : existingRule.itemCode}'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(labelText: 'الاسم بالعربية', hintText: 'مثال: حلق شباك سحاب', border: OutlineInputBorder()),
                            onChanged: (_) => validate(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: itemCodeCtrl,
                            decoration: const InputDecoration(labelText: 'كود الصنف (Item Code)', hintText: 'مثال: F-01', border: OutlineInputBorder()),
                            onChanged: (_) => validate(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: outputKind,
                            decoration: const InputDecoration(labelText: 'نوع المخرج', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'profile', child: Text('قطاع ألمنيوم (Profile)')),
                              DropdownMenuItem(value: 'glass', child: Text('لوح زجاج (Glass)')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => outputKind = val);
                                validate();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: systemIdCtrl,
                            decoration: const InputDecoration(labelText: 'نظام القطاع', border: OutlineInputBorder()),
                            onChanged: (_) => validate(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lengthCtrl,
                      decoration: const InputDecoration(labelText: 'معادلة الطول (Length Formula)', border: OutlineInputBorder()),
                      onChanged: (_) => validate(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityCtrl,
                      decoration: const InputDecoration(labelText: 'معادلة العدد (Quantity Formula)', border: OutlineInputBorder()),
                      onChanged: (_) => validate(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: conditionsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الشروط (مفصولة بفاصلة)',
                        hintText: 'مثال: sashCount == 2, hasScreen == true',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => validate(),
                    ),
                    const SizedBox(height: 12),
                    if (validationError != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                        ),
                        child: Text(validationError!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
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
                            Text('صيغة المعادلة والشروط صالحة هندسياً', style: TextStyle(color: AppColors.success, fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: validationError != null
                    ? null
                    : () async {
                        final conditions = conditionsCtrl.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();

                        final ruleToSave = CalculationRule(
                          id: existingRule?.id ?? '',
                          profileSystemId: systemIdCtrl.text.trim(),
                          itemCode: itemCodeCtrl.text.trim(),
                          nameArabic: nameCtrl.text.trim(),
                          outputKind: outputKind,
                          profileType: profileType,
                          cutAngleLeft: cutAngleLeft,
                          cutAngleRight: cutAngleRight,
                          lengthFormula: lengthCtrl.text.trim(),
                          quantityFormula: quantityCtrl.text.trim(),
                          conditions: conditions,
                          version: existingRule?.version ?? 1,
                          status: RuleStatus.draft,
                          effectiveAt: DateTime.now(),
                          createdBy: currentUser?.uid,
                        );

                        await repo.saveDraftRule(ruleToSave, adminUid: currentUser?.uid);
                        if (context.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم حفظ المسودة بنجاح!')),
                          );
                        }
                      },
                child: const Text('حفظ كمسودة'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // TAB 2: Rule Sandbox
  // ===========================================================================
  Widget _buildSandboxTab(BuildContext context, bool isDark) {
    return const _SandboxView();
  }

  // ===========================================================================
  // TAB 3: Global Saw Defaults
  // ===========================================================================
  Widget _buildGlobalSettingsTab(BuildContext context, bool isDark) {
    return const _GlobalOptimizerSettingsView();
  }

  // ===========================================================================
  // TAB 4: Audit Logs
  // ===========================================================================
  Widget _buildAuditLogsTab(BuildContext context, bool isDark) {
    final logsAsync = ref.watch(auditLogsProvider);

    return logsAsync.when(
      data: (logs) {
        if (logs.isEmpty) {
          return const Center(child: Text('لا توجد سجلات تدقيق حتى الآن'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: logs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, idx) {
            final log = logs[idx];
            final action = log['action'] as String? ?? 'action';
            final ruleKey = log['ruleKey'] as String? ?? '';
            final version = log['version']?.toString() ?? '';

            return Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.amberPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.history_rounded, color: AppColors.amberPrimary, size: 20),
                ),
                title: Text('$action • $ruleKey (v$version)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('المعرف: ${log['ruleId'] ?? log['id']}'),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('خطأ في تحميل سجل التدقيق: $err')),
    );
  }
}

// =============================================================================
// Sandbox Interactive View
// =============================================================================
class _SandboxView extends ConsumerStatefulWidget {
  const _SandboxView();

  @override
  ConsumerState<_SandboxView> createState() => _SandboxViewState();
}

class _SandboxViewState extends ConsumerState<_SandboxView> {
  CalculationRule? _selectedBaseline;
  final _testLengthCtrl = TextEditingController(text: '(W / 2) + 0.9');
  final _testQuantityCtrl = TextEditingController(text: 'sashCount * 2');
  double _testW = 120.0;
  double _testH = 150.0;
  int _testSashCount = 2;

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(allAdminRulesProvider);

    return rulesAsync.when(
      data: (rules) {
        final approvedRules = rules.where((r) => r.isApproved).toList();
        if (approvedRules.isEmpty) {
          return const Center(child: Text('لا توجد قواعد معتمدة متاحة للاختبار'));
        }

        _selectedBaseline ??= approvedRules.first;

        final candidateRule = _selectedBaseline!.copyWith(
          lengthFormula: _testLengthCtrl.text.trim(),
          quantityFormula: _testQuantityCtrl.text.trim(),
        );

        final testSpec = UnitSpecification(
          widthCm: _testW,
          heightCm: _testH,
          quantity: 1,
          sashCount: _testSashCount,
          profileSystemId: _selectedBaseline!.profileSystemId,
        );

        final sandboxResult = RuleSandbox.testDraftRule(
          candidateRule: candidateRule,
          approvedRules: approvedRules,
          testSpec: testSpec,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('اختر القاعدة المعتمدة كمرجع أساسي (Baseline)', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<CalculationRule>(
                        initialValue: _selectedBaseline,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: approvedRules.map((r) {
                          return DropdownMenuItem(
                            value: r,
                            child: Text('${r.nameArabic.isNotEmpty ? r.nameArabic : r.itemCode} (${r.ruleKey})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedBaseline = val;
                              _testLengthCtrl.text = val.lengthFormula;
                              _testQuantityCtrl.text = val.quantityFormula;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Candidate Editor
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('المعادلة المقترحة للاختبار (Candidate)', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _testLengthCtrl,
                              decoration: const InputDecoration(labelText: 'معادلة الطول', border: OutlineInputBorder()),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _testQuantityCtrl,
                              decoration: const InputDecoration(labelText: 'معادلة العدد', border: OutlineInputBorder()),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            const Text('أبعاد نموذج الاختبار:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: _testW,
                                    min: 50,
                                    max: 300,
                                    divisions: 25,
                                    label: 'العرض: ${_testW.toInt()} سم',
                                    onChanged: (v) => setState(() => _testW = v),
                                  ),
                                ),
                                Text('W: ${_testW.toInt()} سم', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: _testH,
                                    min: 50,
                                    max: 300,
                                    divisions: 25,
                                    label: 'الارتفاع: ${_testH.toInt()} سم',
                                    onChanged: (v) => setState(() => _testH = v),
                                  ),
                                ),
                                Text('H: ${_testH.toInt()} سم', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('عدد الدرف: ', style: TextStyle(fontSize: 12)),
                                ChoiceChip(
                                  label: const Text('2 درفة'),
                                  selected: _testSashCount == 2,
                                  onSelected: (_) => setState(() => _testSashCount = 2),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('4 درف'),
                                  selected: _testSashCount == 4,
                                  onSelected: (_) => setState(() => _testSashCount = 4),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Comparison & Results
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('نتائج المقارنة الفورية (Diff Evaluation)', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: sandboxResult.hasDiff ? AppColors.amberPrimary.withValues(alpha: 0.15) : AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: sandboxResult.hasDiff ? AppColors.amberPrimary : AppColors.success),
                              ),
                              child: Row(
                                children: [
                                  Icon(sandboxResult.hasDiff ? Icons.difference_rounded : Icons.check_circle_rounded, color: sandboxResult.hasDiff ? AppColors.amberPrimary : AppColors.success),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(sandboxResult.summaryMessage, style: const TextStyle(fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Table(
                              border: TableBorder.all(color: AppColors.slate700.withValues(alpha: 0.3)),
                              children: [
                                const TableRow(
                                  children: [
                                    Padding(padding: EdgeInsets.all(8), child: Text('المعيار', style: TextStyle(fontWeight: FontWeight.bold))),
                                    Padding(padding: EdgeInsets.all(8), child: Text('الأصل (Baseline)', style: TextStyle(fontWeight: FontWeight.bold))),
                                    Padding(padding: EdgeInsets.all(8), child: Text('المقترح (Candidate)', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                ),
                                TableRow(
                                  children: [
                                    const Padding(padding: EdgeInsets.all(8), child: Text('طول القطعة')),
                                    Padding(padding: const EdgeInsets.all(8), child: Text('${(sandboxResult.baselinePiece?.lengthCm ?? 0.0).toStringAsFixed(2)} سم')),
                                    Padding(padding: const EdgeInsets.all(8), child: Text('${(sandboxResult.sandboxPiece?.lengthCm ?? 0.0).toStringAsFixed(2)} سم')),
                                  ],
                                ),
                                TableRow(
                                  children: [
                                    const Padding(padding: EdgeInsets.all(8), child: Text('عدد القطع')),
                                    Padding(padding: const EdgeInsets.all(8), child: Text('${sandboxResult.baselinePiece?.quantity ?? 0}')),
                                    Padding(padding: const EdgeInsets.all(8), child: Text('${sandboxResult.sandboxPiece?.quantity ?? 0}')),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('خطأ: $err')),
    );
  }
}

// =============================================================================
// Global Optimizer Settings View (System Configs)
// =============================================================================
class _GlobalOptimizerSettingsView extends ConsumerStatefulWidget {
  const _GlobalOptimizerSettingsView();

  @override
  ConsumerState<_GlobalOptimizerSettingsView> createState() => _GlobalOptimizerSettingsViewState();
}

class _GlobalOptimizerSettingsViewState extends ConsumerState<_GlobalOptimizerSettingsView> {
  final _barLenCtrl = TextEditingController(text: '660.0');
  final _trimLossCtrl = TextEditingController(text: '4.0');
  final _kerfCtrl = TextEditingController(text: '0.5');
  final _minRemnantCtrl = TextEditingController(text: '50.0');
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repo = ref.read(rulesRepositoryProvider);
      final config = await repo.getSystemCuttingOptimizer();
      if (mounted) {
        setState(() {
          _barLenCtrl.text = config.barLengthCm.toStringAsFixed(1);
          _trimLossCtrl.text = config.trimLossCm.toStringAsFixed(1);
          _kerfCtrl.text = config.kerfPerCutCm.toStringAsFixed(2);
          _minRemnantCtrl.text = config.minRemnantCm.toStringAsFixed(1);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('إعدادات المنصة الافتراضية لمنشار التقطيع (Platform Defaults)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text(
                    'تعتبر هذه القيم هي المعايير العامة لجميع الورش الجديدة والتي لم تقم بإدخال إعدادات مخصصة.',
                    style: TextStyle(fontSize: 12, color: AppColors.slate400),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _barLenCtrl,
                    decoration: const InputDecoration(labelText: 'طول القضيب الخام الافتراضي (سم)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _trimLossCtrl,
                    decoration: const InputDecoration(labelText: 'فاقد تسوية طرفي القضيب (سم)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _kerfCtrl,
                    decoration: const InputDecoration(labelText: 'سماكة شفرة المنشار (Kerf سم)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _minRemnantCtrl,
                    decoration: const InputDecoration(labelText: 'الحد الأدنى للسكراب القابل للاستخدام (سم)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      icon: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check_rounded, size: 16),
                      label: const Text('حفظ إعدادات المنصة'),
                      onPressed: _isSaving
                          ? null
                          : () async {
                              setState(() => _isSaving = true);
                              try {
                                final repo = ref.read(rulesRepositoryProvider);
                                final currentUser = ref.read(currentUserProvider).value;
                                await repo.saveSystemCuttingSettings(
                                  barLengthCm: double.parse(_barLenCtrl.text),
                                  trimLossCm: double.parse(_trimLossCtrl.text),
                                  kerfPerCutCm: double.parse(_kerfCtrl.text),
                                  minRemnantCm: double.parse(_minRemnantCtrl.text),
                                  adminUid: currentUser?.uid ?? 'admin',
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('تم حفظ الإعدادات العامة للمنصة بنجاح')),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _isSaving = false);
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
