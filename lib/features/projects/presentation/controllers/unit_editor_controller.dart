import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../../../features/rules/data/rules_repository.dart';
import '../../data/projects_repository.dart';
import '../../domain/models/project.dart';
import '../../domain/models/project_unit.dart';

class UnitEditorState {
  final String id;
  final String projectId;
  final String name;
  final String location;
  final double widthCm;
  final double heightCm;
  final int quantity;
  final String unitType; // 'window' or 'facade'
  final String glazingMode; // 'single' or 'double'
  final String sharhOption; // 'none', 'one_side', 'two_sides'
  final int sashCount;
  final int screenCount;
  final bool hasScreen;
  final String profileSystemId;
  final String color;
  final String rollerType;
  final String glassType;
  final double glassThicknessMm;
  final bool hasCorners;
  final bool hasGasket;
  final Map<String, dynamic> overrides;
  final ProjectDefaults projectDefaults;
  final List<ProjectUnit> existingUnits;
  final bool isSaving;
  final CalculationResult calculationResult;

  const UnitEditorState({
    this.id = '',
    this.projectId = '',
    this.name = 'شباك 1',
    this.location = '',
    this.widthCm = 0.0,
    this.heightCm = 0.0,
    this.quantity = 1,
    this.unitType = 'window',
    this.glazingMode = 'double',
    this.sharhOption = 'none',
    this.sashCount = 2,
    this.screenCount = 1,
    this.hasScreen = true,
    this.profileSystemId = SeedRules.system2000Beaded,
    this.color = 'white',
    this.rollerType = 'slider',
    this.glassType = 'clear',
    this.glassThicknessMm = 6.0,
    this.hasCorners = true,
    this.hasGasket = false,
    this.overrides = const {},
    this.projectDefaults = const ProjectDefaults(),
    this.existingUnits = const [],
    this.isSaving = false,
    required this.calculationResult,
  });

  bool isFieldOverridden(String key) => overrides.containsKey(key);

  bool get hasAnyOverrides => overrides.isNotEmpty;

  Map<String, Map<String, String>> get unitRuleOverrides {
    final raw = overrides['ruleOverrides'];
    if (raw is! Map) return const {};
    final result = <String, Map<String, String>>{};
    for (final entry in raw.entries) {
      if (entry.value is Map) {
        result[entry.key.toString()] = (entry.value as Map).map(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
        );
      }
    }
    return result;
  }

  String get effectiveProfileSystemId =>
      overrides.containsKey('profileSystemId')
          ? (overrides['profileSystemId'] as String? ?? profileSystemId)
          : projectDefaults.profileSystemId;

  String get effectiveGlazingMode => overrides.containsKey('glazingMode')
      ? (overrides['glazingMode'] as String? ?? glazingMode)
      : projectDefaults.glazingMode;

  String get effectiveColor => overrides.containsKey('color')
      ? (overrides['color'] as String? ?? color)
      : projectDefaults.color;

  String get effectiveGlassType => overrides.containsKey('glassType')
      ? (overrides['glassType'] as String? ?? glassType)
      : projectDefaults.glassType;

  double get effectiveGlassThicknessMm =>
      overrides.containsKey('glassThicknessMm')
          ? ((overrides['glassThicknessMm'] as num?)?.toDouble() ??
              glassThicknessMm)
          : projectDefaults.glassThicknessMm;

  bool get effectiveHasGasket => overrides.containsKey('hasGasket')
      ? (overrides['hasGasket'] as bool? ?? hasGasket)
      : projectDefaults.hasGasket;

  UnitSpecification toEngineSpec() {
    return UnitSpecification(
      widthCm: widthCm,
      heightCm: heightCm,
      quantity: quantity,
      unitType: unitType,
      glazingMode: effectiveGlazingMode,
      sharhOption: sharhOption,
      sashCount: sashCount,
      screenCount: screenCount,
      hasScreen: hasScreen,
      profileSystemId: effectiveProfileSystemId,
      rollerType: rollerType,
      glassType: effectiveGlassType,
      glassThicknessMm: effectiveGlassThicknessMm,
      hasCorners: hasCorners,
      hasGasket: effectiveHasGasket,
      customOptions: {'color': effectiveColor},
    );
  }

