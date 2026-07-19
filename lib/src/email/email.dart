import '../common/issue_code.dart';
import '../common/validation_result.dart';

/// Validation, normalization and typo-hinting for email addresses.
///
/// Validation is pragmatic (one `@`, non-empty local part, dotted domain with
/// a plausible TLD) rather than full RFC 5322. Typo hinting is offline only.
class Email {
  Email._();

  static final RegExp _local = RegExp(r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+$");
  static final RegExp _domain =
      RegExp(r'^([a-z0-9](-?[a-z0-9])*\.)+[a-z]{2,}$');

  /// Popular domains used as targets for the typo heuristic.
  static const List<String> _knownDomains = [
    'gmail.com', 'googlemail.com', 'yahoo.com', 'hotmail.com',
    'outlook.com', 'icloud.com', 'gmx.net', 'web.de', 'live.com',
  ];

  /// Trims and lower-cases [input].
  static String normalize(String input) => input.trim().toLowerCase();

  /// Optimal string alignment (Damerau) distance between [a] and [b]. Unlike
  /// plain Levenshtein it counts an adjacent transposition (e.g. `gmial` vs
  /// `gmail`) as a single edit, which matches how people mistype domains.
  static int _distance(String a, String b) {
    final n = a.length;
    final m = b.length;
    final d = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = 0; i <= n; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= m; j++) {
      d[0][j] = j;
    }
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        var v = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost]
            .reduce((x, y) => x < y ? x : y);
        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
          final transposed = d[i - 2][j - 2] + 1;
          if (transposed < v) v = transposed;
        }
        d[i][j] = v;
      }
    }
    return d[n][m];
  }

  /// Returns a close known domain within edit distance 1, or null.
  static String? _closeDomain(String domain) {
    if (_knownDomains.contains(domain)) return null;
    for (final known in _knownDomains) {
      if (_distance(domain, known) == 1) return known;
    }
    return null;
  }

  /// Validates [input]. On success returns [Valid] (with a typo [Suggestion]
  /// when the domain is a near-miss of a popular provider).
  static ValidationResult validate(String input) {
    final s = normalize(input);
    if (s.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.emailEmpty, 'Email is empty.')]);
    }
    final at = '@'.allMatches(s).length;
    if (at == 0) {
      return const Invalid(
          [ValidationIssue(IssueCode.emailMissingAt, 'Missing @.')]);
    }
    if (at > 1) {
      return const Invalid(
          [ValidationIssue(IssueCode.emailMultipleAt, 'Multiple @.')]);
    }
    final i = s.indexOf('@');
    final local = s.substring(0, i);
    final domain = s.substring(i + 1);
    if (local.isEmpty || !_local.hasMatch(local)) {
      return const Invalid(
          [ValidationIssue(IssueCode.emailEmptyLocal, 'Bad local part.')]);
    }
    if (!_domain.hasMatch(domain)) {
      return const Invalid(
          [ValidationIssue(IssueCode.emailBadDomain, 'Bad domain.')]);
    }
    final close = _closeDomain(domain);
    return Valid(s,
        suggestions: close == null
            ? const []
            : [Suggestion('$local@$close', 'typo-domain')]);
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input) => validate(input) is Valid;
}
