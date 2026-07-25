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