  UnitEditorState copyWith({
    String? id,
    String? projectId,
    String? name,
    String? location,
    double? widthCm,
    double? heightCm,
    int? quantity,
    String? unitType,
    String? glazingMode,
    String? sharhOption,
    int? sashCount,
    int? screenCount,
    bool? hasScreen,
    String? profileSystemId,
    String? color,
    String? rollerType,
    String? glassType,
    double? glassThicknessMm,
    bool? hasCorners,
    bool? hasGasket,
    Map<String, dynamic>? overrides,
    ProjectDefaults? projectDefaults,
    List<ProjectUnit>? existingUnits,
    bool? isSaving,
    CalculationResult? calculationResult,
  }) {
    return UnitEditorState(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      location: location ?? this.location,
      widthCm: widthCm ?? this.widthCm,
      heightCm: heightCm ?? this.heightCm,
      quantity: quantity ?? this.quantity,
      unitType: unitType ?? this.unitType,
      glazingMode: glazingMode ?? this.glazingMode,
      sharhOption: sharhOption ?? this.sharhOption,
      sashCount: sashCount ?? this.sashCount,
      screenCount: screenCount ?? this.screenCount,
      hasScreen: hasScreen ?? this.hasScreen,
      profileSystemId: profileSystemId ?? this.profileSystemId,
      color: color ?? this.color,
      rollerType: rollerType ?? this.rollerType,
      glassType: glassType ?? this.glassType,
      glassThicknessMm: glassThicknessMm ?? this.glassThicknessMm,
      hasCorners: hasCorners ?? this.hasCorners,
      hasGasket: hasGasket ?? this.hasGasket,
      overrides: overrides ?? this.overrides,
      projectDefaults: projectDefaults ?? this.projectDefaults,
      existingUnits: existingUnits ?? this.existingUnits,
      isSaving: isSaving ?? this.isSaving,
      calculationResult: calculationResult ?? this.calculationResult,
    );
  }
}

class UnitEditorNotifier extends Notifier<UnitEditorState> {
  List<CalculationRule> get _workshopRules {
    final activeId = ref.read(activeWorkshopIdProvider);
    final user = ref.read(currentUserProvider).value;
    final workshopId = activeId ?? (user?.workshopId ?? '');
    return ref.read(effectiveRulesProvider(workshopId)).value ??
        SeedRules.getSystem2000BeadedRules();
  }

  CalculatorEngine _buildEngine({
    required ProjectDefaults projectDefaults,
    required Map<String, Map<String, String>> unitRuleOverrides,
  }) {
    final effectiveRules = ProjectUnit.resolveEffectiveRules(
      _workshopRules,
      projectDefaults: projectDefaults,
      unitRuleOverrides: unitRuleOverrides,
    );
    return CalculatorEngine(rules: effectiveRules);
  }

  @override
  UnitEditorState build() {
    return _buildInitialState(
      projectId: '',
      unit: null,
      projectDefaults: const ProjectDefaults(),
      existingUnits: const [],
    );
  }

  void loadUnit({
    required String projectId,
    ProjectUnit? initialUnit,
    ProjectDefaults? projectDefaults,
    List<ProjectUnit>? existingUnits,
  }) {
    state = _buildInitialState(
      projectId: projectId,
      unit: initialUnit,
      projectDefaults: projectDefaults ?? const ProjectDefaults(),
      existingUnits: existingUnits ?? const [],
    );
  }

