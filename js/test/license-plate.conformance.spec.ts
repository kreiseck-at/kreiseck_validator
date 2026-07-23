import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { LicensePlate } from '../src/license-plate/index';

type Parse = { country: string; districtCode: string; region: string | null; serial: string; type: string };
type Vec = { input: string; country?: string; isValid?: boolean; code?: string; normalized?: string; format?: string; parse?: Parse };
const vectors: Vec[] = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../test/vectors/license_plate.json', import.meta.url)), 'utf8'),
);

describe('license plate conformance', () => {
  for (const v of vectors) {
    it(`license_plate: ${v.input} (${v.country ?? 'inferred'})`, () => {
      const options = { country: v.country };
      const r = LicensePlate.validate(v.input, options);
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
      if (v.format !== undefined) expect(LicensePlate.format(v.input, options)).toBe(v.format);
      if (v.parse) {
        const info = LicensePlate.parse(v.input, options)!;
        expect(info.country).toBe(v.parse.country);
        expect(info.districtCode).toBe(v.parse.districtCode);
        expect(info.region).toBe(v.parse.region);
        expect(info.serial).toBe(v.parse.serial);
        expect(info.type).toBe(v.parse.type);
      }
    });
  }
});
