import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../projects/domain/models/project_unit.dart';
import '../../../projects/presentation/screens/project_detail_screen.dart';
import '../../../rules/data/rules_repository.dart';
import '../../data/cut_plan_repository.dart';
import '../widgets/cut_summary_card.dart';
import '../widgets/item_group_section.dart';
import '../widgets/oversized_cuts_panel.dart';

class CutPlanScreen extends ConsumerStatefulWidget {
  final String workshopId;
  final String projectId;

  const CutPlanScreen({
    super.key,
    required this.workshopId,
    required this.projectId,
  });

  @override
  ConsumerState<CutPlanScreen> createState() => _CutPlanScreenState();
}

class _CutPlanScreenState extends ConsumerState<CutPlanScreen> {
  bool _isSaving = false;
  OptimizationResult? _result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final query = (workshopId: widget.workshopId, projectId: widget.projectId);
    final projectAsync = ref.watch(projectDetailProvider(query));
    final unitsAsync = ref.watch(projectUnitsProvider(query));
    final optimizerAsync = ref.watch(cuttingOptimizerProvider(widget.workshopId));
    final availableRemnantsAsync = ref.watch(availableRemnantsProvider(widget.workshopId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          title: projectAsync.when(
            data: (p) => Text('خطة القص — ${p?.name ?? ""}'),
            loading: () => const Text('خطة القص'),
            error: (_, _) => const Text('خطة القص'),
          ),
          centerTitle: false,
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.layers_rounded),
              tooltip: 'مخزن الفضلات',
              onPressed: () => context.push(
                '/dashboard/owner/remnants?workshopId=${widget.workshopId}',
              ),
            ),
          ],
        ),
        body: unitsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('خطأ في تحميل الوحدات: $e')),
          data: (units) {
            if (units.isEmpty) {
              return const Center(child: Text('لا توجد وحدات في هذا المشروع'));
            }

            final optimizer = optimizerAsync.value ?? const CutOptimizer();
            // A project can only consume remnants from OTHER projects / shelf stock, never its own
            final availableRemnants = (availableRemnantsAsync.value ?? [])
                .where((r) => r.sourceProjectId != widget.projectId)
                .toList();

            // Build cut pieces from all units
            final allPieces = _buildPieces(units, ref);

            // Run optimizer (remnant-aware) once — or when remnants load
            _result ??= optimizer.optimize(
              pieces: allPieces,
              availableRemnants: availableRemnants.map((r) => r.toRemnantStock()).toList(),
            );

            final result = _result!;

            return Column(
              children: [
                // ── Summary Card ──────────────────────────────────────
                CutSummaryCard(
                  summary: result.summary,
                  isDark: isDark,
                  onRefresh: () => _regenerate(optimizer, allPieces, availableRemnants),
                ),

                // ── Bar Plans List ────────────────────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (result.hasOversizedCuts)
                        OversizedCutsPanel(cuts: result.oversizedCuts, isDark: isDark),
                      ..._buildItemGroups(result, isDark),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: _result != null ? _buildActionBar(context, isDark) : null,
      ),
    );
  }

  List<CutPiece> _buildPieces(List<ProjectUnit> units, WidgetRef ref) {
    final engine = ref.read(calculatorEngineProvider(widget.workshopId));
    final allPieces = <CutPiece>[];
    for (var i = 0; i < units.length; i++) {
      final u = units[i];
      final label = u.name.trim().isNotEmpty ? u.name.trim() : 'W${i + 1}';
      final res = engine.calculate(u.toEngineSpec());
      for (var copy = 1; copy <= u.quantity; copy++) {
        final tag = u.quantity > 1 ? '$label (#$copy)' : label;
        for (final p in res.pieces) {
          allPieces.add(CutPiece(
            itemCode: p.itemCode,
            nameArabic: p.nameArabic,
            lengthCm: p.lengthCm,
            quantity: p.quantity,
            cutAngleLeft: p.cutAngleLeft,
            cutAngleRight: p.cutAngleRight,
            profileType: p.profileType,
            unitTag: tag,
          ));
        }
      }
    }
    return allPieces;
  }

  List<Widget> _buildItemGroups(OptimizationResult result, bool isDark) {
    final grouped = <String, List<BarCuttingPlan>>{};
    for (final bar in result.barPlans) {
      grouped.putIfAbsent(bar.itemCode, () => []).add(bar);
    }
    return grouped.entries
        .map((e) => ItemGroupSection(
              itemCode: e.key,
              barPlans: e.value,
              isDark: isDark,
            ))
        .toList();
  }

  void _regenerate(
    CutOptimizer optimizer,
    List<CutPiece> pieces,
    List<RemnantDoc> remnants,
  ) {
    final externalRemnants = remnants
        .where((r) => r.sourceProjectId != widget.projectId)
        .toList();
    setState(() {
      _result = optimizer.optimize(
        pieces: pieces,
        availableRemnants: externalRemnants.map((r) => r.toRemnantStock()).toList(),
      );
    });
  }

  Widget _buildActionBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('حفظ الخطة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amberPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSaving ? null : _savePlan,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.layers_rounded, size: 16),
                label: const Text('الفضلات'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => context.push(
                  '/dashboard/owner/remnants?workshopId=${widget.workshopId}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePlan() async {
    if (_result == null) return;
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    final query = (workshopId: widget.workshopId, projectId: widget.projectId);
    final project = ref.read(projectDetailProvider(query)).value;
    if (project == null) return;

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(cutPlanRepositoryProvider);
      final optimizer = ref.read(cuttingOptimizerProvider(widget.workshopId)).value;
      final planId = await repo.saveCutPlan(
        workshopId: widget.workshopId,
        projectId: widget.projectId,
        projectName: project.name,
        generatedByUid: currentUser.uid,
        result: _result!,
        minRemnantCm: optimizer?.minRemnantCm ?? 50.0,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _result!.usedRemnants
                  ? 'تم حفظ الخطة · ${_result!.consumedRemnantIds.length} فضلة مستخدمة'
                  : 'تم حفظ خطة القص بنجاح',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        // Invalidate remnants so stock screen refreshes
        ref.invalidate(availableRemnantsProvider(widget.workshopId));
        debugPrint('Cut plan saved: $planId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
