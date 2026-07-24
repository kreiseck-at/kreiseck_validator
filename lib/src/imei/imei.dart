import '../common/issue_code.dart';
import '../common/luhn.dart';
import '../common/validation_result.dart';
import 'imei_info.dart';

/// Validation, normalization and formatting of IMEI (International Mobile
/// Equipment Identity) numbers.
///
/// Validation requires exactly 15 digits and a passing Luhn checksum over
/// all 15 digits (see `doc/algorithms.md`). IMEISV (16-digit, no checksum)
/// is out of scope.
class Imei {
  Imei._();

  static final RegExp _digits = RegExp(r'^[0-9]+$');

  /// Returns the digits-only form, discarding spaces and dashes.
  static String _strip(String input) => input.replaceAll(RegExp(r'[\s-]'), '');

  /// Validates [input], returning a [Valid] with the compact 15-digit
  /// normalized form or an [Invalid] describing why it was rejected.
  static ValidationResult validate(String input) {
    final s = _strip(input);
    if (s.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.imeiEmpty, 'IMEI is empty.')]);
    }
    if (!_digits.hasMatch(s)) {
      return const Invalid([
        ValidationIssue(IssueCode.imeiBadChars, 'IMEI has invalid characters.')
      ]);
    }
    if (s.length != 15) {
      return const Invalid(
          [ValidationIssue(IssueCode.imeiBadLength, 'IMEI must be 15 digits.')]);
    }
    if (!luhnOk(s)) {
      return const Invalid([
        ValidationIssue(IssueCode.imeiBadChecksum, 'Fails the Luhn checksum.')
      ]);
    }
    return Valid(s);
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input) => validate(input) is Valid;

  /// Returns the compact 15-digit canonical form. Throws [FormatException]
  /// if [input] is not a valid IMEI.
  static String normalize(String input) => switch (validate(input)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };

  /// Returns the compact 15-digit form. Throws [FormatException] if invalid.
  static String format(String input) => normalize(input);

  /// Like [format] but returns null instead of throwing on invalid input.
  static String? tryFormat(String input) {
    try {
      return format(input);
    } on FormatException {
      return null;
    }
  }

  /// Parses [input] into an [ImeiInfo], or null when it is not a valid IMEI.
  static ImeiInfo? parse(String input) {
    final r = validate(input);
    if (r is! Valid) return null;
    final s = r.normalized;
    return ImeiInfo(
      tac: s.substring(0, 8),
      serialNumber: s.substring(8, 14),
      checkDigit: s.substring(14),
      reportingBodyIdentifier: s.substring(0, 2),
    );
  }
}
