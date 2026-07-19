import 'package:input_validator/src/common/country.dart';
import 'package:input_validator/src/common/issue_code.dart';
import 'package:input_validator/src/common/validation_result.dart';
import 'package:input_validator/src/phone/phone.dart';
import 'package:test/test.dart';

void main() {
  test('accepts an E.164 number', () {
    expect(Phone.isValid('+436601234567'), isTrue);
  });

  test('parses a national AT number with a country hint', () {
    expect(
        Phone.normalize('0660 1234567', country: Country.at), '+436601234567');
  });

  test('rejects a national number without a country hint', () {
    final r = Phone.validate('0660 1234567');
    expect((r as Invalid).issues.first.code, IssueCode.phoneAmbiguousCountry);
  });

  test('rejects letters', () {
    final r = Phone.validate('+49 ABC');
    expect((r as Invalid).issues.first.code, IssueCode.phoneBadChars);
  });

  test('formats international by default', () {
    expect(Phone.format('+436601234567'), '+43 660 1234567');
  });

  test('formats national when asked', () {
    expect(Phone.format('+436601234567', international: false), '0660 1234567');
  });

  test('strips an embedded (0) trunk prefix from E.164 input', () {
    expect(Phone.normalize('+43 (0) 660 1234567'), '+436601234567');
  });
}
