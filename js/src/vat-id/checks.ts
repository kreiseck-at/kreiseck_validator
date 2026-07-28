import { mod1110Ok, mod9710Ok } from '../common/iso7064';
import { luhnOk } from '../common/luhn';
import type { VatSubtype } from './types';

// Per-country VAT check-digit verification and subtype classification.
//
// Every function here receives the body WITHOUT its prefix, already
// upper-cased, separator-free and matched against the country's structure
// pattern -- so it may assume the length and character set are right and only
// has to do arithmetic.
//
// Each algorithm is documented in doc/algorithms.md together with the source
// it was taken from, and every one of them is pinned by at least one published
// number in test/vectors/vat_id.json. None of this code is derived from
// another implementation's source.

// A non-negative remainder.
//
// JavaScript's % keeps the sign of the dividend -- (6 - 9) % 10 is -3, where
// Dart gives 7. Several check digits below subtract a sum from a constant, so
// every one of those goes through this rather than a bare %. Getting it wrong
// fails silently on roughly half of all inputs, which is exactly the kind of
// bug the shared test vectors exist to catch.
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

// The digit at index of digits.
function d(digits: string, index: number): number {
  return digits.charCodeAt(index) - 48;
}

// digits read as an integer, folded modulo m so no intermediate value can
// exceed m * 10 + 9. Long identifiers would otherwise lose precision.
function modOf(digits: string, m: number): number {
  let r = 0;
  for (let i = 0; i < digits.length; i++) {
    r = (r * 10 + d(digits, i)) % m;
  }
  return r;
}

// The Luhn check digit that makes body + digit satisfy the Luhn checksum.
function luhnCheckDigit(body: string): number {
  for (let i = 0; i <= 9; i++) {
    if (luhnOk(`${body}${i}`)) return i;
  }
  return -1; // unreachable: exactly one digit always satisfies Luhn
}

function isDigit(c: string): boolean {
  const code = c.charCodeAt(0);
  return code >= 48 && code <= 57;
}

// --- single-formula countries ----------------------------------------------

// AT: Luhn over the eight digits, the check digit being
// (6 - luhn(first seven)) mod 10.
function checkAt(body: string): boolean {
  let sum = 0;
  // Doubling alternates from the right of the seven-digit body, starting
  // undoubled: the seventh digit counts as itself, the sixth is doubled.
  let alt = false;
  for (let i = 6; i >= 0; i--) {
    let x = d(body, i);
    if (alt) { x *= 2; if (x > 9) x -= 9; }
    sum += x;
    alt = !alt;
  }
  return mod(6 - sum % 10, 10) === d(body, 7);
}

// BE: the first eight digits read as a number, PLUS the last two read as a
// number, is a multiple of 97. Note the addition -- this is not one long
// number taken modulo 97.
function checkBe(body: string): boolean {
  return (modOf(body.substring(0, 8), 97) + Number(body.substring(8, 10))) % 97 === 0;
}

// CH: weights 5, 4, 3, 2, 7, 6, 5, 4 over the first eight digits; the check
// digit is (11 - sum) mod 11, and a computed 10 means no number was issued.
function checkCh(body: string): boolean {
  const check = mod(11 - weighted(body, [5, 4, 3, 2, 7, 6, 5, 4]) % 11, 11);
  return check !== 10 && check === d(body, 8);
}

// CY: digits at even positions mapped through a substitution table, digits at
// odd positions added as they are, the sum modulo 26 selecting a letter.
function checkCy(body: string): boolean {
  const map = [1, 0, 5, 7, 9, 13, 15, 17, 19, 21];
  let sum = 0;
  for (let i = 0; i < 8; i++) {
    sum += i % 2 === 0 ? map[d(body, i)] : d(body, i);
  }
  return 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'[sum % 26] === body[8];
}

// DE: ISO 7064 MOD 11,10 over the whole body.
function checkDe(body: string): boolean { return mod1110Ok(body); }

// HR: the OIB, ISO 7064 MOD 11,10.
function checkHr(body: string): boolean { return mod1110Ok(body); }

// DK: weights 2, 7, 6, 5, 4, 3, 2, 1; the weighted sum is a multiple of 11.
function checkDk(body: string): boolean {
  return weighted(body, [2, 7, 6, 5, 4, 3, 2, 1]) % 11 === 0;
}

// EE: weights 3, 7, 1 repeated; the weighted sum is a multiple of 10.
function checkEe(body: string): boolean {
  return weighted(body, [3, 7, 1, 3, 7, 1, 3, 7, 1]) % 10 === 0;
}

