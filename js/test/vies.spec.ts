import { describe, it, expect } from 'vitest';
import { VatId } from '../src/vat-id/index';

// Both halves of the VIES seam are pure functions over strings -- the package
// never makes the call. The response bodies below were captured from the live
// service while this was implemented.

describe('viesRequest', () => {
  it('builds a request for a valid number', () => {
    const r = VatId.viesRequest('ATU16210507')!;
    expect(r.url).toBe(
      'https://ec.europa.eu/taxation_customs/vies/rest-api/ms/AT/vat/U16210507');
    expect(r.method).toBe('GET');
    expect(r.headers.Accept).toBe('application/json');
  });
  it('keeps the tax spelling in the path, not the ISO one', () => {
    expect(VatId.viesRequest('EL094259216')!.url).toContain('/ms/EL/vat/');
    expect(VatId.viesRequest('XI220430231')!.url).toContain('/ms/XI/vat/');
  });
  it('returns null for an invalid number', () => {
    expect(VatId.viesRequest('ATU16210508')).toBeNull();
  });
  it('returns null for Switzerland, which VIES does not cover', () => {
    expect(VatId.isValid('CHE116281710')).toBe(true);
    expect(VatId.viesRequest('CHE116281710')).toBeNull();
  });
});

describe('parseViesResponse', () => {
  it('reads a positive answer with a disclosed name', () => {
    const body = '{"isValid":true,"requestDate":"2026-07-28T08:46:06.285Z",'
      + '"userError":"VALID","name":"FERRARI N.V.",'
      + '"address":"VIA ABETONE INFERIORE 4","vatNumber":"03656470360"}';
    const reg = VatId.parseViesResponse(body)!;
    expect(reg.valid).toBe(true);
    expect(reg.name).toBe('FERRARI N.V.');
    expect(reg.address).toBe('VIA ABETONE INFERIORE 4');
    expect(reg.requestDate).toBe('2026-07-28T08:46:06.285Z');
  });
  it('treats a withheld name as absent, not as the string "---"', () => {
    const reg = VatId.parseViesResponse(
      '{"isValid":true,"userError":"VALID","name":"---","address":"---"}')!;
    expect(reg.valid).toBe(true);
    expect(reg.name).toBeNull();
    expect(reg.address).toBeNull();
  });
  it('reads a negative answer', () => {
    const reg = VatId.parseViesResponse(
      '{"isValid":false,"userError":"INVALID","name":"","address":""}')!;
    expect(reg.valid).toBe(false);
    expect(reg.name).toBeNull();
  });
  it('returns null when the member state was too busy', () => {
    // Captured from a real FR lookup: this is not a rejection, and reading it
    // as one would refuse a valid customer.
    expect(VatId.parseViesResponse(
      '{"isValid":false,"userError":"MS_MAX_CONCURRENT_REQ"}')).toBeNull();
  });
  it('returns null when the member state was unavailable', () => {
    expect(VatId.parseViesResponse(
      '{"isValid":false,"userError":"MS_UNAVAILABLE"}')).toBeNull();
  });
  it('returns null for malformed or unexpected bodies', () => {
    expect(VatId.parseViesResponse('not json')).toBeNull();
    expect(VatId.parseViesResponse('[]')).toBeNull();
    expect(VatId.parseViesResponse('{}')).toBeNull();
  });
});
