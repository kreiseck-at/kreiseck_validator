// test/phone_format_test.dart
import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:test/test.dart';

void main() {
  test('mobile spacing is unchanged', () {
    expect(Phone.format('+436641234567'), '+43 664 1234567');
    expect(Phone.format('+436641234567', international: false), '0664 1234567');
  });

  test('Vienna landline uses the 1-digit area code', () {
    // national = 15321234 -> area '1', rest '5321234'
    expect(Phone.format('+4315321234'), '+43 1 5321234');
    expect(Phone.format('+4315321234', international: false), '01 5321234');
  });

  test('Graz landline uses the 3-digit area code', () {
    expect(Phone.format('+43316123456'), '+43 316 123456');
    expect(Phone.format('+43316123456', international: false), '0316 123456');
  });

  test('unknown area code falls back without throwing', () {
    // 0288x is not in the curated table -> approximate split, still readable.
    expect(Phone.format('+43288123456', international: false).startsWith('0'),
        isTrue);
  });
}
