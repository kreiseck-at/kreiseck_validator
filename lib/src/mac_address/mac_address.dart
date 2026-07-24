import '../common/issue_code.dart';
import '../common/validation_result.dart';
import 'mac_info.dart';

/// Output notation for `MacAddress.format`.
enum MacNotation {
  /// `aa:bb:cc:dd:ee:ff`
  colon,

  /// `aa-bb-cc-dd-ee-ff`
  hyphen,

  /// `aabb.ccdd.eeff` (Cisco style, groups of 4 hex digits).
  dot,

  /// `aabbccddeeff`
  bare,
}

/// Validation, normalization and formatting of MAC hardware addresses
/// (IEEE EUI-48 and EUI-64), accepting colon, hyphen, Cisco-dot and bare
/// notations (see `doc/algorithms.md`).
class MacAddress {
  MacAddress._();

  static final RegExp _colon48 = RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$');
  static final RegExp _colon64 = RegExp(r'^([0-9A-Fa-f]{2}:){7}[0-9A-Fa-f]{2}$');
  static final RegExp _hyphen48 = RegExp(r'^([0-9A-Fa-f]{2}-){5}[0-9A-Fa-f]{2}$');
  static final RegExp _hyphen64 = RegExp(r'^([0-9A-Fa-f]{2}-){7}[0-9A-Fa-f]{2}$');
  static final RegExp _dot48 = RegExp(r'^([0-9A-Fa-f]{4}\.){2}[0-9A-Fa-f]{4}$');
  static final RegExp _dot64 = RegExp(r'^([0-9A-Fa-f]{4}\.){3}[0-9A-Fa-f]{4}$');
  static final RegExp _bare48 = RegExp(r'^[0-9A-Fa-f]{12}$');
  static final RegExp _bare64 = RegExp(r'^[0-9A-Fa-f]{16}$');

  /// Extracts the bare hex digits (12 or 16, in input order) from
  /// [trimmed] when it matches one of the recognized notations, or returns
  /// null otherwise.
  static String? _extractHex(String trimmed) {
    if (_colon48.hasMatch(trimmed) || _colon64.hasMatch(trimmed)) {
      return trimmed.replaceAll(':', '');
    }
    if (_hyphen48.hasMatch(trimmed) || _hyphen64.hasMatch(trimmed)) {
      return trimmed.replaceAll('-', '');
    }
    if (_dot48.hasMatch(trimmed) || _dot64.hasMatch(trimmed)) {
      return trimmed.replaceAll('.', '');
    }
    if (_bare48.hasMatch(trimmed) || _bare64.hasMatch(trimmed)) {
      return trimmed;
    }
    return null;
  }

  /// Joins lower-cased [hex] into groups of [size] characters separated by
  /// [sep].
  static String _grouped(String hex, int size, String sep) {
    final lower = hex.toLowerCase();
    final groups = <String>[];
    for (var i = 0; i < lower.length; i += size) {
      groups.add(lower.substring(i, i + size));
    }
    return groups.join(sep);
  }

  /// Validates [input], returning a [Valid] with the canonical lower-case
  /// colon-separated form or an [Invalid] describing why it was rejected.
  static ValidationResult validate(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.macEmpty, 'MAC address is empty.')]);
    }
    final hex = _extractHex(trimmed);
    if (hex == null) {
      return const Invalid([
        ValidationIssue(
            IssueCode.macBadFormat, 'MAC address has an unrecognized format.')
      ]);
    }
    return Valid(_grouped(hex, 2, ':'));
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input) => validate(input) is Valid;

  /// Returns the canonical lower-case colon-separated form. Throws
  /// [FormatException] if [input] is not a valid MAC address.
  static String normalize(String input) => switch (validate(input)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };

  /// Formats [input] using [notation] (default [MacNotation.colon]),
  /// optionally upper-cased. Throws [FormatException] if [input] is not a
  /// valid MAC address.
  static String format(
    String input, {
    MacNotation notation = MacNotation.colon,
    bool upperCase = false,
  }) {
    final hex = normalize(input).replaceAll(':', '');
    final String out;
    switch (notation) {
      case MacNotation.colon:
        out = _grouped(hex, 2, ':');
      case MacNotation.hyphen:
        out = _grouped(hex, 2, '-');
      case MacNotation.dot:
        out = _grouped(hex, 4, '.');
      case MacNotation.bare:
        out = hex.toLowerCase();
    }
    return upperCase ? out.toUpperCase() : out;
  }

  /// Like [format] but returns null instead of throwing on invalid input.
  static String? tryFormat(
    String input, {
    MacNotation notation = MacNotation.colon,
    bool upperCase = false,
  }) {
    try {
      return format(input, notation: notation, upperCase: upperCase);
    } on FormatException {
      return null;
    }
  }

  /// Parses [input] into a [MacInfo], or null when it is not a valid MAC
  /// address.
  static MacInfo? parse(String input) {
    final r = validate(input);
    if (r is! Valid) return null;
    final octets = r.normalized.split(':');
    final b0 = int.parse(octets[0], radix: 16);
    final isMulticast = (b0 & 1) == 1;
    final isLocal = (b0 & 2) == 2;
    return MacInfo(
      oui: octets.sublist(0, 3).join(':'),
      nic: octets.sublist(3).join(':'),
      isUnicast: !isMulticast,
      isMulticast: isMulticast,
      isUniversal: !isLocal,
      isLocal: isLocal,
      type: octets.length == 8 ? MacAddressType.eui64 : MacAddressType.eui48,
    );
  }
}
