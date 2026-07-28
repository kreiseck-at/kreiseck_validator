import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';
import type { FieldDescriptor } from '../common/field';
import { luhnOk } from '../common/luhn';
import { prepare } from '../common/partial';
import type { TaxNumberInfo } from './types';

// Validation, normalization, formatting and parsing of tax numbers.
//
// Austria only in this release. `country` is required so other countries can
// be added without a breaking rename -- a bare tax number is meaningless
// without knowing whose it is.
//
// The Austrian Abgabenkontonummer is nine digits -- a two-digit Finanzamt
// number, six free digits and a check digit -- conventionally written
// `12-345/6789`.
//
// The check is the Luhn algorithm over all nine digits. The official
// description states it as
// `S = F + Q(A) + N1 + Q(N2) + N3 + Q(N4) + N5 + Q(N6)` with `Q(z)` the digit
// sum of `2z` and `P = (80 - S) mod 10`; that is Luhn written out, and the
// documented example 98-123/4560 confirms it (S = 40, P = 0).
//
// The Finanzamt number is reported by parse but never rejected.

export interface TaxNumberOptions { country: string }
export interface TaxNumberFieldOptions { country?: string }

const SEPARATORS_RE = /[\s./-]/g;
const DIGITS_RE = /^[0-9]+$/;

function isAustria(country: string | undefined): boolean {
  return country !== undefined && country.toUpperCase() === 'AT';
}

// Validates input for the given country, returning the nine bare digits.
function validate(input: string, o: TaxNumberOptions): ValidationResult {
  if (!isAustria(o.country)) {
    return invalid('taxNumberUnknownCountry', 'No tax-number rules for this country.');
  }
  const compact = input.replace(SEPARATORS_RE, '');
  if (compact.length === 0) {
    return invalid('taxNumberEmpty', 'Tax number is empty.');
  }
  if (!DIGITS_RE.test(compact)) {
    return invalid('taxNumberBadChars', 'Tax number must be digits only.');
  }
  if (compact.length !== 9) {
    return invalid('taxNumberBadLength', 'Tax number must be 9 digits.');
  }
  if (!luhnOk(compact)) {
    return invalid('taxNumberBadChecksum', 'Tax number check digit is wrong.');
  }
  return valid(compact);
}

// True when validate returns a valid result.
function isValid(input: string, o: TaxNumberOptions): boolean {
  return validate(input, o).ok;
}

// Returns the nine bare digits. Throws FormatError if invalid.
function normalize(input: string, o: TaxNumberOptions): string {
  const r = validate(input, o);
  if (!r.ok) throw new FormatError(r.issues[0].message);
  return r.normalized;
}

// Returns the conventional 12-345/6789 form. Throws FormatError if invalid.
function format(input: string, o: TaxNumberOptions): string {
  const n = normalize(input, o);
  return `${n.substring(0, 2)}-${n.substring(2, 5)}/${n.substring(5)}`;
}

// Like format but returns null instead of throwing on invalid input.
function tryFormat(input: string, o: TaxNumberOptions): string | null {
  try {
    return format(input, o);
  } catch (e) {
    if (e instanceof FormatError) return null;
    throw e;
  }
}

// Parses input into a TaxNumberInfo, or null when it is not valid.
function parse(input: string, o: TaxNumberOptions): TaxNumberInfo | null {
  const r = validate(input, o);
  if (!r.ok) return null;
  const n = r.normalized;
  return { office: n.substring(0, 2), number: n.substring(2), checkDigit: n[8] };
}

// Describes a tax-number input field. maxLength is the length of the formatted
// text, separators included.
function fieldDescriptor(o: TaxNumberFieldOptions = {}): FieldDescriptor {
  if (!isAustria(o.country)) {
    return {
      keyboard: 'digits',
      autofill: null,
      capitalization: 'none',
      maxLength: null,
      example: null,
      allowedChars: '0-9/-',
    };
  }
  return {
    keyboard: 'digits',
    autofill: null,
    capitalization: 'none',
    maxLength: 11,
    example: '98-123/4560',
    allowedChars: '0-9/-',
  };
}

// Formats partially typed input: non-digits dropped, the - and / re-inserted
// as soon as enough digits exist, capped at nine digits. Never throws.
function formatPartial(input: string, o: TaxNumberFieldOptions = {}): string {
  const s = prepare(input, fieldDescriptor(o), { separators: '/-', maxSignificant: 9 });
  if (!isAustria(o.country)) return s;
  if (s.length <= 2) return s;
  if (s.length <= 5) return `${s.substring(0, 2)}-${s.substring(2)}`;
  return `${s.substring(0, 2)}-${s.substring(2, 5)}/${s.substring(5)}`;
}

export const TaxNumber = {
  isValid, validate, normalize, format, tryFormat, parse, fieldDescriptor, formatPartial,
};
export type { TaxNumberInfo };
