import '../common/issue_code.dart';
import '../common/validation_result.dart';

/// Recognized card networks.
enum CardNetwork {
  /// Visa (starts with 4).
  visa,

  /// Mastercard (51-55 or 2221-2720).
  mastercard,

  /// American Express (34/37).
  amex,

  /// Discover (6011/65/644-649).
  discover,

  /// Not recognized.
  unknown,
}

/// Validation, normalization and formatting of payment-card numbers.
///
/// Validation combines a network-specific length check with the Luhn
/// checksum. See `doc/algorithms.md` for the Luhn algorithm.
class CreditCard {
  CreditCard._();

  static final RegExp _digits = RegExp(r'^[0-9]+$');

  /// Returns the digits-only form, discarding spaces and dashes.
  static String _strip(String input) => input.replaceAll(RegExp(r'[\s-]'), '');

  /// Detects the [CardNetwork] from the leading digits, or null if empty.
  static CardNetwork? network(String input) {
    final s = _strip(input);
    if (s.isEmpty || !_digits.hasMatch(s)) return null;
    final n2 =
        int.parse(s.substring(0, s.length >= 2 ? 2 : 1).padRight(2, '0'));
    final n3 = int.parse(
        s.substring(0, s.length >= 3 ? 3 : s.length).padRight(3, '0'));
    final n4 = s.length >= 4 ? int.parse(s.substring(0, 4)) : n2 * 100;
    if (s[0] == '4') return CardNetwork.visa;
    if (n2 == 34 || n2 == 37) return CardNetwork.amex;
    if ((n2 >= 51 && n2 <= 55) || (n4 >= 2221 && n4 <= 2720)) {
      return CardNetwork.mastercard;
    }
    if (n4 == 6011 || n2 == 65 || (n3 >= 644 && n3 <= 649)) {
      return CardNetwork.discover;
    }
    return CardNetwork.unknown;
  }

  /// True when [input] passes the Luhn checksum (digits weighted right-to-left).
  static bool _luhnOk(String digits) {
    var sum = 0;
    var alt = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var d = digits.codeUnitAt(i) - 0x30;
      if (alt) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
      alt = !alt;
    }
    return sum % 10 == 0;
  }

  static const Map<CardNetwork, Set<int>> _lengths = {
    CardNetwork.visa: {13, 16, 19},
    CardNetwork.mastercard: {16},
    CardNetwork.amex: {15},
    CardNetwork.discover: {16, 19},
  };

  /// Validates [input], returning a [Valid] with the digits-only normalized
  /// form or an [Invalid] describing why it was rejected.
  static ValidationResult validate(String input) {
    final s = _strip(input);
    if (s.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.cardEmpty, 'Card number is empty.')]);
    }
    if (!_digits.hasMatch(s)) {
      return const Invalid([
        ValidationIssue(IssueCode.cardBadChars, 'Card number has non-digits.')
      ]);
    }
    final net = network(s);
    final allowed = _lengths[net];
    if (allowed != null) {
      if (!allowed.contains(s.length)) {
        return const Invalid([
          ValidationIssue(IssueCode.cardBadLength, 'Wrong length for network.')
        ]);
      }
    } else if (s.length < 12 || s.length > 19) {
      // Unknown network: enforce the ISO/IEC 7812 PAN range so short,
      // Luhn-clean junk (e.g. "00") is not accepted as a card.
      return const Invalid([
        ValidationIssue(IssueCode.cardBadLength, 'Implausible card length.')
      ]);
    }
    if (!_luhnOk(s)) {
      return const Invalid(
          [ValidationIssue(IssueCode.cardBadLuhn, 'Fails the Luhn checksum.')]);
    }
    return Valid(s);
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input) => validate(input) is Valid;

  /// Returns the digits-only canonical form. Throws [FormatException] if
  /// [input] is not a valid card number.
  static String normalize(String input) => switch (validate(input)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };

  /// Returns [input] grouped for display (Amex 4-6-5, otherwise 4-4-4-4).
  /// Throws [FormatException] if invalid.
  static String format(String input) {
    final s = normalize(input);
    final groups = network(s) == CardNetwork.amex ? [4, 6, 5] : null;
    if (groups == null) {
      return RegExp(r'.{1,4}').allMatches(s).map((m) => m.group(0)).join(' ');
    }
    final out = <String>[];
    var i = 0;
    for (final g in groups) {
      out.add(s.substring(i, i + g));
      i += g;
    }
    return out.join(' ');
  }

  /// Like [format] but returns null instead of throwing on invalid input.
  static String? tryFormat(String input) {
    try {
      return format(input);
    } on FormatException {
      return null;
    }
  }
}
