import '../common/field_descriptor.dart';
import '../common/issue_code.dart';
import '../common/luhn.dart';
import '../common/partial_format.dart';
import '../common/validation_result.dart';
import 'tax_number_info.dart';

/// Validation, normalization, formatting and parsing of tax numbers.
///
/// Austria only in this release. [country] is required so other countries can
/// be added without a breaking rename — a bare tax number is meaningless
/// without knowing whose it is.
///
/// The Austrian Abgabenkontonummer is nine digits — a two-digit Finanzamt
/// number, six free digits and a check digit — conventionally written
/// `12-345/6789`.
///
/// The check is the Luhn algorithm over all nine digits. The official
/// description states it as
/// `S = F + Q(A) + N1 + Q(N2) + N3 + Q(N4) + N5 + Q(N6)` with `Q(z)` the digit
/// sum of `2z` and `P = (80 - S) mod 10`; that is Luhn written out, and the
/// documented example 98-123/4560 confirms it (S = 40, P = 0).
///
/// The Finanzamt number is reported by [parse] but never rejected — see
/// [TaxNumberInfo.office].
class TaxNumber {
  TaxNumber._();

  static final RegExp _separators = RegExp(r'[\s./-]');
  static final RegExp _digitsOnly = RegExp(r'^[0-9]+$');

  /// Validates [input] for [country], returning [Valid] with the nine bare
  /// digits.
  static ValidationResult validate(String input, {required String country}) {
    if (country.toUpperCase() != 'AT') {
      return const Invalid([
        ValidationIssue(IssueCode.taxNumberUnknownCountry,
            'No tax-number rules for this country.')
      ]);
    }
    final compact = input.replaceAll(_separators, '');
    if (compact.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.taxNumberEmpty, 'Tax number is empty.')]);
    }
    if (!_digitsOnly.hasMatch(compact)) {
      return const Invalid([
        ValidationIssue(
            IssueCode.taxNumberBadChars, 'Tax number must be digits only.')
      ]);
    }
    if (compact.length != 9) {
      return const Invalid([
        ValidationIssue(
            IssueCode.taxNumberBadLength, 'Tax number must be 9 digits.')
      ]);
    }
    if (!luhnOk(compact)) {
      return const Invalid([
        ValidationIssue(IssueCode.taxNumberBadChecksum,
            'Tax number check digit is wrong.')
      ]);
    }
    return Valid(compact);
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input, {required String country}) =>
      validate(input, country: country) is Valid;

  /// Returns the nine bare digits. Throws [FormatException] if [input] is not
  /// a valid tax number for [country].
  static String normalize(String input, {required String country}) =>
      switch (validate(input, country: country)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };

  /// Returns the conventional `12-345/6789` form. Throws [FormatException] if
  /// invalid.
  static String format(String input, {required String country}) {
    final n = normalize(input, country: country);
    return '${n.substring(0, 2)}-${n.substring(2, 5)}/${n.substring(5)}';
  }

  /// Like [format] but returns null instead of throwing on invalid input.
  static String? tryFormat(String input, {required String country}) {
    try {
      return format(input, country: country);
    } on FormatException {
      return null;
    }
  }

  /// Parses [input] into a [TaxNumberInfo], or null when it is not a valid tax
  /// number for [country].
  static TaxNumberInfo? parse(String input, {required String country}) {
    final r = validate(input, country: country);
    if (r is! Valid) return null;
    final n = r.normalized;
    return TaxNumberInfo(
      office: n.substring(0, 2),
      number: n.substring(2),
      checkDigit: n[8],
    );
  }

  /// Describes a tax-number input field. [maxLength] is the length of the
  /// formatted text, separators included.
  static FieldDescriptor fieldDescriptor({String? country}) {
    if (country == null || country.toUpperCase() != 'AT') {
      return const FieldDescriptor(
        keyboard: KeyboardType.digits,
        allowedChars: '0-9/-',
      );
    }
    return const FieldDescriptor(
      keyboard: KeyboardType.digits,
      maxLength: 11,
      example: '98-123/4560',
      allowedChars: '0-9/-',
    );
  }

  /// Formats partially typed [input]: non-digits dropped, the `-` and `/`
  /// re-inserted as soon as enough digits exist, capped at nine digits. Never
  /// throws.
  static String formatPartial(String input, {String? country}) {
    final s = prepare(input, fieldDescriptor(country: country),
        separators: '/-', maxSignificant: 9);
    if (country == null || country.toUpperCase() != 'AT') return s;
    if (s.length <= 2) return s;
    if (s.length <= 5) return '${s.substring(0, 2)}-${s.substring(2)}';
    return '${s.substring(0, 2)}-${s.substring(2, 5)}/${s.substring(5)}';
  }
}
