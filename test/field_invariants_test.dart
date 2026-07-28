import 'dart:convert';
import 'dart:io';

import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:kreiseck_validator/src/common/partial_format.dart';
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

/// Resolves a phone country, or null for the generic form.
Country? _country(String? iso2) => iso2 == null ? null : Country.fromIso2(iso2);

final List<_Type> _types = [
  _Type('imei', Imei.fieldDescriptor, Imei.tryFormat),
  _Type('iccid', Iccid.fieldDescriptor, Iccid.tryFormat),
  _Type('vin', Vin.fieldDescriptor, Vin.tryFormat),
  _Type('credit_card', CreditCard.fieldDescriptor, CreditCard.tryFormat),
  _Type('iban', Iban.fieldDescriptor, Iban.tryFormat),
  _Type('mac_address', MacAddress.fieldDescriptor, MacAddress.tryFormat),
  // Country-dependent types: the generic (no-country) descriptor never has
  // an example, so only a per-country entry exercises the example-validity,
  // maxLength-fit and filter-soundness groups below.
  _Type('postal_code:AT', () => PostalCode.fieldDescriptor(country: 'AT'),
      (v) => PostalCode.tryFormat(v, country: 'AT')),
  _Type('postal_code:DE', () => PostalCode.fieldDescriptor(country: 'DE'),
      (v) => PostalCode.tryFormat(v, country: 'DE')),
  _Type('postal_code:NL', () => PostalCode.fieldDescriptor(country: 'NL'),
      (v) => PostalCode.tryFormat(v, country: 'NL')),
  _Type('postal_code:GB', () => PostalCode.fieldDescriptor(country: 'GB'),
      (v) => PostalCode.tryFormat(v, country: 'GB')),
  _Type('license_plate:AT', () => LicensePlate.fieldDescriptor(country: 'AT'),
      (v) => LicensePlate.tryFormat(v, country: 'AT')),
  _Type('license_plate:DE', () => LicensePlate.fieldDescriptor(country: 'DE'),
      (v) => LicensePlate.tryFormat(v, country: 'DE')),
  // Phone.fieldDescriptor's example is always null (never invented, see
  // Phone.fieldDescriptor's doc comment), so this entry contributes no
  // assertions to the example-based groups below; it is listed anyway so the
  // type is represented and picks up coverage automatically if that ever
  // changes.
  _Type('phone:AT', () => Phone.fieldDescriptor(country: _country('AT')),
      (v) => Phone.tryFormat(v, country: _country('AT'))),
  _Type('bic', Bic.fieldDescriptor, Bic.tryFormat),
  _Type('gtin', Gtin.fieldDescriptor, Gtin.tryFormat),
  _Type('vat_id:AT', () => VatId.fieldDescriptor(country: 'AT'),
      (v) => VatId.tryFormat(v, country: 'AT')),
  _Type('vat_id:NL', () => VatId.fieldDescriptor(country: 'NL'),
      (v) => VatId.tryFormat(v, country: 'NL')),
  _Type(
      'social_security:AT',
      () => SocialSecurityNumber.fieldDescriptor(country: 'AT'),
      (v) => SocialSecurityNumber.tryFormat(v, country: 'AT')),
  _Type('tax_number:AT', () => TaxNumber.fieldDescriptor(country: 'AT'),
      (v) => TaxNumber.tryFormat(v, country: 'AT')),
  // CompanyRegister's `format` prepends a presentational `FN `, which
  // `formatPartial` deliberately does not while the user is still typing, so
  // this type has no format for a partial formatter to agree with -- the same
  // situation as email, url and host below.
  _Type('company_register:AT',
      () => CompanyRegister.fieldDescriptor(country: 'AT'), null),
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

/// Resolves any (type, options) pair from `format_partial.json` to its
/// descriptor -- a superset of [_types] above, since the vectors cover
/// options combinations (e.g. every `MacNotation`) that [_types] doesn't
/// enumerate one-by-one.
FieldDescriptor _descriptorForPartial(String type, Map<String, Object?> o) =>
    switch (type) {
      'imei' => Imei.fieldDescriptor(allowSv: o['allowSv'] as bool? ?? false),
      'iccid' => Iccid.fieldDescriptor(),
      'vin' => Vin.fieldDescriptor(),
      'iban' => Iban.fieldDescriptor(country: o['country'] as String?),
      'credit_card' => CreditCard.fieldDescriptor(),
      'mac_address' => MacAddress.fieldDescriptor(
          notation: _notation(o['notation'] as String?),
          upperCase: o['upperCase'] as bool? ?? false,
        ),
      'postal_code' =>
        PostalCode.fieldDescriptor(country: o['country'] as String?),
      'license_plate' =>
        LicensePlate.fieldDescriptor(country: o['country'] as String?),
      'phone' => Phone.fieldDescriptor(country: _country(o['country'] as String?)),
      'bic' => Bic.fieldDescriptor(),
      'gtin' => Gtin.fieldDescriptor(),
      'vat_id' => VatId.fieldDescriptor(country: o['country'] as String?),
      'social_security' =>
        SocialSecurityNumber.fieldDescriptor(country: o['country'] as String?),
      'company_register' =>
        CompanyRegister.fieldDescriptor(country: o['country'] as String?),
      'tax_number' =>
        TaxNumber.fieldDescriptor(country: o['country'] as String?),
      'email' => Email.fieldDescriptor(),
      'url' => Url.fieldDescriptor(),
      'host' => Host.fieldDescriptor(),
      _ => throw ArgumentError('unknown type $type'),
    };

String _partialForType(String type, String input, Map<String, Object?> o) =>
    switch (type) {
      'imei' =>
        Imei.formatPartial(input, allowSv: o['allowSv'] as bool? ?? false),
      'iccid' => Iccid.formatPartial(input),
      'vin' => Vin.formatPartial(input),
      'iban' => Iban.formatPartial(input, country: o['country'] as String?),
      'credit_card' => CreditCard.formatPartial(input),
      'mac_address' => MacAddress.formatPartial(
          input,
          notation: _notation(o['notation'] as String?),
          upperCase: o['upperCase'] as bool? ?? false,
        ),
      'postal_code' =>
        PostalCode.formatPartial(input, country: o['country'] as String?),
      'license_plate' =>
        LicensePlate.formatPartial(input, country: o['country'] as String?),
      'phone' =>
        Phone.formatPartial(input, country: _country(o['country'] as String?)),
      'bic' => Bic.formatPartial(input),
      'gtin' => Gtin.formatPartial(input),
      'vat_id' => VatId.formatPartial(input, country: o['country'] as String?),
      'social_security' => SocialSecurityNumber.formatPartial(input,
          country: o['country'] as String?),
      'company_register' => CompanyRegister.formatPartial(input,
          country: o['country'] as String?),
      'tax_number' =>
        TaxNumber.formatPartial(input, country: o['country'] as String?),
      'email' => Email.formatPartial(input),
      'url' => Url.formatPartial(input),
      'host' => Host.formatPartial(input),
      _ => throw ArgumentError('unknown type $type'),
    };

/// Mirrors [Host.formatPartial]'s filter step (drop disallowed ASCII
/// characters, keep every non-ASCII one) without its length cap -- used as
/// this test's "steps 1-2, untruncated" baseline for `host` instead of the
/// generic [prepare], since a plain [FieldDescriptor.allowedChars] filter
/// would (wrongly, for this check) also drop the non-ASCII characters
/// [Host.formatPartial] deliberately keeps (see its doc comment).
String _hostFiltered(String input, String allowedChars) {
  final allowed = RegExp('[$allowedChars]');
  final b = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final ch = input[i];
    if (input.codeUnitAt(i) > 0x7f || allowed.hasMatch(ch)) b.write(ch);
  }
  return b.toString();
}

