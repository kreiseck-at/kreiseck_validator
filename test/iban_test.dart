import 'package:input_validator/src/common/issue_code.dart';
import 'package:input_validator/src/common/validation_result.dart';
import 'package:input_validator/src/iban/iban.dart';
import 'package:test/test.dart';

void main() {
  test('accepts a valid Austrian IBAN with spaces', () {
    expect(Iban.isValid('AT61 1904 3002 3457 3201'), isTrue);
  });

  test('rejects a bad checksum', () {
    final r = Iban.validate('AT611904300234573200');
    expect((r as Invalid).issues.first.code, IssueCode.ibanBadChecksum);
  });

  test('rejects wrong length for a DACH country', () {
    final r = Iban.validate('DE89370400440532013');
    expect((r as Invalid).issues.first.code, IssueCode.ibanBadLength);
  });

  test('normalize uppercases and removes spaces', () {
    expect(Iban.normalize('at61 1904 3002 3457 3201'), 'AT611904300234573201');
  });

  test('format groups in 4s', () {
    expect(Iban.format('DE89370400440532013000'),
        'DE89 3704 0044 0532 0130 00');
  });
}
