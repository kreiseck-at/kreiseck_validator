import '../common/issue_code.dart';
import '../common/validation_result.dart';

/// Validation, normalization and display formatting of web URLs / domains.
///
/// This is a pragmatic plausibility check (scheme, host, TLD), not a full
/// URL grammar. Only `http` and `https` schemes are accepted.
class Url {
  Url._();

  static final RegExp _host =
      RegExp(r'^([a-z0-9](-?[a-z0-9])*\.)+[a-z]{2,}$');

  /// Splits [input] into (scheme, rest), defaulting scheme to null.
  static (String?, String) _split(String input) {
    final m = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.-]*)://(.*)$').firstMatch(input);
    if (m == null) return (null, input);
    return (m.group(1)!.toLowerCase(), m.group(2)!);
  }

  /// Validates [input], returning [Valid] with the [normalize] form.
  static ValidationResult validate(String input,
      {String defaultScheme = 'https'}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.urlEmpty, 'URL is empty.')]);
    }
    final (scheme, rest) = _split(trimmed);
    if (scheme != null && scheme != 'http' && scheme != 'https') {
      return const Invalid([
        ValidationIssue(IssueCode.urlBadScheme, 'Only http/https allowed.')
      ]);
    }
    final slash = rest.indexOf('/');
    final hostPart = (slash == -1 ? rest : rest.substring(0, slash));
    final host = hostPart.toLowerCase();
    if (!_host.hasMatch(host)) {
      return const Invalid(
          [ValidationIssue(IssueCode.urlBadHost, 'Invalid host.')]);
    }
    return Valid(normalize(trimmed, defaultScheme: defaultScheme));
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input) => validate(input) is Valid;

  /// Returns the canonical URL: lower-cased host, explicit scheme
  /// (default [defaultScheme]), no trailing slash on the path.
  static String normalize(String input, {String defaultScheme = 'https'}) {
    final trimmed = input.trim();
    final (scheme, rest) = _split(trimmed);
    final slash = rest.indexOf('/');
    final host = (slash == -1 ? rest : rest.substring(0, slash)).toLowerCase();
    var path = slash == -1 ? '' : rest.substring(slash);
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return '${scheme ?? defaultScheme}://$host$path';
  }

  /// Returns a compact display form: no scheme, no leading `www.`, no
  /// trailing slash. Throws [FormatException] if [input] is invalid.
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
