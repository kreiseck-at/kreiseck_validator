import { describe, it, expect } from 'vitest';
import { mod1110Ok, mod9710Ok } from '../src/common/iso7064';

describe('ISO 7064 MOD 11,10', () => {
  it('accepts the documented example', () => {
    expect(mod1110Ok('794623')).toBe(true);
  });
  it('rejects a wrong check digit', () => {
    expect(mod1110Ok('794624')).toBe(false);
  });
  it('rejects a transposition', () => {
    expect(mod1110Ok('974623')).toBe(false);
  });
  it('rejects a non-digit', () => {
    expect(mod1110Ok('79462X')).toBe(false);
  });
});

describe('ISO 7064 MOD 97,10', () => {
  it('accepts a rearranged IBAN', () => {
    expect(mod9710Ok('1904300234573201AT61')).toBe(true);
  });
  it('rejects a broken one', () => {
    expect(mod9710Ok('1904300234573201AT62')).toBe(false);
  });
  it('rejects a non-alphanumeric', () => {
    expect(mod9710Ok('1904300234573201AT6 ')).toBe(false);
  });
});
