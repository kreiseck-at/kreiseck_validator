import 'dart:convert';
import 'dart:io';

import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:test/test.dart';

Country? _country(String? s) => s == null ? null : Country.fromIso2(s);

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