// FI: weights 7, 9, 10, 5, 8, 4, 2, 1; the weighted sum is a multiple of 11.
function checkFi(body: string): boolean {
  return weighted(body, [7, 9, 10, 5, 8, 4, 2, 1]) % 11 === 0;
}

// GR: an iterative doubling accumulator over the first eight digits; the check
// digit is 2c mod 11 mod 10.
function checkGr(body: string): boolean {
  let c = 0;
  for (let i = 0; i < 8; i++) c = c * 2 + d(body, i);
  return c * 2 % 11 % 10 === d(body, 8);
}

// HU: weights 9, 7, 3, 1 repeated; the weighted sum is a multiple of 10.
function checkHu(body: string): boolean {
  return weighted(body, [9, 7, 3, 1, 9, 7, 3, 1]) % 10 === 0;
}

// IT: Luhn over all eleven digits, plus two structural rules the pattern
// cannot express -- the office code in positions 8-10 must be a real one, and
// the seven-digit company part must not be all zeros.
function checkIt(body: string): boolean {
  if (!luhnOk(body)) return false;
  const office = body.substring(7, 10);
  const inRange = office >= '001' && office <= '100';
  if (!inRange && !['120', '121', '888', '999'].includes(office)) return false;
  return Number(body.substring(0, 7)) !== 0;
}

// LU: the first six digits modulo 89 equal the last two as a number.
function checkLu(body: string): boolean {
  return Number(body.substring(0, 6)) % 89 === Number(body.substring(6, 8));
}

// MT: weights 3, 4, 6, 7, 8, 9, 10, 1; the weighted sum is a multiple of 37.
function checkMt(body: string): boolean {
  return weighted(body, [3, 4, 6, 7, 8, 9, 10, 1]) % 37 === 0;
}

// PL: weights 6, 5, 7, 2, 3, 4, 5, 6, 7 and -1 on the check digit; the
// weighted sum is a multiple of 11.
function checkPl(body: string): boolean {
  return mod(weighted(body, [6, 5, 7, 2, 3, 4, 5, 6, 7, -1]), 11) === 0;
}

// PT: weights 9 down to 2; the check digit is (11 - sum) mod 11 mod 10.
function checkPt(body: string): boolean {
  const sum = weighted(body, [9, 8, 7, 6, 5, 4, 3, 2]);
  return mod(11 - sum, 11) % 10 === d(body, 8);
}

// RO: the body left-padded to nine digits, weights 7, 5, 3, 2, 1, 7, 5, 3, 2;
// the check digit is 10 * sum mod 11 mod 10.
function checkRo(body: string): boolean {
  const padded = body.substring(0, body.length - 1).padStart(9, '0');
  const sum = weighted(padded, [7, 5, 3, 2, 1, 7, 5, 3, 2]);
  return 10 * sum % 11 % 10 === d(body, body.length - 1);
}

// SE: the last two digits are always 01, and the first ten satisfy Luhn.
function checkSe(body: string): boolean {
  return body.substring(10) === '01' && luhnOk(body.substring(0, 10));
}

// SI: weights 8 down to 2; the check digit is 11 - (sum mod 11), where a
// computed 10 becomes 0 and 11 cannot occur for an issued number.
function checkSi(body: string): boolean {
  let check = 11 - weighted(body, [8, 7, 6, 5, 4, 3, 2]) % 11;
  if (check === 10) check = 0;
  return check !== 11 && check === d(body, 7);
}

// SK: the whole ten-digit number is a multiple of 11.
function checkSk(body: string): boolean { return modOf(body, 11) === 0; }

// --- branching countries ---------------------------------------------------

// BG: legal entities (9 digits) and natural persons (10) use different sums.
function checkBg(body: string): boolean {
  if (body.length === 9) {
    let sum = 0;
    for (let i = 0; i < 8; i++) sum += (i + 1) * d(body, i);
    let check = sum % 11;
    if (check === 10) {
      sum = 0;
      for (let i = 0; i < 8; i++) sum += (i + 3) * d(body, i);
      check = sum % 11;
    }
    return check % 10 === d(body, 8);
  }
  const sum = weighted(body, [4, 3, 2, 7, 6, 5, 4, 3, 2]);
  return mod(11 - sum, 11) === d(body, 9);
}

function subtypeBg(body: string): VatSubtype {
  return body.length === 9 ? 'legal' : 'person';
}

