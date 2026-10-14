import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { VoucherCode } from '../src/voucher-code/index';

type Vec = { input: string; isValid?: boolean; code?: string; normalized?: string; format?: string };
const vectors: Vec[] = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../test/vectors/voucher_code.json', import.meta.url)), 'utf8'),
);

const ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

describe('voucher code conformance', () => {
  for (const v of vectors) {
    it(`voucher_code: "${v.input}"`, () => {
      const r = VoucherCode.validate(v.input);
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
      if (v.format !== undefined && r.ok) expect(VoucherCode.format(v.input)).toBe(v.format);
    });
  }
});

describe('voucher code', () => {
  it('generate yields valid codes from 11 bytes', () => {
    for (let i = 0; i < 256; i++) {
      const bytes = Uint8Array.from({ length: 11 }, (_, j) => (i * 7 + j * 13) & 255);
      const code = VoucherCode.generate(bytes);
      expect(code.length).toBe(12);
      expect(VoucherCode.isValid(code)).toBe(true);
    }
  });

  it('generate needs at least 11 bytes', () => {
    expect(() => VoucherCode.generate(new Uint8Array(10))).toThrow();
  });

  it('every single-symbol error is detected', () => {
    const code = VoucherCode.generate(Uint8Array.from({ length: 11 }, (_, j) => j * 29));
    for (let pos = 0; pos < 12; pos++) {
      for (const ch of ALPHABET) {
        if (ch === code[pos]) continue;
        const wrong = code.slice(0, pos) + ch + code.slice(pos + 1);
        expect(VoucherCode.isValid(wrong), wrong).toBe(false);
      }
    }
  });

  it('every swap of two adjacent symbols is detected', () => {
    for (let seed = 0; seed < 64; seed++) {
      const code = VoucherCode.generate(Uint8Array.from({ length: 11 }, (_, j) => (seed * 31 + j * 17) & 255));
      for (let pos = 0; pos < 11; pos++) {
        if (code[pos] === code[pos + 1]) continue;
        const t = code.slice(0, pos) + code[pos + 1] + code[pos] + code.slice(pos + 2);
        expect(VoucherCode.isValid(t), t).toBe(false);
      }
    }
  });

  it('format groups as XXXX-XXXX-XXXX', () => {
    const code = VoucherCode.generate(new Uint8Array(11).fill(3));
    expect(VoucherCode.format(code.toLowerCase())).toMatch(/^[0-9A-Z]{4}-[0-9A-Z]{4}-[0-9A-Z]{4}$/);
  });

  it('tryFormat returns null on invalid input', () => {
    expect(VoucherCode.tryFormat('nope')).toBeNull();
  });

  it('checkSymbol matches the generated code', () => {
    expect(VoucherCode.checkSymbol('K7QM3XRP9DW')).toBe('F');
  });
});
