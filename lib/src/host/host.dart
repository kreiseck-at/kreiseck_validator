import '../common/issue_code.dart';
import '../common/validation_result.dart';
import 'host_info.dart';

/// Validation, normalization and formatting of a bare host: a hostname
/// (RFC 1123), an IPv4 address or an IPv6 address, with an optional port
/// (see `doc/algorithms.md`).
///
/// This is more lenient than [Url]: it accepts `localhost`, single-label
/// hostnames and IP literals, and does not require a scheme.
class Host {
  Host._();

  static final RegExp _ipv4 = RegExp(
      r'^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$');
  static final RegExp _hexGroup = RegExp(r'^[0-9a-f]{1,4}$');
  static final RegExp _label =
      RegExp(r'^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$');
  static final RegExp _digits = RegExp(r'^[0-9]+$');

  static bool _isHostname(String h) {
    if (h.isEmpty || h.length > 253) return false;
    final labels = h.split('.');
    for (final l in labels) {
      if (!_label.hasMatch(l)) return false;
    }
    return true;
  }

  static bool _isIpv6(String h) {
    if (h.isEmpty) return false;
    final parts = h.split('::');
    if (parts.length > 2) return false;
    final hasDouble = parts.length == 2;
    List<String> groups;
    if (hasDouble) {
      final left = parts[0];
      final right = parts[1];
      final leftGroups = left.isEmpty ? <String>[] : left.split(':');
      final rightGroups = right.isEmpty ? <String>[] : right.split(':');
      if (leftGroups.any((g) => g.isEmpty) ||
          rightGroups.any((g) => g.isEmpty)) {
        return false;
      }
      groups = [...leftGroups, ...rightGroups];
    } else {
      groups = h.split(':');
      if (groups.any((g) => g.isEmpty)) return false;
    }
    var count = 0;
    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      final isLast = i == groups.length - 1;
      if (g.contains('.')) {
        if (!isLast || !_ipv4.hasMatch(g)) return false;
        count += 2;
      } else {
        if (!_hexGroup.hasMatch(g)) return false;
        count += 1;
      }
    }
    return hasDouble ? count <= 7 : count == 8;
  }

  /// Classifies [hostPart] (already lower-cased) as `'ipv4'`, `'ipv6'` or
  /// `'hostname'`, or returns null when it matches none.
  static String? _classify(String hostPart) {
    if (_ipv4.hasMatch(hostPart)) return 'ipv4';
    if (_isIpv6(hostPart)) return 'ipv6';
    if (_isHostname(hostPart)) return 'hostname';
    return null;
  }

  /// Parses a decimal port string into `0..65535`, or null when it is not
  /// a valid port.
  static int? _port(String digits) {
    if (digits.isEmpty || !_digits.hasMatch(digits)) return null;
    if (digits.length > 15) return -1; // unmistakably out of range
    final n = int.parse(digits);
    return n <= 65535 ? n : -1;
  }

  static String _normalized(String host, String type, int? port) {
    final base = type == 'ipv6' && port != null ? '[$host]' : host;
    return port == null ? base : '$base:$port';
  }

  /// Splits the port off [lower] (already trimmed and lower-cased) and
  /// classifies the remaining host part, returning either a rejection
  /// [ValidationIssue] or the accepted `(host, type, port, normalized)`.
  static (ValidationIssue?, (String, String, int?, String)?) _analyze(
      String lower) {
    String hostPart;
    int? port;

    if (lower.startsWith('[')) {
      final close = lower.indexOf(']');
      if (close == -1) {
        return (
          const ValidationIssue(
              IssueCode.hostBadFormat, 'Missing closing bracket.'),
          null
        );
      }
      hostPart = lower.substring(1, close);
      final after = lower.substring(close + 1);
      if (after.isEmpty) {
        port = null;
      } else if (after.startsWith(':')) {
        final digits = after.substring(1);
        if (digits.isEmpty || !_digits.hasMatch(digits)) {
          return (
            const ValidationIssue(
                IssueCode.hostBadFormat, 'Invalid port after host.'),
            null
          );
        }
        final p = _port(digits);
        if (p == null || p < 0) {
          return (
            const ValidationIssue(
                IssueCode.hostBadPort, 'Port must be 0-65535.'),
            null
          );
        }
        port = p;
      } else {
        return (
          const ValidationIssue(
              IssueCode.hostBadFormat, 'Unexpected characters after host.'),
          null
        );
      }
    } else {
      final colonCount = lower.split(':').length - 1;
      if (colonCount == 1) {
        final idx = lower.indexOf(':');
        final after = lower.substring(idx + 1);
        if (after.isNotEmpty && _digits.hasMatch(after)) {
          hostPart = lower.substring(0, idx);
          final p = _port(after);
          if (p == null || p < 0) {
            return (
              const ValidationIssue(
                  IssueCode.hostBadPort, 'Port must be 0-65535.'),
              null
            );
          }
          port = p;
        } else {
          hostPart = lower;
          port = null;
        }
      } else {
        hostPart = lower;
        port = null;
      }
    }

    if (hostPart.isEmpty) {
      return (
        const ValidationIssue(IssueCode.hostEmpty, 'Host is empty.'),
        null
      );
    }

    final type = _classify(hostPart);
    if (type == null) {
      return (
        const ValidationIssue(
            IssueCode.hostBadFormat, 'Host has an invalid format.'),
        null
      );
    }

    return (null, (hostPart, type, port, _normalized(hostPart, type, port)));
  }

  /// Validates [input], returning a [Valid] with the [normalize] form or an
  /// [Invalid] describing why it was rejected.
  static ValidationResult validate(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.hostEmpty, 'Host is empty.')]);
    }
    final (issue, result) = _analyze(trimmed.toLowerCase());
    if (issue != null) return Invalid([issue]);
    return Valid(result!.$4);
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input) => validate(input) is Valid;

  /// Returns the canonical form: lower-cased host, IPv6 re-bracketed when a
  /// port is present, port appended. Throws [FormatException] if [input] is
  /// not a valid host.
  static String normalize(String input) => switch (validate(input)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };

  /// Returns the canonical form. Throws [FormatException] if [input] is
  /// invalid.
  static String format(String input) => normalize(input);

  /// Like [format] but returns null instead of throwing on invalid input.
  static String? tryFormat(String input) {
    try {
      return format(input);
    } on FormatException {
      return null;
    }
  }

  /// Parses [input] into a [HostInfo], or null when it is not a valid host.
  static HostInfo? parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final (issue, result) = _analyze(trimmed.toLowerCase());
    if (issue != null) return null;
    final (host, type, port, _) = result!;
    final hostType = switch (type) {
      'ipv4' => HostType.ipv4,
      'ipv6' => HostType.ipv6,
      _ => HostType.hostname,
    };
    return HostInfo(
        host: host, type: hostType, port: port, hasPort: port != null);
  }
}
