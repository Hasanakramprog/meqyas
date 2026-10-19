import 'package:maqyas_engine/maqyas_engine.dart';

void main() {
  const engine = CalculatorEngine();

  // Define a 2-sash sliding window with a screen (W=120cm, H=150cm)
  const windowSpec = UnitSpecification(
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

  final result = engine.calculate(windowSpec);

  print('=== Maqyas Engineering Calculation Result ===');
  print('Valid: ${result.isValid}');
  print('\nProfiles to Cut:');
  for (final piece in result.pieces) {
    print(' - ${piece.nameArabic} (${piece.itemCode}): ${piece.lengthCm} cm x ${piece.quantity} [${piece.cutAngleLeft}° / ${piece.cutAngleRight}°]');
  }

  print('\nGlass Specification:');
  print(' - Pane Dimensions: ${result.glass.paneWidthCm} cm x ${result.glass.paneHeightCm} cm');
  print(' - Total Area: ${result.glass.totalAreaM2.toStringAsFixed(4)} m²');
  print(' - Total Weight: ${result.glass.weightKg.toStringAsFixed(2)} kg');

  print('\nAccessories:');
  for (final acc in result.accessories) {
    print(' - ${acc.nameArabic}: ${acc.quantity} ${acc.unit}');
  }

  // Run 1D Cut Optimizer
  const optimizer = CutOptimizer();
  final optResult = optimizer.optimize(pieces: result.pieces);

  print('\n=== 1D Stock Bar Optimization (660 cm bars) ===');
  print('Total raw bars needed: ${optResult.summary.totalBarsNeeded}');
  print('Scrap percentage: ${optResult.summary.scrapPercentage.toStringAsFixed(2)}%');
  for (final bar in optResult.barPlans) {
    print('Bar #${bar.barNumber} (${bar.itemCode}): ${bar.cuts.map((c) => "${c.lengthCm}cm").join(" + ")} | Remnant: ${bar.remainingLengthCm.toStringAsFixed(1)} cm (useful: ${bar.isRemnantUseful})');
  }
}
