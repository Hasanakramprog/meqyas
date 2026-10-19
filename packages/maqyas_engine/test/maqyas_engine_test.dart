import 'package:maqyas_engine/maqyas_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Section 8.9 Required Test Vectors (Window W=120, H=150)', () {
    late CalculatorEngine engine;
    late UnitSpecification testVectorSpec;
    late CalculationResult result;

    setUp(() {
      engine = const CalculatorEngine();
      testVectorSpec = const UnitSpecification(
        widthCm: 120.0,
        heightCm: 150.0,
        quantity: 1,
        unitType: 'window',
        glazingMode: 'single',
        sashCount: 2,
        screenCount: 1,
        hasScreen: true,
        profileSystemId: SeedRules.system2000Beaded,
        glassThicknessMm: 6.0,
      );
      result = engine.calculate(testVectorSpec);
    });

    test('Calculation has no errors and is valid', () {
      expect(result.isValid, isTrue);
      expect(result.issues, isEmpty);
    });

    test('glass height == 136 cm', () {
      expect(result.glass.paneHeightCm, closeTo(136.0, 0.001));
    });

    test('glass width per sash == 51.9 cm', () {
      expect(result.glass.paneWidthCm, closeTo(51.9, 0.001));
    });

    test('glass pane area == 0.70584 m²', () {
      expect(result.glass.singlePaneAreaM2, closeTo(0.70584, 0.0001));
      expect(result.glass.totalAreaM2, closeTo(0.70584 * 2, 0.0001));
    });

    test('glass weight calculation is physically sound', () {
      // 0.70584 m² * 2 panes * 6mm * 2.5 kg/m²/mm = 21.1752 kg
      expect(result.glass.weightKg, closeTo(21.1752, 0.001));
    });

    test('track == 117 cm, qty 2', () {
      final track = result.pieces.firstWhere((p) => p.itemCode == 'track');
      expect(track.lengthCm, closeTo(117.0, 0.001));
      expect(track.quantity, equals(2));
    });

    test('u_profile == 146.7 cm, qty 2', () {
      final uProfile = result.pieces.firstWhere((p) => p.itemCode == 'u_profile');
      expect(uProfile.lengthCm, closeTo(146.7, 0.001));
      expect(uProfile.quantity, equals(2));
    });

    test('kaab == 58.75 cm, qty 4', () {
      final kaab = result.pieces.firstWhere((p) => p.itemCode == 'kaab');
      expect(kaab.lengthCm, closeTo(58.75, 0.001));
      expect(kaab.quantity, equals(4));
    });

    test('screen vertical == 145.9 cm, qty 2', () {
      final screenVert = result.pieces.firstWhere((p) => p.itemCode == 'screen_vertical');
      expect(screenVert.lengthCm, closeTo(145.9, 0.001));
      expect(screenVert.quantity, equals(2));
    });

    test('screen horizontal == 60.75 cm, qty 2 (kaab_len + 2 = 58.75 + 2)', () {
      final screenHoriz = result.pieces.firstWhere((p) => p.itemCode == 'screen_horizontal');
      expect(screenHoriz.lengthCm, closeTo(60.75, 0.001));
      expect(screenHoriz.quantity, equals(2));
    });
  });

  group('Behavioral Spec Tests', () {
    test('Window vs Facade: handle faces and water plugs change 6 -> 12', () {
      const engine = CalculatorEngine();

      // Window
      const windowSpec = UnitSpecification(
        widthCm: 120.0,
        heightCm: 150.0,
        unitType: 'window',
        sashCount: 2,
        profileSystemId: SeedRules.system2000Beaded,
      );
      final windowRes = engine.calculate(windowSpec);
      final winHandle = windowRes.accessories.firstWhere((a) => a.code == 'glass_handle');
      final winWaterPlug = windowRes.accessories.firstWhere((a) => a.code == 'water_plug');
      expect(winHandle.quantity, equals(2)); // 1 face * 2 sashes
      expect(winWaterPlug.quantity, equals(6));

      // Facade
      const facadeSpec = UnitSpecification(
        widthCm: 120.0,
        heightCm: 150.0,
        unitType: 'facade',
        sashCount: 2,
        profileSystemId: SeedRules.system2000Beaded,
      );
      final facadeRes = engine.calculate(facadeSpec);
      final facadeHandle = facadeRes.accessories.firstWhere((a) => a.code == 'glass_handle');
      final facadeWaterPlug = facadeRes.accessories.firstWhere((a) => a.code == 'water_plug');
      expect(facadeHandle.quantity, equals(4)); // 2 faces * 2 sashes
      expect(facadeWaterPlug.quantity, equals(12));
    });

    test('Missing rule reports error status and NEVER guesses', () {
      const engine = CalculatorEngine(rules: []); // empty rules
      const spec = UnitSpecification(
        widthCm: 100,
        heightCm: 100,
        profileSystemId: 'unknown_system_xyz',
      );
      final res = engine.calculate(spec);
      expect(res.isValid, isFalse);
      expect(res.issues.isNotEmpty, isTrue);
      expect(res.issues.first.message, contains('No rule defined'));
    });

    test('Negative length blocks calculation and reports error', () {
      // W = 1.0 cm, so (W - 3) = -2.0 cm
      const engine = CalculatorEngine();
      const spec = UnitSpecification(
        widthCm: 1.0,
        heightCm: 150.0,
        profileSystemId: SeedRules.system2000Beaded,
      );
      final res = engine.calculate(spec);
      expect(res.isValid, isFalse);
      final lengthIssue = res.issues.firstWhere((i) => i.itemCode == 'track');
      expect(lengthIssue.message, contains('must be strictly positive'));
    });

    test('Circular dependency in formulas is caught and throws CircularDependencyException', () {
      final graph = DependencyGraph();
      graph.addDependency(node: 'A', dependsOnNode: 'B');
      graph.addDependency(node: 'B', dependsOnNode: 'C');
      graph.addDependency(node: 'C', dependsOnNode: 'A'); // cycle A -> B -> C -> A

      expect(() => graph.topologicalSort(), throwsA(isA<CircularDependencyException>()));
    });
  });

  group('1D Cut Optimizer Tests (Section 8.8)', () {
    test('Respects 660 cm bar, 4 cm trim (656 cm usable), 0.5 cm kerf, and 50 cm remnant', () {
      const optimizer = CutOptimizer(
        barLengthCm: 660.0,
        trimLossCm: 4.0,
        kerfPerCutCm: 0.5,
        minRemnantCm: 50.0,
      );

      // 4 pieces of 150 cm each
      // Total cut length = 600 cm
      // Kerf for 4 cuts = 4 * 0.5 = 2.0 cm
      // Total used = 602.0 cm on 656 cm usable bar
      // Remaining = 656.0 - 602.0 = 54.0 cm (>= 50 cm -> useful remnant!)
      final pieces = [
        const CutPiece(
          itemCode: 'track',
          nameArabic: 'سكة',
          lengthCm: 150.0,
          quantity: 4,
          profileType: 'track',
        ),
      ];

      final result = optimizer.optimize(pieces: pieces);
      expect(result.summary.totalBarsNeeded, equals(1));
      final barPlan = result.barPlans.first;
      expect(barPlan.cuts.length, equals(4));
      expect(barPlan.totalCutsLengthCm, equals(600.0));
      expect(barPlan.totalKerfLossCm, equals(2.0));
      expect(barPlan.remainingLengthCm, closeTo(54.0, 0.001));
      expect(barPlan.isRemnantUseful, isTrue);
      expect(barPlan.reusableRemnantCm, closeTo(54.0, 0.001));
    });

    test('Pieces requiring multiple bars are packed using First-Fit Decreasing', () {
      const optimizer = CutOptimizer();
      // 3 pieces of 300 cm
      // Each needs 300 + 0.5 = 300.5 cm
      // Two pieces need 601 cm <= 656 cm (fits on 1 bar)
      // Third piece must open bar 2
      final pieces = [
        const CutPiece(
          itemCode: 'jamb',
          nameArabic: 'جنب',
          lengthCm: 300.0,
          quantity: 3,
          profileType: 'jamb',
        ),
      ];

      final result = optimizer.optimize(pieces: pieces);
      expect(result.summary.totalBarsNeeded, equals(2));
      expect(result.barPlans[0].cuts.length, equals(2));
      expect(result.barPlans[1].cuts.length, equals(1));
    });
  });

  group('2D Mesh Remnant Optimizer Tests (Section 8.7)', () {
    test('Rejects cut when remnant is too narrow even if total area suffices', () {
      // Remnant: 50 cm width x 200 cm length = 10,000 cm²
      const remnant = MeshRemnant(id: 'rem_1', widthCm: 50.0, lengthCm: 200.0);

      // Requested: 60 cm width x 100 cm length = 6,000 cm² (area is less than 10,000 cm²!)
      // But width 60 > 50, and 60 > 50 in normal orientation; even rotated 100 > 50.
      final decision = MeshOptimizer.evaluateCut(
        requestedWidthCm: 60.0,
        requestedLengthCm: 100.0,
        source: remnant,
      );

      expect(decision.isApproved, isFalse);
      expect(decision.rejectionReason, contains('Never cut by area alone'));
    });

    test('Approves cut when dimensions physically fit', () {
      const remnant = MeshRemnant(id: 'rem_2', widthCm: 100.0, lengthCm: 200.0);
      final decision = MeshOptimizer.evaluateCut(
        requestedWidthCm: 60.0,
        requestedLengthCm: 120.0,
        source: remnant,
      );

      expect(decision.isApproved, isTrue);
      expect(decision.remainingWidthCm, equals(40.0));
      expect(decision.remainingLengthCm, equals(80.0));
    });

    test('Cannot consume a remnant twice', () {
      const consumedRemnant = MeshRemnant(id: 'rem_3', widthCm: 100.0, lengthCm: 200.0, isConsumed: true);
      final decision = MeshOptimizer.evaluateCut(
        requestedWidthCm: 50.0,
        requestedLengthCm: 50.0,
        source: consumedRemnant,
      );
      expect(decision.isApproved, isFalse);
      expect(decision.rejectionReason, contains('already marked as consumed'));
    });
  });
}
