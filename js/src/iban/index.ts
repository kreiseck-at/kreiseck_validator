import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';
import { kIbanBban, kBanks } from './metadata';

// Validation, normalization and formatting of IBANs.
//
// The ISO 13616 check digits are verified with the Mod-97 algorithm. Length
// is enforced for every country with a known BBAN layout; other countries
// are accepted on checksum alone.

const STRUCTURE_RE = /^[A-Z]{2}[0-9]{2}[0-9A-Z]+$/;
const WHITESPACE_RE = /\s/g;

// Removes all whitespace and upper-cases the input.
function strip(input: string): string {
  return input.replace(WHITESPACE_RE, '').toUpperCase();
}

// Mod-97 checksum: move first 4 chars to the end, map letters A-Z to
// 10-35, take the big integer mod 97 in 7-digit chunks; valid when == 1.
function checksumOk(iban: string): boolean {
  const rearranged = iban.substring(4) + iban.substring(0, 4);
  let digits = '';
  for (let i = 0; i < rearranged.length; i++) {
    const cu = rearranged.charCodeAt(i);
    if (cu >= 0x30 && cu <= 0x39) {
      digits += String(cu - 0x30);
    } else if (cu >= 0x41 && cu <= 0x5a) {
      digits += String(cu - 0x37);
    } else {
      return false;
    }
  }
  let remainder = 0;
  for (let i = 0; i < digits.length; i += 7) {
    const end = Math.min(i + 7, digits.length);
    remainder = parseInt(`${remainder}${digits.substring(i, end)}`, 10) % 97;
  }
  return remainder === 1;
}

// Validates input, returning the compact upper-case form on success.
function validate(input: string): ValidationResult {
  const s = strip(input);
  if (s.length === 0) {
    return invalid('ibanEmpty', 'IBAN is empty.');
  }
  if (!STRUCTURE_RE.test(s)) {
    return invalid('ibanBadChars', 'IBAN has invalid characters.');
  }
  const country = s.substring(0, 2);
  const expected = kIbanBban[country]?.length;
  if (expected !== undefined && s.length !== expected) {
    return invalid('ibanBadLength', 'Wrong length.');
  }
  if (!checksumOk(s)) {
    return invalid('ibanBadChecksum', 'Checksum failed.');
  }
  return valid(s);
}

// True when validate returns a valid result.
function isValid(input: string): boolean {
  return validate(input).ok;
}

// Returns the compact upper-case canonical form. Throws FormatError.
function normalize(input: string): string {
  const r = validate(input);
  if (!r.ok) {
    throw new FormatError(r.issues[0].message);
  }
  return r.normalized;
}

// Returns the IBAN grouped in blocks of four. Throws FormatError.
function format(input: string): string {
  return (normalize(input).match(/.{1,4}/g) ?? []).join(' ');
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

// Structured data parsed out of an IBAN by Iban.parse.
//
// Structural fields (bankCode, branchCode, accountNumber) are filled for
// every country whose BBAN layout is known; they are null otherwise.
// bankName and bic are filled only when the bank code is known.
//
// country is the ISO 3166-1 alpha-2 code, exposed as a plain string.
export interface IbanInfo {
  country: string;
  checkDigits: string;
  bankCode: string | null;
  branchCode: string | null;
  accountNumber: string | null;
  bankName: string | null;
  bic: string | null;
  formatted: string;
}

// Parses input into an IbanInfo, or null when it is not a valid IBAN.
function parse(input: string): IbanInfo | null {
  const r = validate(input);
  if (!r.ok) return null;
  const s = r.normalized;
  const code = s.substring(0, 2);
  const struct = kIbanBban[code];
  let bankCode: string | null = null;
  let branchCode: string | null = null;
  let accountNumber: string | null = null;
  if (struct !== undefined && s.length === struct.length) {
    const rawBank = s.substring(struct.bankStart, struct.bankEnd);
    bankCode = rawBank.length === 0 ? null : rawBank;
    const bStart = struct.branchStart;
    const bEnd = struct.branchEnd;
    if (bStart !== null && bEnd !== null) {
      branchCode = s.substring(bStart, bEnd);
    }
    accountNumber = s.substring(bEnd ?? struct.bankEnd);
  }
  let bankName: string | null = null;
  let bic: string | null = null;
  if (bankCode !== null) {
    const bank = kBanks[code]?.[bankCode];
    if (bank !== undefined) {
      bankName = bank.name;
      bic = bank.bic;
    }
  }
  return {
    country: code,
    checkDigits: s.substring(2, 4),
    bankCode,
    branchCode,
    accountNumber,
    bankName,
    bic,
    formatted: format(input),
  };
}

export const Iban = { isValid, validate, normalize, format, tryFormat, parse };
