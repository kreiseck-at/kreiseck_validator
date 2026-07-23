import { describe, it, expect } from 'vitest';
import iban from '../src/data/iban-metadata.json';
import phone from '../src/data/phone-metadata.json';

describe('bundled data', () => {
  it('IBAN metadata has bban + banks with AT/DE/CH', () => {
    expect(iban.bban.AT.length).toBe(20);
    expect(iban.bban.AT.example).toBe('AT611904300234573201');
    expect(iban.banks.AT['12000']).toEqual({ name: 'UniCredit Bank Austria AG', bic: 'BKAUATWW' });
    expect(iban.banks.DE['37040044']).toEqual({ name: 'Commerzbank', bic: 'COBADEFF' });
    expect(iban.banks.CH['00100'].bic).toBe('SNBZCHZZ');
  });
  it('phone metadata has a countries array', () => {
    expect(Array.isArray(phone.countries)).toBe(true);
    expect(phone.countries.length).toBeGreaterThan(200);
  });
});
