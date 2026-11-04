import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:test/test.dart';

void main() {
  test('lists the five values in a fixed order', () {
    expect(Gender.values, ['m', 'f', 'd', 'i', 'o']);
  });

  test('labels every value in German (default) and English', () {
    expect(Gender.values.map(Gender.label).toList(),
        ['männlich', 'weiblich', 'divers', 'inter', 'offen']);
    expect(Gender.values.map((v) => Gender.label(v, locale: 'en')).toList(),
        ['male', 'female', 'diverse', 'inter', 'open']);
  });

  test('options pair every value with its label, in order', () {
    final options = Gender.options();
    expect(options.map((o) => o.value).toList(), Gender.values);
    expect(options.map((o) => o.label).toList(),
        ['männlich', 'weiblich', 'divers', 'inter', 'offen']);
    expect(Gender.options(locale: 'en')[1].label, 'female');
  });

  test('normalize returns the code and throws FormatException on unknown input',
      () {
    expect(Gender.normalize('Weiblich'), 'f');
    expect(() => Gender.normalize('keine angabe'), throwsFormatException);
  });

  test('label accepts any valid input and throws on an unknown one', () {
    expect(Gender.label('W'), 'weiblich');
    expect(() => Gender.label('x'), throwsFormatException);
  });
}
