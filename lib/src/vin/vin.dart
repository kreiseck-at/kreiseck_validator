import '../common/issue_code.dart';
import '../common/validation_result.dart';
import 'vin_info.dart';

/// Validation, normalization and formatting of Vehicle Identification
/// Numbers (ISO 3779).
///
/// Validation checks structure only: 17 characters from the ISO 3779
/// charset (`I`, `O`, `Q` are forbidden to avoid confusion with `1`/`0`).
/// The check digit is mandatory only for North American VINs -- European
/// VINs frequently have no valid check digit -- so it is never enforced by
/// [validate]; its result is exposed via `Vin.parse(...).checkDigitValid`
/// instead.
class Vin {
  Vin._();

  static final RegExp _charset = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');

  static const Map<String, int> _transliteration = {
    'A': 1, 'B': 2, 'C': 3, 'D': 4, 'E': 5, 'F': 6, 'G': 7, 'H': 8,
    'J': 1, 'K': 2, 'L': 3, 'M': 4, 'N': 5, 'P': 7, 'R': 9,
    'S': 2, 'T': 3, 'U': 4, 'V': 5, 'W': 6, 'X': 7, 'Y': 8, 'Z': 9,
    '0': 0, '1': 1, '2': 2, '3': 3, '4': 4,
    '5': 5, '6': 6, '7': 7, '8': 8, '9': 9,
  };

  static const List<int> _weights = [
    8, 7, 6, 5, 4, 3, 2, 10, 0, 9, 8, 7, 6, 5, 4, 3, 2,
  ];

  static const Map<String, int> _yearCodes = {
    'A': 1980, 'B': 1981, 'C': 1982, 'D': 1983, 'E': 1984, 'F': 1985,
    'G': 1986, 'H': 1987, 'J': 1988, 'K': 1989, 'L': 1990, 'M': 1991,
    'N': 1992, 'P': 1993, 'R': 1994, 'S': 1995, 'T': 1996, 'V': 1997,
    'W': 1998, 'X': 1999, 'Y': 2000,
    '1': 2001, '2': 2002, '3': 2003, '4': 2004, '5': 2005,
    '6': 2006, '7': 2007, '8': 2008, '9': 2009,
  };

  /// Validates [input], returning a [Valid] with the upper-cased 17-char
  /// normalized form or an [Invalid] describing why it was rejected.
  static ValidationResult validate(String input) {
    final upper = input.trim().toUpperCase();
    if (upper.isEmpty) {
      return const Invalid([ValidationIssue(IssueCode.vinEmpty, 'VIN is empty.')]);
    }
    if (upper.length != 17) {
      return const Invalid([
        ValidationIssue(IssueCode.vinBadLength, 'VIN must be 17 characters.')
      ]);
    }
    if (!_charset.hasMatch(upper)) {
      return const Invalid([
        ValidationIssue(IssueCode.vinBadChars, 'VIN has invalid characters.')
      ]);
    }
    return Valid(upper);
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input) => validate(input) is Valid;

  /// Returns the upper-cased 17-char canonical form. Throws
  /// [FormatException] if [input] is not a structurally valid VIN.
  static String normalize(String input) => switch (validate(input)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };

  /// Returns the upper-cased 17-char form. Throws [FormatException] if
  /// invalid.
  static String format(String input) => normalize(input);

  /// Like [format] but returns null instead of throwing on invalid input.
  static String? tryFormat(String input) {
    try {
      return format(input);
    } on FormatException {
      return null;
    }
  }

  /// Computes the ISO 3779 weighted-sum check digit expected for the
  /// (already validated, upper-case) 17-char [vin].
  static String _expectedCheckDigit(String vin) {
    var sum = 0;
    for (var i = 0; i < 17; i++) {
      sum += _transliteration[vin[i]]! * _weights[i];
    }
    final r = sum % 11;
    return r == 10 ? 'X' : r.toString();
  }

  /// Decodes the model year from char 10, disambiguating the 30-year
  /// repeat cycle using char 7 (a letter selects 2010-2039, a digit keeps
  /// the 1980-2009 base cycle).
  static int _decodeModelYear(String vin) {
    final baseYear = _yearCodes[vin[9]]!;
    final positionSeven = vin[6];
    final isLetter = RegExp(r'^[A-Z]$').hasMatch(positionSeven);
    return isLetter ? baseYear + 30 : baseYear;
  }

  /// Parses [input] into a [VinInfo], or null when it is not a
  /// structurally valid VIN.
  static VinInfo? parse(String input) {
    final r = validate(input);
    if (r is! Valid) return null;
    final vin = r.normalized;
    final checkDigit = vin.substring(8, 9);
    return VinInfo(
      wmi: vin.substring(0, 3),
      vds: vin.substring(3, 9),
      vis: vin.substring(9, 17),
      checkDigit: checkDigit,
      checkDigitValid: _expectedCheckDigit(vin) == checkDigit,
      modelYear: _decodeModelYear(vin),
      plantCode: vin.substring(10, 11),
    );
  }
}
