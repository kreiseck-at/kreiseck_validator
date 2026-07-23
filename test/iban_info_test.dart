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

  group('Iban.parse', () {
    test('AT IBAN with a known BLZ resolves bank and BIC', () {
      final info = Iban.parse('AT72 1200 0002 3457 3201')!;
      expect(info.country.iso2, 'AT');
      expect(info.checkDigits, '72');
      expect(info.bankCode, '12000');
      expect(info.branchCode, isNull);
      expect(info.accountNumber, '00234573201');
      expect(info.bankName, 'UniCredit Bank Austria AG');
      expect(info.bic, 'BKAUATWW');
      expect(info.formatted, 'AT72 1200 0002 3457 3201');
    });

    test('AT IBAN with an unknown BLZ has null enrichment', () {
      final info = Iban.parse('AT61 1904 3002 3457 3201')!;
      expect(info.bankCode, '19043');
      expect(info.accountNumber, '00234573201');
      expect(info.bankName, isNull);
      expect(info.bic, isNull);
    });

    test('DE IBAN splits bank code, no branch, no enrichment', () {
      final info = Iban.parse('DE89 3704 0044 0532 0130 00')!;
      expect(info.country.iso2, 'DE');
      expect(info.bankCode, '37040044');
      expect(info.branchCode, isNull);
      expect(info.accountNumber, '0532013000');
      expect(info.bankName, isNull);
      expect(info.bic, isNull);
    });

    test('valid IBAN for a country without a structure entry', () {
      // US has no IBAN spec, but the string is checksum-valid and US is a
      // known country, so structural fields stay null.
      final info = Iban.parse('US78 1234 5678 90')!;
      expect(info.country.iso2, 'US');
      expect(info.checkDigits, '78');
      expect(info.bankCode, isNull);
      expect(info.branchCode, isNull);
      expect(info.accountNumber, isNull);
    });

    test('invalid IBAN returns null', () {
      expect(Iban.parse('AT61 1904 3002 3457 3200'), isNull); // bad checksum
      expect(Iban.parse('not an iban'), isNull);
    });

    test('country with a branch code splits bank and branch (IT)', () {
      final info = Iban.parse('IT60X0542811101000000123456')!;
      expect(info.country.iso2, 'IT');
      expect(info.bankCode, '05428');
      expect(info.branchCode, '11101');
      expect(info.accountNumber, '000000123456');
      expect(info.bankName, isNull);
      expect(info.bic, isNull);
    });

    test('country with a zero-width bank slice yields null bankCode (AO)', () {
      final info = Iban.parse('AO14006900000000001234567')!;
      expect(info.country.iso2, 'AO');
      expect(info.bankCode, isNull);
      expect(info.branchCode, isNull);
      expect(info.accountNumber, '006900000000001234567');
    });
  });
}
