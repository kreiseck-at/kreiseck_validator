import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { MacAddress } from '../src/mac-address/index';
import type { MacNotation } from '../src/mac-address/types';

type Parse = {
  oui?: string;
  nic?: string;
  isUnicast?: boolean;
  isMulticast?: boolean;
  isUniversal?: boolean;
  isLocal?: boolean;
  type?: string;
};
type Vec = {
  input: string;
  isValid?: boolean;
  code?: string;
  normalized?: string;
  format?: string;
  notation?: MacNotation;
  upperCase?: boolean;
  parse?: Parse;
};
const vectors: Vec[] = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../test/vectors/mac.json', import.meta.url)), 'utf8'),
);

describe('mac_address conformance', () => {
  for (const v of vectors) {
    it(`mac_address: ${v.input}`, () => {
      const r = MacAddress.validate(v.input);
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
      if (v.format !== undefined) {
        const opts = { notation: v.notation ?? 'colon', upperCase: v.upperCase ?? false };
        expect(MacAddress.format(v.input, opts)).toBe(v.format);
      }
      if (v.parse) {
        const info = MacAddress.parse(v.input)!;
        const p = v.parse;
        if (p.oui !== undefined) expect(info.oui).toBe(p.oui);
        if (p.nic !== undefined) expect(info.nic).toBe(p.nic);
        if (p.isUnicast !== undefined) expect(info.isUnicast).toBe(p.isUnicast);
        if (p.isMulticast !== undefined) expect(info.isMulticast).toBe(p.isMulticast);
        if (p.isUniversal !== undefined) expect(info.isUniversal).toBe(p.isUniversal);
        if (p.isLocal !== undefined) expect(info.isLocal).toBe(p.isLocal);
        if (p.type !== undefined) expect(info.type).toBe(p.type);
      }
    });
  }
});
