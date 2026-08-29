import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Url } from '../src/url/index';

type Vec = {
  input: string;
  options?: { requireProtocol?: boolean; protocols?: string[]; allowCredentials?: boolean; allowLocalhost?: boolean };
  webhook?: boolean;
  isValid?: boolean;
  code?: string;
  normalized?: string;
  format?: string;
};
const vectors: Vec[] = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../test/vectors/url.json', import.meta.url)), 'utf8'),
);

describe('url conformance', () => {
  for (const v of vectors) {
    it(`url: ${v.input}`, () => {
      const r = v.webhook ? Url.webhook(v.input) : Url.validate(v.input, v.options ?? {});
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
      if (v.format !== undefined) expect(Url.format(v.input)).toBe(v.format);
    });
  }
});
