import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:test/test.dart';

/// Prefixes that ship no bundled example, with the reason.
///
/// `XI` is the only one. A Northern Ireland VAT number is the holder's GB
/// number re-prefixed, so it shares GB's algorithm exactly and GB's vectors
/// cover it; no published XI registration was obtainable, and inventing one
/// would put a number in the metadata that nobody ever issued.
const Set<String> kWithoutExample = {'XI'};

void main() {
  test('covers 33 VAT prefixes', () {
    expect(kVatFormats.length, 33);
  });

  test('Greece is keyed GR and prefixed EL', () {
    expect(kVatFormats['GR']!.prefix, 'EL');
    expect(kVatFormats.containsKey('EL'), isFalse);
    expect(VatId.normalize('094259216', country: 'GR'), 'EL094259216');
    expect(VatId.normalize('094259216', country: 'EL'), 'EL094259216');
    expect(VatId.parse('EL094259216')!.country, 'GR');
  });

  test('Northern Ireland keeps the XI prefix but reports GB', () {
    // Same digits as the GB vector, re-prefixed -- that is how HMRC issues an
    // XI number in the first place.
    final info = VatId.parse('XI220430231')!;
    expect(info.prefix, 'XI');
    expect(info.country, 'GB');
  });

  test('every country has a check-digit implementation', () {
    for (final iso2 in kVatFormats.keys) {
      // Reaching the checksum at all proves a function is registered:
      // checkVat throws StateError when one is missing.
      expect(() => VatId.isValid('${kVatFormats[iso2]!.prefix}0'), returnsNormally,
          reason: 'no check-digit implementation for $iso2');
    }
  });

  test('every bundled example validates and is canonical', () {
    for (final entry in kVatFormats.entries) {
      if (kWithoutExample.contains(entry.key)) {
        expect(entry.value.example, isNull);
        continue;
      }
      final example = entry.value.example;
      expect(example, isNotNull, reason: '${entry.key} has no example');
      expect(VatId.isValid(example!), isTrue,
          reason: '${entry.key} example $example does not validate');
      expect(VatId.normalize(example), example,
          reason: '${entry.key} example $example is not canonical');
    }
  });

  group('prefixFor', () {
    test('returns the tax spelling, which is not always the ISO code', () {
      expect(VatId.prefixFor('AT'), 'ATU');
      expect(VatId.prefixFor('CH'), 'CHE');
      expect(VatId.prefixFor('GR'), 'EL');
      expect(VatId.prefixFor('EL'), 'EL');
      expect(VatId.prefixFor('XI'), 'XI');
      expect(VatId.prefixFor('DE'), 'DE');
      expect(VatId.prefixFor('de'), 'DE');
    });

    test('returns null for a country without a VAT ID here', () {
      expect(VatId.prefixFor('US'), isNull);
      expect(VatId.prefixFor('ZZ'), isNull);
    });

    test('agrees with the prefix parse reports', () {
      for (final entry in kVatFormats.entries) {
        final example = entry.value.example;
        if (example == null) continue;
        expect(VatId.prefixFor(entry.key), VatId.parse(example)!.prefix,
            reason: 'prefixFor(${entry.key}) disagrees with parse');
      }
    });
  });

  test('a prefix in the value wins over the country option', () {
    expect(VatId.parse('ATU16210507', country: 'DE')!.country, 'AT');
  });

  test("Belgium's nine-digit legacy form gains its leading zero", () {
    expect(VatId.normalize('BE417497106'), 'BE0417497106');
  });
}
