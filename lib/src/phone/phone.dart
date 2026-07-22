import '../common/country.dart';
import '../common/issue_code.dart';
import '../common/validation_result.dart';
import 'at_numbering.dart';
import 'phone_format.dart';
import 'phone_info.dart';
import 'phone_number_type.dart';

/// Validation, normalization (to E.164) and formatting of phone numbers for
/// every country, using libphonenumber-derived metadata. See `doc/algorithms.md`.
class Phone {
  Phone._();

  static final RegExp _allowedChars = RegExp(r'^\+?[0-9\s\-/().]+$');

  static String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  static bool _matchesPattern(Country c, String nsn) =>
      RegExp('^(?:${c.pattern})\$').hasMatch(nsn);

  static bool _lengthOk(Country c, String nsn) =>
      c.possibleLengths.isEmpty || c.possibleLengths.contains(nsn.length);

  /// Resolves the (country, nationalSignificantNumber) for [input].
  /// Returns null country when it cannot be determined.
  static (Country?, String) _resolve(String trimmed, Country? hint) {
    if (trimmed.startsWith('+')) {
      final d = _digits(trimmed);
      // Longest matching calling code (1-3 digits).
      for (final len in const [3, 2, 1]) {
        if (d.length <= len) continue;
        final cc = d.substring(0, len);
        final candidates =
            Country.values.where((c) => c.callingCode == cc).toList();
        if (candidates.isEmpty) continue;
        final nsn = d.substring(len);
        // Among candidates sharing a calling code, prefer the main region
        // (e.g. US for +1) so an ambiguous number is not attributed to an
        // alphabetically-earlier co-tenant (e.g. CA).
        final main = Country.fromCallingCode(cc);
        final ordered = <Country>[
          if (main != null && candidates.contains(main)) main,
          for (final c in candidates)
            if (!identical(c, main)) c,
        ];
        for (final c in ordered) {
          if (_lengthOk(c, nsn) && _matchesPattern(c, nsn)) return (c, nsn);
        }
        // Tolerate an accidentally-included trunk "0" from the international
        // "(0)" display convention, e.g. "+43 (0) 660 ...". Only a single
        // leading zero is stripped, and only when the raw number matched no
        // candidate, so strict validation is preserved for real numbers.
        if (nsn.startsWith('0')) {
          final stripped = nsn.substring(1);
          for (final c in ordered) {
            if (_lengthOk(c, stripped) && _matchesPattern(c, stripped)) {
              return (c, stripped);
            }
          }
        }
        // No candidate validates: return the main region (or first) with the
        // raw nsn so the caller can report the specific length/pattern error.
        return (main ?? candidates.first, nsn);
      }
      return (null, '');
    }
    // National input: needs a country hint; strip the trunk prefix.
    if (hint == null) return (null, '');
    var d = _digits(trimmed);
    final np = hint.nationalPrefix;
    if (np != null && d.startsWith(np)) d = d.substring(np.length);
    return (hint, d);
  }

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

    final (resolved, nsn) = _resolve(trimmed, country);
    if (resolved == null) {
      final code = trimmed.startsWith('+')
          ? IssueCode.phoneUnknownCountry
          : IssueCode.phoneAmbiguousCountry;
      final msg =
          trimmed.startsWith('+') ? 'Unknown country.' : 'Country required.';
      return Invalid([ValidationIssue(code, msg)]);
    }

    final lengths = resolved.possibleLengths;
    if (lengths.isNotEmpty) {
      final min = lengths.first;
      final max = lengths.last;
      if (nsn.length < min) {
        return const Invalid(
            [ValidationIssue(IssueCode.phoneTooShort, 'Too short.')]);
      }
      if (nsn.length > max) {
        return const Invalid(
            [ValidationIssue(IssueCode.phoneTooLong, 'Too long.')]);
      }
    }
    if (!_matchesPattern(resolved, nsn)) {
      return const Invalid(
          [ValidationIssue(IssueCode.phoneInvalid, 'Not a valid number.')]);
    }
    return Valid('+${resolved.callingCode}$nsn');
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

  /// Splits a normalized E.164 string into (country, nationalNumber),
  /// reusing the same calling-code resolution (and main-region preference)
  /// as [validate].
  static (Country, String) _ccCountry(String e164) {
    final (c, nsn) = _resolve(e164, null);
    if (c == null) {
      // Should not happen for an already-validated E.164.
      throw const FormatException('Unresolvable calling code.');
    }
    return (c, nsn);
  }

  /// Formats [input] internationally (`+43 1 234567`) or nationally
  /// (`01 234567`) when [international] is false. Throws [FormatException].
  static String format(String input,
      {Country? country, bool international = true}) {
    final e164 = normalize(input, country: country);
    final (c, nsn) = _ccCountry(e164);
    final grouped = formatNsn(c.formats, nsn,
        international: international, nationalPrefix: c.nationalPrefix);
    if (grouped == null) {
      // Fallback: E.164 for international, prefixed digits for national.
      return international
          ? '+${c.callingCode} $nsn'
          : '${c.nationalPrefix ?? ''}$nsn';
    }
    return international ? '+${c.callingCode} $grouped' : grouped;
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

  /// Classifies [input] by number type. Returns [PhoneNumberType.unknown] for
  /// invalid input or countries without classification data (all but AT).
  static PhoneNumberType type(String input, {Country? country}) {
    final result = validate(input, country: country);
    if (result is! Valid) return PhoneNumberType.unknown;
    final (c, nsn) = _ccCountry(result.normalized);
    if (c.iso2 != 'AT') return PhoneNumberType.unknown;
    return AtNumbering.classify(nsn).type;
  }

  /// Parses [input] into a [PhoneInfo] bundle, or null if invalid.
  static PhoneInfo? parse(String input, {Country? country}) {
    final result = validate(input, country: country);
    if (result is! Valid) return null;
    final e164 = result.normalized;
    final (c, nsn) = _ccCountry(e164);
    final numberType =
        c.iso2 == 'AT' ? AtNumbering.classify(nsn).type : PhoneNumberType.unknown;
    return PhoneInfo(
      e164: e164,
      country: c,
      type: numberType,
      national: format(input, country: country, international: false),
      international: format(input, country: country, international: true),
    );
  }
}
