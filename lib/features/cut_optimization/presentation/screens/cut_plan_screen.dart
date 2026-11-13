import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:maqyas_engine/maqyas_engine.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../projects/domain/models/project.dart';
import '../../../projects/domain/models/project_unit.dart';
import '../../../projects/presentation/screens/project_detail_screen.dart';
import '../../../projects/presentation/widgets/project_stepper_bar.dart';
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
  bool _hasUnsavedChanges = false;
  DateTime? _savedAt;
  String? _lastUnitsSignature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeId = ref.watch(activeWorkshopIdProvider);
    final effectiveWorkshopId = widget.workshopId.isNotEmpty
        ? widget.workshopId
        : (activeId ?? '');

    final query = (workshopId: effectiveWorkshopId, projectId: widget.projectId);
    final projectAsync = ref.watch(projectDetailProvider(query));
    final unitsAsync = ref.watch(projectUnitsProvider(query));
    final optimizerAsync = ref.watch(cuttingOptimizerProvider(effectiveWorkshopId));
    final allRemnantsAsync = ref.watch(remnantsProvider(effectiveWorkshopId));
    final savedCutPlanAsync = ref.watch(savedCutPlanProvider(query));

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
        ),
        body: unitsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('خطأ في تحميل الوحدات: $e')),
          data: (units) {
            if (units.isEmpty) {
              return const Center(child: Text('لا توجد وحدات في هذا المشروع'));
            }
            if (allRemnantsAsync.isLoading || savedCutPlanAsync.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final optimizer = optimizerAsync.value ?? const CutOptimizer();
            final savedPlan = savedCutPlanAsync.value;
            final allRemnants = allRemnantsAsync.value ?? [];

            final availableRemnants = filterAvailableRemnantsForProject(
              allRemnants: allRemnants,
              projectId: widget.projectId,
              savedPlan: savedPlan,
            );

            // Build cut pieces from all units
            final allPieces = _buildPieces(
              units,
              projectAsync.value,
              effectiveWorkshopId,
              ref,
            );

            final currentTotalCuts = allPieces.fold<int>(0, (acc, p) => acc + p.quantity);
            final currentTotalLength = allPieces.fold<double>(0, (acc, p) => acc + (p.lengthCm * p.quantity));

            final savedCutsCount = (savedPlan?.result.barPlans.fold<int>(0, (s, b) => s + b.cuts.length) ?? 0) +
                (savedPlan?.result.oversizedCuts.length ?? 0);
            final savedTotalLength = savedPlan?.result.summary.totalCutLengthCm ?? 0;
            final hasUnitsChangedSinceSave = savedPlan != null &&
                (currentTotalCuts != savedCutsCount || (currentTotalLength - savedTotalLength).abs() > 0.5);

            final colorSig = (allPieces
                    .map((p) => '${p.itemCode}:${p.color ?? 'white'}')
                    .toSet()
                    .toList()
                  ..sort())
                .join(',');
            final remSig = remnantsSignature(availableRemnants);
            final liveSig =
                '${currentTotalCuts}_${currentTotalLength.toStringAsFixed(2)}_${colorSig}_${remSig}_${optimizer.barLengthCm}_${optimizer.kerfPerCutCm}';
            if (_result == null || _lastUnitsSignature != liveSig) {
              _lastUnitsSignature = liveSig;
              final liveOpt = optimizer.optimize(
                pieces: allPieces,
                availableRemnants:
                    availableRemnants.map((r) => r.toRemnantStock()).toList(),
              );
              final savedRemnantsSet =
                  savedPlan?.result.consumedRemnantIds.toSet() ?? const <String>{};
              final liveRemnantsSet = liveOpt.consumedRemnantIds.toSet();
              final savedBarKeys = (savedPlan?.result.barPlans ?? const [])
                  .map((b) => '${b.itemCode}:${normalizeProfileColor(b.color)}')
                  .toSet();
              final liveBarKeys = liveOpt.barPlans
                  .map((b) => '${b.itemCode}:${normalizeProfileColor(b.color)}')
                  .toSet();
              final remnantsChangedSinceSave = savedPlan != null &&
                  (liveOpt.summary.totalBarsNeeded !=
                          savedPlan.result.summary.totalBarsNeeded ||
                      savedRemnantsSet.length != liveRemnantsSet.length ||
                      !savedRemnantsSet.containsAll(liveRemnantsSet) ||
                      savedBarKeys.length != liveBarKeys.length ||
                      !savedBarKeys.containsAll(liveBarKeys));
              if (savedPlan != null &&
                  !hasUnitsChangedSinceSave &&
                  !remnantsChangedSinceSave) {
                _result = savedPlan.result;
                _savedAt = savedPlan.generatedAt;
                _hasUnsavedChanges = false;
              } else {
                _result = liveOpt;
                _savedAt = savedPlan?.generatedAt;
                _hasUnsavedChanges = savedPlan != null;
              }
            }

            final result = _result!;

            return Column(
              children: [
                if (widget.projectId.isNotEmpty)
                  ProjectStepperBar(
                    projectId: widget.projectId,
                    workshopId: effectiveWorkshopId,
                    activeStep: 4,
                  ),
                // ── Status Banner for Saved Plan ──────────────────────
                if (_savedAt != null && !_hasUnsavedChanges)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'خطة معتمدة ومحفوظة · ${DateFormat('d MMMM yyyy - hh:mm a', 'ar').format(_savedAt!)}',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

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

  List<CutPiece> _buildPieces(
    List<ProjectUnit> units,
    Project? project,
    String workshopId,
    WidgetRef ref,
  ) {
    final workshopRules =
        ref.read(effectiveRulesProvider(workshopId)).value ??
            SeedRules.getSystem2000BeadedRules();
    final defaults = project?.defaults ?? const ProjectDefaults();
    final allPieces = <CutPiece>[];
    for (var i = 0; i < units.length; i++) {
      final u = units[i];
      final label = u.name.trim().isNotEmpty ? u.name.trim() : 'W${i + 1}';
      final unitRules = ProjectUnit.resolveEffectiveRules(
        workshopRules,
        projectDefaults: defaults,
        unitRuleOverrides: u.unitRuleOverrides,
      );
      final engine = CalculatorEngine(rules: unitRules);
      final res = engine.calculate(u.toEngineSpec(defaults));
      final unitColor = normalizeProfileColor(u.effectiveColor(defaults));
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
            color: unitColor,
          ));
        }
      }
    }
    return allPieces;
  }

  List<Widget> _buildItemGroups(OptimizationResult result, bool isDark) {
    final grouped = <String, List<BarCuttingPlan>>{};
    for (final bar in result.barPlans) {
      final key = '${bar.itemCode}::${normalizeProfileColor(bar.color)}';
      grouped.putIfAbsent(key, () => []).add(bar);
    }
    return grouped.entries
        .map((e) => ItemGroupSection(
              itemCode: e.value.first.itemCode,
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
      _hasUnsavedChanges = true;
    });
  }

  Widget _buildActionBar(BuildContext context, bool isDark) {
    final alreadySaved = !_hasUnsavedChanges && _savedAt != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
              child: ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        alreadySaved
                            ? Icons.check_circle_rounded
                            : Icons.content_cut_rounded,
                        size: 18,
                      ),
                label: const Text(
                  'قص',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      alreadySaved ? AppColors.success : AppColors.amberPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSaving ? null : _savePlan,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.folder_copy_rounded, size: 18),
                label: const Text(
                  'الانتقال إلى قائمة المشاريع',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.amberPrimary,
                  side: const BorderSide(color: AppColors.amberPrimary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => context.go('/dashboard/owner'),
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

    final effectiveWorkshopId = widget.workshopId.isNotEmpty
        ? widget.workshopId
        : (ref.read(activeWorkshopIdProvider) ?? '');
    final query = (workshopId: effectiveWorkshopId, projectId: widget.projectId);
    final project = ref.read(projectDetailProvider(query)).value;
    if (project == null) return;

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(cutPlanRepositoryProvider);
      final optimizer =
          ref.read(cuttingOptimizerProvider(effectiveWorkshopId)).value;
      final planId = await repo.saveCutPlan(
        workshopId: effectiveWorkshopId,
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
                  ? 'تم اعتماد القص وحفظ الخطة · ${_result!.consumedRemnantIds.length} فضلة مستخدمة'
                  : 'تم اعتماد القص وحفظ الخطة بنجاح',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        ref.invalidate(remnantsProvider(effectiveWorkshopId));
        ref.invalidate(availableRemnantsProvider(effectiveWorkshopId));
        ref.invalidate(savedCutPlanProvider(query));
        setState(() {
          _hasUnsavedChanges = false;
          _savedAt = DateTime.now();
        });
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
