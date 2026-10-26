import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:maqyas_engine/maqyas_engine.dart';
import 'package:printing/printing.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../projects/domain/models/project.dart';
import '../../../projects/domain/models/project_unit.dart';
import '../../../projects/data/projects_repository.dart';
import '../../../projects/presentation/screens/project_detail_screen.dart';
import '../../../reports/data/label_generator.dart';
import '../../../reports/data/pdf_generator.dart';
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
  bool _isExportingPdf = false;
  bool _isExportingLabels = false;
  OptimizationResult? _result;
  bool _hasUnsavedChanges = false;
  DateTime? _savedAt;

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
          actions: [
            IconButton(
              icon: _isExportingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.amberPrimary))
                  : const Icon(Icons.picture_as_pdf_rounded, color: AppColors.amberPrimary),
              tooltip: 'تصدير جدول القص PDF',
              onPressed: (_result == null || _isExportingPdf) ? null : _exportPdf,
            ),
            IconButton(
              icon: _isExportingLabels
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning))
                  : const Icon(Icons.qr_code_2_rounded, color: AppColors.warning),
              tooltip: 'طباعة ملصقات QR للقطع',
              onPressed: (_result == null || _isExportingLabels) ? null : _exportLabels,
            ),
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
            if (allRemnantsAsync.isLoading || savedCutPlanAsync.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final optimizer = optimizerAsync.value ?? const CutOptimizer();
            final savedPlan = savedCutPlanAsync.value;
            final allRemnants = allRemnantsAsync.value ?? [];

            // A project can consume:
            // 1. Available shelf remnants from other projects
            // 2. PLUS remnants that were previously consumed by this project's own saved plan
            //    (since recalculating supersedes that plan and re-evaluates its inputs)
            final availableRemnants = allRemnants.where((r) {
              if (r.sourceProjectId == widget.projectId) return false;
              if (r.isAvailable) return true;
              if (savedPlan != null) {
                if (r.usedInPlanId == savedPlan.id) return true;
                if (savedPlan.result.consumedRemnantIds.contains(r.id) &&
                    (r.usedInPlanId == null || r.usedInPlanId == savedPlan.id)) {
                  return true;
                }
              }
              return false;
            }).toList();

            // Build cut pieces from all units
            final allPieces = _buildPieces(units, ref);

            final currentTotalCuts = allPieces.fold<int>(0, (acc, p) => acc + p.quantity);
            final currentTotalLength = allPieces.fold<double>(0, (acc, p) => acc + (p.lengthCm * p.quantity));

            final savedCutsCount = (savedPlan?.result.barPlans.fold<int>(0, (s, b) => s + b.cuts.length) ?? 0) +
                (savedPlan?.result.oversizedCuts.length ?? 0);
            final savedTotalLength = savedPlan?.result.summary.totalCutLengthCm ?? 0;
            final hasUnitsChangedSinceSave = savedPlan != null &&
                (currentTotalCuts != savedCutsCount || (currentTotalLength - savedTotalLength).abs() > 0.5);

            if (_result == null) {
              if (savedPlan != null) {
                _result = savedPlan.result;
                _savedAt = savedPlan.generatedAt;
                _hasUnsavedChanges = false;
              } else {
                _result = optimizer.optimize(
                  pieces: allPieces,
                  availableRemnants: availableRemnants.map((r) => r.toRemnantStock()).toList(),
                );
                _hasUnsavedChanges = true;
              }
            }

            final result = _result!;

            return Column(
              children: [
                // ── Status Banner for Saved Plan ──────────────────────
                if (_savedAt != null && !_hasUnsavedChanges && hasUnitsChangedSinceSave)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'تم تعديل وحدات المشروع بعد حفظ هذه الخطة!',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'الخطة المحفوظة أدناه تحتوي على ($savedCutsCount قطعة) بينما المشروع حالياً يحتوي على ($currentTotalCuts قطعة). الخطة الحالية لا تشمل التعديلات الأخيرة.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.slate300 : AppColors.slate700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning,
                              foregroundColor: Colors.black,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('إعادة حساب الخطة لتشمل الإضافات', style: TextStyle(fontSize: 12)),
                            onPressed: () => _confirmRecalculate(
                              context: context,
                              project: projectAsync.value,
                              units: unitsAsync.value ?? [],
                              savedPlan: savedCutPlanAsync.value!,
                              optimizer: optimizer,
                              allPieces: allPieces,
                              availableRemnants: availableRemnants,
                              effectiveWorkshopId: effectiveWorkshopId,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_savedAt != null && !_hasUnsavedChanges)
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
                  )
                else if (_savedAt != null && _hasUnsavedChanges)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'إعادة حساب تجريبية (لم تُحفظ بعد)',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (savedPlan != null)
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () {
                              setState(() {
                                _result = savedPlan.result;
                                _savedAt = savedPlan.generatedAt;
                                _hasUnsavedChanges = false;
                              });
                            },
                            child: const Text('تراجع للسابقة', style: TextStyle(fontSize: 12)),
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
      _hasUnsavedChanges = true;
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
              flex: 3,
              child: ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(
                        (!_hasUnsavedChanges && _savedAt != null)
                            ? Icons.check_circle_rounded
                            : Icons.save_rounded,
                        size: 18,
                      ),
                label: Text(
                  (!_hasUnsavedChanges && _savedAt != null)
                      ? 'الخطة معتمدة ومحفوظة ✅'
                      : (_savedAt != null ? 'تحديث وحفظ الخطة 💾' : 'حفظ الخطة 💾'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (!_hasUnsavedChanges && _savedAt != null)
                      ? AppColors.success
                      : AppColors.amberPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSaving
                    ? null
                    : (!_hasUnsavedChanges && _savedAt != null)
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('الخطة معتمدة ومحفوظة مسبقاً. لإعادة الحساب من المخزن الحالي اضغط على زر التحديث 🔄 أعلى البطاقة.'),
                              ),
                            );
                          }
                        : _savePlan,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'تصدير PDF',
              icon: _isExportingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_rounded),
              onPressed: (_result == null || _isExportingPdf) ? null : _exportPdf,
            ),
            const SizedBox(width: 4),
            IconButton.filledTonal(
              tooltip: 'ملصقات QR',
              icon: _isExportingLabels
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.qr_code_2_rounded),
              onPressed: (_result == null || _isExportingLabels) ? null : _exportLabels,
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _resolveWorkshopName() async {
    final currentUser = ref.read(currentUserProvider).value;
    final ownerUid = currentUser?.uid ?? '';
    final workshops = ref.read(ownerWorkshopsProvider(ownerUid)).value ?? [];
    for (final w in workshops) {
      if (w.id == widget.workshopId) return w.name;
    }
    return workshops.isNotEmpty ? workshops.first.name : 'ورشة مقياس للألمنيوم';
  }

  Future<void> _exportPdf() async {
    if (_result == null) return;
    final query = (workshopId: widget.workshopId, projectId: widget.projectId);
    final project = ref.read(projectDetailProvider(query)).value;
    final projectName = project?.name ?? 'المشروع';
    final workshopName = await _resolveWorkshopName();

    setState(() => _isExportingPdf = true);
    try {
      final pdfBytes = await CutPlanPdfGenerator.generate(
        workshopName: workshopName,
        projectName: projectName,
        result: _result!,
      );

      await Printing.layoutPdf(
        name: 'خطة_قص_${projectName.replaceAll(" ", "_")}.pdf',
        onLayout: (format) async => pdfBytes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تجهيز ملف PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Future<void> _exportLabels() async {
    if (_result == null) return;
    final query = (workshopId: widget.workshopId, projectId: widget.projectId);
    final project = ref.read(projectDetailProvider(query)).value;
    final projectName = project?.name ?? 'المشروع';

    setState(() => _isExportingLabels = true);
    try {
      final pdfBytes = await QrLabelPdfGenerator.generate(
        projectName: projectName,
        projectId: widget.projectId,
        result: _result!,
      );

      await Printing.layoutPdf(
        name: 'ملصقات_${projectName.replaceAll(" ", "_")}.pdf',
        onLayout: (format) async => pdfBytes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تجهيز ملصقات QR: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingLabels = false);
    }
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
      final optimizer = ref.read(cuttingOptimizerProvider(effectiveWorkshopId)).value;
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
                  ? 'تم حفظ الخطة · ${_result!.consumedRemnantIds.length} فضلة مستخدمة'
                  : 'تم حفظ خطة القص بنجاح',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        // Invalidate remnants and saved plan so stock & plan screens refresh
        ref.invalidate(remnantsProvider(effectiveWorkshopId));
        ref.invalidate(availableRemnantsProvider(effectiveWorkshopId));
        ref.invalidate(savedCutPlanProvider(query));
        setState(() {
          _hasUnsavedChanges = false;
          _savedAt = DateTime.now();
        });
        debugPrint('Cut plan saved: $planId');

        // Optional background upload of PDF to Firebase Storage
        try {
          final workshopName = await _resolveWorkshopName();
          final pdfBytes = await CutPlanPdfGenerator.generate(
            workshopName: workshopName,
            projectName: project.name,
            result: _result!,
          );
          final storageRef = FirebaseStorage.instance
              .ref('workshops/${widget.workshopId}/cut-plans/$planId/cut_plan.pdf');
          await storageRef.putData(
            pdfBytes,
            SettableMetadata(contentType: 'application/pdf'),
          );
          final url = await storageRef.getDownloadURL();
          await FirebaseFirestore.instance
              .collection('workshops')
              .doc(widget.workshopId)
              .collection('cutPlans')
              .doc(planId)
              .update({'pdfUrl': url});
          debugPrint('Cut plan PDF uploaded: $url');
        } catch (err) {
          debugPrint('PDF storage upload skipped: $err');
        }
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

  Future<void> _confirmRecalculate({
    required BuildContext context,
    required Project? project,
    required List<ProjectUnit> units,
    required SavedCutPlan savedPlan,
    required CutOptimizer optimizer,
    required List<CutPiece> allPieces,
    required List<RemnantDoc> availableRemnants,
    required String effectiveWorkshopId,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 16,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.slate700 : AppColors.slate300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
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
                            'إرشاد مهني: هل قُصت النوافذ السابقة بالفعل؟',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'تطبيق المنطق الصناعي السليم في ورشة الألمنيوم',
                            style: TextStyle(fontSize: 12, color: AppColors.slate400),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'الواقع في الورشة: لا يمكنك فيزيائياً خلط القديم بالجديد إذا كان عامل المنشار قد قص النوافذ القديمة، لأنها أصبحت قطعاً مقصوصة ومنتهية وفضلتها قد تكون استُهلكت بالفعل في مشروع آخر! إعادة الحساب الشامل ستدمج قطعاً من القديم والجديد في قضبان خام مشتركة، وهذا مستحيل تنفيذه.',
                  style: TextStyle(fontSize: 13, color: isDark ? AppColors.slate300 : AppColors.slate600, height: 1.45),
                ),
                const SizedBox(height: 18),

                // Option 1: Move new unit(s) to Batch 2 (Recommended if cut)
                InkWell(
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _splitToBatchProject(
                      context: context,
                      project: project,
                      units: units,
                      savedPlan: savedPlan,
                      workshopId: effectiveWorkshopId,
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.amberPrimary.withValues(alpha: 0.08),
                      border: Border.all(color: AppColors.amberPrimary.withValues(alpha: 0.5), width: 1.5),
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
                                  const Text(
                                    'نعم، قُصت بالفعل (فصل كدفعة ثانية)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.amberPrimary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('موصى به بالورشة', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'نقل النوافذ الجديدة إلى مشروع ملحق باسم «${project?.name ?? "المشروع"} (دفعة 2)» لحساب خطة مستقلة تسحب من المخزن والفضلات الحالية، مع بقاء ما تم قصه محفوظاً وسليماً دون تغيير.',
                                style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate300 : AppColors.slate600, height: 1.35),
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

                // Option 2: Full recalculation (if not cut yet)
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _regenerate(optimizer, allPieces, availableRemnants);
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
                        const Icon(Icons.refresh_rounded, color: AppColors.slate400, size: 28),
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
                                'إذا كان المشروع بأكمله لم يُقص بعد في الواقع، فسيتم خلط كافة القطع وإعادة الحساب الشامل لتحقيق أعلى نسبة توفير للألمنيوم.',
                                style: TextStyle(fontSize: 12, color: isDark ? AppColors.slate400 : AppColors.slate500, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.slate400),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _splitToBatchProject({
    required BuildContext context,
    required Project? project,
    required List<ProjectUnit> units,
    required SavedCutPlan savedPlan,
    required String workshopId,
  }) async {
    if (project == null) return;

    // Identify newly added units (created after saved plan was generated)
    final newUnits = units.where((u) => u.createdAt.isAfter(savedPlan.generatedAt)).toList();
    final unitsToMove = newUnits.isNotEmpty ? newUnits : [units.last];

    final repo = ref.read(projectsRepositoryProvider);

    // Create the batch project
    final batchProject = Project(
      id: '',
      workshopId: workshopId,
      name: '${project.name} (دفعة 2)',
      clientName: project.clientName,
      clientPhone: project.clientPhone,
      location: project.location,
      status: 'in_progress',
      unitCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final newProjectId = await repo.createProject(batchProject);

    // Move units to the new project
    for (final unit in unitsToMove) {
      final unitForBatch = unit.copyWith(
        id: '',
        projectId: newProjectId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveUnit(workshopId, unitForBatch);
      await repo.deleteUnit(workshopId, widget.projectId, unit.id);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إنشاء «${batchProject.name}» ونقل ${unitsToMove.length} وحدة إليها بنجاح ✅'),
          backgroundColor: AppColors.success,
        ),
      );
      context.push('/dashboard/owner/projects/$newProjectId/cut-plan?workshopId=$workshopId');
    }
  }
}