/// The separator characters step 4 (grouping) is allowed to insert into a
/// type's `formatPartial` output, or null when the type never groups
/// (filter/truncate-only or identity types). Used to strip exactly those
/// characters back out so what remains is the significant-character
/// sequence, for comparison against the input run through steps 1-3 alone.
String? _groupingSeparatorsOf(String type, Map<String, Object?> o) =>
    switch (type) {
      'credit_card' => ' ',
      'iban' => ' ',
      'mac_address' => switch (_notation(o['notation'] as String?)) {
          MacNotation.colon => ':',
          MacNotation.hyphen => '-',
          MacNotation.dot => '.',
          MacNotation.bare => null,
        },
      // Every postal country's separator (see PostalPattern.format) is
      // either ' ' or '-'; the compact form never contains either as
      // content, so stripping both universally is safe regardless of
      // country.
      'postal_code' => ' -',
      // LicensePlate accepts '.', '-' and ' ' as typed separators (see
      // LicensePlate.fieldDescriptor's doc comment) but format() only ever
      // emits ' ' and '-'; including '.' in the strip set is harmless.
      'license_plate' => ' .-',
      'phone' => ' ',
      'social_security' => ' ',
      // TaxNumber.format writes 12-345/6789: two different separators, both
      // inserted by the grouping step and neither ever content.
      'tax_number' => '/-',
      _ => null, // imei, iccid, vin, bic, gtin, vat_id, email, url, host.
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

  // Guarantee 3 (character fidelity): the sequence of significant characters
  // -- everything that isn't a separator step 4 (grouping) inserts -- is
  // preserved in order. Only filtering (step 2) removes a character and only
  // truncation (step 3) removes a suffix; grouping itself must never
  // reorder, invent or drop one. This is what a Flutter companion package's
  // cursor mapping depends on.
  group('character fidelity', () {
    for (final c in _load('format_partial.json')) {
      final type = c['type']! as String;
      final input = c['input']! as String;
      final options = (c['options'] as Map?)?.cast<String, Object?>() ?? {};
      test('$type preserves significant character order: "$input"', () {
        final d = _descriptorForPartial(type, options);
        final output = _partialForType(type, input, options);
        final sep = _groupingSeparatorsOf(type, options);

        // Steps 1-2 (case, filter) applied to the input, with no truncation
        // -- the case-insensitive superset every valid prefix of the actual
        // output must come from. Case is normalized on both sides because a
        // couple of types (e.g. MacAddress with upperCase: false) apply a
        // final case pass outside the descriptor's own `capitalization`;
        // that's a casing detail, not a reordering one, so it must not make
        // this check spuriously fail.
        var expectedFull = (switch (type) {
          'host' => _hostFiltered(input, d.allowedChars!),
          // CompanyRegister strips a leading `FN`, which its allowedChars
          // otherwise admits (F and N are letters). That prefix is
          // presentation, not content, so the baseline has to drop it too --
          // the same kind of documented deviation as `host` above.
          'company_register' =>
            prepare(input.replaceFirst(RegExp(r'^\s*[Ff][Nn][\s.]*'), ''), d),
          _ => prepare(input, d),
        })
            .toUpperCase();
        var actualSignificant = output.toUpperCase();
        if (sep != null) {
          final sepRe = RegExp('[$sep]');
          expectedFull = expectedFull.replaceAll(sepRe, '');
          actualSignificant = actualSignificant.replaceAll(sepRe, '');
        }

        // Truncation only ever removes a suffix, so whatever length the
        // actual significant output has, it must be a PREFIX of the fully
        // filtered/cased (untruncated) input -- this catches reordering
        // without hard-coding each type's truncation cap (which, e.g. for
        // CreditCard, depends on the detected network).
        expect(actualSignificant.length <= expectedFull.length, isTrue,
            reason: '$type: formatPartial("$input") -> "$output" produced '
                'more significant characters ("$actualSignificant") than '
                'filtering the input could ever produce ("$expectedFull")');
        expect(
          actualSignificant,
          expectedFull.substring(0, actualSignificant.length),
          reason: '$type: formatPartial("$input") -> "$output" reordered, '
              'invented or dropped a significant character beyond '
              'filtering and truncation',
        );
      });
    }
  });
}
