import '../common/country.dart';
import '../common/issue_code.dart';
import '../common/validation_result.dart';
import 'at_numbering.dart';

/// Validation, normalization (to E.164) and formatting of phone numbers.
///
/// International scope is E.164 syntax only; national parsing and pretty
/// formatting are provided for DACH (DE/AT/CH). See `doc/algorithms.md`.
class Phone {
  Phone._();

  /// Calling code -> country for the DACH set.
  static const Map<String, Country> _byCallingCode = {
    '49': Country.de,
    '43': Country.at,
    '41': Country.ch,
  };

  /// National-number length bounds (subscriber digits, excluding country code).
  static const Map<Country, (int, int)> _natLen = {
    Country.de: (6, 11),
    Country.at: (7, 11),
    Country.ch: (9, 9),
  };

  static final RegExp _allowedChars = RegExp(r'^\+?[0-9\s\-/().]+$');

  static String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  /// Validates [input], returning [Valid] with the E.164 normalized form.
  static ValidationResult validate(String input, {Country? country}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.phoneEmpty, 'Phone is empty.')]);
    }
    if (!_allowedChars.hasMatch(trimmed)) {
      return const Invalid(
          [ValidationIssue(IssueCode.phoneBadChars, 'Bad characters.')]);
    }

    String cc;
    String national;
    if (trimmed.startsWith('+')) {
      final d = _digits(trimmed);
      cc = _byCallingCode.keys.firstWhere(d.startsWith, orElse: () => '');
      if (cc.isEmpty) {
        return const Invalid([
          ValidationIssue(IssueCode.phoneUnknownCountry, 'Unknown country.')
        ]);
      }
      national = d.substring(cc.length);
      if (national.startsWith('0')) national = national.substring(1);
    } else {
      if (country == null) {
        return const Invalid([
          ValidationIssue(IssueCode.phoneAmbiguousCountry, 'Country required.')
        ]);
      }
      cc = country.callingCode;
      var d = _digits(trimmed);
      if (d.startsWith('0')) d = d.substring(1); // national trunk prefix
      national = d;
    }

    final resolved = _byCallingCode[cc]!;
    final (min, max) = _natLen[resolved]!;
    if (national.length < min) {
      return const Invalid(
          [ValidationIssue(IssueCode.phoneTooShort, 'Too short.')]);
    }
    if (national.length > max) {
      return const Invalid(
          [ValidationIssue(IssueCode.phoneTooLong, 'Too long.')]);
    }
    return Valid('+$cc$national');
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input, {Country? country}) =>
      validate(input, country: country) is Valid;

  /// Returns the E.164 canonical form. Throws [FormatException].
  static String normalize(String input, {Country? country}) =>
      switch (validate(input, country: country)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };

  /// Formats [input] internationally (`+43 660 1234567`) or nationally
  /// (`0660 1234567`) when [international] is false. Throws [FormatException].
  static String format(String input,
      {Country? country, bool international = true}) {
    final e164 = normalize(input, country: country);
    final d = e164.substring(1);
    final cc = _byCallingCode.keys.firstWhere(d.startsWith);
    final national = d.substring(cc.length);
    if (cc == '43') {
      return AtNumbering.format(national, international: international);
    }
    final area = national.substring(0, 3);
    final rest = national.substring(3);
    return international ? '+$cc $area $rest' : '0$area $rest';
  }

  /// Like [format] but returns null on invalid input.
  static String? tryFormat(String input,
      {Country? country, bool international = true}) {
    try {
      return format(input, country: country, international: international);
    } on FormatException {
      return null;
    }
  }
}
