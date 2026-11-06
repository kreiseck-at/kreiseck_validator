import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { ExternalVoucherNumber, isOwnVoucherCode } from '../src/external-voucher-number/index';

type Vec = { input: string; isValid: boolean; normalized?: string };
const vectors: Vec[] = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../test/vectors/external_voucher_number.json', import.meta.url)), 'utf8'),
);

describe('external voucher number conformance', () => {
  for (const v of vectors) {
    it(`external_voucher_number: ${JSON.stringify(v.input)}`, () => {
      expect(ExternalVoucherNumber.isValid(v.input)).toBe(v.isValid);
      expect(ExternalVoucherNumber.normalize(v.input)).toBe(v.isValid ? v.normalized : null);
    });
  }
});

describe('external voucher number', () => {
  it('composes to NFC before checking', () => {
    // "e" + combining acute is not in the allowed set, even after composing
    expect(ExternalVoucherNumber.normalize('é')).toBeNull();
  });

  it('isOwnVoucherCode accepts own codes only', () => {
    expect(isOwnVoucherCode('K7QM-3XRP-9DWF')).toBe(true);
    expect(isOwnVoucherCode('K7QM3XRP9DWF')).toBe(true);
    expect(isOwnVoucherCode('FG-1234')).toBe(false);
  });
});
