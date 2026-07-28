import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { TaxNumber } from '../src/tax-number/index';

type Parse = { office?: string; number?: string; checkDigit?: string };
type Vec = {
  input: string;
  country: string;
  isValid?: boolean;
  code?: string;
  normalized?: string;
  format?: string;
  parse?: Parse;
};
const vectors: Vec[] = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../test/vectors/tax_number.json', import.meta.url)), 'utf8'),
);

describe('tax number conformance', () => {
  for (const v of vectors) {
    it(`tax_number: ${v.input} (${v.country})`, () => {
      const options = { country: v.country };
      const r = TaxNumber.validate(v.input, options);
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
      if (v.format !== undefined && r.ok) expect(TaxNumber.format(v.input, options)).toBe(v.format);
      if (v.parse) {
        const info = TaxNumber.parse(v.input, options)!;
        if (v.parse.office !== undefined) expect(info.office).toBe(v.parse.office);
        if (v.parse.number !== undefined) expect(info.number).toBe(v.parse.number);
        if (v.parse.checkDigit !== undefined) expect(info.checkDigit).toBe(v.parse.checkDigit);
      }
    });
  }
});
