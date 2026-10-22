/// Money helpers for Ethiopian Birr (ETB) and Santim.
///
/// Rules:
/// - 1 Birr = 100 Santim.
/// - All monetary values must be stored as integer santim (no doubles/floats).
/// - Conversion from decimal birr strings directly parses characters into
///   integer santim without floating-point arithmetic to avoid precision loss.
/// - Unrepresentable values (e.g. fractional santim with >2 decimal places)
///   are rejected explicitly.
library;

/// Exception thrown when a birr amount string cannot be parsed into santim.
class MoneyFormatException extends FormatException {
  const MoneyFormatException(super.message, [super.source, super.offset]);
}

/// The number of santim in one Ethiopian Birr.
const int santimPerBirr = 100;

/// Maximum representable santim in a 64-bit signed integer (92,233,720,368,547,758.07 Birr).
const int maxSantim = 9223372036854775807;

/// Minimum representable santim in a 64-bit signed integer (-92,233,720,368,547,758.08 Birr).
const int minSantim = -9223372036854775808;

/// Maximum whole birr amount that can be converted to santim without 64-bit overflow.
const int maxWholeBirr = 92233720368547758;

/// Parses a user-entered decimal birr string directly into integer santim without
/// using floating-point arithmetic.
///
/// Accepts strings like:
/// - `"25"` -> `2500`
/// - `"25.5"` -> `2550`
/// - `"25.50"` -> `2550`
/// - `"0.05"` -> `5`
/// - `".5"` -> `50`
/// - `"-25.50"` -> `-2550` (if [allowNegative] is true)
///
/// Throws [MoneyFormatException] if:
/// - The string is empty or contains only whitespace.
/// - The string contains non-digit characters (other than an optional leading sign and a single decimal point).
/// - The string has more than 2 decimal places (unrepresentable fractional santim).
/// - [allowNegative] is false and a negative amount is provided.
/// - The value overflows or underflows 64-bit integer limits.
int parseBirrToSantim(String input, {bool allowNegative = true}) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    throw MoneyFormatException('Birr amount cannot be empty', input);
  }

  var sign = 1;
  var startIndex = 0;
  if (trimmed.startsWith('+')) {
    startIndex = 1;
  } else if (trimmed.startsWith('-')) {
    if (!allowNegative) {
      throw MoneyFormatException('Negative amounts are not allowed', input);
    }
    sign = -1;
    startIndex = 1;
  }

  final rest = trimmed.substring(startIndex);
  if (rest.isEmpty) {
    throw MoneyFormatException('Birr amount contains only a sign', input);
  }

  final dotIndex = rest.indexOf('.');
  if (dotIndex != -1 && rest.indexOf('.', dotIndex + 1) != -1) {
    throw MoneyFormatException(
      'Birr amount contains multiple decimal points',
      input,
    );
  }

  final String wholeStr;
  final String fracStr;
  if (dotIndex == -1) {
    wholeStr = rest;
    fracStr = '';
  } else {
    wholeStr = rest.substring(0, dotIndex);
    fracStr = rest.substring(dotIndex + 1);
  }

  if (wholeStr.isEmpty && fracStr.isEmpty) {
    throw MoneyFormatException('Birr amount contains no digits', input);
  }

  var wholeBirr = 0;
  if (wholeStr.isNotEmpty) {
    if (!_isAllDigits(wholeStr)) {
      throw MoneyFormatException(
        'Whole birr amount contains non-digit characters',
        input,
      );
    }
    final parsedWhole = int.tryParse(wholeStr);
    if (parsedWhole == null || parsedWhole > maxWholeBirr) {
      throw MoneyFormatException(
        'Birr amount exceeds maximum representable integer limits',
        input,
      );
    }
    wholeBirr = parsedWhole;
  }

  var fracSantim = 0;
  if (fracStr.isNotEmpty) {
    if (!_isAllDigits(fracStr)) {
      throw MoneyFormatException(
        'Fractional birr amount contains non-digit characters',
        input,
      );
    }
    if (fracStr.length > 2) {
      throw MoneyFormatException(
        'Fractional birr amount has more than 2 decimal places (unrepresentable santim)',
        input,
      );
    }
    if (fracStr.length == 1) {
      fracSantim = (fracStr.codeUnitAt(0) - 48) * 10;
    } else {
      fracSantim =
          (fracStr.codeUnitAt(0) - 48) * 10 + (fracStr.codeUnitAt(1) - 48);
    }
  }

  // Exact 64-bit boundary check:
  if (wholeBirr == maxWholeBirr) {
    if (sign == 1 && fracSantim > 7) {
      throw MoneyFormatException(
        'Birr amount exceeds maximum representable santim',
        input,
      );
    }
    if (sign == -1 && fracSantim > 8) {
      throw MoneyFormatException(
        'Birr amount is below minimum representable santim',
        input,
      );
    }
  }

  if (sign == -1 && wholeBirr == maxWholeBirr && fracSantim == 8) {
    return minSantim;
  }

  final total = wholeBirr * santimPerBirr + fracSantim;
  return sign == -1 ? -total : total;
}

