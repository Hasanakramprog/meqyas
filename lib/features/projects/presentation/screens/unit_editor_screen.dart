import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meqyas/app/theme/app_colors.dart';
import 'package:meqyas/features/auth/presentation/controllers/auth_controller.dart';
import '../../domain/models/project_unit.dart';
import '../controllers/unit_editor_controller.dart';
import '../widgets/accessories_summary_view.dart';
import '../widgets/bar_layout_view.dart';
import '../widgets/cutting_list_view.dart';
import '../widgets/window_drawing_canvas.dart';

class UnitEditorScreen extends ConsumerStatefulWidget {
  final String projectId;
  final ProjectUnit? initialUnit;

  const UnitEditorScreen({
    super.key,
    required this.projectId,
    this.initialUnit,
  });

  @override
  ConsumerState<UnitEditorScreen> createState() => _UnitEditorScreenState();
}

class _UnitEditorScreenState extends ConsumerState<UnitEditorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final unit = widget.initialUnit;
    _widthController = TextEditingController(text: (unit?.widthCm ?? 120.0).toStringAsFixed(1));
    _heightController = TextEditingController(text: (unit?.heightCm ?? 150.0).toStringAsFixed(1));
    _nameController = TextEditingController(text: unit?.name ?? 'شباك جديد');
    _locationController = TextEditingController(text: unit?.location ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(unitEditorProvider.notifier).loadUnit(
            projectId: widget.projectId,
            initialUnit: widget.initialUnit,
          );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final state = ref.watch(unitEditorProvider);
    final notifier = ref.read(unitEditorProvider.notifier);
    final currentUser = ref.watch(currentUserProvider).value;
    final workshopId = currentUser?.workshopId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialUnit == null ? 'إضافة عنصر قياس جديد' : 'تعديل ${state.name}'),
        actions: [
          IconButton(
            tooltip: 'حفظ العنصر',
            icon: state.isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded, color: AppColors.amberPrimary),
            onPressed: state.isSaving
                ? null
                : () async {
                    final success = await notifier.save(workshopId);
                    if (context.mounted) {
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم حفظ تفاصيل العنصر وحساباته بنجاح!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        context.pop();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('يرجى تصحيح الأبعاد والخيارات قبل الحفظ'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Interactive 2D CAD Canvas
                SizedBox(
                  height: 320,
                  child: WindowDrawingCanvas(
                    widthCm: state.widthCm,
                    heightCm: state.heightCm,
                    sashCount: state.sashCount,
                    hasScreen: state.hasScreen,
                    unitType: state.unitType,
                    glazingMode: state.glazingMode,
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Navigation Studio Tabs
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AppColors.amberPrimary,
                    unselectedLabelColor: isDark ? AppColors.slate400 : AppColors.slate600,
                    indicatorColor: AppColors.amberPrimary,
                    tabs: const [
                      Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'القياسات والخيارات'),
                      Tab(icon: Icon(Icons.content_cut_rounded, size: 18), text: 'قائمة التقطيع'),
                      Tab(icon: Icon(Icons.straighten_rounded, size: 18), text: 'توزيع القضبان'),
                      Tab(icon: Icon(Icons.handyman_rounded, size: 18), text: 'الملحقات'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Tab Body
                SizedBox(
                  height: 600,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildConfigurationTab(context, state, notifier, isDark),
                      SingleChildScrollView(child: CuttingListView(result: state.calculationResult)),
                      SingleChildScrollView(child: BarLayoutView(pieces: state.calculationResult.pieces)),
                      SingleChildScrollView(child: AccessoriesSummaryView(accessories: state.calculationResult.accessories)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigurationTab(
    BuildContext context,
    UnitEditorState state,
    UnitEditorNotifier notifier,
    bool isDark,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Identifiers (Name & Location)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('التعريف والمكان', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'اسم العنصر (مثال: شباك الصالون)'),
                          onChanged: (val) => notifier.updateNameAndLocation(name: val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _locationController,
                          decoration: const InputDecoration(labelText: 'الموقع / الغرفة (مثال: الدور الأرضي)'),
                          onChanged: (val) => notifier.updateNameAndLocation(location: val),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Dimensions Inputs (W, H, Qty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الأبعاد والكمية (بالسنتيمتر)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _widthController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'العرض الخارجي W (سم)',
                            suffixText: 'سم',
                          ),
                          onChanged: (val) {
                            final w = double.tryParse(val);
                            if (w != null && w > 0) {
                              notifier.updateDimensions(widthCm: w);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _heightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'الارتفاع الخارجي H (سم)',
                            suffixText: 'سم',
                          ),
                          onChanged: (val) {
                            final h = double.tryParse(val);
                            if (h != null && h > 0) {
                              notifier.updateDimensions(heightCm: h);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 90,
                        child: DropdownButtonFormField<int>(
                          initialValue: state.quantity,
                          decoration: const InputDecoration(labelText: 'الكمية'),
                          items: List.generate(20, (i) => i + 1)
                              .map((q) => DropdownMenuItem(value: q, child: Text('$q')))
                              .toList(),
                          onChanged: (q) {
                            if (q != null) notifier.updateDimensions(quantity: q);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Unit Options (Type, Glazing, Sashes, Screen)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الخيارات الهندسية والمواصفات', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),

                  // Unit Type & Glazing Mode
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: state.unitType,
                          decoration: const InputDecoration(labelText: 'نوع الوحدة'),
                          items: const [
                            DropdownMenuItem(value: 'window', child: Text('شباك نافذة')),
                            DropdownMenuItem(value: 'facade', child: Text('واجهة زجاجية')),
                          ],
                          onChanged: (val) {
                            if (val != null) notifier.updateOptions(unitType: val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: state.glazingMode,
                          decoration: const InputDecoration(labelText: 'نوع تركيب الزجاج'),
                          items: const [
                            DropdownMenuItem(value: 'single', child: Text('مفرد (Single)')),
                            DropdownMenuItem(value: 'double', child: Text('مزدوج (Double)')),
                          ],
                          onChanged: (val) {
                            if (val != null) notifier.updateOptions(glazingMode: val);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Sash Count & Flyscreen
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: state.sashCount,
                          decoration: const InputDecoration(labelText: 'عدد الدرف (السحاب)'),
                          items: const [
                            DropdownMenuItem(value: 2, child: Text('درفتان (2 sashes)')),
                            DropdownMenuItem(value: 3, child: Text('3 درف')),
                            DropdownMenuItem(value: 4, child: Text('4 درف')),
                          ],
                          onChanged: (val) {
                            if (val != null) notifier.updateOptions(sashCount: val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('درفة منخل (شبك)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          value: state.hasScreen,
                          activeTrackColor: AppColors.amberPrimary,
                          onChanged: (val) => notifier.updateOptions(hasScreen: val),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Sharh Options
                  DropdownButtonFormField<String>(
                    initialValue: state.sharhOption,
                    decoration: const InputDecoration(labelText: 'خيار الشرح (تعديل الأجناب للبروز الحجري)'),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('بدون شرح (+5 سم للجناب)')),
                      DropdownMenuItem(value: 'one_side', child: Text('شرح جهة واحدة (+2.5 سم للجناب)')),
                      DropdownMenuItem(value: 'two_sides', child: Text('شرح جهتين (+0 سم للجناب)')),
                    ],
                    onChanged: (val) {
                      if (val != null) notifier.updateOptions(sharhOption: val);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
