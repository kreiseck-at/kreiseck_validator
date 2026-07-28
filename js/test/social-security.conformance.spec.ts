import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { SocialSecurityNumber } from '../src/social-security/index';

type BirthDate = { day: number; month: number; twoDigitYear: number };
type Parse = { serial?: string; checkDigit?: string; birthDate?: BirthDate | null };
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
  readFileSync(fileURLToPath(new URL('../../test/vectors/social_security.json', import.meta.url)), 'utf8'),
);

describe('social security conformance', () => {
  for (const v of vectors) {
    it(`social_security: ${v.input} (${v.country})`, () => {
      const options = { country: v.country };
      const r = SocialSecurityNumber.validate(v.input, options);
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
      if (v.format !== undefined && r.ok) {
        expect(SocialSecurityNumber.format(v.input, options)).toBe(v.format);
      }
      if (v.parse) {
        const info = SocialSecurityNumber.parse(v.input, options)!;
        if (v.parse.serial !== undefined) expect(info.serial).toBe(v.parse.serial);
        if (v.parse.checkDigit !== undefined) expect(info.checkDigit).toBe(v.parse.checkDigit);
        if ('birthDate' in v.parse) {
          if (v.parse.birthDate === null) expect(info.birthDate).toBeNull();
          else expect(info.birthDate).toEqual(v.parse.birthDate);
        }
      }
    });
  }
});