bool _isAllDigits(String s) {
  for (var i = 0; i < s.length; i++) {
    final code = s.codeUnitAt(i);
    if (code < 48 || code > 57) {
      return false;
    }
  }
  return true;
}

/// Attempts to parse a user-entered decimal birr string into integer santim without
/// using floating-point arithmetic.
///
/// Returns `null` if [input] is `null`, malformed, unrepresentable, or violates
/// [allowNegative].
int? tryParseBirrToSantim(String? input, {bool allowNegative = true}) {
  if (input == null) return null;
  try {
    return parseBirrToSantim(input, allowNegative: allowNegative);
  } on FormatException {
    return null;
  }
}

/// Formats an integer [santim] value as a decimal birr string for display.
///
/// Parameters:
/// - [useGrouping]: When true, inserts thousands commas in the whole birr part
///   (e.g. `"1,234.50"` instead of `"1234.50"`). Default is `false`.
/// - [symbol]: Optional currency symbol (e.g. `'ETB'` or `'ብር'`).
/// - [symbolAtStart]: When true, places the symbol before the number
///   (e.g. `'ብር 25.50'`). When false, places it after (e.g. `'25.50 ETB'`).
///   Default is `false`.
String formatSantimAsBirr(
  int santim, {
  bool useGrouping = false,
  String? symbol,
  bool symbolAtStart = false,
}) {
  if (santim == minSantim) {
    final numberStr = useGrouping
        ? '-92,233,720,368,547,758.08'
        : '-92233720368547758.08';
    return _applySymbol(
      numberStr,
      isNegative: true,
      symbol: symbol,
      symbolAtStart: symbolAtStart,
    );
  }

  final isNegative = santim < 0;
  final absSantim = isNegative ? -santim : santim;
  final wholeBirr = absSantim ~/ santimPerBirr;
  final subSantim = absSantim % santimPerBirr;

  final wholeBirrStr = useGrouping
      ? _formatWithGrouping(wholeBirr)
      : wholeBirr.toString();
  final subSantimStr = subSantim.toString().padLeft(2, '0');

  final signStr = isNegative ? '-' : '';
  final numberStr = '$signStr$wholeBirrStr.$subSantimStr';

  return _applySymbol(
    numberStr,
    isNegative: isNegative,
    symbol: symbol,
    symbolAtStart: symbolAtStart,
  );
}

/// Convenience alias for [formatSantimAsBirr].
String formatBirr(
  int santim, {
  bool useGrouping = false,
  String? symbol,
  bool symbolAtStart = false,
}) => formatSantimAsBirr(
  santim,
  useGrouping: useGrouping,
  symbol: symbol,
  symbolAtStart: symbolAtStart,
);

String _applySymbol(
  String numberStr, {
  required bool isNegative,
  String? symbol,
  required bool symbolAtStart,
}) {
  if (symbol == null || symbol.isEmpty) {
    return numberStr;
  }

  if (symbolAtStart) {
    if (isNegative) {
      return '-$symbol ${numberStr.substring(1)}';
    }
    return '$symbol $numberStr';
  }

  return '$numberStr $symbol';
}

String _formatWithGrouping(int n) {
  final digits = n.toString();
  if (digits.length <= 3) return digits;

  final buffer = StringBuffer();
  final remainder = digits.length % 3;
  if (remainder > 0) {
    buffer.write(digits.substring(0, remainder));
  }
  for (var i = remainder; i < digits.length; i += 3) {
    if (buffer.isNotEmpty) {
      buffer.write(',');
    }
    buffer.write(digits.substring(i, i + 3));
  }
  return buffer.toString();
}

