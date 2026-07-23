import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Iban } from '../src/iban/index';

type Parse = { country: string; checkDigits: string; bankCode: string | null; branchCode: string | null; accountNumber: string | null; bankName: string | null; bic: string | null };
type Vec = { input: string; isValid?: boolean; code?: string; normalized?: string; format?: string; parse?: Parse };
const vectors: Vec[] = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../test/vectors/iban.json', import.meta.url)), 'utf8'),
);

describe('iban conformance', () => {
  for (const v of vectors) {
    it(`iban: ${v.input}`, () => {
      const r = Iban.validate(v.input);
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
      if (v.format !== undefined) expect(Iban.format(v.input)).toBe(v.format);
      if (v.parse) {
        const info = Iban.parse(v.input)!;
        expect(info.country).toBe(v.parse.country); // country exposed as ISO2 string
        expect(info.checkDigits).toBe(v.parse.checkDigits);
        expect(info.bankCode).toBe(v.parse.bankCode);
        expect(info.branchCode).toBe(v.parse.branchCode);
        expect(info.accountNumber).toBe(v.parse.accountNumber);
        expect(info.bankName).toBe(v.parse.bankName);
        expect(info.bic).toBe(v.parse.bic);
      }
    });
  }
});
