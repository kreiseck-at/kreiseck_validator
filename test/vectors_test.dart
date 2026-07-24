import 'dart:convert';
import 'dart:io';

import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:test/test.dart';

Country? _country(String? s) => s == null ? null : Country.fromIso2(s);

MacNotation _notation(String? s) => switch (s) {
      'hyphen' => MacNotation.hyphen,
      'dot' => MacNotation.dot,
      'bare' => MacNotation.bare,
      _ => MacNotation.colon,
    };

String? _codeOf(ValidationResult r) =>
    r is Invalid ? r.issues.first.code.name : null;

void _check(
  String name,
  Map<String, Object?> c,
  ValidationResult Function() validate,
  String Function() format,
) {
  final input = c['input'];
  test('$name: $input', () {
    final r = validate();
    if (c.containsKey('isValid')) {
      expect(r is Valid, c['isValid'], reason: 'isValid for $input');
    }
    if (c.containsKey('code')) {
      expect(_codeOf(r), c['code'], reason: 'code for $input');
    }
    if (c.containsKey('normalized')) {
      expect((r as Valid).normalized, c['normalized']);
    }
    if (c.containsKey('format')) {
      expect(format(), c['format']);
    }
  });
}

List<Map<String, Object?>> _load(String file) =>
    (jsonDecode(File('test/vectors/$file').readAsStringSync()) as List)
        .cast<Map<String, Object?>>();

