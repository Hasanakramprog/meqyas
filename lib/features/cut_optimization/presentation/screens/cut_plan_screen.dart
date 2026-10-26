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
import '../../../projects/domain/models/project_unit.dart';
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
    final availableRemnantsAsync = ref.watch(availableRemnantsProvider(effectiveWorkshopId));
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
            if (availableRemnantsAsync.isLoading || savedCutPlanAsync.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final optimizer = optimizerAsync.value ?? const CutOptimizer();
            // A project can only consume remnants from OTHER projects / shelf stock, never its own
            final availableRemnants = (availableRemnantsAsync.value ?? [])
                .where((r) => r.sourceProjectId != widget.projectId)
                .toList();

            // Build cut pieces from all units
            final allPieces = _buildPieces(units, ref);

            final savedPlan = savedCutPlanAsync.value;
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
}
