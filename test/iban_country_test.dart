import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:test/test.dart';

void main() {
  group('IbanCountry', () {
    test('describes the Austrian IBAN format', () {
      final at = IbanCountry.of('AT')!;
      expect(at.iso2, 'AT');
      expect(at.length, 20);
      expect(at.bankCodeLength, 5);
      expect(at.branchCodeLength, isNull);
      expect(at.accountLength, 11);
      expect(at.hasBranchCode, isFalse);
      expect(at.example, 'AT61 1904 3002 3457 3201');
    });

    test('exposes a branch code length where the country has one', () {
      final it = IbanCountry.of('IT')!;
      expect(it.length, 27);
      expect(it.bankCodeLength, 5);
      expect(it.branchCodeLength, 5);
      expect(it.accountLength, 12);
      expect(it.hasBranchCode, isTrue);
    });

    test('lookup is case-insensitive', () {
      final lower = IbanCountry.of('at')!;
      final upper = IbanCountry.of('AT')!;
      expect(lower.iso2, upper.iso2);
      expect(lower.length, upper.length);
    });

    test('returns null for countries without an IBAN', () {
      expect(IbanCountry.of('XX'), isNull); // not a country
      expect(IbanCountry.of('US'), isNull); // real country, no IBAN
    });

    test('every example is a valid IBAN and values is sorted', () {
      final values = IbanCountry.values;
      expect(values, isNotEmpty);
      for (final c in values) {
        expect(Iban.isValid(c.example), isTrue,
            reason: 'invalid example for ${c.iso2}: ${c.example}');
      }
      final codes = values.map((c) => c.iso2).toList();
      final sorted = [...codes]..sort();
      expect(codes, sorted);
    });
  });
}
