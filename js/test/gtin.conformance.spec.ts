import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Gtin } from '../src/gtin/index';

type Parse = { length?: number; checkDigit?: string; gtin14?: string };
type Vec = { input: string; isValid?: boolean; code?: string; normalized?: string; format?: string; parse?: Parse };
const vectors: Vec[] = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../test/vectors/gtin.json', import.meta.url)), 'utf8'),
);

describe('gtin conformance', () => {
  for (const v of vectors) {
    it(`gtin: ${v.input}`, () => {
      const r = Gtin.validate(v.input);
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
      if (v.format !== undefined && r.ok) expect(Gtin.format(v.input)).toBe(v.format);
      if (v.parse) {
        const info = Gtin.parse(v.input)!;
        if (v.parse.length !== undefined) expect(info.length).toBe(v.parse.length);
        if (v.parse.checkDigit !== undefined) expect(info.checkDigit).toBe(v.parse.checkDigit);
        if (v.parse.gtin14 !== undefined) expect(info.gtin14).toBe(v.parse.gtin14);
      }
    });
  }
});

describe('Gtin.checkDigit', () => {
  it('completes a 12-digit body into a valid EAN-13', () => {
    expect(Gtin.checkDigit('400638133393')).toBe('1');
    expect(Gtin.isValid('400638133393' + Gtin.checkDigit('400638133393'))).toBe(true);
  });
  it('completes a 7-digit body into a valid GTIN-8', () => {
    expect(Gtin.checkDigit('9638507')).toBe('4');
  });
});
