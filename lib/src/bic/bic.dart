import '../common/country.dart';
import '../common/field_descriptor.dart';
import '../common/issue_code.dart';
import '../common/partial_format.dart';
import '../common/validation_result.dart';
import 'bic_info.dart';

/// Validation, normalization, formatting and parsing of Business Identifier
/// Codes (ISO 9362) — the codes commonly called SWIFT codes.
///
/// Structure: 4 letters institution, 2 letters ISO country, 2 alphanumerics
/// location, optionally 3 alphanumerics branch. The country segment is checked
/// against the bundled [Country] table, so a typo that lands on a non-country
/// is caught rather than accepted.
///
/// An `XXX` branch code is preserved rather than stripped: it is meaningful in
/// SEPA payloads. The location code's second character is parsed rather than
/// ignored — a test-and-training BIC in a production payment file is a silent
/// failure, so [BicInfo.kind] surfaces it.
///
/// No check digit exists: ISO 9362 has none. Everything here is structural.
class Bic {
  Bic._();

  static final RegExp _shape =
      RegExp(r'^[A-Z]{4}[A-Z]{2}[A-Z0-9]{2}([A-Z0-9]{3})?$');
  static final RegExp _space = RegExp(r'\s');
  static final RegExp _nonAlnum = RegExp('[^A-Z0-9]');

  /// Validates [input], returning [Valid] with the compact upper-case form or
  /// an [Invalid] describing why it was rejected.
  static ValidationResult validate(String input) {
    final upper = input.toUpperCase().replaceAll(_space, '');
    if (upper.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.bicEmpty, 'BIC is empty.')]);
    }
    if (upper.length != 8 && upper.length != 11) {
      return const Invalid([
        ValidationIssue(
            IssueCode.bicBadLength, 'BIC must be 8 or 11 characters.')
      ]);
    }
    if (!_shape.hasMatch(upper)) {
      return const Invalid([
        ValidationIssue(IssueCode.bicBadChars, 'BIC has invalid characters.')
      ]);
    }
    if (Country.fromIso2(upper.substring(4, 6)) == null) {
      return const Invalid([
        ValidationIssue(
            IssueCode.bicUnknownCountry, 'BIC has an unknown country code.')
      ]);
    }
    return Valid(upper);
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input) => validate(input) is Valid;

  /// Returns the compact upper-case form. Throws [FormatException] if [input]
  /// is not a valid BIC.
  static String normalize(String input) => switch (validate(input)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };

  /// Returns the 8- or 11-character form. Throws [FormatException] if invalid.
  static String format(String input) => normalize(input);

  /// Like [format] but returns null instead of throwing on invalid input.
  static String? tryFormat(String input) {
    try {
      return format(input);
    } on FormatException {
      return null;
    }
  }

  /// Parses [input] into a [BicInfo], or null when it is not a valid BIC.
  static BicInfo? parse(String input) {
    final r = validate(input);
    if (r is! Valid) return null;
    final b = r.normalized;
    return BicInfo(
      institution: b.substring(0, 4),
      country: b.substring(4, 6),
      location: b.substring(6, 8),
      branch: b.length == 11 ? b.substring(8, 11) : null,
      kind: switch (b[7]) {
        '0' => BicKind.test,
        '1' => BicKind.passive,
        '2' => BicKind.reverseBilling,
        _ => BicKind.live,
      },
    );
  }

  /// True when [bic] and [iban] agree on their country segment.
  ///
  /// Only the countries are compared — a BIC carries no account information —
  /// but a mismatch reliably means one of the two fields was pasted from the
  /// wrong account. Returns false when either value is unusable.
  static bool matchesIban(String bic, String iban) {
    final b = parse(bic);
    if (b == null) return false;
    final i = iban.toUpperCase().replaceAll(_nonAlnum, '');
    if (i.length < 2) return false;
    return b.country == i.substring(0, 2);
  }

  /// Describes a BIC input field.
  static FieldDescriptor fieldDescriptor() => const FieldDescriptor(
        keyboard: KeyboardType.text,
        capitalization: Capitalization.characters,
        maxLength: 11,
        example: 'BKAUATWW',
        allowedChars: '0-9A-Z',
      );

  /// Formats partially typed [input]: upper-cased, non-alphanumerics dropped,
  /// capped at 11. A BIC is written as one run, so there is no grouping step.
  /// Never throws.
  static String formatPartial(String input) =>
      prepare(input, fieldDescriptor(), maxSignificant: 11);
}
