import { describe, it, expect } from 'vitest';
import { IbanCountry } from '../src/iban/country';
import { Iban } from '../src/iban/index';

describe('IbanCountry', () => {
  it('describes the Austrian format', () => {
    const at = IbanCountry.of('AT')!;
    expect(at.iso2).toBe('AT');
    expect(at.length).toBe(20);
    expect(at.bankCodeLength).toBe(5);
    expect(at.branchCodeLength).toBeNull();
    expect(at.accountLength).toBe(11);
    expect(at.hasBranchCode).toBe(false);
    expect(at.example).toBe('AT61 1904 3002 3457 3201');
  });
  it('exposes a branch length for IT', () => {
    const it = IbanCountry.of('IT')!;
    expect(it.bankCodeLength).toBe(5);
    expect(it.branchCodeLength).toBe(5);
    expect(it.hasBranchCode).toBe(true);
  });
  it('is case-insensitive and null for unknown', () => {
    expect(IbanCountry.of('at')!.iso2).toBe('AT');
    expect(IbanCountry.of('XX')).toBeNull();
    expect(IbanCountry.of('US')).toBeNull();
  });
  it('every example is valid and values is sorted', () => {
    const values = IbanCountry.values();
    expect(values.length).toBeGreaterThan(100);
    for (const c of values) expect(Iban.isValid(c.example)).toBe(true);
    const codes = values.map((c) => c.iso2);
    expect(codes).toEqual([...codes].sort());
  });
});
