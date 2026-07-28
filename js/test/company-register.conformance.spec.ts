import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { CompanyRegister } from '../src/company-register/index';

type Parse = { number?: string; checkChar?: string };
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
  readFileSync(fileURLToPath(new URL('../../test/vectors/company_register.json', import.meta.url)), 'utf8'),
);

describe('company register conformance', () => {
  for (const v of vectors) {
    it(`company_register: ${v.input} (${v.country})`, () => {
      const options = { country: v.country };
      const r = CompanyRegister.validate(v.input, options);
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
      if (v.format !== undefined && r.ok) expect(CompanyRegister.format(v.input, options)).toBe(v.format);
      if (v.parse) {
        const info = CompanyRegister.parse(v.input, options)!;
        if (v.parse.number !== undefined) expect(info.number).toBe(v.parse.number);
        if (v.parse.checkChar !== undefined) expect(info.checkChar).toBe(v.parse.checkChar);
      }
    });
  }
});

describe('CompanyRegister.checkChar', () => {
  // Every one of these is a real, published Firmenbuchnummer; see
  // doc/algorithms.md for where each came from.
  const real: [string, string][] = [
    ['415772', 'f'], ['187010', 's'], ['536480', 't'], ['512160', 'b'],
    ['271797', 'b'], ['270943', 'x'], ['247642', 'f'], ['254941', 'p'],
    ['71396', 'w'], ['93363', 'z'], ['77676', 'f'], ['94684', 't'],
  ];
  for (const [digits, letter] of real) {
    it(`computes ${letter} for ${digits}`, () => {
      expect(CompanyRegister.checkChar(digits)).toBe(letter);
    });
  }
  it('does not follow the folklore mod-26 rule', () => {
    // 'number mod 26' would give 'g' for 415772; the real letter is 'f'.
    expect(CompanyRegister.checkChar('415772')).not.toBe('g');
  });
});
