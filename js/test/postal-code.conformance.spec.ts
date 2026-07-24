import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { PostalCode } from '../src/postal-code/index';

type Parse = { country: string; code: string };
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
  readFileSync(fileURLToPath(new URL('../../test/vectors/postal_code.json', import.meta.url)), 'utf8'),
);

describe('postal code conformance', () => {
  for (const v of vectors) {
    it(`postal_code: ${v.input} (${v.country})`, () => {
      const options = { country: v.country };
      const r = PostalCode.validate(v.input, options);
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
      if (v.format !== undefined) expect(PostalCode.format(v.input, options)).toBe(v.format);
      if (v.parse) {
        const info = PostalCode.parse(v.input, options)!;
        expect(info.country).toBe(v.parse.country);
        expect(info.code).toBe(v.parse.code);
      }
    });
  }
});
