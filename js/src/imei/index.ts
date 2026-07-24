import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';
import { luhnOk } from '../common/luhn';
import type { ImeiInfo } from './types';

// Validation, normalization and formatting of IMEI (International Mobile
// Equipment Identity) numbers.
//
// Validation requires exactly 15 digits and a passing Luhn checksum over
// all 15 digits. IMEISV (16-digit, no checksum) is out of scope.

const DIGITS_RE = /^[0-9]+$/;

// Returns the digits-only form, discarding spaces and dashes.
function strip(input: string): string {
  return input.replace(/[\s-]/g, '');
}

// Validates input, returning a valid result with the compact 15-digit
// normalized form or an invalid result describing why it was rejected.
function validate(input: string): ValidationResult {
  const s = strip(input);
  if (s.length === 0) {
    return invalid('imeiEmpty', 'IMEI is empty.');
  }
  if (!DIGITS_RE.test(s)) {
    return invalid('imeiBadChars', 'IMEI has invalid characters.');
  }
  if (s.length !== 15) {
    return invalid('imeiBadLength', 'IMEI must be 15 digits.');
  }
  if (!luhnOk(s)) {
    return invalid('imeiBadChecksum', 'Fails the Luhn checksum.');
  }
  return valid(s);
}

// True when validate returns a valid result.
function isValid(input: string): boolean {
  return validate(input).ok;
}

// Returns the compact 15-digit canonical form. Throws FormatError if input
// is not a valid IMEI.
function normalize(input: string): string {
  const r = validate(input);
  if (!r.ok) {
    throw new FormatError(r.issues[0].message);
  }
  return r.normalized;
}

// Returns the compact 15-digit form. Throws FormatError if invalid.
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

// Parses input into an ImeiInfo, or null when it is not a valid IMEI.
function parse(input: string): ImeiInfo | null {
  const r = validate(input);
  if (!r.ok) return null;
  const s = r.normalized;
  return {
    tac: s.substring(0, 8),
    serialNumber: s.substring(8, 14),
    checkDigit: s.substring(14),
    reportingBodyIdentifier: s.substring(0, 2),
  };
}

export const Imei = { isValid, validate, normalize, format, tryFormat, parse };
export type { ImeiInfo };
