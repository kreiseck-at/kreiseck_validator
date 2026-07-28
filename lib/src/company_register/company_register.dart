import '../common/field_descriptor.dart';
import '../common/issue_code.dart';
import '../common/validation_result.dart';
import 'company_register_info.dart';

/// Validation, normalization, formatting and parsing of company-register
/// numbers.
///
/// Austria only in this release. [country] is required so other countries can
/// be added without a breaking rename.
///
/// The Austrian Firmenbuchnummer is up to six digits plus one check letter,
/// written `FN 123456a`. The check letter is computed from the digits
/// **zero-padded to six**, weighted 6, 4, 14, 15, 10, 1 from the left, summed
/// modulo 17, and indexed into a 17-letter table that omits the confusable
/// `C`, `E`, `J`, `L`, `N`, `O`, `Q`, `R` and `U`. That table is itself a
/// validation rule: a `c` can never be a valid check letter.
///
/// Two pieces of folklore about this number are wrong, and both are refuted by
/// the verification data in `doc/algorithms.md`:
///
/// - It is **not** `number mod 26`. That rule reproduces one of twelve real
///   numbers, by coincidence.
/// - The letter does **not** encode the legal form. Seven verified GmbHs carry
///   seven different letters.
///
/// This is also the one type whose [normalize] does not upper-case: the
/// canonical written form keeps the check letter lower-case. The `FN` prefix is
/// presentation — accepted on input, not stored.
class CompanyRegister {
  CompanyRegister._();

  static const String _table = 'ABDFGHIKMPSTVWXYZ';
  static const List<int> _weights = [6, 4, 14, 15, 10, 1];

  static final RegExp _shape = RegExp(r'^([0-9]{1,6})([A-Za-z])$');
  /// Strips a leading `FN` (either case, with any following dots or spaces)
  /// and every remaining space. The prefix is presentation, not data.
  static final RegExp _strip = RegExp(r'^\s*[Ff][Nn][\s.]*|\s');
  static final RegExp _disallowed = RegExp('[^0-9A-Za-z]');

  /// The expected check letter, lower-case, for the digit string [digits]
  /// (1-6 digits, not padded — this pads internally).
  static String checkChar(String digits) {
    final padded = digits.padLeft(6, '0');
    var sum = 0;
    for (var i = 0; i < 6; i++) {
      sum += (padded.codeUnitAt(i) - 0x30) * _weights[i];
    }
    return _table[sum % 17].toLowerCase();
  }

  /// Validates [input] for [country], returning [Valid] with the digits plus
  /// the lower-case check letter and no `FN` prefix.
  static ValidationResult validate(String input, {required String country}) {
    if (country.toUpperCase() != 'AT') {
      return const Invalid([
        ValidationIssue(IssueCode.companyRegisterUnknownCountry,
            'No company-register rules for this country.')
      ]);
    }
    final compact = input.toUpperCase().replaceAll(_strip, '');
    if (compact.isEmpty) {
      return const Invalid([
        ValidationIssue(IssueCode.companyRegisterEmpty,
            'Company-register number is empty.')
      ]);
    }
    final m = _shape.firstMatch(compact);
    if (m == null) {
      return const Invalid([
        ValidationIssue(IssueCode.companyRegisterBadFormat,
            'Company-register number must be up to 6 digits and one letter.')
      ]);
    }
    final digits = m.group(1)!;
    final letter = m.group(2)!.toLowerCase();
    if (!_table.toLowerCase().contains(letter)) {
      return const Invalid([
        ValidationIssue(IssueCode.companyRegisterBadFormat,
            'That letter is never used as a check letter.')
      ]);
    }
    if (checkChar(digits) != letter) {
      return const Invalid([
        ValidationIssue(IssueCode.companyRegisterBadChecksum,
            'Company-register check letter is wrong.')
      ]);
    }
    return Valid('$digits$letter');
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input, {required String country}) =>
      validate(input, country: country) is Valid;

  /// Returns the digits plus the lower-case check letter, without the `FN`
  /// prefix. Throws [FormatException] if [input] is not valid for [country].
  static String normalize(String input, {required String country}) =>
      switch (validate(input, country: country)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };

  /// Returns the conventional `FN 123456a` form. Throws [FormatException] if
  /// invalid.
  static String format(String input, {required String country}) =>
      'FN ${normalize(input, country: country)}';

  /// Like [format] but returns null instead of throwing on invalid input.
  static String? tryFormat(String input, {required String country}) {
    try {
      return format(input, country: country);
    } on FormatException {
      return null;
    }
  }

  /// Parses [input] into a [CompanyRegisterInfo], or null when it is not valid
  /// for [country].
  static CompanyRegisterInfo? parse(String input, {required String country}) {
    final r = validate(input, country: country);
    if (r is! Valid) return null;
    final n = r.normalized;
    return CompanyRegisterInfo(
      number: n.substring(0, n.length - 1),
      checkChar: n[n.length - 1],
    );
  }

  /// Describes a company-register input field.
  ///
  /// [Capitalization.none], unlike every other alphanumeric identifier here:
  /// the canonical form keeps the check letter lower-case, so upper-casing at
  /// the keyboard would fight [normalize]. [maxLength] is 7 — the identifier
  /// without the presentational `FN`.
  static FieldDescriptor fieldDescriptor({String? country}) {
    if (country == null || country.toUpperCase() != 'AT') {
      return const FieldDescriptor(
        keyboard: KeyboardType.text,
        allowedChars: '0-9A-Za-z',
      );
    }
    return const FieldDescriptor(
      keyboard: KeyboardType.text,
      maxLength: 7,
      example: '415772f',
      allowedChars: '0-9A-Za-z',
    );
  }

  /// Formats partially typed [input]: the `FN` prefix and anything outside
  /// digits and letters dropped, capped at seven characters, a trailing letter
  /// lower-cased. Never throws.
  static String formatPartial(String input, {String? country}) {
    var s = input.replaceAll(_strip, '').replaceAll(_disallowed, '');
    if (s.length > 7) s = s.substring(0, 7);
    if (s.isEmpty) return s;
    final head = s.substring(0, s.length - 1);
    final last = s.substring(s.length - 1);
    return '${head.replaceAll(RegExp('[^0-9]'), '')}${last.toLowerCase()}';
  }
}
