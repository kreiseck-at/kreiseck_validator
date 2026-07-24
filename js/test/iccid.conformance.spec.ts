import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Iccid } from '../src/iccid/index';

type Parse = { mii: string; country: string | null; issuerIdentifier: string; checkDigit: string | null };
type Vec = { input: string; isValid?: boolean; code?: string; normalized?: string; format?: string; parse?: Parse };
const vectors: Vec[] = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../test/vectors/iccid.json', import.meta.url)), 'utf8'),
);

describe('iccid conformance', () => {
  for (const v of vectors) {
    it(`iccid: ${v.input}`, () => {
      const r = Iccid.validate(v.input);
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
      if (v.format !== undefined && r.ok) expect(Iccid.format(v.input)).toBe(v.format);
      if (v.parse) {
        const info = Iccid.parse(v.input)!;
        expect(info.mii).toBe(v.parse.mii);
        expect(info.country?.iso2 ?? null).toBe(v.parse.country);
        expect(info.issuerIdentifier).toBe(v.parse.issuerIdentifier);
        expect(info.checkDigit).toBe(v.parse.checkDigit);
      }
    });
  }
});