void main() {
  group('credit_card', () {
    for (final c in _load('credit_card.json')) {
      final input = c['input']! as String;
      _check('credit_card', c, () => CreditCard.validate(input),
          () => CreditCard.format(input));
    }
  });

  group('iban', () {
    for (final c in _load('iban.json')) {
      final input = c['input']! as String;
      _check('iban', c, () => Iban.validate(input), () => Iban.format(input));
      if (c.containsKey('parse')) {
        test('iban parse: $input', () {
          final info = Iban.parse(input)!;
          final p = c['parse']! as Map<String, Object?>;
          expect(info.country.iso2, p['country']);
          expect(info.checkDigits, p['checkDigits']);
          expect(info.bankCode, p['bankCode']);
          expect(info.branchCode, p['branchCode']);
          expect(info.accountNumber, p['accountNumber']);
          expect(info.bankName, p['bankName']);
          expect(info.bic, p['bic']);
        });
      }
    }
  });

  group('imei', () {
    for (final c in _load('imei.json')) {
      final input = c['input']! as String;
      _check('imei', c, () => Imei.validate(input), () => Imei.format(input));
      if (c.containsKey('parse')) {
        test('imei parse: $input', () {
          final info = Imei.parse(input)!;
          final p = c['parse']! as Map<String, Object?>;
          expect(info.tac, p['tac']);
          expect(info.serialNumber, p['serialNumber']);
          expect(info.checkDigit, p['checkDigit']);
          expect(info.reportingBodyIdentifier, p['reportingBodyIdentifier']);
        });
      }
    }
  });

  group('iccid', () {
    for (final c in _load('iccid.json')) {
      final input = c['input']! as String;
      _check(
          'iccid', c, () => Iccid.validate(input), () => Iccid.format(input));
      if (c.containsKey('parse')) {
        test('iccid parse: $input', () {
          final info = Iccid.parse(input)!;
          final p = c['parse']! as Map<String, Object?>;
          expect(info.mii, p['mii']);
          expect(info.country?.iso2, p['country']);
          expect(info.issuerIdentifier, p['issuerIdentifier']);
          expect(info.checkDigit, p['checkDigit']);
        });
      }
    }
  });

  group('mac_address', () {
    for (final c in _load('mac.json')) {
      final input = c['input']! as String;
      final notation = _notation(c['notation'] as String?);
      final upperCase = c['upperCase'] as bool? ?? false;
      _check(
          'mac_address',
          c,
          () => MacAddress.validate(input),
          () => MacAddress.format(input,
              notation: notation, upperCase: upperCase));
      if (c.containsKey('parse')) {
        test('mac_address parse: $input', () {
          final info = MacAddress.parse(input)!;
          final p = c['parse']! as Map<String, Object?>;
          if (p.containsKey('oui')) expect(info.oui, p['oui']);
          if (p.containsKey('nic')) expect(info.nic, p['nic']);
          if (p.containsKey('isUnicast')) {
            expect(info.isUnicast, p['isUnicast']);
          }
          if (p.containsKey('isMulticast')) {
            expect(info.isMulticast, p['isMulticast']);
          }
          if (p.containsKey('isUniversal')) {
            expect(info.isUniversal, p['isUniversal']);
          }
          if (p.containsKey('isLocal')) expect(info.isLocal, p['isLocal']);
          if (p.containsKey('type')) expect(info.type.name, p['type']);
        });
      }
    }
  });

  group('vin', () {
    for (final c in _load('vin.json')) {
      final input = c['input']! as String;
      _check('vin', c, () => Vin.validate(input), () => Vin.format(input));
      if (c.containsKey('parse')) {
        test('vin parse: $input', () {
          final info = Vin.parse(input)!;
          final p = c['parse']! as Map<String, Object?>;
          if (p.containsKey('wmi')) expect(info.wmi, p['wmi']);
          if (p.containsKey('vds')) expect(info.vds, p['vds']);
          if (p.containsKey('vis')) expect(info.vis, p['vis']);
          if (p.containsKey('checkDigit')) {
            expect(info.checkDigit, p['checkDigit']);
          }
          if (p.containsKey('checkDigitValid')) {
            expect(info.checkDigitValid, p['checkDigitValid']);
          }
          if (p.containsKey('modelYear')) expect(info.modelYear, p['modelYear']);
          if (p.containsKey('plantCode')) expect(info.plantCode, p['plantCode']);
        });
      }
    }
  });

  group('license_plate', () {
    for (final c in _load('license_plate.json')) {
      final input = c['input']! as String;
      final country = c['country'] as String?;
      _check(
          'license_plate',
          c,
          () => LicensePlate.validate(input, country: country),
          () => LicensePlate.format(input, country: country));
      if (c.containsKey('parse')) {
        test('license_plate parse: $input', () {
          final info = LicensePlate.parse(input, country: country)!;
          final p = c['parse']! as Map<String, Object?>;
          expect(info.country, p['country']);
          expect(info.districtCode, p['districtCode']);
          expect(info.region, p['region']);
          expect(info.serial, p['serial']);
          expect(info.type.name, p['type']);
        });
      }
    }
  });

  group('postal_code', () {
    for (final c in _load('postal_code.json')) {
      final input = c['input']! as String;
      final country = c['country']! as String;
      _check(
          'postal_code',
          c,
          () => PostalCode.validate(input, country: country),
          () => PostalCode.format(input, country: country));
      if (c.containsKey('parse')) {
        test('postal_code parse: $input', () {
          final info = PostalCode.parse(input, country: country)!;
          final p = c['parse']! as Map<String, Object?>;
          expect(info.country, p['country']);
          expect(info.code, p['code']);
        });
      }
    }
  });

  group('url', () {
    for (final c in _load('url.json')) {
      final input = c['input']! as String;
      _check('url', c, () => Url.validate(input), () => Url.format(input));
    }
  });

  group('email', () {
    for (final c in _load('email.json')) {
      final input = c['input']! as String;
      _check('email', c, () => Email.validate(input), () => input);
    }
  });

  group('phone', () {
    for (final c in _load('phone.json')) {
      final input = c['input']! as String;
      final country = _country(c['country'] as String?);
      final international = c['international'] as bool? ?? true;
      _check(
          'phone',
          c,
          () => Phone.validate(input, country: country),
          () => Phone.format(input,
              country: country, international: international));
      if (c.containsKey('type')) {
        test('phone type: $input', () {
          expect(Phone.type(input, country: country).name, c['type']);
        });
      }
    }
  });

  group('phone_global', () {
    for (final c in _load('phone_global.json')) {
      final input = c['input']! as String;
      final country = _country(c['country'] as String?);
      final international = c['international'] as bool? ?? true;
      _check(
          'phone_global',
          c,
          () => Phone.validate(input, country: country),
          () => Phone.format(input,
              country: country, international: international));
    }
  });
}
