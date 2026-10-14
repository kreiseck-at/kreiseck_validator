import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';
import type { FieldDescriptor } from '../common/field';

// Voucher codes: 12 symbols of Crockford Base32 (no I, L, O, U), the last one a
// Damm check symbol over GF(32) (x^5 + x^2 + 1, x∘y = 2·x ⊕ y). The check symbol
// catches every single-symbol error and every swap of two adjacent symbols.
// Input is case-insensitive; O reads as 0, I and L read as 1; spaces and dashes
// are ignored. See doc/algorithms.md.

const ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const LENGTH = 12;

function mul(a: number, b: number): number {
  let r = 0;
  while (b !== 0) {
    if ((b & 1) !== 0) r ^= a;
    b >>= 1;
    a <<= 1;
    if ((a & 32) !== 0) a ^= 0x25;
  }
  return r;
}

function interim(s: string): number {
  let acc = 0;
  for (const ch of s) {
    acc = mul(2, acc) ^ ALPHABET.indexOf(ch);
  }
  return acc;
}

function strip(input: string): string {
  return input
    .toUpperCase()
    .replace(/[\s-]/g, '')
    .replace(/O/g, '0')
    .replace(/I/g, '1')
    .replace(/L/g, '1');
}

// Returns the check symbol for an 11-symbol payload (already normalized).
function checkSymbol(payload: string): string {
  return ALPHABET[mul(2, interim(payload))];
}

// Builds a code from at least 11 random bytes (each byte's low five bits pick
// one symbol; 256 is a multiple of 32, so every symbol is equally likely).
function generate(randomBytes: Uint8Array): string {
  if (randomBytes.length < LENGTH - 1) {
    throw new RangeError(`needs at least ${LENGTH - 1} bytes`);
  }
  let payload = '';
  for (let i = 0; i < LENGTH - 1; i++) payload += ALPHABET[randomBytes[i] & 31];
  return payload + checkSymbol(payload);
}

// Validates input, returning a valid result with the compact upper-case form
// or an invalid result describing why it was rejected.
function validate(input: string): ValidationResult {
  const s = strip(input);
  if (s.length === 0) {
    return invalid('voucherCodeEmpty', 'Voucher code is empty.');
  }
  for (const c of s) {
    if (!ALPHABET.includes(c)) {
      return invalid('voucherCodeBadChars', 'Voucher code has invalid characters.');
    }
  }
  if (s.length !== LENGTH) {
    return invalid('voucherCodeBadLength', 'Voucher code must have 12 characters.');
  }
  if (interim(s) !== 0) {
    return invalid('voucherCodeBadChecksum', 'Fails the check symbol.');
  }
  return valid(s);
}

// True when validate returns a valid result.
function isValid(input: string): boolean {
  return validate(input).ok;
}

// Returns the compact upper-case canonical form. Throws FormatError if input
// is not a valid voucher code.
function normalize(input: string): string {
  const r = validate(input);
  if (!r.ok) {
    throw new FormatError(r.issues[0].message);
  }
  return r.normalized;
}

// Returns the code grouped as XXXX-XXXX-XXXX. Throws FormatError if invalid.
function format(input: string): string {
  const s = normalize(input);
  return `${s.substring(0, 4)}-${s.substring(4, 8)}-${s.substring(8)}`;
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

// Describes a voucher-code input field.
function fieldDescriptor(): FieldDescriptor {
  return {
    keyboard: 'text',
    autofill: null,
    capitalization: 'characters',
    maxLength: 14,
    example: 'K7QM-3XRP-9DWF',
    allowedChars: '0-9A-Za-z -',
  };
}

// Partial input for a text field: upper case, O/I/L mapped, foreign
// characters dropped, dashes after 4 and 8 symbols, at most 12 symbols.
// Never throws.
function formatPartial(input: string): string {
  const s = [...strip(input)].filter((c) => ALPHABET.includes(c)).slice(0, LENGTH);
  let out = '';
  for (let i = 0; i < s.length; i++) {
    if (i === 4 || i === 8) out += '-';
    out += s[i];
  }
  return out;
}

export const VoucherCode = {
  isValid,
  validate,
  normalize,
  format,
  tryFormat,
  generate,
  checkSymbol,
  fieldDescriptor,
  formatPartial,
};
