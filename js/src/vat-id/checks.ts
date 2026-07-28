import type { VatSubtype } from './types';

// Per-country VAT check-digit verification and subtype classification.
//
// Every function here receives the body WITHOUT its prefix, already
// upper-cased, separator-free and matched against the country's structure
// pattern -- so it may assume the length and character set are right and only
// has to do arithmetic.
//
// Each algorithm is documented in doc/algorithms.md together with the source
// it was taken from. None of this code is derived from another
// implementation's source.

// A non-negative remainder.
//
// JavaScript's % keeps the sign of the dividend -- (6 - 9) % 10 is -3, where
// Dart gives 7. Every check digit in this file is a positive residue, so every
// one of them goes through this rather than a bare %. Getting it wrong fails
// silently on roughly half of all inputs, which is exactly the kind of bug the
// shared test vectors exist to catch.
export function mod(value: number, m: number): number {
  return ((value % m) + m) % m;
}

// Sum of each digit of `digits` times the weight at the same index.
export function weighted(digits: string, weights: number[]): number {
  let sum = 0;
  const n = Math.min(weights.length, digits.length);
  for (let i = 0; i < n; i++) {
    sum += (digits.charCodeAt(i) - 48) * weights[i];
  }
  return sum;
}

// AT: Luhn over the eight digits, with the check digit being
// (6 - luhn(first seven)) mod 10.
function checkAt(body: string): boolean {
  let sum = 0;
  // Doubling alternates from the right of the seven-digit body, starting
  // undoubled: the seventh digit counts as itself, the sixth is doubled.
  let alt = false;
  for (let i = 6; i >= 0; i--) {
    let d = body.charCodeAt(i) - 48;
    if (alt) { d *= 2; if (d > 9) d -= 9; }
    sum += d;
    alt = !alt;
  }
  return mod(6 - sum % 10, 10) === body.charCodeAt(7) - 48;
}

const CHECKS: Record<string, (body: string) => boolean> = {
  AT: checkAt,
};

const SUBTYPES: Record<string, (body: string) => VatSubtype> = {};

// True when the check digit of body is correct for iso2. Throws when no
// algorithm is registered: every country in kVatFormats must have one, and
// the test suite proves it.
export function checkVat(iso2: string, body: string): boolean {
  const check = CHECKS[iso2];
  if (check === undefined) {
    throw new Error(`No VAT check digit implemented for ${iso2}`);
  }
  return check(body);
}

// Which kind of number body is for iso2.
export function vatSubtypeOf(iso2: string, body: string): VatSubtype {
  const classify = SUBTYPES[iso2];
  return classify === undefined ? 'standard' : classify(body);
}