// CZ: three different numbers share one field.
//
// Eight digits is a legal entity and may not start with 9. Nine digits
// starting with 6 is a historical special form. Nine or ten digits otherwise
// is a rodné číslo (birth number): the ten-digit form carries a check digit,
// the nine-digit form carries none at all, so for that one length there is
// nothing to verify beyond the structure -- the embedded birth date is a
// plausibility rule about a person, not a checksum, and is deliberately not
// enforced here.
function checkCz(body: string): boolean {
  if (body.length === 8) {
    if (body[0] === '9') return false;
    let check = mod(11 - weighted(body, [8, 7, 6, 5, 4, 3, 2]), 11);
    if (check === 0) check = 1;
    return check % 10 === d(body, 7);
  }
  if (body.length === 9 && body[0] === '6') {
    const sum = weighted(body.substring(1), [8, 7, 6, 5, 4, 3, 2]);
    return mod(8 - mod(10 - sum % 11, 11), 10) === d(body, 8);
  }
  if (body.length === 10) {
    return modOf(body.substring(0, 9), 11) % 10 === d(body, 9);
  }
  return true; // nine-digit birth number: no check digit exists
}

function subtypeCz(body: string): VatSubtype {
  if (body.length === 8) return 'legal';
  if (body.length === 9 && body[0] === '6') return 'special';
  return 'individual';
}

// ES: four different identifiers share one field, told apart by the first
// character.
function checkEs(body: string): boolean {
  const dniLetters = 'TRWAGMYFPDXBNJZSQVHLCKE';
  const first = body[0];
  if (isDigit(first)) {
    return dniLetters[Number(body.substring(0, 8)) % 23] === body[8];
  }
  if ('XYZ'.includes(first)) {
    const lead = 'XYZ'.indexOf(first);
    return dniLetters[Number(`${lead}${body.substring(1, 8)}`) % 23] === body[8];
  }
  if ('KLM'.includes(first)) {
    return dniLetters[Number(body.substring(1, 8)) % 23] === body[8];
  }
  if ('ABCDEFGHJNPQRSUVW'.includes(first)) {
    // A legal entity: the Luhn check digit over the seven digits, accepted
    // either as that digit or as the letter it maps to. Sources disagree on
    // which organisation types must use which form, so both are allowed.
    const check = luhnCheckDigit(body.substring(1, 8));
    return body[8] === `${check}` || body[8] === 'JABCDEFGHI'[check];
  }
  return false;
}

function subtypeEs(body: string): VatSubtype {
  const first = body[0];
  if (isDigit(first) || 'KLM'.includes(first)) return 'dni';
  if ('XYZ'.includes(first)) return 'nie';
  return 'cif';
}

// FR: two digits or characters in front of a nine-digit SIREN.
//
// An all-numeric prefix is the SIREN followed by 12, modulo 97. A prefix
// containing a letter uses an alphabet-index formula instead. Either way the
// SIREN itself must satisfy Luhn, except for the Monegasque 000 block, which
// is a valid TVA number but not a SIREN.
//
// `check` is always non-negative here: the letter branch is only reached when
// at least one of the first two characters is a letter, whose alphabet index
// is at least 10, which keeps both formulas above zero. That is what lets the
// integer division below match Python's floor division.
function checkFr(body: string): boolean {
  const alphabet = '0123456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  const siren = body.substring(2);
  if (siren.substring(0, 3) !== '000' && !luhnOk(siren)) return false;
  if (isDigit(body[0]) && isDigit(body[1])) {
    return Number(body.substring(0, 2)) === modOf(`${siren}12`, 97);
  }
  const check = isDigit(body[0])
    ? alphabet.indexOf(body[0]) * 24 + alphabet.indexOf(body[1]) - 10
    : alphabet.indexOf(body[0]) * 34 + alphabet.indexOf(body[1]) - 100;
  return (Number(siren) + 1 + Math.floor(check / 11)) % 11 === check % 11;
}

// GB and XI: weights 8, 7, 6, 5, 4, 3, 2, 10, 1 over the first nine digits,
// modulo 97.
//
// Numbers whose first three digits reach 100 belong to a later allocation
// block and accept three residues rather than one. A twelve-digit number is a
// branch trader: only its first nine digits are checked. The GD/HA forms are
// government departments and health authorities, distinguished by their
// numeric range rather than a checksum.
function checkGb(body: string): boolean {
  if (body.startsWith('GD')) return Number(body.substring(2)) < 500;
  if (body.startsWith('HA')) return Number(body.substring(2)) >= 500;
  const nine = body.substring(0, 9);
  const sum = weighted(nine, [8, 7, 6, 5, 4, 3, 2, 10, 1]) % 97;
  if (Number(nine.substring(0, 3)) >= 100) {
    return sum === 0 || sum === 42 || sum === 55;
  }
  return sum === 0;
}

function subtypeGb(body: string): VatSubtype {
  if (body.startsWith('GD')) return 'government';
  if (body.startsWith('HA')) return 'healthAuthority';
  return body.length === 12 ? 'branch' : 'standard';
}

