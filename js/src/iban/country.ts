import { kIbanBban } from './metadata';
import type { IbanBban } from './metadata';

// A public description of one country's IBAN format: its total length, the
// lengths of the bank / branch / account fields, and a valid example.
//
// Obtained via IbanCountry.of or IbanCountry.values. Derived from the same
// bundled metadata that drives IBAN validation.
//
// The field lengths need not add up to length: a few countries (e.g. Italy
// and San Marino) place a national check character between the check digits
// and the bank code, and that character belongs to none of the three fields.
export interface IbanCountry {
  // ISO 3166-1 alpha-2 code, upper-case (e.g. AT).
  iso2: string;
  // Total IBAN length for this country.
  length: number;
  // Length of the bank identifier (0 if the country has none).
  bankCodeLength: number;
  // Length of the branch identifier, or null if the country has none.
  branchCodeLength: number | null;
  // Length of the account-number field.
  accountLength: number;
  // A valid example IBAN, grouped in blocks of four, e.g.
  // AT61 1904 3002 3457 3201.
  example: string;
  // Whether this country's IBAN carries a branch identifier.
  hasBranchCode: boolean;
}

function group(compact: string): string {
  const parts = compact.match(/.{1,4}/g) ?? [];
  return parts.join(' ');
}

function from(iso2: string, b: IbanBban): IbanCountry {
  const branchStart = b.branchStart;
  const branchEnd = b.branchEnd;
  const branchLen = branchStart === null ? null : branchEnd! - branchStart;
  const accountStart = branchEnd ?? b.bankEnd;
  return {
    iso2,
    length: b.length,
    bankCodeLength: b.bankEnd - b.bankStart,
    branchCodeLength: branchLen,
    accountLength: b.length - accountStart,
    example: group(b.example),
    hasBranchCode: branchLen !== null,
  };
}

// The descriptor for code (case-insensitive ISO2), or null if the country
// has no known IBAN format.
function of(code: string): IbanCountry | null {
  const cc = code.toUpperCase();
  const b = kIbanBban[cc];
  return b === undefined ? null : from(cc, b);
}

// All known IBAN countries, sorted by ISO2 code.
function values(): IbanCountry[] {
  const codes = Object.keys(kIbanBban).sort();
  return codes.map((cc) => from(cc, kIbanBban[cc]));
}

export const IbanCountry = { of, values };
