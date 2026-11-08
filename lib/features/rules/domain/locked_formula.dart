/// Splits a calculation formula into locked structure (variables, operators,
/// brackets) and editable numeric constants.
///
/// Used by the workshop owner rules screen so the owner can only change the
/// numbers inside a formula (e.g. the `14` in `H - 14`), never its structure.
/// The admin rule editor keeps free-text editing.
library;

/// Allowed deviation from the admin-approved value (±50%).
const double kLockedFormulaTolerance = 0.5;

class FormulaSegment {
  /// Raw text of this segment exactly as it appears in the formula.
  final String text;

  /// True when this segment is a numeric constant the owner may edit.
  final bool isNumber;

  const FormulaSegment.text(this.text) : isNumber = false;
  const FormulaSegment.number(this.text) : isNumber = true;

  double get numericValue => double.parse(text);
}

class LockedFormula {
  final String source;
  final List<FormulaSegment> segments;

  LockedFormula._(this.source, this.segments);

  /// Matches standalone numeric constants. Digits that are part of an
  /// identifier (e.g. `profile2`, `x_10`) are not treated as constants.
  static final RegExp _numberPattern = RegExp(
    r'(?<![A-Za-z_\d.])\d+(?:\.\d+)?(?![A-Za-z_\d.])',
  );

  factory LockedFormula.parse(String formula) {
    final segments = <FormulaSegment>[];
    var cursor = 0;
    for (final match in _numberPattern.allMatches(formula)) {
      if (match.start > cursor) {
        segments.add(FormulaSegment.text(formula.substring(cursor, match.start)));
      }
      segments.add(FormulaSegment.number(match.group(0)!));
      cursor = match.end;
    }
    if (cursor < formula.length) {
      segments.add(FormulaSegment.text(formula.substring(cursor)));
    }
    return LockedFormula._(formula, segments);
  }

  List<FormulaSegment> get numberSegments =>
      segments.where((s) => s.isNumber).toList();

  List<double> get numbers =>
      numberSegments.map((s) => s.numericValue).toList();

  int get numberCount => numberSegments.length;

  /// Structure signature with every number replaced by a placeholder.
  /// Whitespace is ignored so `H-14` and `H - 14` share a structure.
  String get structureKey => segments
      .map((s) => s.isNumber ? '#' : s.text.replaceAll(RegExp(r'\s+'), ''))
      .join();

  bool hasSameStructureAs(LockedFormula other) =>
      structureKey == other.structureKey;

  /// Rebuilds the formula keeping all locked text and replacing each numeric
  /// constant (in order) with [values].
  String rebuild(List<String> values) {
    assert(values.length == numberCount);
    final buffer = StringBuffer();
    var i = 0;
    for (final s in segments) {
      if (s.isNumber) {
        buffer.write(values[i++].trim());
      } else {
        buffer.write(s.text);
      }
    }
    return buffer.toString();
  }

  /// Formats a number without a trailing `.0` (14.0 -> "14", 16.20 -> "16.2").
  static String formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    var text = value.toStringAsFixed(4);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    return text.replaceFirst(RegExp(r'\.$'), '');
  }
}

/// Allowed range for one editable constant, derived from the admin value.
class NumberBounds {
  final double original;
  final double min;
  final double max;
  final bool integerOnly;

  const NumberBounds._(this.original, this.min, this.max, this.integerOnly);

  /// ±[kLockedFormulaTolerance] around [original]. When [integerOnly] is set
  /// (whole-number constants in quantity formulas) bounds snap to integers and
  /// always allow at least ±1 so a value like `2` can become `1` or `3`.
  factory NumberBounds.around(double original, {bool integerOnly = false}) {
    final delta = original.abs() * kLockedFormulaTolerance;
    var min = original - delta;
    var max = original + delta;
    if (integerOnly) {
      min = min.ceilToDouble();
      max = max.floorToDouble();
      if (original != 0) {
        if (min > original - 1) min = original - 1;
        if (max < original + 1) max = original + 1;
        if (min < 1) min = 1;
      }
    }
    return NumberBounds._(original, min, max, integerOnly);
  }

  /// True when the original is 0: ±50% of 0 leaves nothing to edit.
  bool get isLocked => min == max;

  /// Arabic error message, or null when [input] is valid.
  String? validate(String input) {
    final text = input.trim();
    if (text.isEmpty) return 'أدخل قيمة';
    final value = double.tryParse(text);
    if (value == null) return 'رقم غير صالح';
    if (integerOnly && value != value.roundToDouble()) {
      return 'يجب أن يكون عدداً صحيحاً';
    }
    // Tiny epsilon so values typed exactly at the edge are accepted.
    const eps = 1e-9;
    if (value < min - eps || value > max + eps) {
      return 'المسموح من ${LockedFormula.formatNumber(min)} '
          'إلى ${LockedFormula.formatNumber(max)}';
    }
    return null;
  }
}

