import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

describe('bundle isolation', () => {
  it('the iban entry does not contain phone metadata', () => {
    const js = readFileSync(fileURLToPath(new URL('../dist/iban/index.js', import.meta.url)), 'utf8');
    // A libphonenumber-derived token that only appears in phone metadata.
    expect(js.includes('libphonenumberVersion')).toBe(false);
  });
});
