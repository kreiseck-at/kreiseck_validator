import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import type { FieldDescriptor } from '../src/common/field';
import { prepare } from '../src/common/partial';
import { Imei } from '../src/imei/index';
import { Iccid } from '../src/iccid/index';
import { Vin } from '../src/vin/index';
import { Iban } from '../src/iban/index';
import { CreditCard } from '../src/credit-card/index';
import { MacAddress } from '../src/mac-address/index';
import { PostalCode } from '../src/postal-code/index';
import { LicensePlate } from '../src/license-plate/index';
import { Phone } from '../src/phone/index';
import { Email } from '../src/email/index';
import { Bic } from '../src/bic/index';
import { Gtin } from '../src/gtin/index';
import { VatId } from '../src/vat-id/index';
import { SocialSecurityNumber } from '../src/social-security/index';
import { CompanyRegister } from '../src/company-register/index';
import { TaxNumber } from '../src/tax-number/index';
import { Url } from '../src/url/index';
import { Host } from '../src/host/index';
import type { MacNotation } from '../src/mac-address/types';

function load<T>(name: string): T[] {
  return JSON.parse(
    readFileSync(fileURLToPath(new URL(`../../test/vectors/${name}`, import.meta.url)), 'utf8'),
  );
}

// Options accompanying a format_partial.json vector: an untyped bag, since
// its shape depends on `type` (country, allowSv, notation, upperCase, ...).
type Options = Record<string, unknown>;

interface PartialVec {
  type: string;
  options?: Options;
  input: string;
  output: string;
}

// Every (type, options) pair covered by the descriptor vectors, paired with
// its descriptor.
interface Type {
  name: string;
  descriptor: () => FieldDescriptor;
  // Formats an already-valid value, or null when the type has no `format`
  // that a partial formatter is expected to agree with.
  formatValid: ((input: string) => string | null) | null;
}

