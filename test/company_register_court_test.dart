import 'dart:convert';
import 'dart:io';

import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:test/test.dart';

void main() {
  final vec = jsonDecode(
          File('test/vectors/company_register_courts.json').readAsStringSync())
      as Map<String, Object?>;
  final courts = (vec['courts']! as List).cast<Map<String, Object?>>();
  final cases = (vec['cases']! as List).cast<Map<String, Object?>>();

  test('courts are exactly the vector list, in order', () {
    expect(CompanyRegister.courts.length, courts.length);
    for (var i = 0; i < courts.length; i++) {
      final c = CompanyRegister.courts[i];
      expect(c.code, courts[i]['code']);
      expect(c.name, courts[i]['name']);
      expect(c.city, courts[i]['city']);
      expect(c.bundesland, courts[i]['bundesland']);
      expect(c.bundeslandName, courts[i]['bundeslandName']);
    }
  });

  test('16 courts, one Handelsgericht, unique codes, ISO 3166-2:AT states', () {
    expect(CompanyRegister.courts, hasLength(16));
    expect(CompanyRegister.courts.where((c) => c.name.startsWith('Handelsgericht')),
        hasLength(1));
    expect(CompanyRegister.courts.map((c) => c.code).toSet(), hasLength(16));
    for (final c in CompanyRegister.courts) {
      expect(c.bundesland, matches(RegExp(r'^AT-[1-9]$')));
    }
  });

  for (final v in cases) {
    final input = v['input']! as String;
    final code = v['code'] as String?;
    test('court: "$input" -> $code', () {
      expect(CompanyRegister.court(input)?.code, code);
    });
  }

  test('every court resolves from its own name, city and code', () {
    for (final c in CompanyRegister.courts) {
      expect(CompanyRegister.court(c.name)?.code, c.code);
      expect(CompanyRegister.court(c.city)?.code, c.code);
      expect(CompanyRegister.court(c.code)?.code, c.code);
    }
  });
}
