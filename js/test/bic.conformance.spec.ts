import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Bic } from '../src/bic/index';

type Parse = {
  institution?: string;
  country?: string;
  location?: string;
  branch?: string | null;
  kind?: string;
};
type Vec = { input: string; isValid?: boolean; code?: string; normalized?: string; format?: string; parse?: Parse };
const vectors: Vec[] = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../test/vectors/bic.json', import.meta.url)), 'utf8'),
);

describe('bic conformance', () => {
  for (const v of vectors) {
    it(`bic: ${v.input}`, () => {
      const r = Bic.validate(v.input);
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
      if (v.format !== undefined && r.ok) expect(Bic.format(v.input)).toBe(v.format);
      if (v.parse) {
        const info = Bic.parse(v.input)!;
        const p = v.parse;
        if (p.institution !== undefined) expect(info.institution).toBe(p.institution);
        if (p.country !== undefined) expect(info.country).toBe(p.country);
        if (p.location !== undefined) expect(info.location).toBe(p.location);
        if ('branch' in p) expect(info.branch).toBe(p.branch);
        if (p.kind !== undefined) expect(info.kind).toBe(p.kind);
      }
    });
  }
});

describe('Bic.matchesIban', () => {
  it('accepts a BIC and IBAN from the same country', () => {
    expect(Bic.matchesIban('BKAUATWW', 'AT61 1904 3002 3457 3201')).toBe(true);
  });
  it('rejects a country mismatch', () => {
    expect(Bic.matchesIban('COBADEFF', 'AT611904300234573201')).toBe(false);
  });
  it('rejects an unusable BIC', () => {
    expect(Bic.matchesIban('nonsense', 'AT611904300234573201')).toBe(false);
  });
  it('rejects an unusable IBAN', () => {
    expect(Bic.matchesIban('BKAUATWW', 'A')).toBe(false);
  });
});
