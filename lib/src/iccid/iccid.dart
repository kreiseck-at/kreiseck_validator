import '../common/country.dart';
import '../common/issue_code.dart';
import '../common/luhn.dart';
import '../common/validation_result.dart';
import 'iccid_info.dart';

/// Validation, normalization and formatting of ICCID (Integrated Circuit
/// Card Identifier, ITU-T E.118) numbers, i.e. SIM card identifiers.
///
/// Validation requires 19 or 20 digits starting with the telecom MII `89`.
/// When the ICCID is 20 digits, the last digit is a Luhn check digit;
/// 19-digit ICCIDs carry no check digit (see `doc/algorithms.md`).
class Iccid {
  Iccid._();

  static final RegExp _digits = RegExp(r'^[0-9]+$');

  /// Returns the digits-only form, discarding spaces and dashes.
  static String _strip(String input) => input.replaceAll(RegExp(r'[\s-]'), '');

  /// Validates [input], returning a [Valid] with the compact digit-only
  /// normalized form or an [Invalid] describing why it was rejected.
  static ValidationResult validate(String input) {
    final s = _strip(input);
    if (s.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.iccidEmpty, 'ICCID is empty.')]);
    }
    if (!_digits.hasMatch(s)) {
      return const Invalid([
        ValidationIssue(
            IssueCode.iccidBadChars, 'ICCID has invalid characters.')
      ]);
    }
    if ((s.length != 19 && s.length != 20) || !s.startsWith('89')) {
      return const Invalid([
        ValidationIssue(IssueCode.iccidBadLength,
            'ICCID must be 19 or 20 digits starting with 89.')
      ]);
    }
    if (s.length == 20 && !luhnOk(s)) {
      return const Invalid([
        ValidationIssue(
            IssueCode.iccidBadChecksum, 'Fails the Luhn checksum.')
      ]);
    }
    return Valid(s);
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input) => validate(input) is Valid;

  /// Returns the compact digit-only canonical form. Throws
  /// [FormatException] if [input] is not a valid ICCID.
  static String normalize(String input) => switch (validate(input)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };

  /// Returns the compact digit-only form. Throws [FormatException] if
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

  /// Parses [input] into an [IccidInfo], or null when it is not a valid
  /// ICCID.
  static IccidInfo? parse(String input) {
    final r = validate(input);
    if (r is! Valid) return null;
    final s = r.normalized;
    final hasCheckDigit = s.length == 20;
    final checkDigit = hasCheckDigit ? s.substring(s.length - 1) : null;
    final afterMii = s.substring(2, hasCheckDigit ? s.length - 1 : s.length);

    Country? country;
    var countryCodeLength = 0;
    for (final k in [3, 2, 1]) {
      if (afterMii.length < k) continue;
      final candidate = afterMii.substring(0, k);
      final resolved = Country.fromCallingCode(candidate);
      if (resolved != null) {
        country = resolved;
        countryCodeLength = k;
        break;
      }
    }

    return IccidInfo(
      mii: s.substring(0, 2),
      country: country,
      issuerIdentifier: afterMii.substring(countryCodeLength),
      checkDigit: checkDigit,
    );
  }
}
