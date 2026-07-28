import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { VatId } from '../src/vat-id/index';
import { kVatFormats } from '../src/vat-id/metadata';

type Parse = { country?: string; prefix?: string; number?: string; subtype?: string };
type Vec = {
  input: string;
  country?: string;
  isValid?: boolean;
  code?: string;
  normalized?: string;
  format?: string;
  parse?: Parse;
};
const vectors: Vec[] = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../test/vectors/vat_id.json', import.meta.url)), 'utf8'),
);

describe('vat id conformance', () => {
  for (const v of vectors) {
    it(`vat_id: ${v.input}${v.country ? ` (${v.country})` : ''}`, () => {
      const options = v.country === undefined ? {} : { country: v.country };
      const r = VatId.validate(v.input, options);
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
      if (v.format !== undefined && r.ok) expect(VatId.format(v.input, options)).toBe(v.format);
      if (v.parse) {
        const info = VatId.parse(v.input, options)!;
        if (v.parse.country !== undefined) expect(info.country).toBe(v.parse.country);
        if (v.parse.prefix !== undefined) expect(info.prefix).toBe(v.parse.prefix);
        if (v.parse.number !== undefined) expect(info.number).toBe(v.parse.number);
        if (v.parse.subtype !== undefined) expect(info.subtype).toBe(v.parse.subtype);
      }
    });
  }
});

describe('vat id metadata', () => {
  it('covers 30 prefixes', () => {
    expect(Object.keys(kVatFormats).length).toBe(30);
  });
  it('spells Greece EL and keeps the ISO key GR', () => {
    expect(kVatFormats.GR.prefix).toBe('EL');
    expect(kVatFormats.EL).toBeUndefined();
  });
  it('every bundled example validates and round-trips', () => {
    for (const [iso2, f] of Object.entries(kVatFormats)) {
      if (f.example === null) continue;
      expect(VatId.isValid(f.example), `${iso2} example ${f.example}`).toBe(true);
      expect(VatId.normalize(f.example)).toBe(f.example);
    }
  });
});