// IE: a 23-letter alphabet indexed by a weighted sum modulo 23.
//
// The current form is seven digits and one or two letters; the historical form
// puts a letter or symbol in second position. Both feed the same weighting,
// just over differently assembled digits.
function checkIe(body: string): boolean {
  const alphabet = 'WABCDEFGHIJKLMNOPQRSTUV';

  function checkCharFor(digits: string, second: string): string {
    const padded = digits.padStart(7, '0');
    const sum = weighted(padded, [8, 7, 6, 5, 4, 3, 2]);
    const extra = second.length === 0 ? 0 : 9 * alphabet.indexOf(second);
    return alphabet[(sum + extra) % 23];
  }

  const firstSeven = body.substring(0, 7);
  if (![...firstSeven].every(isDigit)) {
    // Historical form: digit, letter or symbol, five digits, check letter.
    return body[7] === checkCharFor(`${body.substring(2, 7)}${body[0]}`, '');
  }
  const second = body.length > 8 ? body.substring(8) : '';
  if (second.length > 0 && !alphabet.includes(second)) return false;
  return body[7] === checkCharFor(firstSeven, second);
}

// LT: nine digits for a company, twelve for a temporarily registered taxpayer.
// A first pass whose remainder is 10 is recomputed with the weight sequence
// shifted by two.
function checkLt(body: string): boolean {
  const n = body.length - 1;
  let sum = 0;
  for (let i = 0; i < n; i++) sum += (1 + i % 9) * d(body, i);
  let check = sum % 11;
  if (check === 10) {
    sum = 0;
    for (let i = 0; i < n; i++) sum += (1 + (i + 2) % 9) * d(body, i);
    check = sum % 11;
  }
  return check % 11 % 10 === d(body, n);
}

function subtypeLt(body: string): VatSubtype {
  return body.length === 12 ? 'temporary' : 'standard';
}

// LV: a legal entity when the first digit exceeds 3, otherwise a personal
// code, and the two use unrelated weightings.
function checkLv(body: string): boolean {
  if (d(body, 0) > 3) {
    return mod(weighted(body, [9, 1, 4, 8, 3, 10, 2, 5, 7, 6, 1]), 11) === 3;
  }
  const sum = weighted(body, [10, 5, 8, 4, 2, 1, 6, 3, 7, 9]);
  return (1 + sum) % 11 % 10 === d(body, 10);
}

function subtypeLv(body: string): VatSubtype {
  return d(body, 0) > 3 ? 'legal' : 'person';
}

// NL: nine digits, B, two digits.
//
// Numbers issued before 2020 embed a BSN and satisfy the Dutch eleven-proof.
// Sole traders were reissued in 2020 with a btw-identificatienummer that
// carries no BSN and is checked with ISO 7064 MOD 97,10 over 'NL' plus the
// whole number instead. Either passing is enough -- insisting on the
// eleven-proof would reject every reissued sole trader.
function nlElevenProof(nine: string): boolean {
  let sum = 0;
  for (let i = 0; i < 8; i++) sum += (9 - i) * d(nine, i);
  return mod(sum - d(nine, 8), 11) === 0;
}

function checkNl(body: string): boolean {
  return nlElevenProof(body.substring(0, 9)) || mod9710Ok(`NL${body}`);
}

function subtypeNl(body: string): VatSubtype {
  return nlElevenProof(body.substring(0, 9)) ? 'bsn' : 'btwId';
}

// --- dispatch --------------------------------------------------------------

const CHECKS: Record<string, (body: string) => boolean> = {
  AT: checkAt, BE: checkBe, BG: checkBg, CH: checkCh, CY: checkCy, CZ: checkCz,
  DE: checkDe, DK: checkDk, EE: checkEe, ES: checkEs, FI: checkFi, FR: checkFr,
  GB: checkGb, GR: checkGr, HR: checkHr, HU: checkHu, IE: checkIe, IT: checkIt,
  LT: checkLt, LU: checkLu, LV: checkLv, MT: checkMt, NL: checkNl, PL: checkPl,
  PT: checkPt, RO: checkRo, SE: checkSe, SI: checkSi, SK: checkSk, XI: checkGb,
};

const SUBTYPES: Record<string, (body: string) => VatSubtype> = {
  BG: subtypeBg, CZ: subtypeCz, ES: subtypeEs, GB: subtypeGb, LT: subtypeLt,
  LV: subtypeLv, NL: subtypeNl, XI: subtypeGb,
};

// True when the check digit of body is correct for iso2. Throws when no
// algorithm is registered: every country in kVatFormats must have one, and the
// test suite proves it. The dispatch deliberately has no "structure is enough"
// fallback.
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
