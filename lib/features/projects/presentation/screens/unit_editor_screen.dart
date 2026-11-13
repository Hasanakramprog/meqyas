import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import 'package:meqyas/app/theme/app_colors.dart';
import 'package:meqyas/features/auth/presentation/controllers/auth_controller.dart';
import '../../../../features/rules/data/rules_repository.dart';
import '../../domain/models/project.dart';
import '../../domain/models/project_unit.dart';
import '../controllers/unit_editor_controller.dart';
import '../widgets/accessories_summary_view.dart';
import '../widgets/bar_layout_view.dart';
import '../widgets/cutting_list_view.dart';
import '../widgets/project_deductions_sheet.dart';
import '../widgets/project_general_properties_card.dart';
import '../widgets/window_drawing_canvas.dart';
import 'project_detail_screen.dart';

class UnitEditorScreen extends ConsumerStatefulWidget {
  final String projectId;
  final ProjectUnit? initialUnit;
  final String? initialWorkshopId;

  const UnitEditorScreen({
    super.key,
    required this.projectId,
    this.initialUnit,
    this.initialWorkshopId,
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
  bool _isCanvasExpanded = true;
  bool _didLoadWithProjectContext = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final unit = widget.initialUnit;
    _widthController = TextEditingController(
      text: unit == null ? '0' : unit.widthCm.toStringAsFixed(1),
    );
    _heightController = TextEditingController(
      text: unit == null ? '0' : unit.heightCm.toStringAsFixed(1),
    );
    _nameController = TextEditingController(text: unit?.name ?? 'شباك 1');
    _locationController = TextEditingController(text: unit?.location ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWithProjectData();
    });
  }

