import { VoucherCode } from '../voucher-code/index';

// Voucher number of an external system (a business's own voucher scheme),
// printed on receipts as-is. Rules: trim (fixed whitespace set, identical in Dart
// and JS), then only [A-Za-z0-9-_./], 1 to 40 characters. Case is preserved.

const TRIM = /^[\t\n\v\f\r \u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff]+|[\t\n\v\f\r \u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff]+$/g;
const PATTERN = /^[A-Za-z0-9\-_./]{1,40}$/;

// Returns the trimmed form, or null if it breaks the rules.
function normalize(input: string): string | null {
  const s = input.replace(TRIM, '');
  return PATTERN.test(s) ? s : null;
}

// True when normalize returns a value.
function isValid(input: string): boolean {
  return normalize(input) !== null;
}

// True when the text is a valid own voucher code (Damm check symbol).
export function isOwnVoucherCode(input: string): boolean {
  return VoucherCode.isValid(input);
}

export const ExternalVoucherNumber = {
  isValid,
  normalize,
};
