import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const DIST_DIR = fileURLToPath(new URL('../dist', import.meta.url));

// Matches `import ... from './chunk-XXXX.js'` and `export ... from '../chunk-XXXX.js'`,
// i.e. any static import/export whose specifier is a relative path.
const RELATIVE_IMPORT_RE = /(?:import|export)[^;]*?from\s+['"](\.\.?\/[^'"]+)['"]/g;

// Reads an entry file and recursively resolves every relative import/export it
// references, returning the concatenated source of the entry plus the full
// transitive closure of imported chunks. Guards against cycles with a visited set.
function readTransitiveClosure(entryAbsPath: string): string {
  const visited = new Set<string>();
  const parts: string[] = [];

  function visit(absPath: string): void {
    if (visited.has(absPath)) return;
    visited.add(absPath);
    const source = readFileSync(absPath, 'utf8');
    parts.push(source);
    const dir = dirname(absPath);
    for (const match of source.matchAll(RELATIVE_IMPORT_RE)) {
      const specifier = match[1];
      visit(resolve(dir, specifier));
    }
  }

  visit(entryAbsPath);
  return parts.join('\n');
}

describe('bundle isolation', () => {
  it('the iban entry closure does not contain phone metadata', () => {
    const closure = readTransitiveClosure(resolve(DIST_DIR, 'iban/index.js'));
    // `callingCode` is a real, used field of the phone metadata that survives
    // the build (unlike unused JSON keys, which esbuild strips from every
    // bundle regardless of leakage). Its presence here would mean phone
    // country data is reachable from the iban entry point.
    expect(closure.includes('callingCode')).toBe(false);
    expect(closure.includes('nationalPrefixFormattingRule')).toBe(false);
  });

  it('positive control: the phone entry closure does contain the sentinel', () => {
    const closure = readTransitiveClosure(resolve(DIST_DIR, 'phone/index.js'));
    // Proves `callingCode` actually survives the build and isn't stripped
    // the way `libphonenumberVersion` used to be, so the assertion above is
    // a meaningful guard rather than something that would pass no matter what.
    expect(closure.includes('callingCode')).toBe(true);
  });
});
