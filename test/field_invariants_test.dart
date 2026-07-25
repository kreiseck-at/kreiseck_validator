import 'dart:convert';
import 'dart:io';

import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:test/test.dart';

List<Map<String, Object?>> _load(String file) =>
    (jsonDecode(File('test/vectors/$file').readAsStringSync()) as List)
        .cast<Map<String, Object?>>();

/// Every (type, options) pair covered by the descriptor vectors, paired with
/// its descriptor.
class _Type {
  const _Type(this.name, this.descriptor, this.formatValid);

  final String name;
  final FieldDescriptor Function() descriptor;

  /// Formats an already-valid value, or null when the type has no `format`
  /// that a partial formatter is expected to agree with.
  final String? Function(String)? formatValid;
}

final List<_Type> _types = [
  _Type('imei', Imei.fieldDescriptor, Imei.tryFormat),
  _Type('iccid', Iccid.fieldDescriptor, Iccid.tryFormat),
  _Type('vin', Vin.fieldDescriptor, Vin.tryFormat),
  _Type('credit_card', CreditCard.fieldDescriptor, CreditCard.tryFormat),
  _Type('iban', Iban.fieldDescriptor, Iban.tryFormat),
  _Type('mac_address', MacAddress.fieldDescriptor, MacAddress.tryFormat),
  _Type('email', Email.fieldDescriptor, null),
  _Type('url', Url.fieldDescriptor, null),
  _Type('host', Host.fieldDescriptor, null),
];

/// Converts a vector's `notation` string to [MacNotation]; defaults to
/// [MacNotation.colon], matching [MacAddress.formatPartial]'s own default.
MacNotation _notation(String? s) => switch (s) {
      'hyphen' => MacNotation.hyphen,
      'dot' => MacNotation.dot,
      'bare' => MacNotation.bare,
      _ => MacNotation.colon,
    };

void main() {
  // Each group filters the type list rather than returning early inside the
  // test body, so no test is generated that asserts nothing.
  group('example validity', () {
    for (final t in _types.where(
        (t) => t.formatValid != null && t.descriptor().example != null)) {
      test('${t.name} example is valid', () {
        final example = t.descriptor().example!;
        expect(t.formatValid!(example), isNotNull,
            reason: '${t.name} example "$example" does not validate');
      });
    }
  });

  group('example fits maxLength', () {
    for (final t in _types.where((t) {
      final d = t.descriptor();
      return d.example != null && d.maxLength != null;
    })) {
      test(t.name, () {
        final d = t.descriptor();
        expect(d.example!.length, lessThanOrEqualTo(d.maxLength!));
      });
    }
  });

  group('filter soundness', () {
    for (final t in _types.where((t) {
      final d = t.descriptor();
      return d.example != null && d.allowedChars != null;
    })) {
      test('${t.name} allowedChars admits its own example', () {
        final d = t.descriptor();
        expect(d.example!.replaceAll(RegExp('[${d.allowedChars}]'), ''), '',
            reason: '${t.name} example "${d.example}" contains characters '
                'its own allowedChars rejects');
      });
    }
  });

  group('agreement with format', () {
    for (final c in _load('credit_card.json')) {
      if (c['isValid'] != true || !c.containsKey('format')) continue;
      final input = c['input']! as String;
      test('credit_card: $input', () {
        expect(CreditCard.formatPartial(input), c['format']);
      });
    }
    for (final c in _load('iban.json')) {
      if (c['isValid'] != true || !c.containsKey('format')) continue;
      final input = c['input']! as String;
      final country = (c['normalized']! as String).substring(0, 2);
      test('iban: $input', () {
        expect(Iban.formatPartial(input, country: country), c['format']);
      });
    }
    for (final c in _load('imei.json')) {
      if (c['isValid'] != true || !c.containsKey('format')) continue;
      final input = c['input']! as String;
      final allowSv = c['allowSv'] as bool? ?? false;
      test('imei: $input', () {
        expect(Imei.formatPartial(input, allowSv: allowSv), c['format']);
      });
    }
    for (final c in _load('iccid.json')) {
      if (c['isValid'] != true || !c.containsKey('format')) continue;
      final input = c['input']! as String;
      test('iccid: $input', () {
        expect(Iccid.formatPartial(input), c['format']);
      });
    }
    for (final c in _load('mac.json')) {
      if (c['isValid'] != true || !c.containsKey('format')) continue;
      final input = c['input']! as String;
      final notation = _notation(c['notation'] as String?);
      final upperCase = c['upperCase'] as bool? ?? false;
      test('mac_address: $input', () {
        expect(
          MacAddress.formatPartial(input,
              notation: notation, upperCase: upperCase),
          c['format'],
        );
      });
    }
    for (final c in _load('vin.json')) {
      if (c['isValid'] != true || !c.containsKey('format')) continue;
      final input = c['input']! as String;
      test('vin: $input', () {
        expect(Vin.formatPartial(input), c['format']);
      });
    }
    for (final c in _load('postal_code.json')) {
      if (c['isValid'] != true || !c.containsKey('format')) continue;
      final input = c['input']! as String;
      final country = c['country']! as String;
      test('postal_code $country: $input', () {
        expect(PostalCode.formatPartial(input, country: country), c['format']);
      });
    }
    for (final c in _load('license_plate.json')) {
      if (c['isValid'] != true || !c.containsKey('format')) continue;
      final input = c['input']! as String;
      final country = c['country'] as String?;
      test('license_plate: $input', () {
        expect(
            LicensePlate.formatPartial(input, country: country), c['format']);
      });
    }
  });
}
