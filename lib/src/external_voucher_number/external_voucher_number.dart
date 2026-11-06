import '../voucher_code/voucher_code.dart';

/// Voucher number of an external system (a business's own voucher scheme),
/// printed on receipts as-is. Rules: trim (fixed whitespace set, identical in Dart
/// and JS; Dart's own `trim` would also strip U+0085), then only
/// `[A-Za-z0-9-_./]`, 1 to 40 characters. Case is preserved.
class ExternalVoucherNumber {
  ExternalVoucherNumber._();

  static final RegExp _trim = RegExp(
      '^[\t\n\v\f\r \u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff]+|[\t\n\v\f\r \u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff]+\$');
  static final RegExp _pattern = RegExp(r'^[A-Za-z0-9\-_./]{1,40}$');

  /// Returns the trimmed form, or null if it breaks the rules.
  static String? normalize(String input) {
    final s = input.replaceAll(_trim, '');
    return _pattern.hasMatch(s) ? s : null;
  }

  /// True when [normalize] returns a value.
  static bool isValid(String input) => normalize(input) != null;
}

/// True when [input] is a valid own voucher code (Damm check symbol).
bool isOwnVoucherCode(String input) => VoucherCode.isValid(input);
