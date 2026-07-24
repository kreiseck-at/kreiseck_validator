import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Vin } from '../src/vin/index';

type Parse = {
  wmi?: string;
  vds?: string;
  vis?: string;
  checkDigit?: string;
  checkDigitValid?: boolean;
  modelYear?: number;
  plantCode?: string;
};
type Vec = { input: string; isValid?: boolean; code?: string; normalized?: string; format?: string; parse?: Parse };
const vectors: Vec[] = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../test/vectors/vin.json', import.meta.url)), 'utf8'),
);

describe('vin conformance', () => {
  for (const v of vectors) {
    it(`vin: ${v.input}`, () => {
      const r = Vin.validate(v.input);
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
      if (v.format !== undefined && r.ok) expect(Vin.format(v.input)).toBe(v.format);
      if (v.parse) {
        const info = Vin.parse(v.input)!;
        const p = v.parse;
        if (p.wmi !== undefined) expect(info.wmi).toBe(p.wmi);
        if (p.vds !== undefined) expect(info.vds).toBe(p.vds);
        if (p.vis !== undefined) expect(info.vis).toBe(p.vis);
        if (p.checkDigit !== undefined) expect(info.checkDigit).toBe(p.checkDigit);
        if (p.checkDigitValid !== undefined) expect(info.checkDigitValid).toBe(p.checkDigitValid);
        if (p.modelYear !== undefined) expect(info.modelYear).toBe(p.modelYear);
        if (p.plantCode !== undefined) expect(info.plantCode).toBe(p.plantCode);
      }
    });
  }
});
