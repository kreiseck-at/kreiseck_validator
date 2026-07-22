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

  group('validation (uniform)', () {
    test('valid FR mobile via E.164', () {
      expect(Phone.isValid('+33612345678'), isTrue);
    });

    test('valid US number via E.164', () {
      expect(Phone.isValid('+12015550123'), isTrue);
    });

    test('valid national with country hint', () {
      expect(Phone.isValid('0316 123456', country: Country.at), isTrue);
    });

    test('too short is rejected by length', () {
      final r = Phone.validate('+331', country: null);
      expect(r, isA<Invalid>());
      expect((r as Invalid).issues.first.code, IssueCode.phoneTooShort);
    });

    test('structurally invalid is rejected by pattern', () {
      // Correct length for FR but not an assignable pattern.
      final r = Phone.validate('+33099999999');
      expect(r, isA<Invalid>());
      expect((r as Invalid).issues.first.code, IssueCode.phoneInvalid);
    });

    test('unknown calling code', () {
      expect(Phone.validate('+9990000000'),
          isA<Invalid>());
    });
  });

  group('formatting (uniform)', () {
    test('AT international matches libphonenumber grouping', () {
      final e164 = Phone.normalize('0316 123456', country: Country.at);
      final intl = Phone.format(e164, international: true);
      expect(intl.startsWith('+43 '), isTrue);
    });

    test('national form carries the trunk prefix', () {
      final nat =
          Phone.format('0316123456', country: Country.at, international: false);
      expect(nat.startsWith('0'), isTrue);
    });

    test('formats a FR number internationally', () {
      final intl = Phone.format('+33612345678', international: true);
      expect(intl.startsWith('+33 '), isTrue);
    });

    test('tryFormat returns null on invalid input', () {
      expect(Phone.tryFormat('nope'), isNull);
    });
  });

  group('type & parse (global)', () {
    test('AT mobile still classifies', () {
      expect(Phone.type('+43664123456').name, 'mobile');
    });

    test('non-AT number is unknown type', () {
      expect(Phone.type('+33612345678'), PhoneNumberType.unknown);
    });

    test('parse yields a bundle for a FR number', () {
      final info = Phone.parse('+33612345678');
      expect(info, isNotNull);
      expect(info!.country.iso2, 'FR');
      expect(info.e164, '+33612345678');
      expect(info.country.flag, '🇫🇷');
    });

    test('parse yields null for invalid input', () {
      expect(Phone.parse('nope'), isNull);
    });

    test('NANP +1 resolves to the main region (US), not a co-tenant', () {
      final info = Phone.parse('+12015550123');
      expect(info, isNotNull);
      expect(info!.country.iso2, 'US');
    });
  });
}
