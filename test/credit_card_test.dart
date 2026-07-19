import 'package:kreiseck_validator/src/common/issue_code.dart';
import 'package:kreiseck_validator/src/common/validation_result.dart';
import 'package:kreiseck_validator/src/credit_card/credit_card.dart';
import 'package:test/test.dart';

void main() {
  test('accepts a valid Visa number with separators', () {
    expect(CreditCard.isValid('4111 1111 1111 1111'), isTrue);
  });

  test('rejects a number failing the Luhn check', () {
    final r = CreditCard.validate('4111111111111112');
    expect(r, isA<Invalid>());
    expect((r as Invalid).issues.first.code, IssueCode.cardBadLuhn);
  });

  test('normalize strips separators to digits', () {
    expect(CreditCard.normalize('4111-1111 1111 1111'), '4111111111111111');
  });

  test('format groups Visa in 4-4-4-4', () {
    expect(CreditCard.format('4111111111111111'), '4111 1111 1111 1111');
  });

  test('format groups Amex in 4-6-5', () {
    expect(CreditCard.format('378282246310005'), '3782 822463 10005');
  });

  test('detects the card network', () {
    expect(CreditCard.network('4111111111111111'), CardNetwork.visa);
    expect(CreditCard.network('378282246310005'), CardNetwork.amex);
  });

  test('detects Discover across its BIN ranges', () {
    expect(CreditCard.network('6011000000000004'), CardNetwork.discover);
    expect(CreditCard.network('6440000000000000'), CardNetwork.discover);
    expect(CreditCard.network('6500000000000000'), CardNetwork.discover);
  });

  test('rejects an implausibly short number even if Luhn-clean', () {
    expect(CreditCard.isValid('00'), isFalse);
    final r = CreditCard.validate('00');
    expect((r as Invalid).issues.first.code, IssueCode.cardBadLength);
  });

  test('tryFormat returns null on invalid input', () {
    expect(CreditCard.tryFormat('abcd'), isNull);
  });
}
