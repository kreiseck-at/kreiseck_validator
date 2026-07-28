import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:test/test.dart';

/// Countries whose check-digit algorithm is not implemented yet.
///
/// This list is the release gate: `checkVat` throws for anything on it, so a
/// country cannot be added to `kVatFormats` and quietly validate on structure
/// alone. Every entry removed here must be removed because its algorithm and a
/// published example both landed.
const Set<String> kAwaitingCheckDigit = {
  'BE', 'BG', 'CH', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FI', 'FR', 'GB',
  'GR', 'HR', 'HU', 'IE', 'IT', 'LT', 'LU', 'LV', 'MT', 'NL', 'PL', 'PT',
  'RO', 'SE', 'SI', 'SK', 'XI',
};

void main() {
  test('covers 30 VAT prefixes', () {
    expect(kVatFormats.length, 30);
  });

  test('Greece is keyed GR and prefixed EL', () {
    expect(kVatFormats['GR']!.prefix, 'EL');
    expect(kVatFormats.containsKey('EL'), isFalse);
    expect(VatId.normalize('094259216', country: 'GR'), startsWith('EL'));
  }, skip: kAwaitingCheckDigit.contains('GR') ? 'GR check digit pending' : null);

  test('every implemented country has a bundled example that validates', () {
    for (final entry in kVatFormats.entries) {
      if (kAwaitingCheckDigit.contains(entry.key)) continue;
      final example = entry.value.example;
      expect(example, isNotNull,
          reason: '${entry.key} has a check digit but no published example');
      expect(VatId.isValid(example!), isTrue,
          reason: '${entry.key} example $example does not validate');
      expect(VatId.normalize(example), example,
          reason: '${entry.key} example $example is not in canonical form');
    }
  });

  test('no country awaiting a check digit ships an example', () {
    for (final key in kAwaitingCheckDigit) {
      expect(kVatFormats[key]!.example, isNull,
          reason: '$key ships an example but cannot check it');
    }
  });

  test('an unimplemented country throws rather than passing structurally', () {
    // The dispatch seam must never degrade to "structure is enough".
    expect(() => VatId.isValid('DE123456789'), throwsStateError);
  }, skip: kAwaitingCheckDigit.isEmpty ? 'all countries implemented' : null);
}
