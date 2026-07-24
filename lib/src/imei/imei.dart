import '../common/issue_code.dart';
import '../common/luhn.dart';
import '../common/validation_result.dart';
import 'imei_info.dart';

/// Validation, normalization and formatting of IMEI (International Mobile
/// Equipment Identity) numbers.
///
/// Validation requires exactly 15 digits and a passing Luhn checksum over
/// all 15 digits (see `doc/algorithms.md`). Passing `allowSv: true` also
/// accepts a 16-digit IMEISV (IMEI plus a 2-digit software version number);
/// a 16-digit value is never Luhn-checked, since IMEISV has no check digit.
class Imei {
  Imei._();

  static final RegExp _digits = RegExp(r'^[0-9]+$');

  /// Returns the digits-only form, discarding spaces and dashes.
  static String _strip(String input) => input.replaceAll(RegExp(r'[\s-]'), '');

  /// Validates [input], returning a [Valid] with the compact normalized
  /// form (15 digits, or 16 when [allowSv] is true and an IMEISV is given)
  /// or an [Invalid] describing why it was rejected.
  static ValidationResult validate(String input, {bool allowSv = false}) {
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
    final ok = s.length == 15 || (allowSv && s.length == 16);
    if (!ok) {
      return Invalid([
        ValidationIssue(IssueCode.imeiBadLength,
            allowSv ? 'IMEI must be 15 or 16 digits.' : 'IMEI must be 15 digits.')
      ]);
    }
    if (s.length == 15 && !luhnOk(s)) {
      return const Invalid([
        ValidationIssue(IssueCode.imeiBadChecksum, 'Fails the Luhn checksum.')
      ]);
    }
    return Valid(s);
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input, {bool allowSv = false}) =>
      validate(input, allowSv: allowSv) is Valid;

  /// Returns the compact canonical form (15 or 16 digits). Throws
  /// [FormatException] if [input] is not a valid IMEI.
  static String normalize(String input, {bool allowSv = false}) =>
      switch (validate(input, allowSv: allowSv)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };

  /// Returns the compact form. Throws [FormatException] if invalid.
  static String format(String input, {bool allowSv = false}) =>
      normalize(input, allowSv: allowSv);

  /// Like [format] but returns null instead of throwing on invalid input.
  static String? tryFormat(String input, {bool allowSv = false}) {
    try {
      return format(input, allowSv: allowSv);
    } on FormatException {
      return null;
    }
  }

  /// Parses [input] into an [ImeiInfo], or null when it is not a valid IMEI.
  static ImeiInfo? parse(String input, {bool allowSv = false}) {
    final r = validate(input, allowSv: allowSv);
    if (r is! Valid) return null;
    final s = r.normalized;
    final isSv = s.length == 16;
    return ImeiInfo(
      tac: s.substring(0, 8),
      serialNumber: s.substring(8, 14),
      checkDigit: isSv ? null : s.substring(14),
      reportingBodyIdentifier: s.substring(0, 2),
      softwareVersion: isSv ? s.substring(14, 16) : null,
    );
  }
}
