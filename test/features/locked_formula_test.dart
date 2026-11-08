import 'package:flutter_test/flutter_test.dart';
import 'package:meqyas/features/rules/domain/locked_formula.dart';

void main() {
  group('LockedFormula.parse', () {
    test('splits H - 14 into locked text and one number', () {
      final f = LockedFormula.parse('H - 14');
      expect(f.numbers, [14]);
      expect(f.segments.where((s) => !s.isNumber).map((s) => s.text).join(), 'H - ');
    });

    test('finds every constant in (W - 16.2) / 2', () {
      final f = LockedFormula.parse('(W - 16.2) / 2');
      expect(f.numbers, [16.2, 2]);
      expect(f.rebuild(['15', '2']), '(W - 15) / 2');
    });

    test('ignores digits inside identifiers', () {
      final f = LockedFormula.parse('kaab_len + 2 * profile2');
      expect(f.numbers, [2]);
      expect(f.rebuild(['3']), 'kaab_len + 3 * profile2');
    });

    test('formula without numbers has nothing to edit', () {
      expect(LockedFormula.parse('sashCount').numberCount, 0);
    });

    test('structure comparison ignores numbers and whitespace', () {
      final a = LockedFormula.parse('H - 14');
      expect(a.hasSameStructureAs(LockedFormula.parse('H-15')), isTrue);
      expect(a.hasSameStructureAs(LockedFormula.parse('W - 14')), isFalse);
      expect(a.hasSameStructureAs(LockedFormula.parse('H - 14 + 1')), isFalse);
    });

    test('formatNumber drops trailing zeros', () {
      expect(LockedFormula.formatNumber(14), '14');
      expect(LockedFormula.formatNumber(16.20), '16.2');
      expect(LockedFormula.formatNumber(0.5), '0.5');
    });
  });

  group('NumberBounds ±50%', () {
    test('14 allows 7..21', () {
      final b = NumberBounds.around(14);
      expect(b.validate('7'), isNull);
      expect(b.validate('21'), isNull);
      expect(b.validate('15.5'), isNull);
      expect(b.validate('6.9'), isNotNull);
      expect(b.validate('21.1'), isNotNull);
      expect(b.validate(''), isNotNull);
      expect(b.validate('abc'), isNotNull);
    });

    test('quantity integers reject decimals and keep at least ±1', () {
      final b = NumberBounds.around(2, integerOnly: true);
      expect(b.validate('1'), isNull);
      expect(b.validate('3'), isNull);
      expect(b.validate('2.5'), isNotNull);
      expect(b.validate('4'), isNotNull);
    });

    test('zero constant is locked', () {
      expect(NumberBounds.around(0).isLocked, isTrue);
    });
  });
}

