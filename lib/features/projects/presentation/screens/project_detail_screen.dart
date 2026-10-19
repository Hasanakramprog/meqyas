import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import 'package:meqyas/app/theme/app_colors.dart';
import 'package:meqyas/features/auth/presentation/controllers/auth_controller.dart';
import '../../data/projects_repository.dart';
import '../../domain/models/project.dart';
import '../../domain/models/project_unit.dart';
import '../widgets/bar_layout_view.dart';
import '../widgets/cutting_list_view.dart';
import 'quick_entry_sheet.dart';

final projectDetailProvider = StreamProvider.autoDispose.family<Project?, ({String workshopId, String projectId})>((ref, arg) {
  final repo = ref.watch(projectsRepositoryProvider);
  return Stream.fromFuture(repo.getProject(arg.workshopId, arg.projectId));
});

final projectUnitsProvider = StreamProvider.autoDispose.family<List<ProjectUnit>, ({String workshopId, String projectId})>((ref, arg) {
  final repo = ref.watch(projectsRepositoryProvider);
  return repo.watchUnits(arg.workshopId, arg.projectId);
});

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

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
    final workshopId = currentUser?.workshopId ?? '';

    final query = (workshopId: workshopId, projectId: widget.projectId);
    final projectAsync = ref.watch(projectDetailProvider(query));
    final unitsAsync = ref.watch(projectUnitsProvider(query));

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
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => QuickEntrySheet(projectId: widget.projectId),
              );
            },
          ),
          IconButton(
            tooltip: 'إضافة عنصر بتصميم هندسي كامل',
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              context.push('/dashboard/owner/projects/${widget.projectId}/units/new');
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.amberPrimary,
          labelColor: AppColors.amberPrimary,
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
              _buildUnitsListTab(context, units, workshopId, isDark),
              _buildProjectCuttingTab(context, units),
              _buildProjectBarsTab(context, units),
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
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => QuickEntrySheet(projectId: widget.projectId),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.architecture_rounded, size: 18),
                    label: const Text('استوديو التصميم 2D'),
                    onPressed: () {
                      context.push('/dashboard/owner/projects/${widget.projectId}/units/new');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: units.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final u = units[index];
        return Card(
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
                    context.push('/dashboard/owner/projects/${widget.projectId}/units/${u.id}', extra: u);
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
              context.push('/dashboard/owner/projects/${widget.projectId}/units/${u.id}', extra: u);
            },
          ),
        );
      },
    );
  }

  Widget _buildProjectCuttingTab(BuildContext context, List<ProjectUnit> units) {
    if (units.isEmpty) {
      return const Center(child: Text('لا توجد عناصر لحساب التقطيع'));
    }

    const engine = CalculatorEngine();
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

  Widget _buildProjectBarsTab(BuildContext context, List<ProjectUnit> units) {
    if (units.isEmpty) {
      return const Center(child: Text('لا توجد عناصر لحساب القضبان'));
    }

    const engine = CalculatorEngine();
    final allPieces = <CutPiece>[];
    for (var uIdx = 0; uIdx < units.length; uIdx++) {
      final u = units[uIdx];
      final unitLabel = u.name.trim().isNotEmpty ? u.name.trim() : 'W${uIdx + 1}';
      final res = engine.calculate(u.toEngineSpec());
      for (final p in res.pieces) {
        allPieces.add(
          CutPiece(
            itemCode: p.itemCode,
            nameArabic: p.nameArabic,
            lengthCm: p.lengthCm,
            quantity: p.quantity * u.quantity,
            profileType: p.profileType,
            unitTag: unitLabel,
          ),
        );
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: BarLayoutView(pieces: allPieces),
    );
  }
}
