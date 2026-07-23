import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Email } from '../src/email/index';

type Vec = { input: string; isValid?: boolean; code?: string; normalized?: string };
const vectors: Vec[] = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../test/vectors/email.json', import.meta.url)), 'utf8'),
);

describe('email conformance', () => {
  for (const v of vectors) {
    it(`email: ${v.input}`, () => {
      const r = Email.validate(v.input);
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
    });
  }
});
