import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:test/test.dart';

void main() {
  group('Country registry', () {
    test('lists all countries', () {
      expect(Country.values.length, greaterThan(200));
    });

    test('AT metadata', () {
      expect(Country.at.callingCode, '43');
      expect(Country.at.iso2, 'AT');
      expect(Country.at.displayName, 'Austria');
      expect(Country.at.flag, '🇦🇹');
    });

    test('flag derivation for reserved-word ISO2 codes', () {
      expect(Country.fromIso2('IS')!.flag, '🇮🇸');
      expect(Country.fromIso2('IN')!.flag, '🇮🇳');
    });

    test('lookup by iso2 is case-insensitive', () {
      expect(Country.fromIso2('us')!.iso2, 'US');
      expect(Country.fromIso2('ZZ'), isNull);
    });

    test('fromCallingCode returns the main region for shared codes', () {
      expect(Country.fromCallingCode('1')!.iso2, 'US');
      expect(Country.fromCallingCode('43')!.iso2, 'AT');
    });

    test('example number is exposed', () {
      final fr = Country.fromIso2('FR')!;
      expect(fr.exampleE164, startsWith('+33'));
    });
  });
}