  void _loadWithProjectData() {
    final activeId = ref.read(activeWorkshopIdProvider);
    final currentUser = ref.read(currentUserProvider).value;
    final workshopId = widget.initialWorkshopId ??
        activeId ??
        (currentUser?.workshopId ?? '');
    final query = (workshopId: workshopId, projectId: widget.projectId);
    final project = ref.read(projectDetailProvider(query)).value;
    final units = ref.read(projectUnitsProvider(query)).value ?? const [];

    ref.read(unitEditorProvider.notifier).loadUnit(
          projectId: widget.projectId,
          initialUnit: widget.initialUnit,
          projectDefaults: project?.defaults ?? const ProjectDefaults(),
          existingUnits: units,
        );

    final loadedName = ref.read(unitEditorProvider).name;
    if (widget.initialUnit == null) {
      _nameController.text = loadedName;
    }
    _didLoadWithProjectContext = project != null || units.isNotEmpty;
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
    final activeId = ref.watch(activeWorkshopIdProvider);
    final currentUser = ref.watch(currentUserProvider).value;
    final workshopId = widget.initialWorkshopId ??
        activeId ??
        (currentUser?.workshopId ?? '');

    final query = (workshopId: workshopId, projectId: widget.projectId);
    final project = ref.watch(projectDetailProvider(query)).value;
    final existingUnits = ref.watch(projectUnitsProvider(query)).value;

    // Refresh defaults/auto-name once stream emits if not loaded yet
    if (!_didLoadWithProjectContext &&
        (project != null || existingUnits != null)) {
      _didLoadWithProjectContext = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        notifier.loadUnit(
          projectId: widget.projectId,
          initialUnit: widget.initialUnit,
          projectDefaults: project?.defaults ?? const ProjectDefaults(),
          existingUnits: existingUnits ?? const [],
        );
        if (widget.initialUnit == null) {
          _nameController.text = ref.read(unitEditorProvider).name;
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialUnit == null
              ? 'إضافة ${state.name}'
              : 'تعديل ${state.name}',
        ),
        actions: [
          if (state.hasAnyOverrides)
            TextButton.icon(
              onPressed: () {
                notifier.resetAllOverrides();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'تم استرجاع جميع خصائص العنصر إلى افتراضي المشروع ↺',
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.restore_rounded, size: 18),
              label: const Text('استرجاع الافتراضي'),
            ),
          IconButton(
            tooltip: 'حفظ العنصر',
            icon: state.isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.check_rounded,
                    color: AppColors.amberPrimary,
                  ),
            onPressed: state.isSaving
                ? null
                : () async {
                    if (state.widthCm <= 0 || state.heightCm <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'يرجى إدخال العرض والارتفاع بقيمة أكبر من صفر قبل الحفظ',
                          ),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }
                    final success = await notifier.save(workshopId);
                    if (context.mounted) {
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('تم حفظ تفاصيل العنصر وحساباته بنجاح!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        context.pop();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('يرجى تصحيح الأبعاد والخيارات قبل الحفظ'),
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
      body: Column(
        children: [
          // 1. Interactive 2D CAD Canvas (Collapsible for maximum workspace)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: _isCanvasExpanded
                    ? SizedBox(
                        height: 220,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: WindowDrawingCanvas(
                                widthCm: state.widthCm > 0 ? state.widthCm : 120,
                                heightCm:
                                    state.heightCm > 0 ? state.heightCm : 150,
                                sashCount: state.sashCount,
                                hasScreen: state.hasScreen,
                                unitType: state.unitType,
                                glazingMode: state.effectiveGlazingMode,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Tooltip(
                                message: 'تصغير المخطط لمساحة أكبر',
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _isCanvasExpanded = false),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (isDark
                                              ? Colors.black
                                              : Colors.white)
                                          .withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDark
                                            ? AppColors.darkBorder
                                            : AppColors.lightBorder,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.unfold_less_rounded,
                                          size: 16,
                                          color: AppColors.amberPrimary,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'تصغير',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkCard
                              : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.architecture_rounded,
                              size: 18,
                              color: AppColors.amberPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'المخطط: ${state.widthCm.toStringAsFixed(1)} × ${state.heightCm.toStringAsFixed(1)} سم (${state.sashCount} درف)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            InkWell(
                              onTap: () =>
                                  setState(() => _isCanvasExpanded = true),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.amberPrimary
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.unfold_more_rounded,
                                      size: 14,
                                      color: AppColors.amberPrimary,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'عرض الرسم',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.amberPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),

          // 2. Navigation Studio Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AppColors.amberPrimary,
                    unselectedLabelColor:
                        isDark ? AppColors.slate400 : AppColors.slate600,
                    indicatorColor: AppColors.amberPrimary,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.tune_rounded, size: 18),
                        text: 'القياسات والخيارات',
                      ),
                      Tab(
                        icon: Icon(Icons.content_cut_rounded, size: 18),
                        text: 'قائمة التقطيع',
                      ),
                      Tab(
                        icon: Icon(Icons.straighten_rounded, size: 18),
                        text: 'توزيع القضبان',
                      ),
                      Tab(
                        icon: Icon(Icons.handyman_rounded, size: 18),
                        text: 'الملحقات',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Tab Body
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildScrollableTab(
                  child: _buildConfigurationTab(
                    context,
                    state,
                    notifier,
                    workshopId,
                    isDark,
                  ),
                ),
                _buildScrollableTab(
                  child: CuttingListView(result: state.calculationResult),
                ),
                _buildScrollableTab(
                  child: BarLayoutView(
                    pieces: _buildEditorBarPieces(state),
                    optimizer:
                        ref.watch(cuttingOptimizerProvider(workshopId)).value,
                  ),
                ),
                _buildScrollableTab(
                  child: AccessoriesSummaryView(
                    accessories: state.calculationResult.accessories,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableTab({required Widget child}) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: child,
        ),
      ),
    );
  }

  Widget _buildConfigurationTab(
    BuildContext context,
    UnitEditorState state,
    UnitEditorNotifier notifier,
    String workshopId,
    bool isDark,
  ) {
    final workshopRules = ref.watch(effectiveRulesProvider(workshopId)).value ??
        SeedRules.getSystem2000BeadedRules();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Unit Type & Identifiers (Name & Location)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'نوع العنصر والتعريف',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'window',
                      label: Text('شباك نافذة'),
                      icon: Icon(Icons.window_rounded, size: 18),
                    ),
                    ButtonSegment<String>(
                      value: 'facade',
                      label: Text('واجهة زجاجية'),
                      icon: Icon(Icons.apartment_rounded, size: 18),
                    ),
                  ],
                  selected: {state.unitType},
                  onSelectionChanged: (sel) {
                    final newType = sel.first;
                    notifier.updateOptions(unitType: newType);
                    final updatedName = ref.read(unitEditorProvider).name;
                    if (_nameController.text != updatedName) {
                      _nameController.text = updatedName;
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم العنصر (مثال: شباك 1)',
                        ),
                        onChanged: (val) =>
                            notifier.updateNameAndLocation(name: val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'الموقع / الغرفة (مثال: الدور الأرضي)',
                        ),
                        onChanged: (val) =>
                            notifier.updateNameAndLocation(location: val),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 2. Dimensions Inputs (W, H start at 0, Qty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الأبعاد والكمية (بالسنتيمتر)',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _widthController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onTap: () {
                          if (_widthController.text == '0' ||
                              _widthController.text == '0.0') {
                            _widthController.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _widthController.text.length,
                            );
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'العرض الخارجي W (سم)',
                          suffixText: 'سم',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (val) {
                          final w = double.tryParse(val);
                          if (w != null && w >= 0) {
                            notifier.updateDimensions(widthCm: w);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _heightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onTap: () {
                          if (_heightController.text == '0' ||
                              _heightController.text == '0.0') {
                            _heightController.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _heightController.text.length,
                            );
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'الارتفاع الخارجي H (سم)',
                          suffixText: 'سم',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (val) {
                          final h = double.tryParse(val);
                          if (h != null && h >= 0) {
                            notifier.updateDimensions(heightCm: h);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: state.quantity,
                        decoration: const InputDecoration(
                          labelText: 'الكمية',
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        items: List.generate(20, (i) => i + 1)
                            .map(
                              (q) => DropdownMenuItem(
                                value: q,
                                child: Text('$q'),
                              ),
                            )
                            .toList(),
                        onChanged: (q) {
                          if (q != null) {
                            notifier.updateDimensions(quantity: q);
                          }
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

        // 3. Inherited vs Customized General Properties for this Unit
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'خصائص العنصر العامة (موروثة من المشروع أو مخصصة)',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (state.hasAnyOverrides)
                      TextButton.icon(
                        onPressed: notifier.resetAllOverrides,
                        icon: const Icon(Icons.restore_rounded, size: 16),
                        label: const Text('استرجاع الكل للافتراضي'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Aluminum Type & Color
                Row(
                  children: [
                    Expanded(
                      child: _OverridableDropdown<String>(
                        label: 'ألمنيوم العنصر',
                        isOverridden: state.isFieldOverridden('glazingMode'),
                        onReset: () =>
                            notifier.resetFieldToDefault('glazingMode'),
                        value: state.effectiveGlazingMode == 'single'
                            ? 'single'
                            : 'double',
                        items: const [
                          DropdownMenuItem(value: 'double', child: Text('دبل')),
                          DropdownMenuItem(
                            value: 'single',
                            child: Text('عادي (مفرد)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            notifier.updateOptions(glazingMode: val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _OverridableDropdown<String>(
                        label: 'لون العنصر',
                        isOverridden: state.isFieldOverridden('color'),
                        onReset: () => notifier.resetFieldToDefault('color'),
                        value: ProjectGeneralPropertiesCard.colorOptions
                                .any((c) => c.value == state.effectiveColor)
                            ? state.effectiveColor
                            : 'white',
                        items: ProjectGeneralPropertiesCard.colorOptions
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.value,
                                child: Text(c.label),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            notifier.updateOptions(color: val);
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Glass Type & Glass Thickness
                Row(
                  children: [
                    Expanded(
                      child: _OverridableDropdown<String>(
                        label: 'نوع زجاج العنصر',
                        isOverridden: state.isFieldOverridden('glassType'),
                        onReset: () =>
                            notifier.resetFieldToDefault('glassType'),
                        value: ProjectGeneralPropertiesCard.glassTypeOptions
                                .any((g) => g.value == state.effectiveGlassType)
                            ? state.effectiveGlassType
                            : 'clear',
                        items: ProjectGeneralPropertiesCard.glassTypeOptions
                            .map(
                              (g) => DropdownMenuItem(
                                value: g.value,
                                child: Text(g.label),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            notifier.updateOptions(glassType: val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _OverridableDropdown<double>(
                        label: 'سماكة زجاج العنصر',
                        isOverridden:
                            state.isFieldOverridden('glassThicknessMm'),
                        onReset: () =>
                            notifier.resetFieldToDefault('glassThicknessMm'),
                        value: ProjectGeneralPropertiesCard
                                .glassThicknessOptions
                                .any(
                              (t) =>
                                  t.value == state.effectiveGlassThicknessMm,
                            )
                            ? state.effectiveGlassThicknessMm
                            : 6.0,
                        items: ProjectGeneralPropertiesCard
                            .glassThicknessOptions
                            .map(
                              (t) => DropdownMenuItem(
                                value: t.value,
                                child: Text(t.label),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            notifier.updateOptions(glassThicknessMm: val);
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Glass Gasket
                _OverridableDropdown<bool>(
                  label: 'الزبون يدك كوتشوك الزجاج',
                  isOverridden: state.isFieldOverridden('hasGasket'),
                  onReset: () => notifier.resetFieldToDefault('hasGasket'),
                  value: state.effectiveHasGasket,
                  items: const [
                    DropdownMenuItem(
                      value: false,
                      child: Text('لا · لا تضف الكوتشوك للطلبية'),
                    ),
                    DropdownMenuItem(
                      value: true,
                      child: Text('نعم · أضف الكوتشوك للطلبية'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      notifier.updateOptions(hasGasket: val);
                    }
                  },
                ),

                const SizedBox(height: 12),

                // Per-Unit Deductions Button ("تعديل التخسيمات / استرجاع الافتراضي لهذا العنصر")
                OutlinedButton.icon(
                  icon: Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: state.unitRuleOverrides.isNotEmpty
                        ? AppColors.amberPrimary
                        : null,
                  ),
                  label: Text(
                    state.unitRuleOverrides.isNotEmpty
                        ? 'تعديل التخسيمات لهذا العنصر (مخصص: ${state.unitRuleOverrides.length})'
                        : 'تعديل التخسيمات / استرجاع الافتراضي لهذا العنصر',
                  ),
                  onPressed: () {
                    final projectEffectiveRules =
                        ProjectUnit.resolveEffectiveRules(
                      workshopRules,
                      projectDefaults: state.projectDefaults,
                    );
                    ProjectDeductionsSheet.show(
                      context: context,
                      title: 'تعديل التخسيمات لـ "${state.name}"',
                      subtitle:
                          'تطبق هذه التخسيمات على هذا العنصر فقط، ويمكنك استرجاع افتراضي المشروع بضغطة زر.',
                      baseRules: projectEffectiveRules,
                      currentOverrides: state.unitRuleOverrides,
                      onSave: (newOverrides) async {
                        notifier.updateUnitRuleOverrides(newOverrides);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 4. Unit Structural Options (Sashes, Screen, Sharh)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الخيارات الهندسية للعنصر',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),

                // Sash Count
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: state.sashCount,
                  decoration:
                      const InputDecoration(labelText: 'عدد الدرف (السحاب)'),
                  items: const [
                    DropdownMenuItem(
                      value: 2,
                      child: Text('درفتان (2 sashes)'),
                    ),
                    DropdownMenuItem(value: 3, child: Text('3 درف')),
                    DropdownMenuItem(value: 4, child: Text('4 درف')),
                  ],
                  onChanged: (val) {
                    if (val != null) notifier.updateOptions(sashCount: val);
                  },
                ),

                const SizedBox(height: 8),

                // Flyscreen Toggle
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text(
                    'درفة منخل (شبك مقاوم للحشرات)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  value: state.hasScreen,
                  activeTrackColor: AppColors.amberPrimary,
                  onChanged: (val) => notifier.updateOptions(hasScreen: val),
                ),

                const SizedBox(height: 12),

                // Sharh Options
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: state.sharhOption,
                  decoration: const InputDecoration(
                    labelText: 'خيار الشرح (تعديل الأجناب للبروز الحجري)',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'none',
                      child: Text('بدون شرح (+5 سم للجناب)'),
                    ),
                    DropdownMenuItem(
                      value: 'one_side',
                      child: Text('شرح جهة واحدة (+2.5 سم للجناب)'),
                    ),
                    DropdownMenuItem(
                      value: 'two_sides',
                      child: Text('شرح جهتين (+0 سم للجناب)'),
                    ),
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
    );
  }

  List<CutPiece> _buildEditorBarPieces(UnitEditorState state) {
    final unitLabel = state.name.trim().isNotEmpty
        ? state.name.trim()
        : (state.unitType == 'window' ? 'شباك' : 'عنصر');
    final qty = state.quantity > 0 ? state.quantity : 1;
    final allPieces = <CutPiece>[];

    for (var copy = 1; copy <= qty; copy++) {
      final tag = qty > 1 ? '$unitLabel (#$copy)' : unitLabel;
      for (final p in state.calculationResult.pieces) {
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
    return allPieces;
  }
}

class _OverridableDropdown<T> extends StatelessWidget {
  final String label;
  final bool isOverridden;
  final VoidCallback onReset;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _OverridableDropdown({
    required this.label,
    required this.isOverridden,
    required this.onReset,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isOverridden
                    ? AppColors.amberPrimary.withValues(alpha: 0.16)
                    : AppColors.slate400.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                isOverridden ? 'مخصص ✎' : 'افتراضي المشروع',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isOverridden
                      ? AppColors.amberPrimary
                      : AppColors.slate400,
                ),
              ),
            ),
            if (isOverridden) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onReset,
                borderRadius: BorderRadius.circular(4),
                child: const Tooltip(
                  message: 'استرجاع افتراضي المشروع',
                  child: Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.restore_rounded,
                      size: 16,
                      color: AppColors.info,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          isExpanded: true,
          initialValue: value,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
