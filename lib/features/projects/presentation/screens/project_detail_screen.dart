import 'dart:async';
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

import '../widgets/project_deductions_sheet.dart';

import '../widgets/project_general_properties_card.dart';
import '../widgets/project_stepper_bar.dart';
import '../widgets/unit_accessories_mesh_section.dart';

final projectDetailProvider = StreamProvider.autoDispose
    .family<Project?, ({String workshopId, String projectId})>((ref, arg) {
      final repo = ref.watch(projectsRepositoryProvider);
      return repo.watchProject(arg.workshopId, arg.projectId);
    });

final projectUnitsProvider = StreamProvider.autoDispose
    .family<List<ProjectUnit>, ({String workshopId, String projectId})>((
      ref,
      arg,
    ) {
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
  ConsumerState<ProjectDetailScreen> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  Future<void> _addNewItemOfType({
    required String workshopId,
    required String unitType,
    required ProjectDefaults defaults,
    required List<ProjectUnit> existingUnits,
  }) async {
    if (workshopId.isEmpty) return;
    final nextName = ProjectUnit.nextAutoName(unitType, existingUnits);
    final newUnit = ProjectUnit(
      id: '',
      projectId: widget.projectId,
      name: nextName,
      location: '',
      widthCm: 0.0,
      heightCm: 0.0,
      quantity: 1,
      unitType: unitType,
      glazingMode: defaults.glazingMode,
      profileSystemId: defaults.profileSystemId,
      color: defaults.color,
      glassType: defaults.glassType,
      glassThicknessMm: defaults.glassThicknessMm,
      hasGasket: defaults.hasGasket,
      overrides: const {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await ref.read(projectsRepositoryProvider).saveUnit(workshopId, newUnit);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentUser = ref.watch(currentUserProvider).value;
    final ownerUid = currentUser?.uid ?? '';
    final workshops = ref.watch(ownerWorkshopsProvider(ownerUid)).value ?? [];
    final activeId = ref.watch(activeWorkshopIdProvider);

    final workshopId =
        widget.initialWorkshopId ??
        activeId ??
        (workshops.isNotEmpty
            ? workshops.first.id
            : (currentUser?.workshopId ?? ''));

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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: ProjectStepperBar(
            projectId: widget.projectId,
            workshopId: workshopId,
            activeStep: 1,
          ),
        ),
      ),
      body: unitsAsync.when(
        data: (units) {
          return _buildStep1Content(
            context,
            units,
            workshopId,
            isDark,
            projectAsync.value,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('خطأ في تحميل العناصر: $err')),
      ),
    );
  }

  Widget _buildStep1Content(
    BuildContext context,
    List<ProjectUnit> units,
    String workshopId,
    bool isDark,
    Project? project,
  ) {
    final theme = Theme.of(context);
    final effectiveRules =
        ref.watch(effectiveRulesProvider(workshopId)).value ??
        SeedRules.getSystem2000BeadedRules();
    final defaults = project?.defaults ?? const ProjectDefaults();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. General Project Properties Card ("الخصائص العامة للمشروع")
        ProjectGeneralPropertiesCard(
          defaults: defaults,
          workshopRules: effectiveRules,
          onChanged: (updatedDefaults) {
            ref
                .read(projectsRepositoryProvider)
                .updateProjectDefaults(
                  workshopId,
                  widget.projectId,
                  updatedDefaults,
                );
          },
        ),

        const SizedBox(height: 16),

        // 2. Add Item Type Buttons (شباك / واجهة)
        Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'عناصر المشروع (${units.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('إضافة شباك'),
                onPressed: () => _addNewItemOfType(
                  workshopId: workshopId,
                  unitType: 'window',
                  defaults: defaults,
                  existingUnits: units,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('إضافة واجهة'),
                onPressed: () => _addNewItemOfType(
                  workshopId: workshopId,
                  unitType: 'facade',
                  defaults: defaults,
                  existingUnits: units,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        if (units.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.crop_free_rounded,
                  size: 48,
                  color: isDark ? AppColors.slate600 : AppColors.slate400,
                ),
                const SizedBox(height: 12),
                Text(
                  'لا توجد عناصر مضافة في هذا المشروع بعد',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'اضغط "إضافة شباك" أو "إضافة واجهة" لإضافة العناصر (شباك 1، شباك 2، واجهة 1...) وإدخال قياساتها.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.slate400,
                  ),
                ),
              ],
            ),
          )
        else ...[
          for (final u in units)
            _ProjectUnitInlineCard(
              key: ValueKey(u.id),
              unit: u,
              workshopId: workshopId,
              defaults: defaults,
              workshopRules: effectiveRules,
            ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.fact_check_rounded),
            label: const Text('التالي: الانتقال إلى 2 · مراجعة البضاعة'),
            onPressed: () {
              context.push(
                '/dashboard/owner/projects/${widget.projectId}/requirements?workshopId=$workshopId',
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Inline editable item card for Step 1 ("1 · القياسات").
/// Starts with width = 0 and height = 0 when newly added, inherits [ProjectDefaults]
/// automatically, and lets the user customize properties for this specific item or
/// reset back to the project defaults with one tap.
class _ProjectUnitInlineCard extends ConsumerStatefulWidget {
  final ProjectUnit unit;
  final String workshopId;
  final ProjectDefaults defaults;
  final List<CalculationRule> workshopRules;

  const _ProjectUnitInlineCard({
    super.key,
    required this.unit,
    required this.workshopId,
    required this.defaults,
    required this.workshopRules,
  });

  @override
  ConsumerState<_ProjectUnitInlineCard> createState() =>
      _ProjectUnitInlineCardState();
}

class _ProjectUnitInlineCardState
    extends ConsumerState<_ProjectUnitInlineCard> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _widthCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _locationCtrl;
  late final FocusNode _widthFocus;
  late final FocusNode _heightFocus;
  late final ProjectsRepository _projectsRepo;
  Timer? _saveDebounce;
  ProjectUnit? _pendingSaveUnit;
  bool _showCustomProperties = false;

  @override
  void initState() {
    super.initState();
    _projectsRepo = ref.read(projectsRepositoryProvider);
    _nameCtrl = TextEditingController(text: widget.unit.name);
    _widthCtrl = TextEditingController(text: _formatDim(widget.unit.widthCm));
    _heightCtrl = TextEditingController(text: _formatDim(widget.unit.heightCm));
    _locationCtrl = TextEditingController(text: widget.unit.location);
    _widthFocus = FocusNode()..addListener(_onDimFocusChanged);
    _heightFocus = FocusNode()..addListener(_onDimFocusChanged);
  }

  void _onDimFocusChanged() {
    if (!_widthFocus.hasFocus && !_heightFocus.hasFocus) {
      _flushPendingSave();
    }
  }

  @override
  void didUpdateWidget(covariant _ProjectUnitInlineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unit.name != widget.unit.name &&
        _nameCtrl.text != widget.unit.name) {
      _nameCtrl.text = widget.unit.name;
    }
    if (!_widthFocus.hasFocus) {
      final currentW = double.tryParse(_widthCtrl.text) ?? 0.0;
      if ((currentW - widget.unit.widthCm).abs() > 0.001) {
        _widthCtrl.text = _formatDim(widget.unit.widthCm);
      }
    }
    if (!_heightFocus.hasFocus) {
      final currentH = double.tryParse(_heightCtrl.text) ?? 0.0;
      if ((currentH - widget.unit.heightCm).abs() > 0.001) {
        _heightCtrl.text = _formatDim(widget.unit.heightCm);
      }
    }
  }

  static String _formatDim(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _flushPendingSave();
    _widthFocus.removeListener(_onDimFocusChanged);
    _heightFocus.removeListener(_onDimFocusChanged);
    _widthFocus.dispose();
    _heightFocus.dispose();
    _nameCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  void _scheduleSaveUnit(ProjectUnit updated) {
    _pendingSaveUnit = updated;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 450), () {
      _flushPendingSave();
    });
  }

  void _flushPendingSave() {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    final pending = _pendingSaveUnit;
    _pendingSaveUnit = null;
    if (pending != null) {
      _saveUpdatedUnit(pending);
    }
  }

  Future<void> _saveUpdatedUnit(ProjectUnit updated) async {
    await _projectsRepo.saveUnit(
      widget.workshopId,
      updated.copyWith(updatedAt: DateTime.now()),
    );
  }

  Future<void> _setFieldOverride(
    String key,
    dynamic value,
    dynamic defaultVal,
  ) async {
    final nextOverrides = Map<String, dynamic>.from(widget.unit.overrides);
    if (value == defaultVal) {
      nextOverrides.remove(key);
    } else {
      nextOverrides[key] = value;
    }
    await _saveUpdatedUnit(widget.unit.copyWith(overrides: nextOverrides));
  }

  Future<void> _resetSingleField(String key) async {
    final nextOverrides = Map<String, dynamic>.from(widget.unit.overrides)
      ..remove(key);
    await _saveUpdatedUnit(widget.unit.copyWith(overrides: nextOverrides));
  }

  Future<void> _resetAllToDefaults() async {
    final d = widget.defaults;
    await _saveUpdatedUnit(
      widget.unit.copyWith(
        overrides: const {},
        glazingMode: d.glazingMode,
        profileSystemId: d.profileSystemId,
        color: d.color,
        glassType: d.glassType,
        glassThicknessMm: d.glassThicknessMm,
        hasGasket: d.hasGasket,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final u = widget.unit;
    final d = widget.defaults;
    final isCustomized = u.hasAnyOverrides;

    final effGlazing = u.effectiveGlazingMode(d);
    final effColor = u.effectiveColor(d);
    final effGlass = u.effectiveGlassType(d);
    final effThick = u.effectiveGlassThicknessMm(d);
    final effGasket = u.effectiveHasGasket(d);

    final borderColor = isCustomized
        ? AppColors.amberPrimary.withValues(alpha: 0.65)
        : (isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: isCustomized ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row: Icon + Name + Default/Custom Badge + Reset + Customize + Delete
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.glassBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    u.unitType == 'facade'
                        ? Icons.apartment_rounded
                        : Icons.window_rounded,
                    size: 20,
                    color: AppColors.glassBlueLight,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          u.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isCustomized
                              ? AppColors.amberPrimary.withValues(alpha: 0.16)
                              : AppColors.slate400.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isCustomized ? 'مخصص ✎' : 'افتراضي المشروع',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isCustomized
                                ? AppColors.amberPrimary
                                : AppColors.slate400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCustomized)
                  TextButton.icon(
                    onPressed: _resetAllToDefaults,
                    icon: const Icon(Icons.restore_rounded, size: 16),
                    label: const Text(
                      'استرجاع الافتراضي',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => setState(
                    () => _showCustomProperties = !_showCustomProperties,
                  ),
                  icon: Icon(
                    _showCustomProperties
                        ? Icons.expand_less_rounded
                        : Icons.tune_rounded,
                    size: 16,
                  ),
                  label: Text(
                    _showCustomProperties ? 'إخفاء التخصيص' : 'تخصيص الخصائص',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: 'حذف العنصر',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                  onPressed: () async {
                    await ref
                        .read(projectsRepositoryProvider)
                        .deleteUnit(widget.workshopId, u.projectId, u.id);
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Dimensions Row: العرض (starts at 0), الارتفاع (starts at 0), العدد, عدد الدرف, منخل
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _widthCtrl,
                    focusNode: _widthFocus,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onTap: () {
                      if (_widthCtrl.text == '0') {
                        _widthCtrl.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _widthCtrl.text.length,
                        );
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'العرض (سم)',
                      suffixText: 'سم',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (val) {
                      final w = double.tryParse(val.trim());
                      if (w != null && w >= 0) {
                        final base = _pendingSaveUnit ?? u;
                        _scheduleSaveUnit(base.copyWith(widthCm: w));
                      }
                    },
                    onEditingComplete: _flushPendingSave,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _heightCtrl,
                    focusNode: _heightFocus,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onTap: () {
                      if (_heightCtrl.text == '0') {
                        _heightCtrl.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _heightCtrl.text.length,
                        );
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'الارتفاع (سم)',
                      suffixText: 'سم',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (val) {
                      final h = double.tryParse(val.trim());
                      if (h != null && h >= 0) {
                        final base = _pendingSaveUnit ?? u;
                        _scheduleSaveUnit(base.copyWith(heightCm: h));
                      }
                    },
                    onEditingComplete: _flushPendingSave,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: u.quantity,
                    decoration: const InputDecoration(
                      labelText: 'العدد',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    items: List.generate(20, (i) => i + 1)
                        .map(
                          (q) => DropdownMenuItem(value: q, child: Text('$q')),
                        )
                        .toList(),
                    onChanged: (q) {
                      if (q != null) {
                        _saveUpdatedUnit(u.copyWith(quantity: q));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: u.sashCount,
                    decoration: const InputDecoration(
                      labelText: 'الدرف',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 2, child: Text('2')),
                      DropdownMenuItem(value: 3, child: Text('3')),
                      DropdownMenuItem(value: 4, child: Text('4')),
                    ],
                    onChanged: (s) {
                      if (s != null) {
                        _saveUpdatedUnit(u.copyWith(sashCount: s));
                      }
                    },
                  ),
                ),
              ],
            ),

            // Expandable Per-Item Customization Section
            if (_showCustomProperties) ...[
              const Divider(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _InlineOverrideDropdown<String>(
                      label: 'ألمنيوم العنصر',
                      isOverridden: u.isFieldOverridden('glazingMode'),
                      onReset: () => _resetSingleField('glazingMode'),
                      value: effGlazing == 'single' ? 'single' : 'double',
                      items: const [
                        DropdownMenuItem(value: 'double', child: Text('دبل')),
                        DropdownMenuItem(
                          value: 'single',
                          child: Text('عادي (مفرد)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          _setFieldOverride('glazingMode', val, d.glazingMode);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InlineOverrideDropdown<String>(
                      label: 'لون العنصر',
                      isOverridden: u.isFieldOverridden('color'),
                      onReset: () => _resetSingleField('color'),
                      value:
                          ProjectGeneralPropertiesCard.colorOptions.any(
                            (c) => c.value == effColor,
                          )
                          ? effColor
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
                          _setFieldOverride('color', val, d.color);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _InlineOverrideDropdown<String>(
                      label: 'نوع زجاج العنصر',
                      isOverridden: u.isFieldOverridden('glassType'),
                      onReset: () => _resetSingleField('glassType'),
                      value:
                          ProjectGeneralPropertiesCard.glassTypeOptions.any(
                            (g) => g.value == effGlass,
                          )
                          ? effGlass
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
                          _setFieldOverride('glassType', val, d.glassType);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InlineOverrideDropdown<double>(
                      label: 'سماكة زجاج العنصر',
                      isOverridden: u.isFieldOverridden('glassThicknessMm'),
                      onReset: () => _resetSingleField('glassThicknessMm'),
                      value:
                          ProjectGeneralPropertiesCard.glassThicknessOptions
                              .any((t) => t.value == effThick)
                          ? effThick
                          : 6.0,
                      items: ProjectGeneralPropertiesCard.glassThicknessOptions
                          .map(
                            (t) => DropdownMenuItem(
                              value: t.value,
                              child: Text(t.label),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _setFieldOverride(
                            'glassThicknessMm',
                            val,
                            d.glassThicknessMm,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _InlineOverrideDropdown<bool>(
                      label: 'الزبون يدك كوتشوك الزجاج',
                      isOverridden: u.isFieldOverridden('hasGasket'),
                      onReset: () => _resetSingleField('hasGasket'),
                      value: effGasket,
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
                          _setFieldOverride('hasGasket', val, d.hasGasket);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<bool>(
                      isExpanded: true,
                      initialValue: u.hasScreen,
                      decoration: const InputDecoration(
                        labelText: 'درفة منخل',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: true, child: Text('مع منخل')),
                        DropdownMenuItem(
                          value: false,
                          child: Text('بدون منخل'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          _saveUpdatedUnit(u.copyWith(hasScreen: val));
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              UnitAccessoriesAndMeshSection(
                unit: u,
                effectiveGlazingMode: effGlazing,
                onUnitChanged: _saveUpdatedUnit,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  icon: Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: u.unitRuleOverrides.isNotEmpty
                        ? AppColors.amberPrimary
                        : null,
                  ),
                  label: Text(
                    u.unitRuleOverrides.isNotEmpty
                        ? 'تعديل التخسيمات لهذا العنصر (مخصص: ${u.unitRuleOverrides.length})'
                        : 'تعديل التخسيمات / استرجاع الافتراضي لهذا العنصر',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    final projectEffectiveRules =
                        ProjectUnit.resolveEffectiveRules(
                          widget.workshopRules,
                          projectDefaults: d,
                        );
                    ProjectDeductionsSheet.show(
                      context: context,
                      title: 'تعديل التخسيمات لـ "${u.name}"',
                      subtitle: 'تطبق هذه التخسيمات على هذا العنصر فقط، ويمكنك استرجاع افتراضي المشروع بضغطة زر.',
                      baseRules: projectEffectiveRules,
                      currentOverrides: u.unitRuleOverrides,
                      onSave: (newOverrides) async {
                        final nextOverrides = Map<String, dynamic>.from(
                          u.overrides,
                        );
                        if (newOverrides.isEmpty) {
                          nextOverrides.remove('ruleOverrides');
                        } else {
                          nextOverrides['ruleOverrides'] = newOverrides;
                        }
                        await _saveUpdatedUnit(
                          u.copyWith(overrides: nextOverrides),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineOverrideDropdown<T> extends StatelessWidget {
  final String label;
  final bool isOverridden;
  final VoidCallback onReset;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _InlineOverrideDropdown({
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
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isOverridden)
              InkWell(
                onTap: onReset,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.restore_rounded,
                        size: 13,
                        color: AppColors.info,
                      ),
                      SizedBox(width: 2),
                      Text(
                        'افتراضي',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          isExpanded: true,
          initialValue: value,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
