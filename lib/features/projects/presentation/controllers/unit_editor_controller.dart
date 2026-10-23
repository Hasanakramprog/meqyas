import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../../../features/rules/data/rules_repository.dart';
import '../../data/projects_repository.dart';
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
  final String rollerType;
  final String glassType;
  final double glassThicknessMm;
  final bool hasCorners;
  final bool hasGasket;
  final bool isSaving;
  final CalculationResult calculationResult;

  const UnitEditorState({
    this.id = '',
    this.projectId = '',
    this.name = 'شباك 1',
    this.location = '',
    this.widthCm = 120.0,
    this.heightCm = 150.0,
    this.quantity = 1,
    this.unitType = 'window',
    this.glazingMode = 'single',
    this.sharhOption = 'none',
    this.sashCount = 2,
    this.screenCount = 1,
    this.hasScreen = true,
    this.profileSystemId = SeedRules.system2000Beaded,
    this.rollerType = 'slider',
    this.glassType = 'clear',
    this.glassThicknessMm = 6.0,
    this.hasCorners = true,
    this.hasGasket = true,
    this.isSaving = false,
    required this.calculationResult,
  });

  UnitSpecification toEngineSpec() {
    return UnitSpecification(
      widthCm: widthCm,
      heightCm: heightCm,
      quantity: quantity,
      unitType: unitType,
      glazingMode: glazingMode,
      sharhOption: sharhOption,
      sashCount: sashCount,
      screenCount: screenCount,
      hasScreen: hasScreen,
      profileSystemId: profileSystemId,
      rollerType: rollerType,
      glassType: glassType,
      glassThicknessMm: glassThicknessMm,
      hasCorners: hasCorners,
      hasGasket: hasGasket,
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
    String? rollerType,
    String? glassType,
    double? glassThicknessMm,
    bool? hasCorners,
    bool? hasGasket,
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
      rollerType: rollerType ?? this.rollerType,
      glassType: glassType ?? this.glassType,
      glassThicknessMm: glassThicknessMm ?? this.glassThicknessMm,
      hasCorners: hasCorners ?? this.hasCorners,
      hasGasket: hasGasket ?? this.hasGasket,
      isSaving: isSaving ?? this.isSaving,
      calculationResult: calculationResult ?? this.calculationResult,
    );
  }
}

class UnitEditorNotifier extends Notifier<UnitEditorState> {
  CalculatorEngine get _engine {
    final activeId = ref.read(activeWorkshopIdProvider);
    final user = ref.read(currentUserProvider).value;
    final workshopId = activeId ?? (user?.workshopId ?? '');
    return ref.read(calculatorEngineProvider(workshopId));
  }

  @override
  UnitEditorState build() {
    return _buildInitialState('', null);
  }

  void loadUnit({required String projectId, ProjectUnit? initialUnit}) {
    state = _buildInitialState(projectId, initialUnit);
  }

  UnitEditorState _buildInitialState(String projectId, ProjectUnit? unit) {
    if (unit != null) {
      final spec = unit.toEngineSpec();
      final res = _engine.calculate(spec);
      return UnitEditorState(
        id: unit.id,
        projectId: unit.projectId,
        name: unit.name,
        location: unit.location,
        widthCm: unit.widthCm,
        heightCm: unit.heightCm,
        quantity: unit.quantity,
        unitType: unit.unitType,
        glazingMode: unit.glazingMode,
        sharhOption: unit.sharhOption,
        sashCount: unit.sashCount,
        screenCount: unit.screenCount,
        hasScreen: unit.hasScreen,
        profileSystemId: unit.profileSystemId,
        rollerType: unit.rollerType,
        glassType: unit.glassType,
        glassThicknessMm: unit.glassThicknessMm,
        hasCorners: unit.hasCorners,
        hasGasket: unit.hasGasket,
        calculationResult: res,
      );
    }

    const defaultSpec = UnitSpecification(
      widthCm: 120.0,
      heightCm: 150.0,
      quantity: 1,
      profileSystemId: SeedRules.system2000Beaded,
    );
    final res = _engine.calculate(defaultSpec);

    return UnitEditorState(
      projectId: projectId,
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

  void updateOptions({
    String? unitType,
    String? glazingMode,
    String? sharhOption,
    int? sashCount,
    bool? hasScreen,
    int? screenCount,
    String? profileSystemId,
    String? rollerType,
    String? glassType,
    double? glassThicknessMm,
    bool? hasCorners,
    bool? hasGasket,
  }) {
    state = state.copyWith(
      unitType: unitType ?? state.unitType,
      glazingMode: glazingMode ?? state.glazingMode,
      sharhOption: sharhOption ?? state.sharhOption,
      sashCount: sashCount ?? state.sashCount,
      hasScreen: hasScreen ?? state.hasScreen,
      screenCount: screenCount ?? state.screenCount,
      profileSystemId: profileSystemId ?? state.profileSystemId,
      rollerType: rollerType ?? state.rollerType,
      glassType: glassType ?? state.glassType,
      glassThicknessMm: glassThicknessMm ?? state.glassThicknessMm,
      hasCorners: hasCorners ?? state.hasCorners,
      hasGasket: hasGasket ?? state.hasGasket,
    );
    _recalculate();
  }

  void _recalculate() {
    final spec = state.toEngineSpec();
    final res = _engine.calculate(spec);
    state = state.copyWith(calculationResult: res);
  }

  Future<bool> save(String workshopId) async {
    if (!state.calculationResult.isValid) return false;

    state = state.copyWith(isSaving: true);
    try {
      final repo = ref.read(projectsRepositoryProvider);
      final unit = ProjectUnit(
        id: state.id,
        projectId: state.projectId,
        name: state.name.trim().isEmpty ? 'شباك' : state.name.trim(),
        location: state.location.trim(),
        widthCm: state.widthCm,
        heightCm: state.heightCm,
        quantity: state.quantity,
        unitType: state.unitType,
        glazingMode: state.glazingMode,
        sharhOption: state.sharhOption,
        sashCount: state.sashCount,
        screenCount: state.screenCount,
        hasScreen: state.hasScreen,
        profileSystemId: state.profileSystemId,
        rollerType: state.rollerType,
        glassType: state.glassType,
        glassThicknessMm: state.glassThicknessMm,
        hasCorners: state.hasCorners,
        hasGasket: state.hasGasket,
        ruleVersionIdsUsed: state.calculationResult.ruleVersionIdsUsed,
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

final unitEditorProvider = NotifierProvider<UnitEditorNotifier, UnitEditorState>(
  UnitEditorNotifier.new,
);