  UnitEditorState _buildInitialState({
    required String projectId,
    required ProjectUnit? unit,
    required ProjectDefaults projectDefaults,
    required List<ProjectUnit> existingUnits,
  }) {
    if (unit != null) {
      final spec = unit.toEngineSpec(projectDefaults);
      final engine = _buildEngine(
        projectDefaults: projectDefaults,
        unitRuleOverrides: unit.unitRuleOverrides,
      );
      final res = engine.calculate(spec);
      return UnitEditorState(
        id: unit.id,
        projectId: unit.projectId,
        name: unit.name,
        location: unit.location,
        widthCm: unit.widthCm,
        heightCm: unit.heightCm,
        quantity: unit.quantity,
        unitType: unit.unitType,
        glazingMode: unit.effectiveGlazingMode(projectDefaults),
        sharhOption: unit.sharhOption,
        sashCount: unit.sashCount,
        screenCount: unit.screenCount,
        hasScreen: unit.hasScreen,
        profileSystemId: unit.effectiveProfileSystemId(projectDefaults),
        color: unit.effectiveColor(projectDefaults),
        rollerType: unit.rollerType,
        glassType: unit.effectiveGlassType(projectDefaults),
        glassThicknessMm: unit.effectiveGlassThicknessMm(projectDefaults),
        hasCorners: unit.hasCorners,
        hasGasket: unit.effectiveHasGasket(projectDefaults),
        overrides: Map<String, dynamic>.from(unit.overrides),
        projectDefaults: projectDefaults,
        existingUnits: existingUnits,
        calculationResult: res,
      );
    }

    // New Unit: starts at 0 × 0 and auto-increments name per type ("شباك 1", "شباك 2", ...)
    final autoName = ProjectUnit.nextAutoName('window', existingUnits);
    final initialSpec = UnitSpecification(
      widthCm: 0.0,
      heightCm: 0.0,
      quantity: 1,
      unitType: 'window',
      glazingMode: projectDefaults.glazingMode,
      profileSystemId: projectDefaults.profileSystemId,
      glassType: projectDefaults.glassType,
      glassThicknessMm: projectDefaults.glassThicknessMm,
      hasGasket: projectDefaults.hasGasket,
      customOptions: {'color': projectDefaults.color},
    );
    final engine = _buildEngine(
      projectDefaults: projectDefaults,
      unitRuleOverrides: const {},
    );
    final res = engine.calculate(initialSpec);

    return UnitEditorState(
      projectId: projectId,
      name: autoName,
      widthCm: 0.0,
      heightCm: 0.0,
      quantity: 1,
      unitType: 'window',
      glazingMode: projectDefaults.glazingMode,
      profileSystemId: projectDefaults.profileSystemId,
      color: projectDefaults.color,
      glassType: projectDefaults.glassType,
      glassThicknessMm: projectDefaults.glassThicknessMm,
      hasGasket: projectDefaults.hasGasket,
      overrides: const {},
      projectDefaults: projectDefaults,
      existingUnits: existingUnits,
      calculationResult: res,
    );
  }

  void updateDimensions({double? widthCm, double? heightCm, int? quantity}) {
    state = state.copyWith(
      widthCm: widthCm ?? state.widthCm,
      heightCm: heightCm ?? state.heightCm,
      quantity: quantity ?? state.quantity,
    );
    _recalculate();
  }

  void updateNameAndLocation({String? name, String? location}) {
    state = state.copyWith(
      name: name ?? state.name,
      location: location ?? state.location,
    );
  }

  /// Updates unit-specific options. When [unitType] changes on a new unit with an
  /// auto-generated name, the name automatically updates to the next number for that type
  /// (e.g. "شباك 1" ↔ "واجهة 1").
  void updateOptions({
    String? unitType,
    String? sharhOption,
    int? sashCount,
    bool? hasScreen,
    int? screenCount,
    String? rollerType,
    bool? hasCorners,
    String? glazingMode,
    String? profileSystemId,
    String? color,
    String? glassType,
    double? glassThicknessMm,
    bool? hasGasket,
  }) {
    var nextName = state.name;
    if (unitType != null &&
        unitType != state.unitType &&
        state.id.isEmpty &&
        ProjectUnit.isAutoGeneratedName(state.name)) {
      nextName = ProjectUnit.nextAutoName(unitType, state.existingUnits);
    }

    final nextOverrides = Map<String, dynamic>.from(state.overrides);
    if (glazingMode != null) nextOverrides['glazingMode'] = glazingMode;
    if (profileSystemId != null) {
      nextOverrides['profileSystemId'] = profileSystemId;
    }
    if (color != null) nextOverrides['color'] = color;
    if (glassType != null) nextOverrides['glassType'] = glassType;
    if (glassThicknessMm != null) {
      nextOverrides['glassThicknessMm'] = glassThicknessMm;
    }
    if (hasGasket != null) nextOverrides['hasGasket'] = hasGasket;

    state = state.copyWith(
      name: nextName,
      unitType: unitType ?? state.unitType,
      sharhOption: sharhOption ?? state.sharhOption,
      sashCount: sashCount ?? state.sashCount,
      hasScreen: hasScreen ?? state.hasScreen,
      screenCount: screenCount ?? state.screenCount,
      rollerType: rollerType ?? state.rollerType,
      hasCorners: hasCorners ?? state.hasCorners,
      glazingMode: glazingMode ?? state.glazingMode,
      profileSystemId: profileSystemId ?? state.profileSystemId,
      color: color ?? state.color,
      glassType: glassType ?? state.glassType,
      glassThicknessMm: glassThicknessMm ?? state.glassThicknessMm,
      hasGasket: hasGasket ?? state.hasGasket,
      overrides: nextOverrides,
    );
    _recalculate();
  }

