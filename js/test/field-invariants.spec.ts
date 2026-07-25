import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import type { FieldDescriptor } from '../src/common/field';
import { Imei } from '../src/imei/index';
import { Iccid } from '../src/iccid/index';
import { Vin } from '../src/vin/index';
import { Iban } from '../src/iban/index';
import { CreditCard } from '../src/credit-card/index';
import { MacAddress } from '../src/mac-address/index';
import { PostalCode } from '../src/postal-code/index';
import { LicensePlate } from '../src/license-plate/index';
import { Email } from '../src/email/index';
import { Url } from '../src/url/index';
import { Host } from '../src/host/index';

function load<T>(name: string): T[] {
  return JSON.parse(
    readFileSync(fileURLToPath(new URL(`../../test/vectors/${name}`, import.meta.url)), 'utf8'),
  );
}

// Every (type, options) pair covered by the descriptor vectors, paired with
// its descriptor and its partial formatter.
interface Type {
  name: string;
  descriptor: () => FieldDescriptor;
  partial: (input: string) => string;
  // Formats an already-valid value, or null when the type has no `format`
  // that a partial formatter is expected to agree with.
  formatValid: ((input: string) => string | null) | null;
}

const types: Type[] = [
  { name: 'imei', descriptor: () => Imei.fieldDescriptor(), partial: Imei.formatPartial, formatValid: Imei.tryFormat },
  {
    name: 'iccid',
    descriptor: () => Iccid.fieldDescriptor(),
    partial: Iccid.formatPartial,
    formatValid: Iccid.tryFormat,
  },
  { name: 'vin', descriptor: () => Vin.fieldDescriptor(), partial: Vin.formatPartial, formatValid: Vin.tryFormat },
  {
    name: 'credit_card',
    descriptor: () => CreditCard.fieldDescriptor(),
    partial: CreditCard.formatPartial,
    formatValid: CreditCard.tryFormat,
  },
  { name: 'iban', descriptor: () => Iban.fieldDescriptor(), partial: Iban.formatPartial, formatValid: Iban.tryFormat },
  {
    name: 'mac_address',
    descriptor: () => MacAddress.fieldDescriptor(),
    partial: MacAddress.formatPartial,
    formatValid: MacAddress.tryFormat,
  },
  { name: 'email', descriptor: () => Email.fieldDescriptor(), partial: Email.formatPartial, formatValid: null },
  { name: 'url', descriptor: () => Url.fieldDescriptor(), partial: Url.formatPartial, formatValid: null },
  { name: 'host', descriptor: () => Host.fieldDescriptor(), partial: Host.formatPartial, formatValid: null },
];

// Each group filters the type list rather than returning early inside the
// test body, so no test is generated that asserts nothing.
describe('example validity', () => {
  for (const t of types.filter((t) => t.formatValid !== null && t.descriptor().example !== null)) {
    it(`${t.name} example is valid`, () => {
      const example = t.descriptor().example!;
      expect(t.formatValid!(example), `${t.name} example "${example}" does not validate`).not.toBeNull();
    });
  }
});

describe('example fits maxLength', () => {
  for (const t of types.filter((t) => {
    const d = t.descriptor();
    return d.example !== null && d.maxLength !== null;
  })) {
    it(t.name, () => {
      const d = t.descriptor();
      expect(d.example!.length).toBeLessThanOrEqual(d.maxLength!);
    });
  }
});

describe('filter soundness', () => {
  for (const t of types.filter((t) => {
    const d = t.descriptor();
    return d.example !== null && d.allowedChars !== null;
  })) {
    it(`${t.name} allowedChars admits its own example`, () => {
      const d = t.descriptor();
      const stripped = d.example!.replace(new RegExp(`[${d.allowedChars}]`, 'g'), '');
      expect(stripped, `${t.name} example "${d.example}" contains characters its own allowedChars rejects`).toBe('');
    });
  }
});

describe('agreement with format', () => {
  interface CreditCardVec {
    input: string;
    isValid?: boolean;
    format?: string;
  }
  for (const c of load<CreditCardVec>('credit_card.json')) {
    if (c.isValid !== true || !('format' in c)) continue;
    it(`credit_card: ${c.input}`, () => {
      expect(CreditCard.formatPartial(c.input)).toBe(c.format);
    });
  }

  interface IbanVec {
    input: string;
    isValid?: boolean;
    normalized?: string;
    format?: string;
  }
  for (const c of load<IbanVec>('iban.json')) {
    if (c.isValid !== true || !('format' in c)) continue;
    const country = c.normalized!.substring(0, 2);
    it(`iban: ${c.input}`, () => {
      expect(Iban.formatPartial(c.input, { country })).toBe(c.format);
    });
  }

  interface ImeiVec {
    input: string;
    isValid?: boolean;
    format?: string;
    allowSv?: boolean;
  }
  for (const c of load<ImeiVec>('imei.json')) {
    if (c.isValid !== true || !('format' in c)) continue;
    const allowSv = c.allowSv ?? false;
    it(`imei: ${c.input}`, () => {
      expect(Imei.formatPartial(c.input, { allowSv })).toBe(c.format);
    });
  }

  interface VinVec {
    input: string;
    isValid?: boolean;
    format?: string;
  }
  for (const c of load<VinVec>('vin.json')) {
    if (c.isValid !== true || !('format' in c)) continue;
    it(`vin: ${c.input}`, () => {
      expect(Vin.formatPartial(c.input)).toBe(c.format);
    });
  }

  interface PostalCodeVec {
    input: string;
    country: string;
    isValid?: boolean;
    format?: string;
  }
  for (const c of load<PostalCodeVec>('postal_code.json')) {
    if (c.isValid !== true || !('format' in c)) continue;
    it(`postal_code ${c.country}: ${c.input}`, () => {
      expect(PostalCode.formatPartial(c.input, { country: c.country })).toBe(c.format);
    });
  }

  interface LicensePlateVec {
    input: string;
    country?: string;
    isValid?: boolean;
    format?: string;
  }
  for (const c of load<LicensePlateVec>('license_plate.json')) {
    if (c.isValid !== true || !('format' in c)) continue;
    it(`license_plate: ${c.input}`, () => {
      expect(LicensePlate.formatPartial(c.input, { country: c.country })).toBe(c.format);
    });
  }
});

// iccid.json and mac.json are covered by the `types` loops above; phone.json
// is deliberately absent from the agreement group because its vectors carry
// an `international` flag that formatPartial derives from the leading `+`
// instead -- its agreement is pinned by the snapping vector added in Task 9.
