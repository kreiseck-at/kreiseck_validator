import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';
import { luhnOk } from '../common/luhn';
import { fromCallingCode } from '../phone/metadata';
import type { IccidInfo } from './types';

// Validation, normalization and formatting of ICCID (Integrated Circuit
// Card Identifier, ITU-T E.118) numbers, i.e. SIM card identifiers.
//
// Validation requires 19 or 20 digits starting with the telecom MII 89.
// When the ICCID is 20 digits, the last digit is a Luhn check digit;
// 19-digit ICCIDs carry no check digit.

const DIGITS_RE = /^[0-9]+$/;

// Returns the digits-only form, discarding spaces and dashes.
function strip(input: string): string {
  return input.replace(/[\s-]/g, '');
}

// Validates input, returning a valid result with the compact digit-only
// normalized form or an invalid result describing why it was rejected.
function validate(input: string): ValidationResult {
  const s = strip(input);
  if (s.length === 0) {
    return invalid('iccidEmpty', 'ICCID is empty.');
  }
  if (!DIGITS_RE.test(s)) {
    return invalid('iccidBadChars', 'ICCID has invalid characters.');
  }
  if ((s.length !== 19 && s.length !== 20) || !s.startsWith('89')) {
    return invalid('iccidBadLength', 'ICCID must be 19 or 20 digits starting with 89.');
  }
  if (s.length === 20 && !luhnOk(s)) {
    return invalid('iccidBadChecksum', 'Fails the Luhn checksum.');
  }
  return valid(s);
}

// True when validate returns a valid result.
function isValid(input: string): boolean {
  return validate(input).ok;
}

// Returns the compact digit-only canonical form. Throws FormatError if
// input is not a valid ICCID.
function normalize(input: string): string {
  const r = validate(input);
  if (!r.ok) {
    throw new FormatError(r.issues[0].message);
  }
  return r.normalized;
}

// Returns the compact digit-only form. Throws FormatError if invalid.
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

// Parses input into an IccidInfo, or null when it is not a valid ICCID.
function parse(input: string): IccidInfo | null {
  const r = validate(input);
  if (!r.ok) return null;
  const s = r.normalized;
  const hasCheckDigit = s.length === 20;
  const checkDigit = hasCheckDigit ? s.substring(s.length - 1) : null;
  const afterMii = s.substring(2, hasCheckDigit ? s.length - 1 : s.length);

  let country = null;
  let countryCodeLength = 0;
  for (const k of [3, 2, 1]) {
    if (afterMii.length < k) continue;
    const candidate = afterMii.substring(0, k);
    const resolved = fromCallingCode(candidate);
    if (resolved) {
      country = resolved;
      countryCodeLength = k;
      break;
    }
  }

  return {
    mii: s.substring(0, 2),
    country,
    issuerIdentifier: afterMii.substring(countryCodeLength),
    checkDigit,
  };
}

export const Iccid = { isValid, validate, normalize, format, tryFormat, parse };
export type { IccidInfo };