  /// Sets or clears unit-level formula deduction overrides ("تعديل التخسيمات لهذا العنصر").
  void updateUnitRuleOverrides(Map<String, Map<String, String>> ruleOverrides) {
    final nextOverrides = Map<String, dynamic>.from(state.overrides);
    if (ruleOverrides.isEmpty) {
      nextOverrides.remove('ruleOverrides');
    } else {
      nextOverrides['ruleOverrides'] = ruleOverrides;
    }
    state = state.copyWith(overrides: nextOverrides);
    _recalculate();
  }

  /// Resets a single overridden property back to the project default ("استرجاع الافتراضي").
  void resetFieldToDefault(String key) {
    final nextOverrides = Map<String, dynamic>.from(state.overrides)
      ..remove(key);
    final d = state.projectDefaults;
    state = state.copyWith(
      overrides: nextOverrides,
      glazingMode: key == 'glazingMode' ? d.glazingMode : state.glazingMode,
      profileSystemId:
          key == 'profileSystemId' ? d.profileSystemId : state.profileSystemId,
      color: key == 'color' ? d.color : state.color,
      glassType: key == 'glassType' ? d.glassType : state.glassType,
      glassThicknessMm: key == 'glassThicknessMm'
          ? d.glassThicknessMm
          : state.glassThicknessMm,
      hasGasket: key == 'hasGasket' ? d.hasGasket : state.hasGasket,
    );
    _recalculate();
  }

  /// Resets all customized properties on this unit back to the project defaults.
  void resetAllOverrides() {
    final d = state.projectDefaults;
    state = state.copyWith(
      overrides: const {},
      glazingMode: d.glazingMode,
      profileSystemId: d.profileSystemId,
      color: d.color,
      glassType: d.glassType,
      glassThicknessMm: d.glassThicknessMm,
      hasGasket: d.hasGasket,
    );
    _recalculate();
  }

  void _recalculate() {
    final spec = state.toEngineSpec();
    final engine = _buildEngine(
      projectDefaults: state.projectDefaults,
      unitRuleOverrides: state.unitRuleOverrides,
    );
    final res = engine.calculate(spec);
    state = state.copyWith(calculationResult: res);
  }

  Future<bool> save(String workshopId) async {
    if (state.widthCm <= 0 || state.heightCm <= 0) return false;
    if (!state.calculationResult.isValid) return false;

    state = state.copyWith(isSaving: true);
    try {
      final repo = ref.read(projectsRepositoryProvider);
      final defaultName =
          ProjectUnit.nextAutoName(state.unitType, state.existingUnits);
      final unit = ProjectUnit(
        id: state.id,
        projectId: state.projectId,
        name: state.name.trim().isEmpty ? defaultName : state.name.trim(),
        location: state.location.trim(),
        widthCm: state.widthCm,
        heightCm: state.heightCm,
        quantity: state.quantity,
        unitType: state.unitType,
        glazingMode: state.effectiveGlazingMode,
        sharhOption: state.sharhOption,
        sashCount: state.sashCount,
        screenCount: state.screenCount,
        hasScreen: state.hasScreen,
        profileSystemId: state.effectiveProfileSystemId,
        color: state.effectiveColor,
        rollerType: state.rollerType,
        glassType: state.effectiveGlassType,
        glassThicknessMm: state.effectiveGlassThicknessMm,
        hasCorners: state.hasCorners,
        hasGasket: state.effectiveHasGasket,
        ruleVersionIdsUsed: state.calculationResult.ruleVersionIdsUsed,
        overrides: state.overrides,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.saveUnit(workshopId, unit);
      state = state.copyWith(isSaving: false);
      return true;
    } catch (_) {
      state = state.copyWith(isSaving: false);
      return false;
    }
  }
}

final unitEditorProvider =
    NotifierProvider<UnitEditorNotifier, UnitEditorState>(
  UnitEditorNotifier.new,
);
