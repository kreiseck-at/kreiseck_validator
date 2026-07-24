import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Host } from '../src/host/index';

type Parse = {
  host: string;
  type: string;
  port: number | null;
  hasPort: boolean;
};
type Vec = {
  input: string;
  isValid?: boolean;
  code?: string;
  normalized?: string;
  format?: string;
  parse?: Parse;
};
const vectors: Vec[] = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../test/vectors/host.json', import.meta.url)), 'utf8'),
);

describe('host conformance', () => {
  for (const v of vectors) {
    it(`host: ${v.input}`, () => {
      const r = Host.validate(v.input);
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
      if (v.format !== undefined) expect(Host.format(v.input)).toBe(v.format);
      if (v.parse) {
        const info = Host.parse(v.input)!;
        expect(info.host).toBe(v.parse.host);
        expect(info.type).toBe(v.parse.type);
        expect(info.port).toBe(v.parse.port);
        expect(info.hasPort).toBe(v.parse.hasPort);
      }
    });
  }
});
