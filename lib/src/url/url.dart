import '../common/issue_code.dart';
import '../common/validation_result.dart';

/// Validation, normalization and display formatting of web URLs / domains.
///
/// This is a pragmatic plausibility check (scheme, host, TLD), not a full
/// URL grammar. Only `http` and `https` schemes are accepted.
class Url {
  Url._();

  static final RegExp _scheme = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.-]*)://(.*)$');
  static final RegExp _host = RegExp(r'^([a-z0-9](-?[a-z0-9])*\.)+[a-z]{2,}$');

  /// Splits [input] into `(scheme, hostToken, tail)`, where `scheme` is
  /// lower-cased or null, `hostToken` may carry a `:port` suffix, and `tail`
  /// is the path/query/fragment beginning with its delimiter (or empty).
  static (String?, String, String) _parts(String input) {
    final m = _scheme.firstMatch(input);
    final scheme = m?.group(1)?.toLowerCase();
    final rest = m == null ? input : m.group(2)!;
    var cut = rest.length;
    for (final d in const ['/', '?', '#']) {
      final i = rest.indexOf(d);
      if (i != -1 && i < cut) cut = i;
    }
    return (scheme, rest.substring(0, cut), rest.substring(cut));
  }

  /// Returns the lower-cased hostname from a host token, dropping any `:port`.
  static String _hostname(String hostToken) {
    final i = hostToken.indexOf(':');
    return (i == -1 ? hostToken : hostToken.substring(0, i)).toLowerCase();
  }

  /// Validates [input], returning [Valid] with the [normalize] form.
  static ValidationResult validate(String input,
      {String defaultScheme = 'https'}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.urlEmpty, 'URL is empty.')]);
    }
    final (scheme, hostToken, _) = _parts(trimmed);
    if (scheme != null && scheme != 'http' && scheme != 'https') {
      return const Invalid([
        ValidationIssue(IssueCode.urlBadScheme, 'Only http/https allowed.')
      ]);
    }
    if (!_host.hasMatch(_hostname(hostToken))) {
      return const Invalid(
          [ValidationIssue(IssueCode.urlBadHost, 'Invalid host.')]);
    }
    return Valid(normalize(trimmed, defaultScheme: defaultScheme));
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input) => validate(input) is Valid;

  /// Returns the canonical URL: explicit scheme (default [defaultScheme]),
  /// lower-cased host (and port), path/query/fragment preserved, with a single
  /// trailing slash removed from a bare path.
  static String normalize(String input, {String defaultScheme = 'https'}) {
    final trimmed = input.trim();
    final (scheme, hostToken, tail) = _parts(trimmed);
    final host = hostToken.toLowerCase();
    var rest = tail;
    if (rest.length > 1 &&
        rest.endsWith('/') &&
        !rest.contains('?') &&
        !rest.contains('#')) {
      rest = rest.substring(0, rest.length - 1);
    }
    return '${scheme ?? defaultScheme}://$host$rest';
  }

  /// Returns a compact display form: no scheme, no leading `www.`, no trailing
  /// slash. Throws [FormatException] if [input] is invalid.
  static String format(String input) {
    switch (validate(input)) {
      case Invalid(:final issues):
        throw FormatException(issues.first.message);
      case Valid(:final normalized):
        var s = normalized.replaceFirst(RegExp(r'^https?://'), '');
        s = s.replaceFirst(RegExp(r'^www\.'), '');
        if (s.endsWith('/')) s = s.substring(0, s.length - 1);
        return s;
    }
  }

  /// Like [format] but returns null on invalid input.
  static String? tryFormat(String input) {
    try {
      return format(input);
    } on FormatException {
      return null;
    }
  }
}