const types: Type[] = [
  { name: 'imei', descriptor: () => Imei.fieldDescriptor(), formatValid: Imei.tryFormat },
  { name: 'iccid', descriptor: () => Iccid.fieldDescriptor(), formatValid: Iccid.tryFormat },
  { name: 'vin', descriptor: () => Vin.fieldDescriptor(), formatValid: Vin.tryFormat },
  { name: 'credit_card', descriptor: () => CreditCard.fieldDescriptor(), formatValid: CreditCard.tryFormat },
  { name: 'iban', descriptor: () => Iban.fieldDescriptor(), formatValid: Iban.tryFormat },
  { name: 'mac_address', descriptor: () => MacAddress.fieldDescriptor(), formatValid: MacAddress.tryFormat },
  // Country-dependent types: the generic (no-country) descriptor never has
  // an example, so only a per-country entry exercises the example-validity,
  // maxLength-fit and filter-soundness groups below.
  {
    name: 'postal_code:AT',
    descriptor: () => PostalCode.fieldDescriptor({ country: 'AT' }),
    formatValid: (v) => PostalCode.tryFormat(v, { country: 'AT' }),
  },
  {
    name: 'postal_code:DE',
    descriptor: () => PostalCode.fieldDescriptor({ country: 'DE' }),
    formatValid: (v) => PostalCode.tryFormat(v, { country: 'DE' }),
  },
  {
    name: 'postal_code:NL',
    descriptor: () => PostalCode.fieldDescriptor({ country: 'NL' }),
    formatValid: (v) => PostalCode.tryFormat(v, { country: 'NL' }),
  },
  {
    name: 'postal_code:GB',
    descriptor: () => PostalCode.fieldDescriptor({ country: 'GB' }),
    formatValid: (v) => PostalCode.tryFormat(v, { country: 'GB' }),
  },
  {
    name: 'license_plate:AT',
    descriptor: () => LicensePlate.fieldDescriptor({ country: 'AT' }),
    formatValid: (v) => LicensePlate.tryFormat(v, { country: 'AT' }),
  },
  {
    name: 'license_plate:DE',
    descriptor: () => LicensePlate.fieldDescriptor({ country: 'DE' }),
    formatValid: (v) => LicensePlate.tryFormat(v, { country: 'DE' }),
  },
  // Phone.fieldDescriptor's example is always null (never invented, see its
  // doc comment), so this entry contributes no assertions to the
  // example-based groups below; it is listed anyway so the type is
  // represented and picks up coverage automatically if that ever changes.
  {
    name: 'phone:AT',
    descriptor: () => Phone.fieldDescriptor({ country: 'AT' }),
    formatValid: (v) => Phone.tryFormat(v, { country: 'AT' }),
  },
  { name: 'bic', descriptor: () => Bic.fieldDescriptor(), formatValid: Bic.tryFormat },
  { name: 'gtin', descriptor: () => Gtin.fieldDescriptor(), formatValid: Gtin.tryFormat },
  {
    name: 'vat_id:AT',
    descriptor: () => VatId.fieldDescriptor({ country: 'AT' }),
    formatValid: (v) => VatId.tryFormat(v, { country: 'AT' }),
  },
  {
    name: 'vat_id:NL',
    descriptor: () => VatId.fieldDescriptor({ country: 'NL' }),
    formatValid: (v) => VatId.tryFormat(v, { country: 'NL' }),
  },
  {
    name: 'social_security:AT',
    descriptor: () => SocialSecurityNumber.fieldDescriptor({ country: 'AT' }),
    formatValid: (v) => SocialSecurityNumber.tryFormat(v, { country: 'AT' }),
  },
  {
    name: 'tax_number:AT',
    descriptor: () => TaxNumber.fieldDescriptor({ country: 'AT' }),
    formatValid: (v) => TaxNumber.tryFormat(v, { country: 'AT' }),
  },
  // CompanyRegister's format prepends a presentational 'FN ', which
  // formatPartial deliberately does not while the user is still typing, so
  // this type has no format for a partial formatter to agree with -- the same
  // situation as email, url and host below.
  {
    name: 'company_register:AT',
    descriptor: () => CompanyRegister.fieldDescriptor({ country: 'AT' }),
    formatValid: null,
  },
  { name: 'email', descriptor: () => Email.fieldDescriptor(), formatValid: null },
  { name: 'url', descriptor: () => Url.fieldDescriptor(), formatValid: null },
  { name: 'host', descriptor: () => Host.fieldDescriptor(), formatValid: null },
];

