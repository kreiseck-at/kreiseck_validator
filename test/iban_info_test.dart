import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:test/test.dart';

void main() {
  group('IbanInfo', () {
    test('holds the fields it is constructed with', () {
      const info = IbanInfo(
        country: Country.at,
        checkDigits: '72',
        bankCode: '12000',
        accountNumber: '00234573201',
        bankName: 'UniCredit Bank Austria AG',
        bic: 'BKAUATWW',
        formatted: 'AT72 1200 0002 3457 3201',
      );
      expect(info.country.iso2, 'AT');
      expect(info.checkDigits, '72');
      expect(info.bankCode, '12000');
      expect(info.branchCode, isNull);
      expect(info.accountNumber, '00234573201');
      expect(info.bankName, 'UniCredit Bank Austria AG');
      expect(info.bic, 'BKAUATWW');
      expect(info.formatted, 'AT72 1200 0002 3457 3201');
    });
  });
}
