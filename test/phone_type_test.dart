// test/phone_type_test.dart
import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:kreiseck_validator/src/phone/at_numbering.dart';
import 'package:test/test.dart';

void main() {
  PhoneNumberType t(String national) => AtNumbering.classify(national).type;

  test('mobile prefixes classify as mobile', () {
    expect(t('6641234567'), PhoneNumberType.mobile); // 0664
    expect(t('6991234567'), PhoneNumberType.mobile); // 0699
    expect(t('6501234567'), PhoneNumberType.mobile); // 0650
  });

  test('Salzburg 0662 is landline, NOT mobile (the range trap)', () {
    expect(t('662123456'), PhoneNumberType.landline);
  });

  test('geographic area codes classify as landline', () {
    expect(t('15321234'), PhoneNumberType.landline); // 01 Wien
    expect(t('316123456'), PhoneNumberType.landline); // 0316 Graz
    expect(t('5572123456'), PhoneNumberType.landline); // 05572 Dornbirn
  });

  test('06xx regional landlines (not in the curated table) are landline', () {
    expect(t('613212345'), PhoneNumberType.landline); // 06132 Bad Ischl
    expect(t('654212345'), PhoneNumberType.landline); // 06542 Zell am See
  });

  test('service ranges classify correctly', () {
    expect(t('800123456'), PhoneNumberType.freephone); // 0800
    expect(t('810123456'), PhoneNumberType.sharedCost); // 0810
    expect(t('900123456'), PhoneNumberType.premium); // 0900
    expect(t('720123456'), PhoneNumberType.voip); // 0720
  });

  test('corporate 05x/059x classify as corporate', () {
    expect(t('590133999'), PhoneNumberType.corporate); // 0590
    expect(t('500123456'), PhoneNumberType.corporate); // 0500
  });

  test('classify exposes the grouping prefix', () {
    expect(AtNumbering.classify('316123456').prefix, '316');
    expect(AtNumbering.classify('15321234').prefix, '1');
    expect(AtNumbering.classify('6641234567').prefix, '664');
  });

  test('Phone.type classifies AT numbers and is unknown off-AT/invalid', () {
    expect(Phone.type('+436641234567'), PhoneNumberType.mobile);
    expect(Phone.type('0316 123456', country: Country.at),
        PhoneNumberType.landline);
    expect(Phone.type('+491701234567'), PhoneNumberType.unknown); // DE
    expect(Phone.type('nonsense'), PhoneNumberType.unknown);
  });

  test('Phone.parse bundles type and both formats, null on invalid', () {
    final info = Phone.parse('0316123456', country: Country.at)!;
    expect(info.type, PhoneNumberType.landline);
    expect(info.e164, '+43316123456');
    expect(info.national, '0316 123456');
    expect(info.international, '+43 316 123456');
    expect(info.country, Country.at);
    expect(Phone.parse('nonsense'), isNull);
  });
}
