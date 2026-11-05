import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../cut_optimization/data/cut_plan_repository.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/domain/order_model.dart';
import '../../projects/domain/models/project.dart';
import '../../projects/domain/models/project_unit.dart';
import '../../projects/presentation/screens/project_detail_screen.dart';
import '../../rules/data/rules_repository.dart';
import '../../suppliers/data/suppliers_repository.dart';
import '../../suppliers/domain/supplier.dart';
import '../data/requirements_pdf_generator.dart';
import '../data/requirements_repository.dart';
import '../data/requirements_service.dart';
import '../domain/requirement_line.dart';

class ProjectRequirementsScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String? initialWorkshopId;

  const ProjectRequirementsScreen({
    super.key,
    required this.projectId,
    this.initialWorkshopId,
  });

  @override
  ConsumerState<ProjectRequirementsScreen> createState() =>
      _ProjectRequirementsScreenState();
}

class _ProjectRequirementsScreenState
    extends ConsumerState<ProjectRequirementsScreen> {
  bool _isGenerating = false;
  bool _isExportingPdf = false;
  bool _initialGenerationTriggered = false;
  String _selectedCategoryFilter = 'all';

  String _formatQty(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }

  bool _isStale({
    required Project? project,
    required List<ProjectUnit> units,
    required SavedCutPlan? savedCutPlan,
  }) {
    final genAt = project?.requirementsGeneratedAt;
    if (genAt == null) return false;
    // Allow 2 seconds tolerance for server timestamp propagation
    final threshold = genAt.add(const Duration(seconds: 2));
    if (project != null && project.updatedAt.isAfter(threshold)) {
      return true;
    }
    if (savedCutPlan != null && savedCutPlan.generatedAt.isAfter(threshold)) {
      return true;
    }
    for (final u in units) {
      if (u.updatedAt.isAfter(threshold)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _generateInitialSnapshotIfNeeded({
    required String workshopId,
    required Project? project,
    required List<ProjectUnit> units,
    required SavedCutPlan? savedCutPlan,
    required List<RequirementLine> existingLines,
  }) async {
    if (_initialGenerationTriggered || _isGenerating) return;
    if (workshopId.isEmpty || units.isEmpty) return;
    if (existingLines.isNotEmpty || project?.requirementsGeneratedAt != null) {
      return;
    }

    _initialGenerationTriggered = true;
    setState(() => _isGenerating = true);
    try {
      final engine = ref.read(calculatorEngineProvider(workshopId));
      final optimizer =
          ref.read(cuttingOptimizerProvider(workshopId)).value ??
              const CutOptimizer();
      final catalogItems = ref.read(activeCatalogItemsProvider).value ?? [];

      final freshLines = RequirementsService.computeProjectRequirements(
        units: units,
        engine: engine,
        optimizer: optimizer,
        catalogItems: catalogItems,
        savedCutPlanResult: savedCutPlan?.result,
      );

      await ref.read(requirementsRepositoryProvider).saveSnapshot(
            workshopId: workshopId,
            projectId: widget.projectId,
            lines: freshLines,
          );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _regenerateRequirements({
    required String workshopId,
    required List<ProjectUnit> units,
    required SavedCutPlan? savedCutPlan,
    required List<RequirementLine> existingLines,
  }) async {
    if (_isGenerating || workshopId.isEmpty) return;
    if (units.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد وحدات في المشروع لحساب المواد')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final engine = ref.read(calculatorEngineProvider(workshopId));
      final optimizer =
          ref.read(cuttingOptimizerProvider(workshopId)).value ??
              const CutOptimizer();
      final catalogItems = ref.read(activeCatalogItemsProvider).value ?? [];

      final freshAutoLines = RequirementsService.computeProjectRequirements(
        units: units,
        engine: engine,
        optimizer: optimizer,
        catalogItems: catalogItems,
        savedCutPlanResult: savedCutPlan?.result,
      );

      final mergedLines = RequirementsService.mergeRegeneratedLines(
        existingLines: existingLines,
        freshAutoLines: freshAutoLines,
      );

      await ref.read(requirementsRepositoryProvider).saveSnapshot(
            workshopId: workshopId,
            projectId: widget.projectId,
            lines: mergedLines,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم تحديث الكميات المحسوبة مع الاحتفاظ بتعديلاتك والمخزون المتوفر بالورشة ✅',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء إعادة توليد الاحتياجات: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentUser = ref.watch(currentUserProvider).value;
    final ownerUid = currentUser?.uid ?? '';
    final workshops = ref.watch(ownerWorkshopsProvider(ownerUid)).value ?? [];
    final activeId = ref.watch(activeWorkshopIdProvider);

    final workshopId = widget.initialWorkshopId ??
        activeId ??
        (workshops.isNotEmpty
            ? workshops.first.id
            : (currentUser?.workshopId ?? ''));

    final query = (workshopId: workshopId, projectId: widget.projectId);
    final projectAsync = ref.watch(projectDetailProvider(query));
    final unitsAsync = ref.watch(projectUnitsProvider(query));
    final savedCutPlanAsync = ref.watch(savedCutPlanProvider(query));
    final requirementsAsync = ref.watch(projectRequirementsProvider(query));
    final catalogItems = ref.watch(activeCatalogItemsProvider).value ?? [];

    final project = projectAsync.value;
    final units = unitsAsync.value ?? const [];
    final savedCutPlan = savedCutPlanAsync.value;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'احتياجات المشروع من المواد',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              if (project != null)
                Text(
                  project.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.slate400 : AppColors.slate600,
                  ),
                ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'متابعة طلبات التوريد والتسعير المرسلة للموردين',
              icon: const Icon(
                Icons.local_shipping_outlined,
                color: AppColors.glassBlueLight,
              ),
              onPressed: () => context.push(
                '/dashboard/owner/orders?workshopId=$workshopId',
              ),
            ),
            IconButton(
              tooltip: 'إعادة التوليد من وحدات المشروع وخطة القص',
              icon: _isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded, color: AppColors.amberPrimary),
              onPressed: _isGenerating
                  ? null
                  : () => _regenerateRequirements(
                        workshopId: workshopId,
                        units: units,
                        savedCutPlan: savedCutPlan,
                        existingLines: requirementsAsync.value ?? const [],
                      ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amberPrimary,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'إضافة صنف',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => _showAddOrEditDialog(
                  context: context,
                  workshopId: workshopId,
                  catalogItems: catalogItems,
                ),
              ),
            ),
          ],
        ),
        body: requirementsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) =>
              Center(child: Text('خطأ في تحميل جدول الاحتياجات: $err')),
          data: (allLines) {
            // Trigger first-time snapshot generation once data streams are ready
            if (!unitsAsync.isLoading &&
                !savedCutPlanAsync.isLoading &&
                !projectAsync.isLoading &&
                allLines.isEmpty &&
                project?.requirementsGeneratedAt == null &&
                units.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _generateInitialSnapshotIfNeeded(
                  workshopId: workshopId,
                  project: project,
                  units: units,
                  savedCutPlan: savedCutPlan,
                  existingLines: allLines,
                );
              });
            }

            if (_isGenerating && allLines.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('جاري حساب وتوليد جدول احتياجات المشروع...'),
                  ],
                ),
              );
            }

            final activeLines =
                allLines.where((l) => !l.dismissed).toList();
            final dismissedCount =
                allLines.where((l) => l.dismissed).length;
            final isStale = _isStale(
              project: project,
              units: units,
              savedCutPlan: savedCutPlan,
            );

            final filteredLines = _selectedCategoryFilter == 'all'
                ? activeLines
                : activeLines
                    .where((l) => l.category == _selectedCategoryFilter)
                    .toList();

            final totalLinesCount = activeLines.length;
            final toBuyLinesCount =
                activeLines.where((l) => l.toBuyQty > 0).length;
            final coveredLinesCount =
                activeLines.where((l) => l.toBuyQty <= 0).length;

            return Column(
              children: [
                // 1. Staleness Warning Banner
                if (isStale)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'تغيرت وحدات المشروع — إعادة التوليد',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.warning,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'تم تعديل وحدات المشروع أو خطة القص بعد توليد هذا الجدول. اضغط لإعادة تحديث الكميات المحسوبة مع الحفاظ على تعديلاتك اليدوية والمخزون المتوفر لديك.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            foregroundColor: Colors.black,
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text(
                            'إعادة التوليد',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          onPressed: _isGenerating
                              ? null
                              : () => _regenerateRequirements(
                                    workshopId: workshopId,
                                    units: units,
                                    savedCutPlan: savedCutPlan,
                                    existingLines: allLines,
                                  ),
                        ),
                      ],
                    ),
                  ),

                // 2. Top Summary Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          _SummaryStatChip(
                            icon: Icons.inventory_2_outlined,
                            label: 'إجمالي الأصناف',
                            value: '$totalLinesCount',
                            color: AppColors.glassBlueLight,
                            isDark: isDark,
                          ),
                          _SummaryStatChip(
                            icon: Icons.shopping_bag_outlined,
                            label: 'مطلوب شراؤه',
                            value: '$toBuyLinesCount صنف',
                            color: AppColors.amberPrimary,
                            isDark: isDark,
                          ),
                          _SummaryStatChip(
                            icon: Icons.check_circle_outline_rounded,
                            label: 'متوفر بالورشة',
                            value: '$coveredLinesCount صنف',
                            color: AppColors.success,
                            isDark: isDark,
                          ),
                        ],
                      ),
                      if (dismissedCount > 0)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppColors.amberPrimary,
                          ),
                          icon: const Icon(
                            Icons.restore_from_trash_rounded,
                            size: 18,
                          ),
                          label: Text('استعادة المحذوفات ($dismissedCount)'),
                          onPressed: () async {
                            final restored = await ref
                                .read(requirementsRepositoryProvider)
                                .restoreAllDismissed(
                                  workshopId: workshopId,
                                  projectId: widget.projectId,
                                );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تمت استعادة $restored صنف محذوف ✅',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),

                // 3. Category Filter Bar
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      _buildCategoryChip('all', 'الكل (${activeLines.length})'),
                      const SizedBox(width: 8),
                      _buildCategoryChip('aluminum', 'ألمنيوم'),
                      const SizedBox(width: 8),
                      _buildCategoryChip('glass', 'زجاج'),
                      const SizedBox(width: 8),
                      _buildCategoryChip('accessories', 'إكسسوارات'),
                      const SizedBox(width: 8),
                      _buildCategoryChip('fiber', 'شبك وفراشة'),
                      const SizedBox(width: 8),
                      _buildCategoryChip('plastic', 'بلاستيك وربر'),
                      const SizedBox(width: 8),
                      _buildCategoryChip('tools', 'براغي وتثبيت'),
                    ],
                  ),
                ),
                const Divider(height: 16),

                // 4. Main Content (Empty State or Grouped Table/Cards)
                Expanded(
                  child: filteredLines.isEmpty
                      ? _buildEmptyState(
                          context: context,
                          workshopId: workshopId,
                          units: units,
                          savedCutPlan: savedCutPlan,
                          allLines: allLines,
                          catalogItems: catalogItems,
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 820;
                            return _buildGroupedRequirementsView(
                              context: context,
                              workshopId: workshopId,
                              lines: filteredLines,
                              catalogItems: catalogItems,
                              isWide: isWide,
                              isDark: isDark,
                            );
                          },
                        ),
                ),

                // 5. Post-Requirements 3-Option Action Bar (Spec §5.5)
                if (toBuyLinesCount > 0)
                  _buildPostRequirementsActionBar(
                    context: context,
                    workshopId: workshopId,
                    workshops: workshops,
                    project: project,
                    activeLines: activeLines,
                    toBuyCount: toBuyLinesCount,
                    isDark: isDark,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String categoryId, String label) {
    final selected = _selectedCategoryFilter == categoryId;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.amberPrimary.withValues(alpha: 0.22),
      onSelected: (_) {
        setState(() => _selectedCategoryFilter = categoryId);
      },
    );
  }

  Widget _buildEmptyState({
    required BuildContext context,
    required String workshopId,
    required List<ProjectUnit> units,
    required SavedCutPlan? savedCutPlan,
    required List<RequirementLine> allLines,
    required List<CatalogItem> catalogItems,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.table_chart_outlined,
              size: 56,
              color: AppColors.slate400,
            ),
            const SizedBox(height: 14),
            const Text(
              'لا توجد أصناف في هذا القسم حالياً',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              units.isEmpty
                  ? 'أضف وحدات (نوافذ/أبواب) للمشروع أولاً ليتم حساب المواد تلقائياً، أو أضف أصنافاً يدوياً.'
                  : 'يمكنك توليد الاحتياجات تلقائياً من وحدات المشروع أو إضافة صنف يدوياً.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.slate400, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (units.isNotEmpty)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                    label: const Text('توليد الاحتياجات تلقائياً'),
                    onPressed: () => _regenerateRequirements(
                      workshopId: workshopId,
                      units: units,
                      savedCutPlan: savedCutPlan,
                      existingLines: allLines,
                    ),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('إضافة صنف يدوياً'),
                  onPressed: () => _showAddOrEditDialog(
                    context: context,
                    workshopId: workshopId,
                    catalogItems: catalogItems,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedRequirementsView({
    required BuildContext context,
    required String workshopId,
    required List<RequirementLine> lines,
    required List<CatalogItem> catalogItems,
    required bool isWide,
    required bool isDark,
  }) {
    final grouped = <String, List<RequirementLine>>{};
    for (final line in lines) {
      grouped.putIfAbsent(line.category, () => []).add(line);
    }

    final categories = grouped.keys.toList()
      ..sort(
        (a, b) => RequirementLine.categorySortOrder(a)
            .compareTo(RequirementLine.categorySortOrder(b)),
      );

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      itemCount: categories.length,
      itemBuilder: (ctx, idx) {
        final cat = categories[idx];
        final catLines = grouped[cat]!;
        final toBuyInCat = catLines.where((l) => l.toBuyQty > 0).length;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isDark
                  ? AppColors.slate700.withValues(alpha: 0.6)
                  : AppColors.slate300.withValues(alpha: 0.7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Category Group Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.slate800.withValues(alpha: 0.6)
                      : AppColors.slate100,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _categoryIcon(cat),
                      size: 20,
                      color: AppColors.amberPrimary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        RequirementLine.categoryLabelArabic(cat),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.amberPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'الإجمالي: ${catLines.length} · للشراء: $toBuyInCat',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.amberPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isWide)
                _buildDesktopTable(
                  context: context,
                  workshopId: workshopId,
                  catLines: catLines,
                  catalogItems: catalogItems,
                  isDark: isDark,
                )
              else
                Column(
                  children: catLines
                      .map(
                        (line) => _buildMobileLineCard(
                          context: context,
                          workshopId: workshopId,
                          line: line,
                          catalogItems: catalogItems,
                          isDark: isDark,
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable({
    required BuildContext context,
    required String workshopId,
    required List<RequirementLine> catLines,
    required List<CatalogItem> catalogItems,
    required bool isDark,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 780),
        child: DataTable(
          headingRowHeight: 44,
          dataRowMinHeight: 56,
          dataRowMaxHeight: 74,
          columnSpacing: 18,
          columns: const [
            DataColumn(
              label: Text(
                'الصنف',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              numeric: true,
              label: Text(
                'المطلوب (محسوب)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              numeric: true,
              label: Text(
                'لدي في الورشة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              numeric: true,
              label: Text(
                'المطلوب شراؤه',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'الوحدة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'ملاحظة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'المصدر',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'إجراءات',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: catLines.map((line) {
            final dimmed = line.isCoveredInWorkshop;
            final textColor = dimmed ? AppColors.slate400 : null;

            return DataRow(
              color: WidgetStateProperty.resolveWith<Color?>((_) {
                if (line.needsReviewAfterRegen) {
                  return AppColors.warning.withValues(alpha: 0.10);
                }
                if (dimmed) {
                  return isDark
                      ? AppColors.slate800.withValues(alpha: 0.25)
                      : AppColors.slate100.withValues(alpha: 0.6);
                }
                return null;
              }),
              cells: [
                // 1. Item Name + Code + Badges
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        line.nameArabic,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          decoration:
                              dimmed ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (line.engineItemCode.isNotEmpty)
                            Text(
                              line.engineItemCode,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.slate400,
                              ),
                            ),
                          if (line.needsReviewAfterRegen) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'تغيرت الكمية المحسوبة — راجع الكمية',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // 2. Calculated Required Qty (Read-only)
                DataCell(
                  Text(
                    line.isAuto ? _formatQty(line.requiredQty) : '—',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                // 3. In Stock at Workshop (Editable on tap)
                DataCell(
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _promptQuickNumberEdit(
                      context: context,
                      title: 'الكمية المتوفرة في الورشة — ${line.nameArabic}',
                      initialValue: line.inStockQty,
                      unitLabel: line.unitArabic,
                      onSubmitted: (newStock) => _updateInStockQty(
                        workshopId: workshopId,
                        line: line,
                        newInStock: newStock,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: line.inStockQty > 0
                              ? AppColors.success.withValues(alpha: 0.6)
                              : AppColors.slate400.withValues(alpha: 0.4),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatQty(line.inStockQty),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: line.inStockQty > 0
                                  ? AppColors.success
                                  : textColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.edit_outlined,
                            size: 13,
                            color: AppColors.slate400,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // 4. To Buy Qty (Overridable + status badge)
                DataCell(
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _promptQuickNumberEdit(
                      context: context,
                      title: 'الكمية المطلوب شراؤها — ${line.nameArabic}',
                      initialValue: line.toBuyQty,
                      unitLabel: line.unitArabic,
                      onSubmitted: (newToBuy) => _updateToBuyQty(
                        workshopId: workshopId,
                        line: line,
                        newToBuy: newToBuy,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dimmed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'متوفر — لا يحتاج شراء (0)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.amberPrimary
                                  .withValues(alpha: 0.14),
                              border: Border.all(
                                color: AppColors.amberPrimary
                                    .withValues(alpha: 0.5),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatQty(line.toBuyQty),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.amberPrimary,
                                  ),
                                ),
                                if (line.isToBuyOverridden) ...[
                                  const SizedBox(width: 4),
                                  const Tooltip(
                                    message: 'معدّل يدوياً',
                                    child: Icon(
                                      Icons.pan_tool_alt_rounded,
                                      size: 13,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        if (line.isAuto && line.isToBuyOverridden)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'إعادة الحساب التلقائي (المطلوب − المتوفر)',
                            icon: const Icon(
                              Icons.restart_alt_rounded,
                              size: 16,
                              color: AppColors.warning,
                            ),
                            onPressed: () => ref
                                .read(requirementsRepositoryProvider)
                                .resetToBuyOverride(
                                  workshopId: workshopId,
                                  projectId: widget.projectId,
                                  line: line,
                                ),
                          ),
                      ],
                    ),
                  ),
                ),
                // 5. Unit
                DataCell(
                  Text(
                    line.unitArabic,
                    style: TextStyle(fontSize: 12, color: textColor),
                  ),
                ),
                // 6. Note
                DataCell(
                  InkWell(
                    onTap: () => _showAddOrEditDialog(
                      context: context,
                      workshopId: workshopId,
                      catalogItems: catalogItems,
                      existingLine: line,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(
                        line.note.isEmpty ? 'إضافة ملاحظة...' : line.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: line.note.isEmpty
                              ? AppColors.slate400
                              : textColor,
                          fontStyle: line.note.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ),
                  ),
                ),
                // 7. Source Badge (`auto` vs `manual`)
                DataCell(_buildSourceBadge(line.isAuto)),
                // 8. Actions
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'تعديل الصنف',
                        icon: const Icon(
                          Icons.edit_rounded,
                          size: 18,
                          color: AppColors.amberPrimary,
                        ),
                        onPressed: () => _showAddOrEditDialog(
                          context: context,
                          workshopId: workshopId,
                          catalogItems: catalogItems,
                          existingLine: line,
                        ),
                      ),
                      IconButton(
                        tooltip: 'حذف الصنف',
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        onPressed: () => _confirmDeleteLine(
                          context: context,
                          workshopId: workshopId,
                          line: line,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMobileLineCard({
    required BuildContext context,
    required String workshopId,
    required RequirementLine line,
    required List<CatalogItem> catalogItems,
    required bool isDark,
  }) {
    final dimmed = line.isCoveredInWorkshop;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: line.needsReviewAfterRegen
            ? AppColors.warning.withValues(alpha: 0.08)
            : null,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.slate700.withValues(alpha: 0.4)
                : AppColors.slate300.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.nameArabic,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: dimmed ? AppColors.slate400 : null,
                        decoration:
                            dimmed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (line.engineItemCode.isNotEmpty)
                      Text(
                        '${line.engineItemCode} · ${line.unitArabic}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.slate400,
                        ),
                      ),
                  ],
                ),
              ),
              _buildSourceBadge(line.isAuto),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.edit_rounded,
                  size: 18,
                  color: AppColors.amberPrimary,
                ),
                onPressed: () => _showAddOrEditDialog(
                  context: context,
                  workshopId: workshopId,
                  catalogItems: catalogItems,
                  existingLine: line,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.error,
                ),
                onPressed: () => _confirmDeleteLine(
                  context: context,
                  workshopId: workshopId,
                  line: line,
                ),
              ),
            ],
          ),
          if (line.needsReviewAfterRegen)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'تغيرت الكمية المحسوبة بعد التحديث — يرجى مراجعة الكمية المطلوب شراؤها',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (line.isAuto)
                _MobileMetricBox(
                  label: 'المطلوب (محسوب)',
                  value: '${_formatQty(line.requiredQty)} ${line.unitArabic}',
                  color: AppColors.slate400,
                ),
              InkWell(
                onTap: () => _promptQuickNumberEdit(
                  context: context,
                  title: 'لدي في الورشة — ${line.nameArabic}',
                  initialValue: line.inStockQty,
                  unitLabel: line.unitArabic,
                  onSubmitted: (val) => _updateInStockQty(
                    workshopId: workshopId,
                    line: line,
                    newInStock: val,
                  ),
                ),
                child: _MobileMetricBox(
                  label: 'لدي في الورشة ✎',
                  value: '${_formatQty(line.inStockQty)} ${line.unitArabic}',
                  color: line.inStockQty > 0
                      ? AppColors.success
                      : AppColors.slate400,
                ),
              ),
              InkWell(
                onTap: () => _promptQuickNumberEdit(
                  context: context,
                  title: 'المطلوب شراؤه — ${line.nameArabic}',
                  initialValue: line.toBuyQty,
                  unitLabel: line.unitArabic,
                  onSubmitted: (val) => _updateToBuyQty(
                    workshopId: workshopId,
                    line: line,
                    newToBuy: val,
                  ),
                ),
                child: _MobileMetricBox(
                  label: line.isToBuyOverridden
                      ? 'للشراء (معدّل يدوياً) ✎'
                      : 'المطلوب شراؤه ✎',
                  value: dimmed
                      ? 'متوفر — لا يحتاج شراء'
                      : '${_formatQty(line.toBuyQty)} ${line.unitArabic}',
                  color: dimmed ? AppColors.success : AppColors.amberPrimary,
                ),
              ),
              if (line.isAuto && line.isToBuyOverridden)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.restart_alt_rounded, size: 15),
                  label: const Text(
                    'إعادة الحساب',
                    style: TextStyle(fontSize: 11),
                  ),
                  onPressed: () => ref
                      .read(requirementsRepositoryProvider)
                      .resetToBuyOverride(
                        workshopId: workshopId,
                        projectId: widget.projectId,
                        line: line,
                      ),
                ),
            ],
          ),
          if (line.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'ملاحظة: ${line.note}',
              style: const TextStyle(fontSize: 12, color: AppColors.slate400),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSourceBadge(bool isAuto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAuto
            ? AppColors.glassBlue.withValues(alpha: 0.15)
            : AppColors.amberPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isAuto ? 'تلقائي' : 'يدوي',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isAuto ? AppColors.glassBlueLight : AppColors.amberPrimary,
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'aluminum':
        return Icons.view_column_rounded;
      case 'glass':
        return Icons.grid_view_rounded;
      case 'accessories':
        return Icons.handyman_rounded;
      case 'fiber':
        return Icons.blur_on_rounded;
      case 'plastic':
        return Icons.linear_scale_rounded;
      case 'tools':
        return Icons.build_circle_outlined;
      default:
        return Icons.category_rounded;
    }
  }

  Future<void> _updateInStockQty({
    required String workshopId,
    required RequirementLine line,
    required double newInStock,
  }) async {
    final sanitizedStock = newInStock < 0 ? 0.0 : newInStock;
    final updatedToBuy = line.isToBuyOverridden
        ? line.toBuyQty
        : RequirementLine.computeDefaultToBuy(
            line.requiredQty,
            sanitizedStock,
          );

    await ref.read(requirementsRepositoryProvider).upsertLine(
          workshopId: workshopId,
          projectId: widget.projectId,
          line: line.copyWith(
            inStockQty: sanitizedStock,
            toBuyQty: updatedToBuy,
            needsReviewAfterRegen: false,
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<void> _updateToBuyQty({
    required String workshopId,
    required RequirementLine line,
    required double newToBuy,
  }) async {
    final sanitizedToBuy = newToBuy < 0 ? 0.0 : newToBuy;
    final defaultToBuy = RequirementLine.computeDefaultToBuy(
      line.requiredQty,
      line.inStockQty,
    );
    final isOverridden =
        line.isAuto && (sanitizedToBuy - defaultToBuy).abs() > 0.001;

    await ref.read(requirementsRepositoryProvider).upsertLine(
          workshopId: workshopId,
          projectId: widget.projectId,
          line: line.copyWith(
            toBuyQty: sanitizedToBuy,
            isToBuyOverridden: isOverridden,
            needsReviewAfterRegen: false,
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<void> _promptQuickNumberEdit({
    required BuildContext context,
    required String title,
    required double initialValue,
    required String unitLabel,
    required Future<void> Function(double) onSubmitted,
  }) async {
    final ctrl = TextEditingController(text: _formatQty(initialValue));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title, style: const TextStyle(fontSize: 15)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'الكمية ($unitLabel)',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (v) {
              final parsed = double.tryParse(v.trim());
              if (parsed != null && parsed >= 0) {
                Navigator.pop(ctx, parsed);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = double.tryParse(ctrl.text.trim());
                if (parsed != null && parsed >= 0) {
                  Navigator.pop(ctx, parsed);
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await onSubmitted(result);
    }
  }

  Future<void> _confirmDeleteLine({
    required BuildContext context,
    required String workshopId,
    required RequirementLine line,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد حذف الصنف'),
          content: Text(
            line.isAuto
                ? 'هل تريد استبعاد «${line.nameArabic}» من جدول الاحتياجات؟\n(لن يعود تلقائياً عند إعادة التوليد إلا إذا اخترت استعادة المحذوفات)'
                : 'هل أنت متأكد من حذف الصنف اليدوي «${line.nameArabic}»؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final repo = ref.read(requirementsRepositoryProvider);
    await repo.dismissOrDeleteLine(
      workshopId: workshopId,
      projectId: widget.projectId,
      line: line,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف «${line.nameArabic}» من الجدول'),
          action: SnackBarAction(
            label: 'تراجع',
            onPressed: () {
              repo.undoDeleteLine(
                workshopId: workshopId,
                projectId: widget.projectId,
                previousLine: line,
              );
            },
          ),
        ),
      );
    }
  }

  Future<void> _showAddOrEditDialog({
    required BuildContext context,
    required String workshopId,
    required List<CatalogItem> catalogItems,
    RequirementLine? existingLine,
  }) async {
    final isEditing = existingLine != null;
    final isAutoLine = existingLine?.isAuto ?? false;

    var useCatalogPicker =
        !isEditing && catalogItems.isNotEmpty;
    CatalogItem? selectedCatalogItem;
    var searchQuery = '';

    final nameCtrl = TextEditingController(
      text: existingLine?.nameArabic ?? '',
    );
    final inStockCtrl = TextEditingController(
      text: existingLine != null ? _formatQty(existingLine.inStockQty) : '0',
    );
    final toBuyCtrl = TextEditingController(
      text: existingLine != null ? _formatQty(existingLine.toBuyQty) : '1',
    );
    final noteCtrl = TextEditingController(text: existingLine?.note ?? '');

    var selectedCategory = existingLine?.category ?? 'accessories';
    var selectedUnit = existingLine?.unit ?? 'piece';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Enforce commercial unit = roll for fiber/brush (Spec §8.7)
          if (selectedCategory == 'fiber') {
            selectedUnit = 'roll';
          }

          final matchingCatalog = catalogItems.where((c) {
            if (searchQuery.trim().isEmpty) return true;
            final q = searchQuery.trim().toLowerCase();
            return c.arabicName.toLowerCase().contains(q) ||
                c.code.toLowerCase().contains(q) ||
                c.engineItemCode.toLowerCase().contains(q);
          }).toList();

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(
                isEditing
                    ? 'تعديل صنف — ${existingLine.nameArabic}'
                    : 'إضافة صنف لاحتياجات المشروع',
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isEditing && catalogItems.isNotEmpty) ...[
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: true,
                              icon: Icon(Icons.menu_book_rounded, size: 16),
                              label: Text('من الكتالوج'),
                            ),
                            ButtonSegment(
                              value: false,
                              icon: Icon(Icons.edit_note_rounded, size: 16),
                              label: Text('صنف مخصص (حر)'),
                            ),
                          ],
                          selected: {useCatalogPicker},
                          onSelectionChanged: (s) {
                            setDialogState(() {
                              useCatalogPicker = s.first;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (!isEditing && useCatalogPicker) ...[
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'ابحث في الكتالوج بالاسم أو الكود',
                            prefixIcon: Icon(Icons.search_rounded),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) {
                            setDialogState(() => searchQuery = v);
                          },
                        ),
                        const SizedBox(height: 10),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 160),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.slate400.withValues(alpha: 0.4),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: matchingCatalog.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text('لا توجد أصناف مطابقة'),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: matchingCatalog.length,
                                  itemBuilder: (_, i) {
                                    final item = matchingCatalog[i];
                                    final isSelected =
                                        selectedCatalogItem?.id == item.id;
                                    return ListTile(
                                      dense: true,
                                      selected: isSelected,
                                      title: Text(item.arabicName),
                                      subtitle: Text(
                                        '${item.code} · ${RequirementLine.unitLabelArabic(item.unit)}',
                                      ),
                                      trailing: isSelected
                                          ? const Icon(
                                              Icons.check_circle_rounded,
                                              color: AppColors.amberPrimary,
                                            )
                                          : null,
                                      onTap: () {
                                        setDialogState(() {
                                          selectedCatalogItem = item;
                                          nameCtrl.text = item.arabicName;
                                          selectedCategory = item.categoryId;
                                          selectedUnit =
                                              item.categoryId == 'fiber'
                                                  ? 'roll'
                                                  : item.unit;
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (!isAutoLine) ...[
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'اسم الصنف بالعربية *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedCategory,
                                decoration: const InputDecoration(
                                  labelText: 'التصنيف',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'aluminum',
                                    child: Text('ألمنيوم'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'glass',
                                    child: Text('زجاج'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'accessories',
                                    child: Text('إكسسوارات'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'fiber',
                                    child: Text('شبك وفراشة (لفة)'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'plastic',
                                    child: Text('بلاستيك وربر'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'tools',
                                    child: Text('براغي وتثبيت'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val == null) return;
                                  setDialogState(() {
                                    selectedCategory = val;
                                    if (val == 'fiber') {
                                      selectedUnit = 'roll';
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedUnit,
                                decoration: const InputDecoration(
                                  labelText: 'الوحدة',
                                  border: OutlineInputBorder(),
                                ),
                                items: selectedCategory == 'fiber'
                                    ? const [
                                        DropdownMenuItem(
                                          value: 'roll',
                                          child: Text('لفة (Roll)'),
                                        ),
                                      ]
                                    : const [
                                        DropdownMenuItem(
                                          value: 'bar',
                                          child: Text('قضيب (6.6م)'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'piece',
                                          child: Text('حبة'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'roll',
                                          child: Text('لفة'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'm2',
                                          child: Text('م²'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'm',
                                          child: Text('متر'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'box',
                                          child: Text('علبة'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'kg',
                                          child: Text('كغ'),
                                        ),
                                      ],
                                onChanged: selectedCategory == 'fiber'
                                    ? null
                                    : (val) {
                                        if (val == null) return;
                                        setDialogState(() {
                                          selectedUnit = val;
                                        });
                                      },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.glassBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'الكمية المحسوبة من المشروع: ${_formatQty(existingLine!.requiredQty)} ${existingLine.unitArabic}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: inStockCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'لدي في الورشة',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) {
                                if (isAutoLine) {
                                  final stock = double.tryParse(v.trim()) ?? 0;
                                  final autoToBuy =
                                      RequirementLine.computeDefaultToBuy(
                                        existingLine!.requiredQty,
                                        stock,
                                      );
                                  toBuyCtrl.text = _formatQty(autoToBuy);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: toBuyCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'الكمية المطلوب شراؤها *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظة (اختياري)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يرجى إدخال اسم الصنف أو اختياره'),
                        ),
                      );
                      return;
                    }
                    final inStock =
                        double.tryParse(inStockCtrl.text.trim()) ?? 0.0;
                    final toBuy =
                        double.tryParse(toBuyCtrl.text.trim()) ?? 0.0;
                    final now = DateTime.now();

                    final RequirementLine lineToSave;
                    if (isEditing) {
                      final defaultToBuy = RequirementLine.computeDefaultToBuy(
                        existingLine.requiredQty,
                        inStock,
                      );
                      final isOverridden = existingLine.isAuto &&
                          (toBuy - defaultToBuy).abs() > 0.001;

                      lineToSave = existingLine.copyWith(
                        nameArabic: name,
                        category: selectedCategory,
                        unit: selectedCategory == 'fiber'
                            ? 'roll'
                            : selectedUnit,
                        inStockQty: inStock < 0 ? 0 : inStock,
                        toBuyQty: toBuy < 0 ? 0 : toBuy,
                        isToBuyOverridden: isOverridden,
                        needsReviewAfterRegen: false,
                        note: noteCtrl.text.trim(),
                        updatedAt: now,
                      );
                    } else {
                      lineToSave = RequirementLine(
                        id: '',
                        itemId: selectedCatalogItem?.id,
                        engineItemCode:
                            selectedCatalogItem?.engineItemCode ?? '',
                        nameArabic: name,
                        category: selectedCategory,
                        requiredQty: 0,
                        inStockQty: inStock < 0 ? 0 : inStock,
                        toBuyQty: toBuy < 0 ? 0 : toBuy,
                        isToBuyOverridden: false,
                        needsReviewAfterRegen: false,
                        unit: selectedCategory == 'fiber'
                            ? 'roll'
                            : selectedUnit,
                        note: noteCtrl.text.trim(),
                        source: 'manual',
                        dismissed: false,
                        createdAt: now,
                        updatedAt: now,
                      );
                    }

                    Navigator.pop(ctx);
                    await ref.read(requirementsRepositoryProvider).upsertLine(
                          workshopId: workshopId,
                          projectId: widget.projectId,
                          line: lineToSave,
                        );
                  },
                  child: Text(isEditing ? 'حفظ التعديلات' : 'إضافة للجدول'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostRequirementsActionBar({
    required BuildContext context,
    required String workshopId,
    required List<WorkshopInfo> workshops,
    required Project? project,
    required List<RequirementLine> activeLines,
    required int toBuyCount,
    required bool isDark,
  }) {
    final toBuyLines = activeLines.where((l) => l.toBuyQty > 0).toList();
    final workshopInfo = workshops.firstWhere(
      (w) => w.id == workshopId,
      orElse: () => WorkshopInfo(
        id: workshopId,
        name: workshops.isNotEmpty ? workshops.first.name : 'ورشة ألمنيوم',
        location: workshops.isNotEmpty ? workshops.first.location : '',
        phone: workshops.isNotEmpty ? workshops.first.phone : '',
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.assignment_turned_in_rounded,
                  size: 18,
                  color: AppColors.amberPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'جاهز للخطوة التالية ($toBuyCount صنف مطلوب للشراء): اختر طريقة التصدير أو الإرسال للمورد',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                // Option 1: Download Requirements PDF
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.amberPrimary,
                    side: const BorderSide(color: AppColors.amberPrimary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  icon: _isExportingPdf
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text(
                    '1. تحميل PDF للاحتياجات',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isExportingPdf
                      ? null
                      : () => _exportRequirementsPdf(
                            context: context,
                            workshopInfo: workshopInfo,
                            project: project,
                            toBuyLines: toBuyLines,
                          ),
                ),

                // Option 2: Select Supplier & Send Request In-App
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amberPrimary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.send_to_mobile_rounded, size: 18),
                  label: const Text(
                    '2. اختيار مورد وإرسال الطلب بالتطبيق',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showSendInAppOrderDialog(
                    context: context,
                    workshopInfo: workshopInfo,
                    project: project,
                    toBuyLines: toBuyLines,
                  ),
                ),

                // Option 3: Select Supplier & Send PDF to WhatsApp
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text(
                    '3. اختيار مورد وإرسال PDF لواتساب',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showSendWhatsAppWithPdfDialog(
                    context: context,
                    workshopInfo: workshopInfo,
                    project: project,
                    toBuyLines: toBuyLines,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportRequirementsPdf({
    required BuildContext context,
    required WorkshopInfo workshopInfo,
    required Project? project,
    required List<RequirementLine> toBuyLines,
    String? supplierName,
    String? generalNote,
  }) async {
    setState(() => _isExportingPdf = true);
    try {
      final projectName = project?.name ?? 'المشروع';
      final pdfBytes = await RequirementsPdfGenerator.generate(
        workshopName: workshopInfo.name,
        workshopPhone: workshopInfo.phone,
        workshopLocation: workshopInfo.location,
        projectName: projectName,
        clientName: project?.clientName ?? '',
        supplierName: supplierName,
        generalNote: generalNote,
        lines: toBuyLines,
      );

      await Printing.layoutPdf(
        name: 'احتياجات_مواد_${projectName.replaceAll(" ", "_")}.pdf',
        onLayout: (_) async => pdfBytes,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إنشاء ملف PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Future<void> _showSendInAppOrderDialog({
    required BuildContext context,
    required WorkshopInfo workshopInfo,
    required Project? project,
    required List<RequirementLine> toBuyLines,
  }) async {
    final suppliers = ref.read(suppliersListProvider).value ?? [];
    Supplier? selectedSupplier =
        suppliers.isNotEmpty ? suppliers.first : null;
    final notesCtrl = TextEditingController();
    var isSending = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.send_to_mobile_rounded,
                    color: AppColors.amberPrimary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'إرسال طلب تسعير وتوريد للمورد بالتطبيق',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.glassBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'سيتم إرسال (${toBuyLines.length} صنف مطلوب للشراء) إلى المورد المختار داخل التطبيق.\n'
                          'سيقوم المورد بمراجعة الأصناف وتحديد المتوفر لديه وإدخال الأسعار والملاحظات وإرسالها لك.',
                          style: const TextStyle(fontSize: 12, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (suppliers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'لا يوجد موردون مسجلون حالياً في النظام. يرجى إضافة مورد من لوحة الإدارة.',
                            style: TextStyle(color: AppColors.error),
                          ),
                        )
                      else
                        DropdownButtonFormField<Supplier>(
                          initialValue: selectedSupplier,
                          decoration: const InputDecoration(
                            labelText: 'اختر المورد *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.storefront_rounded),
                          ),
                          items: suppliers.map((s) {
                            return DropdownMenuItem<Supplier>(
                              value: s,
                              child: Text(
                                '${s.name}${s.phone.isNotEmpty ? " (${s.phone})" : ""}',
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() => selectedSupplier = val);
                          },
                        ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات الورشة للمورد (اختياري)',
                          hintText:
                              'مثال: يرجى تسعير الأصناف المتوفرة لديكم وتوضيح موعد التوريد...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amberPrimary,
                    foregroundColor: Colors.black,
                  ),
                  icon: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: const Text(
                    'إرسال الطلب للمورد',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: (isSending || selectedSupplier == null)
                      ? null
                      : () async {
                          setDialogState(() => isSending = true);
                          try {
                            final currentUser =
                                ref.read(currentUserProvider).value;
                            final projectName = project?.name ?? 'مشروع';
                            final orderItems = toBuyLines.map((line) {
                              return OrderLineItem(
                                itemId: line.itemId ?? line.engineItemCode,
                                nameArabic: line.nameArabic,
                                category: line.category,
                                requestedQty: line.toBuyQty,
                                qty: line.toBuyQty,
                                isAvailable: true,
                                unit: line.unit,
                                unitPrice: 0.0,
                                projectId: widget.projectId,
                                projectName: projectName,
                                note: line.note,
                              );
                            }).toList();

                            final orderId = await ref
                                .read(ordersRepositoryProvider)
                                .createOrder(
                                  workshopId: workshopInfo.id,
                                  workshopName: workshopInfo.name,
                                  workshopPhone: workshopInfo.phone,
                                  workshopLocation: workshopInfo.location,
                                  supplierId: selectedSupplier!.id,
                                  supplierName: selectedSupplier!.name,
                                  projectId: widget.projectId,
                                  projectName: projectName,
                                  items: orderItems,
                                  notes: notesCtrl.text.trim(),
                                  initialStatus: OrderStatus.sent,
                                  actorUid: currentUser?.uid,
                                );

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تم إرسال الطلب إلى «${selectedSupplier!.name}» بنجاح ✅',
                                  ),
                                  backgroundColor: AppColors.success,
                                  action: SnackBarAction(
                                    label: 'تتبع الطلب',
                                    textColor: Colors.white,
                                    onPressed: () => context.push(
                                      '/dashboard/owner/orders/$orderId?workshopId=${workshopInfo.id}',
                                    ),
                                  ),
                                ),
                              );
                              context.push(
                                '/dashboard/owner/orders/$orderId?workshopId=${workshopInfo.id}',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('فشل إرسال الطلب: $e'),
                                ),
                              );
                            }
                          } finally {
                            if (ctx.mounted) {
                              setDialogState(() => isSending = false);
                            }
                          }
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showSendWhatsAppWithPdfDialog({
    required BuildContext context,
    required WorkshopInfo workshopInfo,
    required Project? project,
    required List<RequirementLine> toBuyLines,
  }) async {
    final suppliers = ref.read(suppliersListProvider).value ?? [];
    Supplier? selectedSupplier =
        suppliers.isNotEmpty ? suppliers.first : null;
    final phoneCtrl = TextEditingController(
      text: selectedSupplier?.allWhatsappNumbers.isNotEmpty == true
          ? selectedSupplier!.allWhatsappNumbers.first
          : (selectedSupplier?.phone ?? ''),
    );
    final noteCtrl = TextEditingController();
    var isProcessing = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.chat_rounded, color: AppColors.success),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'إرسال الاحتياجات وملف PDF عبر واتساب للمورد',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (suppliers.isNotEmpty) ...[
                        DropdownButtonFormField<Supplier>(
                          initialValue: selectedSupplier,
                          decoration: const InputDecoration(
                            labelText: 'اختر المورد',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.storefront_rounded),
                          ),
                          items: suppliers.map((s) {
                            return DropdownMenuItem<Supplier>(
                              value: s,
                              child: Text(s.name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedSupplier = val;
                              if (val != null) {
                                phoneCtrl.text =
                                    val.allWhatsappNumbers.isNotEmpty
                                        ? val.allWhatsappNumbers.first
                                        : val.phone;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم واتساب المورد *',
                          hintText: '9665xxxxxxxx',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظة مرفقة للمورد (اختياري)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'يمكنك فتح محادثة واتساب مباشرة مع ملخص الطلب، أو مشاركة وإرفاق ملف PDF الرسمي للاحتياجات مباشرة إلى واتساب.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(ctx),
                  child: const Text('إغلاق'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('مشاركة ملف PDF لواتساب'),
                  onPressed: isProcessing
                      ? null
                      : () async {
                          setDialogState(() => isProcessing = true);
                          try {
                            final projectName = project?.name ?? 'المشروع';
                            final pdfBytes =
                                await RequirementsPdfGenerator.generate(
                                  workshopName: workshopInfo.name,
                                  workshopPhone: workshopInfo.phone,
                                  workshopLocation: workshopInfo.location,
                                  projectName: projectName,
                                  clientName: project?.clientName ?? '',
                                  supplierName: selectedSupplier?.name,
                                  generalNote: noteCtrl.text.trim(),
                                  lines: toBuyLines,
                                );
                            await Printing.sharePdf(
                              bytes: pdfBytes,
                              filename:
                                  'طلب_مواد_${projectName.replaceAll(" ", "_")}.pdf',
                            );
                          } finally {
                            if (ctx.mounted) {
                              setDialogState(() => isProcessing = false);
                            }
                          }
                        },
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('فتح واتساب المورد + PDF'),
                  onPressed: isProcessing
                      ? null
                      : () async {
                          setDialogState(() => isProcessing = true);
                          try {
                            final projectName = project?.name ?? 'المشروع';
                            final supplierName = selectedSupplier?.name ?? '';
                            final rawPhone = phoneCtrl.text.trim();
                            final cleanPhone =
                                rawPhone.replaceAll(RegExp(r'[^0-9]'), '');

                            // 1. Build formatted Arabic WhatsApp summary
                            final buf = StringBuffer();
                            buf.writeln(
                              '*طلب تسعير وتوريد مواد — ${workshopInfo.name}*',
                            );
                            buf.writeln('المشروع: $projectName');
                            if (supplierName.isNotEmpty) {
                              buf.writeln('السادة: $supplierName');
                            }
                            buf.writeln('-------------------------');
                            for (final item in toBuyLines) {
                              final q = _formatQty(item.toBuyQty);
                              final n = item.note.isNotEmpty
                                  ? ' (${item.note})'
                                  : '';
                              buf.writeln(
                                '• $q ${item.unitArabic} — ${item.nameArabic}$n',
                              );
                            }
                            buf.writeln('-------------------------');
                            if (noteCtrl.text.trim().isNotEmpty) {
                              buf.writeln(
                                'ملاحظة: ${noteCtrl.text.trim()}',
                              );
                            }
                            if (workshopInfo.location.isNotEmpty) {
                              buf.writeln('الموقع: ${workshopInfo.location}');
                            }
                            if (workshopInfo.phone.isNotEmpty) {
                              buf.writeln('هاتف الورشة: ${workshopInfo.phone}');
                            }

                            final encoded =
                                Uri.encodeComponent(buf.toString().trim());
                            final uri = Uri.parse(
                              'https://wa.me/$cleanPhone?text=$encoded',
                            );
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );

                            // 2. Also generate and share/download the PDF so the owner has it ready
                            final pdfBytes =
                                await RequirementsPdfGenerator.generate(
                                  workshopName: workshopInfo.name,
                                  workshopPhone: workshopInfo.phone,
                                  workshopLocation: workshopInfo.location,
                                  projectName: projectName,
                                  clientName: project?.clientName ?? '',
                                  supplierName: supplierName,
                                  generalNote: noteCtrl.text.trim(),
                                  lines: toBuyLines,
                                );
                            await Printing.sharePdf(
                              bytes: pdfBytes,
                              filename:
                                  'طلب_مواد_${projectName.replaceAll(" ", "_")}.pdf',
                            );
                          } finally {
                            if (ctx.mounted) {
                              setDialogState(() => isProcessing = false);
                            }
                          }
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _SummaryStatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.slate300 : AppColors.slate600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileMetricBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MobileMetricBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
