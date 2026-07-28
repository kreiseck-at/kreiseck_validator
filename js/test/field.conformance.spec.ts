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
import type { MacNotation } from '../src/mac-address/types';
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

type Options = Record<string, unknown>;
type DescriptorVec = Options & { type: string; options?: Options };
type PartialVec = { type: string; options?: Options; input: string; output: string };

function load<T>(name: string): T[] {
  return JSON.parse(
    readFileSync(fileURLToPath(new URL(`../../test/vectors/${name}`, import.meta.url)), 'utf8'),
  );
}

function descriptorFor(type: string, o: Options): FieldDescriptor {
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

function partialFor(type: string, input: string, o: Options): string {
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

describe('field descriptor conformance', () => {
  for (const v of load<DescriptorVec>('field_descriptor.json')) {
    it(`${v.type} ${JSON.stringify(v.options ?? {})}`, () => {
      const d = descriptorFor(v.type, v.options ?? {});
      expect(d.keyboard).toBe(v.keyboard);
      expect(d.autofill).toBe(v.autofill);
      expect(d.capitalization).toBe(v.capitalization);
      expect(d.maxLength).toBe(v.maxLength);
      expect(d.example).toBe(v.example);
      expect(d.allowedChars).toBe(v.allowedChars);
    });
  }
});

describe('format partial conformance', () => {
  for (const v of load<PartialVec>('format_partial.json')) {
    it(`${v.type}: "${v.input}"`, () => {
      const once = partialFor(v.type, v.input, v.options ?? {});
      expect(once).toBe(v.output);
      // Idempotence, checked for every type on every vector.
      expect(partialFor(v.type, once, v.options ?? {})).toBe(once);
    });
  }
});
