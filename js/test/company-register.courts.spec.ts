import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { CompanyRegister } from '../src/company-register/index';

type Court = { code: string; name: string; city: string; bundesland: string; bundeslandName: string };
type Vec = { courts: Court[]; cases: { input: string; code: string | null }[] };
const vec: Vec = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../test/vectors/company_register_courts.json', import.meta.url)), 'utf8'),
);

describe('CompanyRegister.courts', () => {
  it('is exactly the vector list, in order', () => {
    expect(CompanyRegister.courts.map((c) => ({ ...c }))).toEqual(vec.courts);
  });
  it('has 16 courts, one Handelsgericht, unique codes, ISO 3166-2:AT states', () => {
    expect(CompanyRegister.courts).toHaveLength(16);
    expect(CompanyRegister.courts.filter((c) => c.name.startsWith('Handelsgericht'))).toHaveLength(1);
    expect(new Set(CompanyRegister.courts.map((c) => c.code)).size).toBe(16);
    for (const c of CompanyRegister.courts) expect(c.bundesland).toMatch(/^AT-[1-9]$/);
  });
  it('is frozen', () => {
    expect(Object.isFrozen(CompanyRegister.courts)).toBe(true);
  });
});

describe('CompanyRegister.court', () => {
  for (const v of vec.cases) {
    it(`court: ${JSON.stringify(v.input)} -> ${v.code}`, () => {
      const r = CompanyRegister.court(v.input);
      expect(r ? r.code : null).toBe(v.code);
    });
  }
  it('every court resolves from its own name, city and code', () => {
    for (const c of CompanyRegister.courts) {
      expect(CompanyRegister.court(c.name)?.code).toBe(c.code);
      expect(CompanyRegister.court(c.city)?.code).toBe(c.code);
      expect(CompanyRegister.court(c.code)?.code).toBe(c.code);
    }
  });
});
