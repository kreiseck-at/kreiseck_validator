import '../voucher_code/voucher_code.dart';

/// Voucher number of an external system (a business's own voucher scheme),
/// printed on receipts as-is. Rules: trim, Unicode NFC, then only
/// `[A-Za-z0-9-_./]`, 1 to 40 characters. Case is preserved.
///
/// Dart has no NFC in its core library; every character outside the allowed
/// ASCII set is rejected either way, and a decomposed sequence consists of
/// such characters, so the result is the same as with NFC first.
class ExternalVoucherNumber {
  ExternalVoucherNumber._();

  static final RegExp _pattern = RegExp(r'^[A-Za-z0-9\-_./]{1,40}$');

  /// Returns the trimmed form, or null if it breaks the rules.
  static String? normalize(String input) {
    final s = input.trim();
    return _pattern.hasMatch(s) ? s : null;
  }

  /// True when [normalize] returns a value.
  static bool isValid(String input) => normalize(input) != null;
}

/// True when [input] is a valid own voucher code (Damm check symbol).
bool isOwnVoucherCode(String input) => VoucherCode.isValid(input);
