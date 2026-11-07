import 'dart:convert';
import 'dart:io';

import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:test/test.dart';

void main() {
  final vectors = (jsonDecode(
          File('test/vectors/external_voucher_number.json').readAsStringSync())
      as List);

  group('external_voucher_number', () {
    for (final c in vectors) {
      final input = c['input'] as String;
      test(jsonEncode(input), () {
        expect(ExternalVoucherNumber.isValid(input), c['isValid']);
        expect(ExternalVoucherNumber.normalize(input),
            c['isValid'] as bool ? c['normalized'] : isNull);
      });
    }
  });

  test('isOwnVoucherCode accepts own codes only', () {
    expect(isOwnVoucherCode('K7QM-3XRP-9DWF'), isTrue);
    expect(isOwnVoucherCode('K7QM3XRP9DWF'), isTrue);
    expect(isOwnVoucherCode('FG-1234'), isFalse);
  });
}
