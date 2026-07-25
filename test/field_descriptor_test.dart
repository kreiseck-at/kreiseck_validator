import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:kreiseck_validator/src/common/partial_format.dart';
import 'package:test/test.dart';

void main() {
  group('groupEvery', () {
    test('leaves short input untouched', () {
      expect(groupEvery('AT6', 4, ' '), 'AT6');
      expect(groupEvery('AT61', 4, ' '), 'AT61');
    });

    test('inserts separators without a trailing one', () {
      expect(groupEvery('AT611', 4, ' '), 'AT61 1');
      expect(groupEvery('AT611904', 4, ' '), 'AT61 1904');
      expect(groupEvery('AABBCC', 2, ':'), 'AA:BB:CC');
    });

    test('handles empty input', () {
      expect(groupEvery('', 4, ' '), '');
    });
  });

  group('groupWidths', () {
    test('applies widths in order', () {
      expect(groupWidths('378282246310005', const [4, 6, 5], ' '),
          '3782 822463 10005');
      expect(groupWidths('37828', const [4, 6, 5], ' '), '3782 8');
    });

    test('appends characters beyond the last width', () {
      expect(groupWidths('3782822463100051', const [4, 6, 5], ' '),
          '3782 822463 100051');
    });
  });

  group('prepare', () {
    const vin = FieldDescriptor(
      keyboard: KeyboardType.text,
      capitalization: Capitalization.characters,
      allowedChars: '0-9A-HJ-NPR-Z',
    );

    test('upper-cases before filtering', () {
      expect(prepare('1hgcm8', vin), '1HGCM8');
    });

    test('drops characters outside allowedChars', () {
      expect(prepare('1HGC-M8', vin), '1HGCM8');
      expect(prepare('1HGCIOQ', vin), '1HGC');
    });

    test('removes separators when asked', () {
      const iban = FieldDescriptor(
        keyboard: KeyboardType.text,
        capitalization: Capitalization.characters,
        allowedChars: '0-9A-Z ',
      );
      expect(prepare('AT61 1904', iban, separators: ' '), 'AT611904');
    });

    test('truncates to maxSignificant', () {
      expect(prepare('1HGCM82633A004352XYZ', vin, maxSignificant: 17),
          '1HGCM82633A004352');
    });

    test('leaves case alone when capitalization is none', () {
      const host = FieldDescriptor(keyboard: KeyboardType.url);
      expect(prepare('Example.COM', host), 'Example.COM');
    });
  });
}
