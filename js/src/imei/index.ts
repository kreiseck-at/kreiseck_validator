import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';
import { luhnOk } from '../common/luhn';
import type { ImeiInfo } from './types';

// Validation, normalization and formatting of IMEI (International Mobile
// Equipment Identity) numbers.
//
// Validation requires exactly 15 digits and a passing Luhn checksum over
// all 15 digits. Passing { allowSv: true } also accepts a 16-digit IMEISV
// (IMEI plus a 2-digit software version number); a 16-digit value is never
// Luhn-checked, since IMEISV has no check digit.

export interface ImeiOptions {
  allowSv?: boolean;
}

const DIGITS_RE = /^[0-9]+$/;

// Returns the digits-only form, discarding spaces and dashes.
function strip(input: string): string {
  return input.replace(/[\s-]/g, '');
}

// Validates input, returning a valid result with the compact normalized
// form (15 digits, or 16 when allowSv is true and an IMEISV is given) or an
// invalid result describing why it was rejected.
function validate(input: string, options: ImeiOptions = {}): ValidationResult {
  const allowSv = options.allowSv ?? false;
  const s = strip(input);
  if (s.length === 0) {
    return invalid('imeiEmpty', 'IMEI is empty.');
  }
  if (!DIGITS_RE.test(s)) {
    return invalid('imeiBadChars', 'IMEI has invalid characters.');
  }
  const ok = s.length === 15 || (allowSv && s.length === 16);
  if (!ok) {
    return invalid('imeiBadLength', allowSv ? 'IMEI must be 15 or 16 digits.' : 'IMEI must be 15 digits.');
  }
  if (s.length === 15 && !luhnOk(s)) {
    return invalid('imeiBadChecksum', 'Fails the Luhn checksum.');
  }
  return valid(s);
}

// True when validate returns a valid result.
function isValid(input: string, options: ImeiOptions = {}): boolean {
  return validate(input, options).ok;
}

// Returns the compact canonical form (15 or 16 digits). Throws FormatError
// if input is not a valid IMEI.
function normalize(input: string, options: ImeiOptions = {}): string {
  const r = validate(input, options);
  if (!r.ok) {
    throw new FormatError(r.issues[0].message);
  }
  return r.normalized;
}

// Returns the compact form. Throws FormatError if invalid.
function format(input: string, options: ImeiOptions = {}): string {
  return normalize(input, options);
}

// Like format but returns null instead of throwing on invalid input.
function tryFormat(input: string, options: ImeiOptions = {}): string | null {
  try {
    return format(input, options);
  } catch (e) {
    if (e instanceof FormatError) return null;
    throw e;
  }
}

// Parses input into an ImeiInfo, or null when it is not a valid IMEI.
function parse(input: string, options: ImeiOptions = {}): ImeiInfo | null {
  const r = validate(input, options);
  if (!r.ok) return null;
  const s = r.normalized;
  const isSv = s.length === 16;
  return {
    tac: s.substring(0, 8),
    serialNumber: s.substring(8, 14),
    checkDigit: isSv ? null : s.substring(14),
    reportingBodyIdentifier: s.substring(0, 2),
    softwareVersion: isSv ? s.substring(14, 16) : null,
  };
}

export const Imei = { isValid, validate, normalize, format, tryFormat, parse };
export type { ImeiInfo };
