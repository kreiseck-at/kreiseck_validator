import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';
import type { FieldDescriptor } from '../common/field';
import type { CompanyRegisterInfo } from './types';

// Validation, normalization, formatting and parsing of company-register
// numbers.
//
// Austria only in this release. `country` is required so other countries can
// be added without a breaking rename.
//
// The Austrian Firmenbuchnummer is up to six digits plus one check letter,
// written `FN 123456a`. The check letter is computed from the digits
// zero-padded to six, weighted 6, 4, 14, 15, 10, 1 from the left, summed
// modulo 17, and indexed into a 17-letter table that omits the confusable
// C, E, J, L, N, O, Q, R and U. That table is itself a validation rule: a `c`
// can never be a valid check letter.
//
// Two pieces of folklore about this number are wrong, and both are refuted by
// the verification data in doc/algorithms.md:
//
// - It is NOT `number mod 26`. That rule reproduces one of twelve real
//   numbers, by coincidence.
// - The letter does NOT encode the legal form. Seven verified GmbHs carry
//   seven different letters.
//
// This is also the one type whose normalize does not upper-case: the canonical
// written form keeps the check letter lower-case. The `FN` prefix is
// presentation -- accepted on input, not stored.

export interface CompanyRegisterOptions { country: string }
export interface CompanyRegisterFieldOptions { country?: string }

const TABLE = 'ABDFGHIKMPSTVWXYZ';
const WEIGHTS = [6, 4, 14, 15, 10, 1];

const SHAPE_RE = /^([0-9]{1,6})([A-Za-z])$/;
// Strips a leading FN (either case, with any following dots or spaces) and
// every remaining space. The prefix is presentation, not data.
const STRIP_RE = /^\s*[Ff][Nn][\s.]*|\s/g;
const DISALLOWED_RE = /[^0-9A-Za-z]/g;
const NON_DIGIT_RE = /[^0-9]/g;

function isAustria(country: string | undefined): boolean {
  return country !== undefined && country.toUpperCase() === 'AT';
}

// The expected check letter, lower-case, for a digit string of 1-6 digits
// (not padded -- this pads internally).
function checkChar(digits: string): string {
  const padded = digits.padStart(6, '0');
  let sum = 0;
  for (let i = 0; i < 6; i++) {
    sum += (padded.charCodeAt(i) - 48) * WEIGHTS[i];
  }
  return TABLE[sum % 17].toLowerCase();
}

// Validates input for the given country, returning the digits plus the
// lower-case check letter and no FN prefix.
function validate(input: string, o: CompanyRegisterOptions): ValidationResult {
  if (!isAustria(o.country)) {
    return invalid('companyRegisterUnknownCountry', 'No company-register rules for this country.');
  }
  const compact = input.toUpperCase().replace(STRIP_RE, '');
  if (compact.length === 0) {
    return invalid('companyRegisterEmpty', 'Company-register number is empty.');
  }
  const m = SHAPE_RE.exec(compact);
  if (m === null) {
    return invalid('companyRegisterBadFormat',
      'Company-register number must be up to 6 digits and one letter.');
  }
  const digits = m[1];
  const letter = m[2].toLowerCase();
  if (!TABLE.toLowerCase().includes(letter)) {
    return invalid('companyRegisterBadFormat', 'That letter is never used as a check letter.');
  }
  if (checkChar(digits) !== letter) {
    return invalid('companyRegisterBadChecksum', 'Company-register check letter is wrong.');
  }
  return valid(`${digits}${letter}`);
}

// True when validate returns a valid result.
function isValid(input: string, o: CompanyRegisterOptions): boolean {
  return validate(input, o).ok;
}

// Returns the digits plus the lower-case check letter, without the FN prefix.
// Throws FormatError if invalid.
function normalize(input: string, o: CompanyRegisterOptions): string {
  const r = validate(input, o);
  if (!r.ok) throw new FormatError(r.issues[0].message);
  return r.normalized;
}

// Returns the conventional FN 123456a form. Throws FormatError if invalid.
function format(input: string, o: CompanyRegisterOptions): string {
  return `FN ${normalize(input, o)}`;
}

// Like format but returns null instead of throwing on invalid input.
function tryFormat(input: string, o: CompanyRegisterOptions): string | null {
  try {
    return format(input, o);
  } catch (e) {
    if (e instanceof FormatError) return null;
    throw e;
  }
}

// Parses input into a CompanyRegisterInfo, or null when it is not valid.
function parse(input: string, o: CompanyRegisterOptions): CompanyRegisterInfo | null {
  const r = validate(input, o);
  if (!r.ok) return null;
  const n = r.normalized;
  return { number: n.substring(0, n.length - 1), checkChar: n[n.length - 1] };
}

// Describes a company-register input field.
//
// capitalization is 'none', unlike every other alphanumeric identifier here:
// the canonical form keeps the check letter lower-case, so upper-casing at the
// keyboard would fight normalize. maxLength is 7 -- the identifier without the
// presentational FN.
function fieldDescriptor(o: CompanyRegisterFieldOptions = {}): FieldDescriptor {
  if (!isAustria(o.country)) {
    return {
      keyboard: 'text',
      autofill: null,
      capitalization: 'none',
      maxLength: null,
      example: null,
      allowedChars: '0-9A-Za-z',
    };
  }
  return {
    keyboard: 'text',
    autofill: null,
    capitalization: 'none',
    maxLength: 7,
    example: '415772f',
    allowedChars: '0-9A-Za-z',
  };
}

// Formats partially typed input: the FN prefix and anything outside digits and
// letters dropped, capped at seven characters, a trailing letter lower-cased.
// Never throws.
function formatPartial(input: string, _o: CompanyRegisterFieldOptions = {}): string {
  let s = input.replace(STRIP_RE, '').replace(DISALLOWED_RE, '');
  if (s.length > 7) s = s.substring(0, 7);
  if (s.length === 0) return s;
  const head = s.substring(0, s.length - 1);
  const last = s.substring(s.length - 1);
  return `${head.replace(NON_DIGIT_RE, '')}${last.toLowerCase()}`;
}

export const CompanyRegister = {
  isValid, validate, normalize, format, tryFormat, parse, checkChar,
  fieldDescriptor, formatPartial,
};
export type { CompanyRegisterInfo };
