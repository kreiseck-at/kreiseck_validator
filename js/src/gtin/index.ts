import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';
import type { FieldDescriptor } from '../common/field';
import { prepare } from '../common/partial';
import type { GtinInfo } from './types';

// Validation, normalization, formatting and parsing of GS1 Global Trade Item
// Numbers: GTIN-8, GTIN-12 (UPC-A), GTIN-13 (EAN-13) and GTIN-14 (ITF-14).
//
// The last digit is the GS1 mod-10 check digit: digits are weighted 3 and 1
// alternately from the right, and the check digit completes the sum to a
// multiple of ten.
//
// normalize keeps the entered length rather than padding to 14 -- an EAN-8 and
// a zero-padded EAN-13 print as different barcodes. GtinInfo.gtin14 exposes
// the padded form for storage and comparison.
//
// No GS1 prefix or country is exposed. A GS1 prefix identifies the member
// organisation that issued the number, not the origin of the goods, and every
// API that surfaces it ends up being read as country-of-origin.

const LENGTHS = [8, 12, 13, 14];
const DIGITS_RE = /^[0-9]+$/;
const SEPARATORS_RE = /[\s-]/g;

// The GS1 mod-10 check digit for body -- a GTIN without its final digit.
// Useful for completing a partial scan; body is assumed to be digits only.
function checkDigit(body: string): string {
  let sum = 0;
  let weight = 3;
  for (let i = body.length - 1; i >= 0; i--) {
    sum += (body.charCodeAt(i) - 48) * weight;
    weight = weight === 3 ? 1 : 3;
  }
  return String((10 - sum % 10) % 10);
}

// Validates input, returning the separator-free digits.
function validate(input: string): ValidationResult {
  const compact = input.replace(SEPARATORS_RE, '');
  if (compact.length === 0) {
    return invalid('gtinEmpty', 'GTIN is empty.');
  }
  if (!DIGITS_RE.test(compact)) {
    return invalid('gtinBadChars', 'GTIN must be digits only.');
  }
  if (!LENGTHS.includes(compact.length)) {
    return invalid('gtinBadLength', 'GTIN must be 8, 12, 13 or 14 digits.');
  }
  if (checkDigit(compact.substring(0, compact.length - 1)) !== compact[compact.length - 1]) {
    return invalid('gtinBadChecksum', 'GTIN check digit is wrong.');
  }
  return valid(compact);
}

// True when validate returns a valid result.
function isValid(input: string): boolean {
  return validate(input).ok;
}

// Returns the separator-free digits. Throws FormatError if input is not a
// valid GTIN.
function normalize(input: string): string {
  const r = validate(input);
  if (!r.ok) throw new FormatError(r.issues[0].message);
  return r.normalized;
}

// Returns the digits as entered, without separators. Throws FormatError if
// invalid.
function format(input: string): string {
  return normalize(input);
}

// Like format but returns null instead of throwing on invalid input.
function tryFormat(input: string): string | null {
  try {
    return format(input);
  } catch (e) {
    if (e instanceof FormatError) return null;
    throw e;
  }
}

// Parses input into a GtinInfo, or null when it is not a valid GTIN.
function parse(input: string): GtinInfo | null {
  const r = validate(input);
  if (!r.ok) return null;
  const n = r.normalized;
  return {
    length: n.length,
    checkDigit: n[n.length - 1],
    gtin14: n.padStart(14, '0'),
  };
}

// Describes a GTIN input field.
function fieldDescriptor(): FieldDescriptor {
  return {
    keyboard: 'digits',
    autofill: null,
    capitalization: 'none',
    maxLength: 14,
    example: '4006381333931',
    allowedChars: '0-9',
  };
}

// Formats partially typed input: non-digits dropped, capped at 14. A GTIN is
// printed as one run, so there is no grouping step. Never throws.
function formatPartial(input: string): string {
  return prepare(input, fieldDescriptor(), { maxSignificant: 14 });
}

export const Gtin = {
  isValid, validate, normalize, format, tryFormat, parse, checkDigit,
  fieldDescriptor, formatPartial,
};
export type { GtinInfo };
