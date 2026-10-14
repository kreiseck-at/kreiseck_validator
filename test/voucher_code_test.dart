import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:test/test.dart';

const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

void main() {
  test('generate yields valid codes from 11 bytes', () {
    for (var i = 0; i < 256; i++) {
      final code = VoucherCode.generate(
          List<int>.generate(11, (j) => (i * 7 + j * 13) & 255));
      expect(code.length, 12);
      expect(VoucherCode.isValid(code), isTrue);
    }
  });

  test('generate needs at least 11 bytes', () {
    expect(() => VoucherCode.generate(List<int>.filled(10, 1)),
        throwsArgumentError);
  });

  test('every single-symbol error is detected', () {
    final code = VoucherCode.generate(List<int>.generate(11, (j) => j * 29));
    for (var pos = 0; pos < 12; pos++) {
      for (final ch in alphabet.split('')) {
        if (ch == code[pos]) continue;
        final wrong = code.replaceRange(pos, pos + 1, ch);
        expect(VoucherCode.isValid(wrong), isFalse, reason: wrong);
      }
    }
  });

  test('every swap of two adjacent symbols is detected', () {
    for (var seed = 0; seed < 64; seed++) {
      final code = VoucherCode.generate(
          List<int>.generate(11, (j) => seed * 31 + j * 17));
      for (var pos = 0; pos < 11; pos++) {
        if (code[pos] == code[pos + 1]) continue;
        final t = code.substring(0, pos) +
            code[pos + 1] +
            code[pos] +
            code.substring(pos + 2);
        expect(VoucherCode.isValid(t), isFalse, reason: t);
      }
    }
  });

  test('format groups as XXXX-XXXX-XXXX', () {
    final code = VoucherCode.generate(List<int>.filled(11, 3));
    expect(VoucherCode.format(code.toLowerCase()),
        matches(RegExp(r'^[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}$')));
  });

  test('tryFormat returns null on invalid input', () {
    expect(VoucherCode.tryFormat('nope'), isNull);
  });

  test('formatPartial maps, filters and groups', () {
    expect(VoucherCode.formatPartial('k7qm3'), 'K7QM-3');
    expect(VoucherCode.formatPartial('k7qm-3xrp-9dwf-extra'), 'K7QM-3XRP-9DWF');
    expect(VoucherCode.formatPartial('o'), '0');
    expect(VoucherCode.formatPartial(''), '');
  });
}
