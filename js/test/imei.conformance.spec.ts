import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Imei } from '../src/imei/index';

type Parse = { tac: string; serialNumber: string; checkDigit: string; reportingBodyIdentifier: string };
type Vec = { input: string; isValid?: boolean; code?: string; normalized?: string; format?: string; parse?: Parse };
const vectors: Vec[] = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../test/vectors/imei.json', import.meta.url)), 'utf8'),
);

describe('imei conformance', () => {
  for (const v of vectors) {
    it(`imei: ${v.input}`, () => {
      const r = Imei.validate(v.input);
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
      if (v.format !== undefined && r.ok) expect(Imei.format(v.input)).toBe(v.format);
      if (v.parse) {
        const info = Imei.parse(v.input)!;
        expect(info.tac).toBe(v.parse.tac);
        expect(info.serialNumber).toBe(v.parse.serialNumber);
        expect(info.checkDigit).toBe(v.parse.checkDigit);
        expect(info.reportingBodyIdentifier).toBe(v.parse.reportingBodyIdentifier);
      }
    });
  }
});
