import '../common/field_descriptor.dart';
import '../common/issue_code.dart';
import '../common/partial_format.dart';
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
    if (hostToken.startsWith('[')) {
      final j = hostToken.indexOf(']');
      return (j == -1 ? hostToken : hostToken.substring(0, j + 1)).toLowerCase();
    }
    final i = hostToken.indexOf(':');
    return (i == -1 ? hostToken : hostToken.substring(0, i)).toLowerCase();
  }

  static final RegExp _whitespace = RegExp(r'[\s\x00-\x1f\x7f]');
  static final RegExp _ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');

  /// True for hosts that are never reachable from the public internet:
  /// `localhost`, `*.localhost`, IPv6 literals and IPv4 loopback/private/
  /// link-local ranges. Used by the strict options ([allowLocalhost] false).
  static bool _isNonPublicHost(String host) {
    if (host == 'localhost' || host.endsWith('.localhost')) return true;
    if (host.startsWith('[')) return true; // IPv6 literal, never public here
    if (!_ipv4.hasMatch(host)) return false;
    final o = host.split('.').map(int.parse).toList();
    if (o.any((n) => n > 255)) return false;
    return o[0] == 127 ||
        o[0] == 10 ||
        o[0] == 0 ||
        (o[0] == 172 && o[1] >= 16 && o[1] <= 31) ||
        (o[0] == 192 && o[1] == 168) ||
        (o[0] == 169 && o[1] == 254);
  }

  /// Validates [input], returning [Valid] with the [normalize] form.
  ///
  /// The defaults keep the lenient behaviour (scheme optional, `http` and
  /// `https` both fine). The strict options are meant for addresses a machine
  /// will call, e.g. webhooks — see [webhook]:
  ///
  /// * [requireProtocol] — a missing `scheme://` is [IssueCode.urlProtocolMissing].
  /// * [protocols] — schemes outside the list are [IssueCode.urlProtocolNotAllowed].
  /// * [allowCredentials] — `user:pass@` before the host is
  ///   [IssueCode.urlCredentials] when false (and [IssueCode.urlBadHost] when true,
  ///   as before).
  /// * [allowLocalhost] — `localhost`, IP literals and private ranges are
  ///   [IssueCode.urlHostNotPublic] when false.
  static ValidationResult validate(
    String input, {
    String defaultScheme = 'https',
    bool requireProtocol = false,
    List<String>? protocols,
    bool allowCredentials = true,
    bool allowLocalhost = true,
  }) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.urlEmpty, 'URL is empty.')]);
    }
    if (_whitespace.hasMatch(trimmed)) {
      return const Invalid([
        ValidationIssue(IssueCode.urlWhitespace, 'URL contains whitespace.')
      ]);
    }
    final (scheme, hostToken, _) = _parts(trimmed);
    if (scheme == null && requireProtocol) {
      return const Invalid([
        ValidationIssue(
            IssueCode.urlProtocolMissing, 'Protocol (https://) is missing.')
      ]);
    }
    if (scheme != null && scheme != 'http' && scheme != 'https') {
      return const Invalid([
        ValidationIssue(IssueCode.urlBadScheme, 'Only http/https allowed.')
      ]);
    }
    if (scheme != null && protocols != null && !protocols.contains(scheme)) {
      return Invalid([
        ValidationIssue(IssueCode.urlProtocolNotAllowed,
            'Only ${protocols.join('/')} allowed.')
      ]);
    }
    if (!allowCredentials && hostToken.contains('@')) {
      return const Invalid([
        ValidationIssue(
            IssueCode.urlCredentials, 'Credentials in the URL are not allowed.')
      ]);
    }
    final host = _hostname(hostToken);
    if (!allowLocalhost && _isNonPublicHost(host)) {
      return const Invalid([
        ValidationIssue(IssueCode.urlHostNotPublic,
            'Host is not reachable from the public internet.')
      ]);
    }
    if (!_host.hasMatch(host)) {
      return const Invalid(
          [ValidationIssue(IssueCode.urlBadHost, 'Invalid host.')]);
    }
    return Valid(normalize(trimmed, defaultScheme: defaultScheme));
  }

  /// Strict check for addresses a server will call: `https://` required, no
  /// other scheme, no credentials, no localhost/private hosts.
  static ValidationResult webhook(String input) => validate(
        input,
        requireProtocol: true,
        protocols: const ['https'],
        allowCredentials: false,
        allowLocalhost: false,
      );

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

  /// Describes a URL input field.
  static FieldDescriptor fieldDescriptor() => const FieldDescriptor(
        keyboard: KeyboardType.url,
        autofill: AutofillHint.url,
        example: 'https://example.com',
      );

  /// Returns [input] unchanged. Unlike [format] — which is a display form
  /// that strips the scheme and `www.` — nothing may be removed while the
  /// user is still typing. Never throws.
  static String formatPartial(String input) =>
      prepare(input, fieldDescriptor());
}
