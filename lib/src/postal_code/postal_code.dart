import '../common/issue_code.dart';
import '../common/validation_result.dart';
import 'postal_info.dart';
import 'postal_pattern.dart';

part 'postal_metadata.g.dart';

/// Validation, normalization, formatting and parsing of postal codes for
/// European countries plus Turkey. See `doc/algorithms.md`.
///
/// The country is required: a bare postal code is ambiguous across
/// countries (e.g. plain 4-digit codes are valid in a dozen countries), so
/// every operation takes `country` (an ISO 3166-1 alpha-2 code). Countries
/// without a curated pattern in [kPostalPatterns] resolve to
/// [IssueCode.postalUnknownCountry].
class PostalCode {
  PostalCode._();

  static final RegExp _separators = RegExp(r'[\s-]');

  static final Map<String, RegExp> _compiled = {};

  static RegExp _regexFor(PostalPattern meta) =>
      _compiled.putIfAbsent(meta.pattern, () => RegExp(meta.pattern));

  static String _compact(String upper) => upper.replaceAll(_separators, '');

  /// Applies a country's canonical spacing rule (see [PostalPattern]) to
  /// its separator-free [compact] form.
  static String _canonicalize(String compact, String format) {
    if (format.isEmpty) return compact;
    if (format == 'U') {
      if (compact.length <= 3) return compact;
      final split = compact.length - 3;
      return '${compact.substring(0, split)} ${compact.substring(split)}';
    }
    final parts = format.split(':');
    final n = int.parse(parts[0]);
    final sep = parts[1];
    if (n >= compact.length) return compact;
    return '${compact.substring(0, n)}$sep${compact.substring(n)}';
  }

  /// Validates [input] against [country]'s pattern, returning [Valid] with
  /// the canonical (spacing-applied) form.
  static ValidationResult validate(String input, {required String country}) {
    final resolved = country.toUpperCase();
    final meta = kPostalPatterns[resolved];
    if (meta == null) {
      return const Invalid([
        ValidationIssue(IssueCode.postalUnknownCountry, 'Unknown country.')
      ]);
    }
    final trimmedUpper = input.trim().toUpperCase();
    if (trimmedUpper.isEmpty) {
      return const Invalid([
        ValidationIssue(IssueCode.postalEmpty, 'Postal code is empty.')
      ]);
    }
    final canonical = _canonicalize(_compact(trimmedUpper), meta.format);
    if (!_regexFor(meta).hasMatch(canonical)) {
      return const Invalid([
        ValidationIssue(
            IssueCode.postalBadFormat, 'Postal code has invalid format.')
      ]);
    }
    return Valid(canonical);
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input, {required String country}) =>
      validate(input, country: country) is Valid;

  /// Returns the canonical form. Throws [FormatException] if [input] is
  /// not a valid postal code for [country].
  static String normalize(String input, {required String country}) =>
      switch (validate(input, country: country)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };

  /// Returns the canonical form. Throws [FormatException] if invalid.
  static String format(String input, {required String country}) =>
      normalize(input, country: country);

  /// Like [format] but returns null instead of throwing on invalid input.
  static String? tryFormat(String input, {required String country}) {
    try {
      return format(input, country: country);
    } on FormatException {
      return null;
    }
  }

  /// Parses [input] into a [PostalInfo], or null when it is not a valid
  /// postal code for [country].
  static PostalInfo? parse(String input, {required String country}) {
    final r = validate(input, country: country);
    if (r is! Valid) return null;
    return PostalInfo(country: country.toUpperCase(), code: r.normalized);
  }
}