/// Converts whole birr and optional fractional santim directly to integer santim.
///
/// [santimFraction] must be between 0 and 99 (inclusive).
int birrToSantim(int wholeBirr, [int santimFraction = 0]) {
  if (santimFraction < 0 || santimFraction > 99) {
    throw ArgumentError.value(
      santimFraction,
      'santimFraction',
      'Must be between 0 and 99',
    );
  }

  if (wholeBirr > maxWholeBirr || wholeBirr < -maxWholeBirr) {
    throw MoneyFormatException('Birr amount exceeds representable limits');
  }

  if (wholeBirr == maxWholeBirr && santimFraction > 7) {
    throw MoneyFormatException('Birr amount exceeds representable limits');
  }
  if (wholeBirr == -maxWholeBirr && santimFraction > 8) {
    throw MoneyFormatException('Birr amount is below representable limits');
  }

  if (wholeBirr == -maxWholeBirr && santimFraction == 8) {
    return minSantim;
  }

  if (wholeBirr < 0) {
    return wholeBirr * santimPerBirr - santimFraction;
  }
  return wholeBirr * santimPerBirr + santimFraction;
}

/// Splits integer [santim] into whole birr and fractional santim remainder.
///
/// [santimRemainder] is always in range 0..99.
/// [wholeBirr] carries the sign of [santim].
({int wholeBirr, int santimRemainder}) splitSantim(int santim) {
  if (santim == minSantim) {
    return (wholeBirr: -92233720368547758, santimRemainder: 8);
  }
  final isNegative = santim < 0;
  final absSantim = isNegative ? -santim : santim;
  final whole = absSantim ~/ santimPerBirr;
  final remainder = absSantim % santimPerBirr;
  return (wholeBirr: isNegative ? -whole : whole, santimRemainder: remainder);
}

/// Extension methods on [int] for santim monetary amounts.
extension SantimIntExtension on int {
  /// Formats this integer santim value as a decimal birr string.
  String toBirrString({
    bool useGrouping = false,
    String? symbol,
    bool symbolAtStart = false,
  }) => formatSantimAsBirr(
    this,
    useGrouping: useGrouping,
    symbol: symbol,
    symbolAtStart: symbolAtStart,
  );

  /// The whole birr portion of this santim value.
  int get wholeBirr => this ~/ santimPerBirr;

  /// The sub-birr fractional santim portion in range `0..99`.
  int get subBirrSantim => (this % santimPerBirr).abs();

  /// Splits this santim value into whole birr and fractional remainder.
  ({int wholeBirr, int santimRemainder}) get splitAsBirr => splitSantim(this);
}

/// Extension methods on [String] for birr amount parsing.
extension BirrStringExtension on String {
  /// Parses this string as a decimal birr amount into integer santim.
  int toSantim({bool allowNegative = true}) =>
      parseBirrToSantim(this, allowNegative: allowNegative);

  /// Attempts to parse this string as a decimal birr amount into integer santim.
  int? tryToSantim({bool allowNegative = true}) =>
      tryParseBirrToSantim(this, allowNegative: allowNegative);
}

/// An extension type representing money strictly as integer santim.
///
/// Provides compile-time type safety while having zero runtime overhead
/// over a primitive `int`.
extension type const Santim(int value) implements int {
  /// Zero santim.
  static const Santim zero = Santim(0);

  /// Parses a decimal birr string into [Santim].
  factory Santim.parseBirr(String input, {bool allowNegative = true}) =>
      Santim(parseBirrToSantim(input, allowNegative: allowNegative));

  /// Attempts to parse a decimal birr string into [Santim].
  static Santim? tryParseBirr(String? input, {bool allowNegative = true}) {
    final parsed = tryParseBirrToSantim(input, allowNegative: allowNegative);
    return parsed != null ? Santim(parsed) : null;
  }

  /// Creates a [Santim] value from whole birr and santim fraction.
  factory Santim.fromBirr(int wholeBirr, [int santimFraction = 0]) =>
      Santim(birrToSantim(wholeBirr, santimFraction));

  /// Formats this value as a decimal birr string for display.
  String formatBirr({
    bool useGrouping = false,
    String? symbol,
    bool symbolAtStart = false,
  }) => formatSantimAsBirr(
    value,
    useGrouping: useGrouping,
    symbol: symbol,
    symbolAtStart: symbolAtStart,
  );

  /// The whole birr portion.
  int get wholeBirr => value ~/ santimPerBirr;

  /// The fractional santim remainder (0..99).
  int get subBirrSantim => (value % santimPerBirr).abs();
}
