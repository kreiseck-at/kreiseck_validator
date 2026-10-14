import '../common/field_descriptor.dart';
import '../common/issue_code.dart';
import '../common/validation_result.dart';

/// Voucher codes: 12 symbols of Crockford Base32 (no I, L, O, U), the last one a
/// Damm check symbol over GF(32) (x^5 + x^2 + 1, x∘y = 2·x ⊕ y). The check symbol
/// catches every single-symbol error and every swap of two adjacent symbols.
/// Input is case-insensitive; O reads as 0, I and L read as 1; spaces and dashes
/// are ignored. See doc/algorithms.md.
class VoucherCode {
  VoucherCode._();

  static const String alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const int length = 12;

  static int _mul(int a, int b) {
    var r = 0;
    while (b != 0) {
      if (b & 1 != 0) r ^= a;
      b >>= 1;
      a <<= 1;
      if (a & 32 != 0) a ^= 0x25;
    }
    return r;
  }

  static int _interim(String s) {
    var interim = 0;
    for (final ch in s.split('')) {
      interim = _mul(2, interim) ^ alphabet.indexOf(ch);
    }
    return interim;
  }

  static String _strip(String input) => input
      .toUpperCase()
      .replaceAll(RegExp(r'[\s-]'), '')
      .replaceAll('O', '0')
      .replaceAll('I', '1')
      .replaceAll('L', '1');

  /// Returns the check symbol for an 11-symbol [payload] (already normalized).
  static String checkSymbol(String payload) =>
      alphabet[_mul(2, _interim(payload))];

  /// Builds a code from at least 11 random bytes (each byte's low five bits pick
  /// one symbol; 256 is a multiple of 32, so every symbol is equally likely).
  static String generate(List<int> randomBytes) {
    if (randomBytes.length < length - 1) {
      throw ArgumentError('needs at least ${length - 1} bytes');
    }
    final payload =
        randomBytes.take(length - 1).map((b) => alphabet[b & 31]).join();
    return payload + checkSymbol(payload);
  }

  /// Validates [input], returning a [Valid] with the compact upper-case form
  /// or an [Invalid] describing why it was rejected.
  static ValidationResult validate(String input) {
    final s = _strip(input);
    if (s.isEmpty) {
      return const Invalid([
        ValidationIssue(IssueCode.voucherCodeEmpty, 'Voucher code is empty.')
      ]);
    }
    if (s.split('').any((c) => !alphabet.contains(c))) {
      return const Invalid([
        ValidationIssue(IssueCode.voucherCodeBadChars,
            'Voucher code has invalid characters.')
      ]);
    }
    if (s.length != length) {
      return const Invalid([
        ValidationIssue(IssueCode.voucherCodeBadLength,
            'Voucher code must have 12 characters.')
      ]);
    }
    if (_interim(s) != 0) {
      return const Invalid([
        ValidationIssue(
            IssueCode.voucherCodeBadChecksum, 'Fails the check symbol.')
      ]);
    }
    return Valid(s);
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input) => validate(input) is Valid;

  /// Returns the compact upper-case canonical form. Throws [FormatException]
  /// if [input] is not a valid voucher code.
  static String normalize(String input) => switch (validate(input)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };

  /// Returns the code grouped as `XXXX-XXXX-XXXX`. Throws [FormatException]
  /// if invalid.
  static String format(String input) {
    final s = normalize(input);
    return '${s.substring(0, 4)}-${s.substring(4, 8)}-${s.substring(8)}';
  }

  /// Like [format] but returns null instead of throwing on invalid input.
  static String? tryFormat(String input) {
    try {
      return format(input);
    } on FormatException {
      return null;
    }
  }

  /// Describes a voucher-code input field.
  static FieldDescriptor fieldDescriptor() => const FieldDescriptor(
        keyboard: KeyboardType.text,
        capitalization: Capitalization.characters,
        maxLength: 14,
        example: 'K7QM-3XRP-9DWF',
        allowedChars: '0-9A-Za-z -',
      );

  /// Partial input for a text field: upper case, O/I/L mapped, foreign
  /// characters dropped, dashes after 4 and 8 symbols, at most 12 symbols.
  /// Never throws.
  static String formatPartial(String input) {
    final s =
        _strip(input).split('').where(alphabet.contains).take(length).join();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i == 4 || i == 8) b.write('-');
      b.write(s[i]);
    }
    return b.toString();
  }
}
