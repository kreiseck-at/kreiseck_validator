import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Phone } from '../src/phone/index';

type Vec = { input: string; country?: string; international?: boolean; isValid?: boolean; code?: string; normalized?: string; format?: string; type?: string };
function load(name: string): Vec[] {
  return JSON.parse(readFileSync(fileURLToPath(new URL(`../../test/vectors/${name}`, import.meta.url)), 'utf8'));
}

for (const file of ['phone.json', 'phone_global.json']) {
  describe(`phone conformance (${file})`, () => {
    for (const v of load(file)) {
      it(`${file}: ${v.input}`, () => {
        const opts = { country: v.country };
        const r = Phone.validate(v.input, opts);
        if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
        if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
        if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
        if (v.format !== undefined) {
          const international = v.international ?? true;
          expect(Phone.format(v.input, { ...opts, international })).toBe(v.format);
        }
        if (v.type !== undefined) expect(Phone.type(v.input, opts).valueOf()).toBe(v.type);
      });
    }
  });
}
