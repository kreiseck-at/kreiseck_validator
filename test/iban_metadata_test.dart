import 'package:kreiseck_validator/src/iban/iban_metadata.dart';
import 'package:test/test.dart';

void main() {
  group('kIbanBban', () {
    test('AT layout: 5-digit bank code, no branch', () {
      final at = kIbanBban['AT']!;
      expect(at.length, 20);
      expect(at.bankStart, 4);
      expect(at.bankEnd, 9);
      expect(at.branchStart, isNull);
      expect(at.branchEnd, isNull);
    });

    test('IT layout has a branch code after the CIN char', () {
      final it = kIbanBban['IT']!;
      expect(it.length, 27);
      expect(it.bankStart, 5); // 4 + 1 CIN
      expect(it.bankEnd, 10);
      expect(it.branchStart, 10);
      expect(it.branchEnd, 15);
    });

    test('covers DACH lengths used by validation', () {
      expect(kIbanBban['DE']!.length, 22);
      expect(kIbanBban['CH']!.length, 21);
    });
  });

  group('kBanks', () {
    test('resolves Bank Austria by BLZ, XXX filler stripped', () {
      final b = kBanks['AT']!['12000']!;
      expect(b.name, 'UniCredit Bank Austria AG');
      expect(b.bic, 'BKAUATWW');
    });

    test('fictional textbook BLZ 19043 is absent', () {
      expect(kBanks['AT']!['19043'], isNull);
    });

    test('resolves a German bank by BLZ (head office)', () {
      final b = kBanks['DE']!['37040044']!;
      expect(b.name, 'Commerzbank');
      expect(b.bic, 'COBADEFF');
    });

    test('resolves a Swiss bank by zero-padded BC number', () {
      final b = kBanks['CH']!['00100']!;
      expect(b.name, 'Schweizerische Nationalbank');
      expect(b.bic, 'SNBZCHZZ');
    });
  });
}
