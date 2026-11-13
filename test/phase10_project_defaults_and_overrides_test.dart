import 'package:flutter_test/flutter_test.dart';
import 'package:maqyas_engine/maqyas_engine.dart';
import 'package:meqyas/features/projects/domain/models/project.dart';
import 'package:meqyas/features/projects/domain/models/project_unit.dart';

void main() {
  group('Phase 10.1 & 10.2 — ProjectDefaults, Auto-Naming & Item Overrides', () {
    test('nextAutoName increments independently per item type (شباك 1, شباك 2, واجهة 1)', () {
      final units = <ProjectUnit>[];

      // 1st window -> شباك 1
      final win1Name = ProjectUnit.nextAutoName('window', units);
      expect(win1Name, 'شباك 1');
      units.add(
        ProjectUnit(
          id: 'u1',
          projectId: 'p1',
          name: win1Name,
          widthCm: 120,
          heightCm: 150,
          unitType: 'window',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // 2nd window -> شباك 2
      final win2Name = ProjectUnit.nextAutoName('window', units);
      expect(win2Name, 'شباك 2');

      // 1st facade -> واجهة 1 (independent counter!)
      final fac1Name = ProjectUnit.nextAutoName('facade', units);
      expect(fac1Name, 'واجهة 1');
      units.add(
        ProjectUnit(
          id: 'u2',
          projectId: 'p1',
          name: fac1Name,
          widthCm: 200,
          heightCm: 220,
          unitType: 'facade',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // 2nd facade -> واجهة 2
      expect(ProjectUnit.nextAutoName('facade', units), 'واجهة 2');
    });

    test('ProjectUnit inherits ProjectDefaults when overrides are empty', () {
      const defaults = ProjectDefaults(
        glazingMode: 'double',
        color: 'champagne',
        glassType: 'reflective',
        glassThicknessMm: 8.0,
        hasGasket: false,
      );

      final unit = ProjectUnit(
        id: 'u1',
        projectId: 'p1',
        name: 'شباك 1',
        widthCm: 120,
        heightCm: 150,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final spec = unit.toEngineSpec(defaults);
      expect(spec.glazingMode, 'double');
      expect(spec.glassType, 'reflective');
      expect(spec.glassThicknessMm, 8.0);
      expect(spec.hasGasket, false);
      expect(spec.customOptions['color'], 'champagne');
    });

    test('Per-item overrides take precedence over ProjectDefaults and reset restores defaults', () {
      const defaults = ProjectDefaults(
        glazingMode: 'double',
        color: 'white',
        glassType: 'clear',
        glassThicknessMm: 6.0,
        hasGasket: false,
      );

      final customizedUnit = ProjectUnit(
        id: 'u1',
        projectId: 'p1',
        name: 'شباك 1',
        widthCm: 120,
        heightCm: 150,
        overrides: const {
          'glassType': 'frosted',
          'glassThicknessMm': 10.0,
          'color': 'black',
          'hasGasket': true,
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(customizedUnit.hasAnyOverrides, true);
      expect(customizedUnit.isFieldOverridden('glassType'), true);
      expect(customizedUnit.isFieldOverridden('glazingMode'), false);

      final customSpec = customizedUnit.toEngineSpec(defaults);
      expect(customSpec.glazingMode, 'double'); // inherited
      expect(customSpec.glassType, 'frosted'); // overridden
      expect(customSpec.glassThicknessMm, 10.0); // overridden
      expect(customSpec.hasGasket, true); // overridden
      expect(customSpec.customOptions['color'], 'black'); // overridden

      // Reset to default -> clears overrides
      final resetUnit = customizedUnit.copyWith(overrides: const {});
      expect(resetUnit.hasAnyOverrides, false);
      final resetSpec = resetUnit.toEngineSpec(defaults);
      expect(resetSpec.glassType, 'clear');
      expect(resetSpec.glassThicknessMm, 6.0);
      expect(resetSpec.hasGasket, false);
      expect(resetSpec.customOptions['color'], 'white');
    });

    test('resolveEffectiveRules layers Workshop -> Project -> Unit deductions accurately', () {
      final baseRules = SeedRules.getSystem2000BeadedRules();
      const defaults = ProjectDefaults(
        ruleOverrides: {
          'system_2000_beaded:track': {
            'lengthFormula': 'W - 3.5',
            'quantityFormula': '2',
          },
        },
      );

      final projectEffective = ProjectUnit.resolveEffectiveRules(
        baseRules,
        projectDefaults: defaults,
      );
      final projectEngine = CalculatorEngine(rules: projectEffective);
      final projectCalc = projectEngine.calculate(
        const UnitSpecification(
          widthCm: 120,
          heightCm: 150,
          glazingMode: 'double',
          profileSystemId: SeedRules.system2000Beaded,
        ),
      );
      expect(projectCalc.isValid, isTrue);
      final trackPieceProject =
          projectCalc.pieces.firstWhere((p) => p.itemCode == 'track');
      expect(trackPieceProject.lengthCm, closeTo(116.5, 0.001));

      // Now override track at the unit level to W - 4
      final unitEffective = ProjectUnit.resolveEffectiveRules(
        baseRules,
        projectDefaults: defaults,
        unitRuleOverrides: const {
          'system_2000_beaded:track': {
            'lengthFormula': 'W - 4',
            'quantityFormula': '2',
          },
        },
      );
      final unitEngine = CalculatorEngine(rules: unitEffective);
      final unitCalc = unitEngine.calculate(
        const UnitSpecification(
          widthCm: 120,
          heightCm: 150,
          profileSystemId: SeedRules.system2000Beaded,
        ),
      );
      final trackPieceUnit =
          unitCalc.pieces.firstWhere((p) => p.itemCode == 'track');
      expect(trackPieceUnit.lengthCm, closeTo(116.0, 0.001));
    });
  });
}

