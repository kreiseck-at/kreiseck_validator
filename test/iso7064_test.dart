import 'package:kreiseck_validator/src/common/iso7064.dart';
import 'package:test/test.dart';

void main() {
  group('ISO 7064 MOD 11,10', () {
    test('accepts the documented example', () {
      expect(mod1110Ok('794623'), isTrue);
    });
    test('rejects a wrong check digit', () {
      expect(mod1110Ok('794624'), isFalse);
    });
    test('rejects a transposition', () {
      expect(mod1110Ok('974623'), isFalse);
    });
    test('rejects a non-digit', () {
      expect(mod1110Ok('79462X'), isFalse);
    });
  });

  group('ISO 7064 MOD 97,10', () {
    test('accepts a rearranged IBAN', () {
      expect(mod9710Ok('1904300234573201AT61'), isTrue);
    });
    test('rejects a broken one', () {
      expect(mod9710Ok('1904300234573201AT62'), isFalse);
    });
    test('rejects a non-alphanumeric', () {
      expect(mod9710Ok('1904300234573201AT6 '), isFalse);
    });
  });
}
