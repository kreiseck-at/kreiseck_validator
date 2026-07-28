import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:test/test.dart';

/// Both halves of the VIES seam are pure functions over strings — the package
/// never makes the call. The response bodies below were captured from the live
/// service while this was implemented.
void main() {
  group('viesRequest', () {
    test('builds a request for a valid number', () {
      final r = VatId.viesRequest('ATU16210507')!;
      expect(
          r.url,
          'https://ec.europa.eu/taxation_customs/vies/rest-api/ms/AT/vat/'
          'U16210507');
      expect(r.method, 'GET');
      expect(r.headers['Accept'], 'application/json');
    });

    test('keeps the tax spelling in the path, not the ISO one', () {
      expect(VatId.viesRequest('EL094259216')!.url, contains('/ms/EL/vat/'));
      expect(VatId.viesRequest('XI220430231')!.url, contains('/ms/XI/vat/'));
    });

    test('returns null for an invalid number', () {
      expect(VatId.viesRequest('ATU16210508'), isNull);
    });

    test('returns null for Switzerland, which VIES does not cover', () {
      expect(VatId.isValid('CHE116281710'), isTrue);
      expect(VatId.viesRequest('CHE116281710'), isNull);
    });
  });

  group('parseViesResponse', () {
    test('reads a positive answer with a disclosed name', () {
      const body = '{"isValid":true,"requestDate":"2026-07-28T08:46:06.285Z",'
          '"userError":"VALID","name":"FERRARI N.V.",'
          '"address":"VIA ABETONE INFERIORE 4","vatNumber":"03656470360"}';
      final reg = VatId.parseViesResponse(body)!;
      expect(reg.valid, isTrue);
      expect(reg.name, 'FERRARI N.V.');
      expect(reg.address, 'VIA ABETONE INFERIORE 4');
      expect(reg.requestDate, '2026-07-28T08:46:06.285Z');
    });

    test('treats a withheld name as absent, not as the string "---"', () {
      const body = '{"isValid":true,"userError":"VALID","name":"---",'
          '"address":"---"}';
      final reg = VatId.parseViesResponse(body)!;
      expect(reg.valid, isTrue);
      expect(reg.name, isNull);
      expect(reg.address, isNull);
    });

    test('reads a negative answer', () {
      const body = '{"isValid":false,"userError":"INVALID","name":"",'
          '"address":""}';
      final reg = VatId.parseViesResponse(body)!;
      expect(reg.valid, isFalse);
      expect(reg.name, isNull);
    });

    test('returns null when the member state was too busy', () {
      // Captured from a real FR lookup: this is not a rejection, and reading
      // it as one would refuse a valid customer.
      const body = '{"isValid":false,"userError":"MS_MAX_CONCURRENT_REQ"}';
      expect(VatId.parseViesResponse(body), isNull);
    });

    test('returns null when the member state was unavailable', () {
      expect(
          VatId.parseViesResponse('{"isValid":false,"userError":"MS_UNAVAILABLE"}'),
          isNull);
    });

    test('returns null for malformed or unexpected bodies', () {
      expect(VatId.parseViesResponse('not json'), isNull);
      expect(VatId.parseViesResponse('[]'), isNull);
      expect(VatId.parseViesResponse('{}'), isNull);
    });
  });
}