// Converts a vector's `notation` string to MacNotation; defaults to 'colon',
// matching MacAddress.formatPartial's own default.
function notationOf(s: string | undefined): MacNotation {
  return (s as MacNotation) ?? 'colon';
}

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

  interface IccidVec {
    input: string;
    isValid?: boolean;
    format?: string;
  }
  for (const c of load<IccidVec>('iccid.json')) {
    if (c.isValid !== true || !('format' in c)) continue;
    it(`iccid: ${c.input}`, () => {
      expect(Iccid.formatPartial(c.input)).toBe(c.format);
    });
  }

  interface MacVec {
    input: string;
    isValid?: boolean;
    format?: string;
    notation?: string;
    upperCase?: boolean;
  }
  for (const c of load<MacVec>('mac.json')) {
    if (c.isValid !== true || !('format' in c)) continue;
    it(`mac_address: ${c.input}`, () => {
      expect(
        MacAddress.formatPartial(c.input, { notation: notationOf(c.notation), upperCase: c.upperCase ?? false }),
      ).toBe(c.format);
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

// phone.json is deliberately absent from the agreement group above because
// its vectors carry an `international` flag that formatPartial derives from
// the leading `+` instead -- its agreement is pinned by the snapping vector
// added in Task 9.

// Resolves any (type, options) pair from format_partial.json to its
// descriptor -- a superset of `types` above, since the vectors cover options
// combinations (e.g. every MacNotation) that `types` doesn't enumerate
// one-by-one.
function descriptorForPartial(type: string, o: Options): FieldDescriptor {
  switch (type) {
    case 'imei':
      return Imei.fieldDescriptor({ allowSv: (o.allowSv as boolean) ?? false });
    case 'iccid':
      return Iccid.fieldDescriptor();
    case 'vin':
      return Vin.fieldDescriptor();
    case 'iban':
      return Iban.fieldDescriptor({ country: o.country as string | undefined });
    case 'credit_card':
      return CreditCard.fieldDescriptor();
    case 'mac_address':
      return MacAddress.fieldDescriptor({
        notation: (o.notation as MacNotation) ?? 'colon',
        upperCase: (o.upperCase as boolean) ?? false,
      });
    case 'postal_code':
      return PostalCode.fieldDescriptor({ country: o.country as string | undefined });
    case 'license_plate':
      return LicensePlate.fieldDescriptor({ country: o.country as string | undefined });
    case 'phone':
      return Phone.fieldDescriptor({ country: o.country as string | undefined });
    case 'bic':
      return Bic.fieldDescriptor();
    case 'gtin':
      return Gtin.fieldDescriptor();
    case 'vat_id':
      return VatId.fieldDescriptor({ country: o.country as string | undefined });
    case 'social_security':
      return SocialSecurityNumber.fieldDescriptor({ country: o.country as string | undefined });
    case 'company_register':
      return CompanyRegister.fieldDescriptor({ country: o.country as string | undefined });
    case 'tax_number':
      return TaxNumber.fieldDescriptor({ country: o.country as string | undefined });
    case 'email':
      return Email.fieldDescriptor();
    case 'url':
      return Url.fieldDescriptor();
    case 'host':
      return Host.fieldDescriptor();
    default:
      throw new Error(`unknown type ${type}`);
  }
}

function partialForType(type: string, input: string, o: Options): string {
  switch (type) {
    case 'imei':
      return Imei.formatPartial(input, { allowSv: (o.allowSv as boolean) ?? false });
    case 'iccid':
      return Iccid.formatPartial(input);
    case 'vin':
      return Vin.formatPartial(input);
    case 'iban':
      return Iban.formatPartial(input, { country: o.country as string | undefined });
    case 'credit_card':
      return CreditCard.formatPartial(input);
    case 'mac_address':
      return MacAddress.formatPartial(input, {
        notation: (o.notation as MacNotation) ?? 'colon',
        upperCase: (o.upperCase as boolean) ?? false,
      });
    case 'postal_code':
      return PostalCode.formatPartial(input, { country: o.country as string | undefined });
    case 'license_plate':
      return LicensePlate.formatPartial(input, { country: o.country as string | undefined });
    case 'phone':
      return Phone.formatPartial(input, { country: o.country as string | undefined });
    case 'bic':
      return Bic.formatPartial(input);
    case 'gtin':
      return Gtin.formatPartial(input);
    case 'vat_id':
      return VatId.formatPartial(input, { country: o.country as string | undefined });
    case 'social_security':
      return SocialSecurityNumber.formatPartial(input, { country: o.country as string | undefined });
    case 'company_register':
      return CompanyRegister.formatPartial(input, { country: o.country as string | undefined });
    case 'tax_number':
      return TaxNumber.formatPartial(input, { country: o.country as string | undefined });
    case 'email':
      return Email.formatPartial(input);
    case 'url':
      return Url.formatPartial(input);
    case 'host':
      return Host.formatPartial(input);
    default:
      throw new Error(`unknown type ${type}`);
  }
}

// Mirrors Host.formatPartial's filter step (drop disallowed ASCII
// characters, keep every non-ASCII one) without its length cap -- used as
// this test's "steps 1-2, untruncated" baseline for 'host' instead of the
// generic prepare, since a plain FieldDescriptor.allowedChars filter would
// (wrongly, for this check) also drop the non-ASCII characters
// Host.formatPartial deliberately keeps (see its doc comment).
function hostFiltered(input: string, allowedChars: string): string {
  const allowed = new RegExp(`[${allowedChars}]`);
  let out = '';
  for (let i = 0; i < input.length; i++) {
    const ch = input[i];
    if (input.charCodeAt(i) > 0x7f || allowed.test(ch)) out += ch;
  }
  return out;
}

// The separator characters step 4 (grouping) is allowed to insert into a
// type's formatPartial output, or null when the type never groups
// (filter/truncate-only or identity types). Used to strip exactly those
// characters back out so what remains is the significant-character
// sequence, for comparison against the input run through steps 1-3 alone.
function groupingSeparatorsOf(type: string, o: Options): string | null {
  switch (type) {
    case 'credit_card':
      return ' ';
    case 'iban':
      return ' ';
    case 'mac_address':
      switch (notationOf(o.notation as string | undefined)) {
        case 'colon':
          return ':';
        case 'hyphen':
          return '-';
        case 'dot':
          return '.';
        case 'bare':
          return null;
      }
      break;
    // Every postal country's separator (see PostalPattern.format) is either
    // ' ' or '-'; the compact form never contains either as content, so
    // stripping both universally is safe regardless of country.
    case 'postal_code':
      return ' -';
    // LicensePlate accepts '.', '-' and ' ' as typed separators but format()
    // only ever emits ' ' and '-'; including '.' in the strip set is
    // harmless.
    case 'license_plate':
      return ' .-';
    case 'phone':
      return ' ';
    case 'social_security':
      return ' ';
    // TaxNumber.format writes 12-345/6789: two different separators, both
    // inserted by the grouping step and neither ever content.
    case 'tax_number':
      return '/-';
    default:
      return null; // imei, iccid, vin, email, url, host: never group.
  }
}

// Guarantee 3 (character fidelity): the sequence of significant characters
// -- everything that isn't a separator step 4 (grouping) inserts -- is
// preserved in order. Only filtering (step 2) removes a character and only
// truncation (step 3) removes a suffix; grouping itself must never reorder,
// invent or drop one. This is what a Flutter companion package's cursor
// mapping depends on.
describe('character fidelity', () => {
  for (const v of load<PartialVec>('format_partial.json')) {
    it(`${v.type} preserves significant character order: "${v.input}"`, () => {
      const options = v.options ?? {};
      const d = descriptorForPartial(v.type, options);
      const output = partialForType(v.type, v.input, options);
      const sep = groupingSeparatorsOf(v.type, options);

      // Steps 1-2 (case, filter) applied to the input, with no truncation --
      // the case-insensitive superset every valid prefix of the actual
      // output must come from. Case is normalized on both sides because a
      // couple of types (e.g. MacAddress with upperCase: false) apply a
      // final case pass outside the descriptor's own capitalization; that's
      // a casing detail, not a reordering one, so it must not make this
      // check spuriously fail.
      // CompanyRegister strips a leading 'FN', which its allowedChars
      // otherwise admits (F and N are letters). That prefix is presentation,
      // not content, so the baseline has to drop it too -- the same kind of
      // documented deviation as 'host'.
      const baseInput = v.type === 'company_register'
        ? v.input.replace(/^\s*[Ff][Nn][\s.]*/, '')
        : v.input;
      let expectedFull = (v.type === 'host' ? hostFiltered(v.input, d.allowedChars!) : prepare(baseInput, d)).toUpperCase();
      let actualSignificant = output.toUpperCase();
      if (sep !== null) {
        const sepRe = new RegExp(`[${sep}]`, 'g');
        expectedFull = expectedFull.replace(sepRe, '');
        actualSignificant = actualSignificant.replace(sepRe, '');
      }

      // Truncation only ever removes a suffix, so whatever length the
      // actual significant output has, it must be a PREFIX of the fully
      // filtered/cased (untruncated) input -- this catches reordering
      // without hard-coding each type's truncation cap (which, e.g. for
      // CreditCard, depends on the detected network).
      expect(
        actualSignificant.length <= expectedFull.length,
        `${v.type}: formatPartial("${v.input}") -> "${output}" produced more significant characters ` +
          `("${actualSignificant}") than filtering the input could ever produce ("${expectedFull}")`,
      ).toBe(true);
      expect(
        actualSignificant,
        `${v.type}: formatPartial("${v.input}") -> "${output}" reordered, invented or dropped a significant ` +
          'character beyond filtering and truncation',
      ).toBe(expectedFull.substring(0, actualSignificant.length));
    });
  }
});
