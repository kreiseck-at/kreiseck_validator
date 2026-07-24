import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';
import { luhnOk } from '../common/luhn';

// Validation, normalization and formatting of payment-card numbers.
//
// Validation combines a network-specific length check with the Luhn
// checksum.

export type CardNetwork = 'visa' | 'mastercard' | 'amex' | 'discover' | 'unknown';

const DIGITS_RE = /^[0-9]+$/;

// Returns the digits-only form, discarding spaces and dashes.
function strip(input: string): string {
  return input.replace(/[\s-]/g, '');
}

// Detects the CardNetwork from the leading digits, or null if empty/non-digit.
function network(input: string): CardNetwork | null {
  const s = strip(input);
  if (s.length === 0 || !DIGITS_RE.test(s)) return null;
  const n2 = parseInt(s.substring(0, s.length >= 2 ? 2 : 1).padEnd(2, '0'), 10);
  const n3 = parseInt(s.substring(0, s.length >= 3 ? 3 : s.length).padEnd(3, '0'), 10);
  const n4 = s.length >= 4 ? parseInt(s.substring(0, 4), 10) : n2 * 100;
  if (s[0] === '4') return 'visa';
  if (n2 === 34 || n2 === 37) return 'amex';
  if ((n2 >= 51 && n2 <= 55) || (n4 >= 2221 && n4 <= 2720)) {
    return 'mastercard';
  }
  if (n4 === 6011 || n2 === 65 || (n3 >= 644 && n3 <= 649)) {
    return 'discover';
  }
  return 'unknown';
}

const LENGTHS: Record<string, Set<number>> = {
  visa: new Set([13, 16, 19]),
  mastercard: new Set([16]),
  amex: new Set([15]),
  discover: new Set([16, 19]),
};

// Validates input, returning a valid result with the digits-only normalized
// form or an invalid result describing why it was rejected.
function validate(input: string): ValidationResult {
  const s = strip(input);
  if (s.length === 0) {
    return invalid('cardEmpty', 'Card number is empty.');
  }
  if (!DIGITS_RE.test(s)) {
    return invalid('cardBadChars', 'Card number has non-digits.');
  }
  const net = network(s);
  const allowed = net === null ? undefined : LENGTHS[net];
  if (allowed !== undefined) {
    if (!allowed.has(s.length)) {
      return invalid('cardBadLength', 'Wrong length for network.');
    }
  } else if (s.length < 12 || s.length > 19) {
    // Unknown network: enforce the ISO/IEC 7812 PAN range so short,
    // Luhn-clean junk (e.g. "00") is not accepted as a card.
    return invalid('cardBadLength', 'Implausible card length.');
  }
  if (!luhnOk(s)) {
    return invalid('cardBadLuhn', 'Fails the Luhn checksum.');
  }
  return valid(s);
}

// True when validate returns a valid result.
function isValid(input: string): boolean {
  return validate(input).ok;
}

// Returns the digits-only canonical form. Throws FormatError if input is
// not a valid card number.
function normalize(input: string): string {
  const r = validate(input);
  if (!r.ok) {
    throw new FormatError(r.issues[0].message);
  }
  return r.normalized;
}

// Returns input grouped for display (Amex 4-6-5, otherwise 4-4-4-4).
// Throws FormatError if invalid.
function format(input: string): string {
  const s = normalize(input);
  const groups = network(s) === 'amex' ? [4, 6, 5] : null;
  if (groups === null) {
    return (s.match(/.{1,4}/g) ?? []).join(' ');
  }
  const out: string[] = [];
  let i = 0;
  for (const g of groups) {
    out.push(s.substring(i, i + g));
    i += g;
  }
  return out.join(' ');
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

export const CreditCard = { isValid, validate, normalize, format, tryFormat, network };
