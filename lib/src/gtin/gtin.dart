import '../common/field_descriptor.dart';
import '../common/issue_code.dart';
import '../common/partial_format.dart';
import '../common/validation_result.dart';
import 'gtin_info.dart';

/// Validation, normalization, formatting and parsing of GS1 Global Trade Item
/// Numbers: GTIN-8, GTIN-12 (UPC-A), GTIN-13 (EAN-13) and GTIN-14 (ITF-14).
///
/// The last digit is the GS1 mod-10 check digit: digits are weighted 3 and 1
/// alternately from the right, and the check digit completes the sum to a
/// multiple of ten.
///
/// [normalize] keeps the entered length rather than padding to 14 — an EAN-8
/// and a zero-padded EAN-13 print as different barcodes. [GtinInfo.gtin14]
/// exposes the padded form for storage and comparison.
///
/// No GS1 prefix or country is exposed. A GS1 prefix identifies the member
/// organisation that issued the number, not the origin of the goods, and every
/// API that surfaces it ends up being read as country-of-origin.
class Gtin {
  Gtin._();

  static const List<int> _lengths = [8, 12, 13, 14];
  static final RegExp _digitsOnly = RegExp(r'^[0-9]+$');
  static final RegExp _separators = RegExp(r'[\s-]');

  /// The GS1 mod-10 check digit for [body] — a GTIN without its final digit.
  ///
  /// Useful for completing a partial scan; [body] is assumed to be digits only.
  static String checkDigit(String body) {
    var sum = 0;
    var weight = 3;
    for (var i = body.length - 1; i >= 0; i--) {
      sum += (body.codeUnitAt(i) - 0x30) * weight;
      weight = weight == 3 ? 1 : 3;
    }
    return ((10 - sum % 10) % 10).toString();
  }

  /// Validates [input], returning [Valid] with the separator-free digits.
  static ValidationResult validate(String input) {
    final compact = input.replaceAll(_separators, '');
    if (compact.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.gtinEmpty, 'GTIN is empty.')]);
    }
    if (!_digitsOnly.hasMatch(compact)) {
      return const Invalid([
        ValidationIssue(IssueCode.gtinBadChars, 'GTIN must be digits only.')
      ]);
    }
    if (!_lengths.contains(compact.length)) {
      return const Invalid([
        ValidationIssue(IssueCode.gtinBadLength,
            'GTIN must be 8, 12, 13 or 14 digits.')
      ]);
    }
    if (checkDigit(compact.substring(0, compact.length - 1)) !=
        compact[compact.length - 1]) {
      return const Invalid([
        ValidationIssue(
            IssueCode.gtinBadChecksum, 'GTIN check digit is wrong.')
      ]);
    }
    return Valid(compact);
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input) => validate(input) is Valid;

  /// Returns the separator-free digits. Throws [FormatException] if [input] is
  /// not a valid GTIN.
  static String normalize(String input) => switch (validate(input)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };

  /// Returns the digits as entered, without separators. Throws
  /// [FormatException] if invalid.
  static String format(String input) => normalize(input);

  /// Like [format] but returns null instead of throwing on invalid input.
  static String? tryFormat(String input) {
    try {
      return format(input);
    } on FormatException {
      return null;
    }
  }

  /// Parses [input] into a [GtinInfo], or null when it is not a valid GTIN.
  static GtinInfo? parse(String input) {
    final r = validate(input);
    if (r is! Valid) return null;
    final n = r.normalized;
    return GtinInfo(
      length: n.length,
      checkDigit: n[n.length - 1],
      gtin14: n.padLeft(14, '0'),
    );
  }

  /// Describes a GTIN input field.
  static FieldDescriptor fieldDescriptor() => const FieldDescriptor(
        keyboard: KeyboardType.digits,
        maxLength: 14,
        example: '4006381333931',
        allowedChars: '0-9',
      );

  /// Formats partially typed [input]: non-digits dropped, capped at 14. A GTIN
  /// is printed as one run, so there is no grouping step. Never throws.
  static String formatPartial(String input) =>
      prepare(input, fieldDescriptor(), maxSignificant: 14);
}
