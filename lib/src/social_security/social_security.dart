import '../common/field_descriptor.dart';
import '../common/issue_code.dart';
import '../common/partial_format.dart';
import '../common/validation_result.dart';
import 'social_security_info.dart';

/// Validation, normalization, formatting and parsing of social-security
/// numbers.
///
/// Austria only in this release. [country] is required so other countries can
/// be added without a breaking rename.
///
/// The Austrian Versicherungsnummer is ten digits, written `NNNP TTMMJJ`: a
/// three-digit serial, a check digit, then the date of birth. The serial runs
/// from 100 to 999 — it never starts with a zero, and `0000TTMMJJ` is the
/// placeholder written on forms to mean the number is unknown, so a leading
/// zero is rejected. The nine non-check digits are weighted 3, 7, 9, 5, 8, 4,
/// 2, 1, 6 from the left and the sum taken modulo 11. A remainder of 10 is
/// never issued — the serial is skipped instead — so such a number is
/// rejected rather than treated as an edge case.
///
/// **Validation never looks at the date.** Fictitious dates are issued on
/// purpose: when every serial for a real date is used up, months 13, 14 and 15
/// are handed out, and someone whose birthday is unknown gets 1 January or
/// 1 July of their birth year. Rejecting those would reject real people. The
/// date plays no part in validity, and [SocialSecurityInfo.birthDate] is null
/// whenever the digits do not form a real calendar date.
class SocialSecurityNumber {
  SocialSecurityNumber._();

  /// Position 4 (index 3) is the check digit itself and carries weight 0.
  static const List<int> _weights = [3, 7, 9, 0, 5, 8, 4, 2, 1, 6];

  static final RegExp _separators = RegExp(r'[\s/-]');
  static final RegExp _digitsOnly = RegExp(r'^[0-9]+$');

  /// February is 29 here on purpose: the number carries no century, so whether
  /// a given two-digit year was a leap year is unknowable. 29 February is
  /// therefore treated as a real date rather than guessed at.
  static const List<int> _daysInMonth = [
    31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
  ];

  /// Validates [input] for [country], returning [Valid] with the ten bare
  /// digits.
  static ValidationResult validate(String input, {required String country}) {
    if (country.toUpperCase() != 'AT') {
      return const Invalid([
        ValidationIssue(IssueCode.ssnUnknownCountry,
            'No social-security-number rules for this country.')
      ]);
    }
    final compact = input.replaceAll(_separators, '');
    if (compact.isEmpty) {
      return const Invalid([
        ValidationIssue(
            IssueCode.ssnEmpty, 'Social-security number is empty.')
      ]);
    }
    if (!_digitsOnly.hasMatch(compact)) {
      return const Invalid([
        ValidationIssue(IssueCode.ssnBadChars,
            'Social-security number must be digits only.')
      ]);
    }
    if (compact.length != 10) {
      return const Invalid([
        ValidationIssue(IssueCode.ssnBadLength,
            'Social-security number must be 10 digits.')
      ]);
    }
    if (compact.codeUnitAt(0) == 0x30) {
      return const Invalid([
        ValidationIssue(IssueCode.ssnBadSerial,
            'Social-security number serial must be 100-999.')
      ]);
    }
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      sum += (compact.codeUnitAt(i) - 0x30) * _weights[i];
    }
    final remainder = sum % 11;
    if (remainder == 10 || remainder != compact.codeUnitAt(3) - 0x30) {
      return const Invalid([
        ValidationIssue(IssueCode.ssnBadChecksum,
            'Social-security number check digit is wrong.')
      ]);
    }
    return Valid(compact);
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input, {required String country}) =>
      validate(input, country: country) is Valid;

  /// Returns the ten bare digits. Throws [FormatException] if [input] is not a
  /// valid social-security number for [country].
  static String normalize(String input, {required String country}) =>
      switch (validate(input, country: country)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };

  /// Returns the conventional `NNNP TTMMJJ` form. Throws [FormatException] if
  /// invalid.
  static String format(String input, {required String country}) {
    final n = normalize(input, country: country);
    return '${n.substring(0, 4)} ${n.substring(4)}';
  }

  /// Like [format] but returns null instead of throwing on invalid input.
  static String? tryFormat(String input, {required String country}) {
    try {
      return format(input, country: country);
    } on FormatException {
      return null;
    }
  }

  /// Parses [input] into a [SocialSecurityInfo], or null when it is not valid
  /// for [country].
  static SocialSecurityInfo? parse(String input, {required String country}) {
    final r = validate(input, country: country);
    if (r is! Valid) return null;
    final n = r.normalized;
    final day = int.parse(n.substring(4, 6));
    final month = int.parse(n.substring(6, 8));
    final real = month >= 1 &&
        month <= 12 &&
        day >= 1 &&
        day <= _daysInMonth[month - 1];
    return SocialSecurityInfo(
      serial: n.substring(0, 3),
      checkDigit: n[3],
      birthDate: real
          ? SsnBirthDate(
              day: day,
              month: month,
              twoDigitYear: int.parse(n.substring(8, 10)),
            )
          : null,
    );
  }

  /// Describes a social-security-number input field. [maxLength] is the length
  /// of the formatted text, the separating space included.
  static FieldDescriptor fieldDescriptor({String? country}) {
    if (country == null || country.toUpperCase() != 'AT') {
      return const FieldDescriptor(
        keyboard: KeyboardType.digits,
        allowedChars: '0-9 ',
      );
    }
    return const FieldDescriptor(
      keyboard: KeyboardType.digits,
      maxLength: 11,
      example: '1238 010190',
      allowedChars: '0-9 ',
    );
  }

  /// Formats partially typed [input]: non-digits dropped, the separating space
  /// inserted once four digits exist, capped at ten digits. Never throws.
  static String formatPartial(String input, {String? country}) {
    final s = prepare(input, fieldDescriptor(country: country),
        separators: ' ', maxSignificant: 10);
    if (country == null || country.toUpperCase() != 'AT') return s;
    if (s.length <= 4) return s;
    return '${s.substring(0, 4)} ${s.substring(4)}';
  }
}
