import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';
import type { VinInfo } from './types';

// Validation, normalization and formatting of Vehicle Identification
// Numbers (ISO 3779).
//
// Validation checks structure only: 17 characters from the ISO 3779
// charset ('I', 'O', 'Q' are forbidden to avoid confusion with '1'/'0').
// The check digit is mandatory only for North American VINs -- European
// VINs frequently have no valid check digit -- so it is never enforced by
// validate; its result is exposed via Vin.parse(...).checkDigitValid
// instead.

const CHARSET_RE = /^[A-HJ-NPR-Z0-9]{17}$/;

const TRANSLITERATION: Record<string, number> = {
  A: 1, B: 2, C: 3, D: 4, E: 5, F: 6, G: 7, H: 8,
  J: 1, K: 2, L: 3, M: 4, N: 5, P: 7, R: 9,
  S: 2, T: 3, U: 4, V: 5, W: 6, X: 7, Y: 8, Z: 9,
  '0': 0, '1': 1, '2': 2, '3': 3, '4': 4,
  '5': 5, '6': 6, '7': 7, '8': 8, '9': 9,
};

const WEIGHTS = [8, 7, 6, 5, 4, 3, 2, 10, 0, 9, 8, 7, 6, 5, 4, 3, 2];

const YEAR_CODES: Record<string, number> = {
  A: 1980, B: 1981, C: 1982, D: 1983, E: 1984, F: 1985,
  G: 1986, H: 1987, J: 1988, K: 1989, L: 1990, M: 1991,
  N: 1992, P: 1993, R: 1994, S: 1995, T: 1996, V: 1997,
  W: 1998, X: 1999, Y: 2000,
  '1': 2001, '2': 2002, '3': 2003, '4': 2004, '5': 2005,
  '6': 2006, '7': 2007, '8': 2008, '9': 2009,
};

const LETTER_RE = /^[A-Z]$/;

// Validates input, returning a valid result with the upper-cased 17-char
// normalized form or an invalid result describing why it was rejected.
function validate(input: string): ValidationResult {
  const upper = input.trim().toUpperCase();
  if (upper.length === 0) {
    return invalid('vinEmpty', 'VIN is empty.');
  }
  if (upper.length !== 17) {
    return invalid('vinBadLength', 'VIN must be 17 characters.');
  }
  if (!CHARSET_RE.test(upper)) {
    return invalid('vinBadChars', 'VIN has invalid characters.');
  }
  return valid(upper);
}

// True when validate returns a valid result.
function isValid(input: string): boolean {
  return validate(input).ok;
}

// Returns the upper-cased 17-char canonical form. Throws FormatError if
// input is not a structurally valid VIN.
function normalize(input: string): string {
  const r = validate(input);
  if (!r.ok) {
    throw new FormatError(r.issues[0].message);
  }
  return r.normalized;
}

// Returns the upper-cased 17-char form. Throws FormatError if invalid.
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

// Computes the ISO 3779 weighted-sum check digit expected for the (already
// validated, upper-case) 17-char vin.
function expectedCheckDigit(vin: string): string {
  let sum = 0;
  for (let i = 0; i < 17; i++) {
    sum += TRANSLITERATION[vin[i]] * WEIGHTS[i];
  }
  const r = sum % 11;
  return r === 10 ? 'X' : String(r);
}

// Decodes the model year from char 10, disambiguating the 30-year repeat
// cycle using char 7 (a letter selects 2010-2039, a digit keeps the
// 1980-2009 base cycle).
function decodeModelYear(vin: string): number {
  const baseYear = YEAR_CODES[vin[9]];
  const positionSeven = vin[6];
  return LETTER_RE.test(positionSeven) ? baseYear + 30 : baseYear;
}

// Parses input into a VinInfo, or null when it is not a structurally valid
// VIN.
function parse(input: string): VinInfo | null {
  const r = validate(input);
  if (!r.ok) return null;
  const vin = r.normalized;
  const checkDigit = vin.substring(8, 9);
  return {
    wmi: vin.substring(0, 3),
    vds: vin.substring(3, 9),
    vis: vin.substring(9, 17),
    checkDigit,
    checkDigitValid: expectedCheckDigit(vin) === checkDigit,
    modelYear: decodeModelYear(vin),
    plantCode: vin.substring(10, 11),
  };
}

export const Vin = { isValid, validate, normalize, format, tryFormat, parse };
export type { VinInfo };
