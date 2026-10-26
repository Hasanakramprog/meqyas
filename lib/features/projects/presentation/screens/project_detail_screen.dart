import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import 'package:meqyas/app/theme/app_colors.dart';
import 'package:meqyas/features/auth/presentation/controllers/auth_controller.dart';
import '../../../../features/rules/data/rules_repository.dart';
import '../../data/projects_repository.dart';
import '../../domain/models/project.dart';
import '../../domain/models/project_unit.dart';
import 'package:meqyas/features/cut_optimization/data/cut_plan_repository.dart';
import '../widgets/bar_layout_view.dart';
import '../widgets/cutting_list_view.dart';
import 'quick_entry_sheet.dart';

final projectDetailProvider = StreamProvider.autoDispose.family<Project?, ({String workshopId, String projectId})>((ref, arg) {
  final repo = ref.watch(projectsRepositoryProvider);
  return repo.watchProject(arg.workshopId, arg.projectId);
});

final projectUnitsProvider = StreamProvider.autoDispose.family<List<ProjectUnit>, ({String workshopId, String projectId})>((ref, arg) {
  final repo = ref.watch(projectsRepositoryProvider);
  return repo.watchUnits(arg.workshopId, arg.projectId);
});

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String? initialWorkshopId;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    this.initialWorkshopId,
  });

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

    final currentUser = ref.watch(currentUserProvider).value;
    final ownerUid = currentUser?.uid ?? '';
    final workshops = ref.watch(ownerWorkshopsProvider(ownerUid)).value ?? [];
    final activeId = ref.watch(activeWorkshopIdProvider);

    final workshopId = widget.initialWorkshopId ??
        activeId ??
        (workshops.isNotEmpty ? workshops.first.id : (currentUser?.workshopId ?? ''));

    final query = (workshopId: workshopId, projectId: widget.projectId);
    final projectAsync = ref.watch(projectDetailProvider(query));
    final unitsAsync = ref.watch(projectUnitsProvider(query));
    final savedCutPlanAsync = ref.watch(savedCutPlanProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: projectAsync.when(
          data: (p) => Text(p?.name ?? 'تفاصيل المشروع'),
          loading: () => const Text('جاري التحميل...'),
          error: (_, _) => const Text('المشروع'),
        ),
        actions: [
          IconButton(
            tooltip: 'إدخال سريع للقياسات',
            icon: const Icon(Icons.flash_on_rounded, color: AppColors.amberPrimary),
            onPressed: () {
              _onAddUnitRequested(
                context,
                workshopId,
                projectAsync.value,
                savedCutPlanAsync.value,
                onContinueSameProject: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => QuickEntrySheet(
                      projectId: widget.projectId,
                      workshopId: workshopId,
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            tooltip: 'إضافة عنصر بتصميم هندسي كامل',
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              _onAddUnitRequested(
                context,
                workshopId,
                projectAsync.value,
                savedCutPlanAsync.value,
              );
            },
          ),
          IconButton(
            tooltip: 'خطة القص من المخزن',
            icon: const Icon(Icons.cut_rounded, color: AppColors.warning),
            onPressed: () {
              context.push(
                '/dashboard/owner/cut-plan?projectId=${widget.projectId}&workshopId=$workshopId',
              );
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'خيارات المشروع',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'delete') {
                _confirmDeleteProject(context, ref, workshopId, projectAsync.value?.name ?? '');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                    SizedBox(width: 8),
                    Text('حذف المشروع', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.amberPrimary,
          labelColor: AppColors.amberPrimary,
          unselectedLabelColor: isDark ? AppColors.slate400 : AppColors.slate600,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt_rounded, size: 18), text: 'عناصر القياس'),
            Tab(icon: Icon(Icons.content_cut_rounded, size: 18), text: 'تقطيع المشروع الكلي'),
            Tab(icon: Icon(Icons.straighten_rounded, size: 18), text: 'تحسين القضبان 660سم'),
          ],
        ),
      ),
      body: unitsAsync.when(
        data: (units) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildUnitsListTab(
                context,
                units,
                workshopId,
                isDark,
                projectAsync.value,
                savedCutPlanAsync.value,
              ),
              _buildProjectCuttingTab(context, units, workshopId),
              _buildProjectBarsTab(context, units, workshopId),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('خطأ في تحميل العناصر: $err')),
      ),
    );
  }

  Widget _buildUnitsListTab(
    BuildContext context,
    List<ProjectUnit> units,
    String workshopId,
    bool isDark,
    Project? project,
    SavedCutPlan? savedPlan,
  ) {
    final theme = Theme.of(context);

    if (units.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.crop_free_rounded, size: 54, color: isDark ? AppColors.slate600 : AppColors.slate400),
              const SizedBox(height: 16),
              Text('لا توجد عناصر قياس مسجلة في هذا المشروع بعد', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'استخدم زر "إدخال سريع" أو "إضافة عنصر" لإدخال أبعاد الشبابيك والواجهات',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.slate400),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.flash_on_rounded, size: 18),
                    label: const Text('إدخال سريع'),
                    onPressed: () {
                      _onAddUnitRequested(
                        context,
                        workshopId,
                        project,
                        savedPlan,
                        onContinueSameProject: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => QuickEntrySheet(
                              projectId: widget.projectId,
                              workshopId: workshopId,
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.architecture_rounded, size: 18),
                    label: const Text('استوديو التصميم 2D'),
                    onPressed: () {
                      _onAddUnitRequested(
                        context,
                        workshopId,
                        project,
                        savedPlan,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final effectiveRules = ref.watch(effectiveRulesProvider(workshopId)).value ?? [];
    final activeRuleIds = effectiveRules.map((r) => r.id).toSet();
    final hasOutdatedUnit = activeRuleIds.isNotEmpty &&
        units.any((u) => u.ruleVersionIdsUsed.isNotEmpty && u.ruleVersionIdsUsed.any((id) => !activeRuleIds.contains(id)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (hasOutdatedUnit)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.amberPrimary.withValues(alpha: 0.1),
              border: Border.all(color: AppColors.amberPrimary.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.amberPrimary, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'تنبيه: تم تحديث بعض قواعد الحساب في الورشة منذ حفظ عناصر هذا المشروع. تحتفظ العناصر الحالية بنتائجها السابقة لضمان ثبات التصنيع، ويمكنك فتح أي عنصر وإعادة حفظه لتطبيق القواعد الأحدث.',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ...units.map((u) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.glassBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.window_rounded, color: AppColors.glassBlueLight),
              ),
              title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                '${u.widthCm} × ${u.heightCm} سم • العدد: ${u.quantity} • ${u.glazingMode == "single" ? "مفرد" : "مزدوج"}${u.location.isNotEmpty ? " • ${u.location}" : ""}',
                style: TextStyle(
                  color: isDark ? AppColors.slate400 : AppColors.slate600,
                  fontSize: 12,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'فتح في استوديو التصميم',
                    icon: const Icon(Icons.tune_rounded, color: AppColors.amberPrimary),
                    onPressed: () {
                      context.push('/dashboard/owner/projects/${widget.projectId}/units/${u.id}?workshopId=$workshopId', extra: u);
                    },
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('تأكيد الحذف'),
                          content: Text('هل أنت متأكد من حذف "${u.name}"؟'),
                          actions: [
                            TextButton(onPressed: () => ctx.pop(false), child: const Text('إلغاء')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                              onPressed: () => ctx.pop(true),
                              child: const Text('حذف'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(projectsRepositoryProvider).deleteUnit(workshopId, widget.projectId, u.id);
                      }
                    },
                  ),
                ],
              ),
              onTap: () {
                context.push('/dashboard/owner/projects/${widget.projectId}/units/${u.id}?workshopId=$workshopId', extra: u);
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProjectCuttingTab(BuildContext context, List<ProjectUnit> units, String workshopId) {
    if (units.isEmpty) {
      return const Center(child: Text('لا توجد عناصر لحساب التتقطيع'));
    }

    final engine = ref.watch(calculatorEngineProvider(workshopId));
    final allPieces = <CutPiece>[];
    var totalGlassArea = 0.0;
    var totalGlassWeight = 0.0;

    for (final u in units) {
      final res = engine.calculate(u.toEngineSpec());
      for (final p in res.pieces) {
        // Multiply by unit quantity
        allPieces.add(
          CutPiece(
            itemCode: p.itemCode,
            nameArabic: p.nameArabic,
            lengthCm: p.lengthCm,
            quantity: p.quantity * u.quantity,
            cutAngleLeft: p.cutAngleLeft,
            cutAngleRight: p.cutAngleRight,
            profileType: p.profileType,
          ),
        );
      }
      totalGlassArea += res.glass.totalAreaM2 * u.quantity;
      totalGlassWeight += res.glass.weightKg * u.quantity;
    }

    final combinedResult = CalculationResult(
      pieces: allPieces,
      glass: GlassSpecification(
        paneWidthCm: 0,
        paneHeightCm: 0,
        quantity: units.length,
        glazingMode: 'combined',
        glassType: 'various',
        thicknessMm: 6.0,
      ),
      accessories: const [],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('إجمالي مساحة الزجاج للمشروع', style: TextStyle(fontSize: 12, color: AppColors.slate400)),
                        const SizedBox(height: 4),
                        Text('${totalGlassArea.toStringAsFixed(3)} م²', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.glassBlueLight)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('إجمالي وزن الزجاج التقريبي', style: TextStyle(fontSize: 12, color: AppColors.slate400)),
                        const SizedBox(height: 4),
                        Text('${totalGlassWeight.toStringAsFixed(1)} كغ', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.amberPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          CuttingListView(result: combinedResult),
        ],
      ),
    );
  }

  Widget _buildProjectBarsTab(BuildContext context, List<ProjectUnit> units, String workshopId) {
    if (units.isEmpty) {
      return const Center(child: Text('لا توجد عناصر لحساب القضبان'));
    }

    final engine = ref.watch(calculatorEngineProvider(workshopId));
    final optimizer = ref.watch(cuttingOptimizerProvider(workshopId)).value;
    final allPieces = <CutPiece>[];
    for (var uIdx = 0; uIdx < units.length; uIdx++) {
      final u = units[uIdx];
      final unitLabel = u.name.trim().isNotEmpty ? u.name.trim() : 'W${uIdx + 1}';
      final res = engine.calculate(u.toEngineSpec());
      for (var copy = 1; copy <= u.quantity; copy++) {
        final tag = u.quantity > 1 ? '$unitLabel (#$copy)' : unitLabel;
        for (final p in res.pieces) {
          allPieces.add(
            CutPiece(
              itemCode: p.itemCode,
              nameArabic: p.nameArabic,
              lengthCm: p.lengthCm,
              quantity: p.quantity,
              cutAngleLeft: p.cutAngleLeft,
              cutAngleRight: p.cutAngleRight,
              profileType: p.profileType,
              unitTag: tag,
            ),
          );
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: BarLayoutView(pieces: allPieces, optimizer: optimizer),
    );
  }

  Future<void> _confirmDeleteProject(
    BuildContext context,
    WidgetRef ref,
    String workshopId,
    String projectName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('حذف المشروع'),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف مشروع «$projectName»؟\n\n'
          'سيتم حذف جميع وحداته القياسية وخطة القص والفضلات المرتبطة به.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف نهائي', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(projectsRepositoryProvider).deleteProject(workshopId, widget.projectId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف المشروع وخطة القص والفضلات بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ أثناء حذف المشروع: $e')),
          );
        }
      }
    }
  }

  Future<void> _onAddUnitRequested(
    BuildContext context,
    String workshopId,
    Project? project,
    SavedCutPlan? savedPlan, {
    VoidCallback? onContinueSameProject,
  }) async {
    if (savedPlan == null || project == null) {
      if (onContinueSameProject != null) {
        onContinueSameProject();
      } else {
        context.push('/dashboard/owner/projects/${widget.projectId}/units/new?workshopId=$workshopId');
      }
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.handyman_rounded, color: AppColors.warning, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إرشاد مهني: خطة القص معتمدة ومحفوظة',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'هل قام عامل المنشار بقص النوافذ السابقة بالفعل؟',
                              style: TextStyle(fontSize: 12, color: AppColors.slate400),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Option A: Batch 2 (Recommended if cut)
                  InkWell(
                    onTap: () async {
                      Navigator.pop(ctx);
                      final newProjectId = await _createBatchProject(context, ref, project, workshopId);
                      if (context.mounted) {
                        context.push('/dashboard/owner/projects/$newProjectId/units/new?workshopId=$workshopId');
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.amberPrimary.withValues(alpha: 0.08),
                        border: Border.all(color: AppColors.amberPrimary.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, color: AppColors.amberPrimary, size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'نعم، قُصت بالفعل (المنطق الصناعي السليم)',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.amberPrimary,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('موصى به', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'لا يمكن فيزيائياً خلط القديم بالجديد؛ لأن النوافذ القديمة أصبحت مقصوصة وفضلتها قد تكون استُهلكت. سيتم إنشاء ملحق باسم «${project.name} (دفعة 2)» لحساب خطة مستقلة للنافذة الجديدة دون المساس بما تم قصه.',
                                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate300 : AppColors.slate600, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.amberPrimary),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Option B: Continue in same project (if not cut yet)
                  InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      if (onContinueSameProject != null) {
                        onContinueSameProject();
                      } else {
                        context.push('/dashboard/owner/projects/${widget.projectId}/units/new?workshopId=$workshopId');
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.slate700.withValues(alpha: 0.3) : AppColors.slate100,
                        border: Border.all(color: AppColors.slate300.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.edit_note_rounded, color: AppColors.slate400, size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'لا، لم تُقص بعد في الورشة (كانت مجرد خطة)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'إذا كان المشروع بأكمله لم يُقص بعد على أرض الواقع، يمكنك إضافة النافذة هنا لنفس المشروع، مع إمكانية إعادة الحساب الكامل لاحقاً للحصول على أعلى نسبة توفير.',
                                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate400 : AppColors.slate500, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.slate400),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String> _createBatchProject(
    BuildContext context,
    WidgetRef ref,
    Project parentProject,
    String workshopId,
  ) async {
    final batchProject = Project(
      id: '',
      workshopId: workshopId,
      name: '${parentProject.name} (دفعة 2)',
      clientName: parentProject.clientName,
      clientPhone: parentProject.clientPhone,
      location: parentProject.location,
      status: 'in_progress',
      unitCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final repo = ref.read(projectsRepositoryProvider);
    final newId = await repo.createProject(batchProject);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إنشاء المشروع الملحق: ${batchProject.name} بنجاح ✅'),
          backgroundColor: AppColors.success,
        ),
      );
    }
    return newId;
  }
}

