import '../common/issue_code.dart';
import '../common/validation_result.dart';

/// Validation, normalization and formatting of IBANs.
///
/// The ISO 13616 check digits are verified with the Mod-97 algorithm
/// (see `doc/algorithms.md`). Length is enforced for DACH countries; other
/// countries are accepted on checksum alone.
class Iban {
  Iban._();

  /// Known IBAN lengths for the DACH scope.
  static const Map<String, int> _dachLengths = {'DE': 22, 'AT': 20, 'CH': 21};

  static final RegExp _structure = RegExp(r'^[A-Z]{2}[0-9]{2}[0-9A-Z]+$');

  static String _strip(String input) =>
      input.replaceAll(RegExp(r'\s'), '').toUpperCase();

  /// Mod-97 checksum: move first 4 chars to the end, map letters A-Z to
  /// 10-35, take the big integer mod 97 in 7-digit chunks; valid when == 1.
  static bool _checksumOk(String iban) {
    final rearranged = iban.substring(4) + iban.substring(0, 4);
    final buf = StringBuffer();
    for (final cu in rearranged.codeUnits) {
      if (cu >= 0x30 && cu <= 0x39) {
        buf.write(cu - 0x30);
      } else if (cu >= 0x41 && cu <= 0x5A) {
        buf.write(cu - 0x37);
      } else {
        return false;
      }
    }
    final s = buf.toString();
    var remainder = 0;
    for (var i = 0; i < s.length; i += 7) {
      final end = i + 7 > s.length ? s.length : i + 7;
      remainder = int.parse('$remainder${s.substring(i, end)}') % 97;
    }
    return remainder == 1;
  }

  /// Validates [input], returning [Valid] with the compact upper-case form.
  static ValidationResult validate(String input) {
    final s = _strip(input);
    if (s.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.ibanEmpty, 'IBAN is empty.')]);
    }
    if (!_structure.hasMatch(s)) {
      return const Invalid([
        ValidationIssue(IssueCode.ibanBadChars, 'IBAN has invalid characters.')
      ]);
    }
    final country = s.substring(0, 2);
    final expected = _dachLengths[country];
    if (expected != null && s.length != expected) {
      return const Invalid(
          [ValidationIssue(IssueCode.ibanBadLength, 'Wrong length.')]);
    }
    if (!_checksumOk(s)) {
      return const Invalid(
          [ValidationIssue(IssueCode.ibanBadChecksum, 'Checksum failed.')]);
    }
    return Valid(s);
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input) => validate(input) is Valid;

  /// Returns the compact upper-case canonical form. Throws [FormatException].
  static String normalize(String input) => switch (validate(input)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };

  /// Returns the IBAN grouped in blocks of four. Throws [FormatException].
  static String format(String input) => RegExp(r'.{1,4}')
      .allMatches(normalize(input))
      .map((m) => m.group(0))
      .join(' ');

  /// Like [format] but returns null on invalid input.
  static String? tryFormat(String input) {
    try {
      return format(input);
    } on FormatException {
      return null;
    }
  }
}
