import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';
import type { FieldDescriptor } from '../common/field';
import { prepare } from '../common/partial';
import type { SocialSecurityInfo, SsnBirthDate } from './types';

// Validation, normalization, formatting and parsing of social-security
// numbers.
//
// Austria only in this release. `country` is required so other countries can
// be added without a breaking rename.
//
// The Austrian Versicherungsnummer is ten digits, written `NNNP TTMMJJ`: a
// three-digit serial, a check digit, then the date of birth. The serial runs
// from 100 to 999 -- it never starts with a zero, and `0000TTMMJJ` is the
// placeholder written on forms to mean the number is unknown, so a leading
// zero is rejected. The nine non-check digits are weighted 3, 7, 9, 5, 8, 4,
// 2, 1, 6 from the left and the sum taken modulo 11. A remainder of 10 is
// never issued -- the serial is skipped instead -- so such a number is
// rejected rather than treated as an edge case.
//
// Validation never looks at the date. Fictitious dates are issued on purpose:
// when every serial for a real date is used up, months 13, 14 and 15 are
// handed out, and someone whose birthday is unknown gets 1 January or 1 July
// of their birth year. Rejecting those would reject real people. The checksum
// alone decides, and birthDate is null whenever the digits do not form a real
// calendar date.

export interface SsnOptions { country: string }
export interface SsnFieldOptions { country?: string }

// Position 4 (index 3) is the check digit itself and carries weight 0.
const WEIGHTS = [3, 7, 9, 0, 5, 8, 4, 2, 1, 6];

const SEPARATORS_RE = /[\s/-]/g;
const DIGITS_RE = /^[0-9]+$/;

// February is 29 here on purpose: the number carries no century, so whether a
// given two-digit year was a leap year is unknowable. 29 February is therefore
// treated as a real date rather than guessed at.
const DAYS_IN_MONTH = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

function isAustria(country: string | undefined): boolean {
  return country !== undefined && country.toUpperCase() === 'AT';
}

// Validates input for the given country, returning the ten bare digits.
function validate(input: string, o: SsnOptions): ValidationResult {
  if (!isAustria(o.country)) {
    return invalid('ssnUnknownCountry', 'No social-security-number rules for this country.');
  }
  const compact = input.replace(SEPARATORS_RE, '');
  if (compact.length === 0) {
    return invalid('ssnEmpty', 'Social-security number is empty.');
  }
  if (!DIGITS_RE.test(compact)) {
    return invalid('ssnBadChars', 'Social-security number must be digits only.');
  }
  if (compact.length !== 10) {
    return invalid('ssnBadLength', 'Social-security number must be 10 digits.');
  }
  if (compact.charCodeAt(0) === 48) {
    return invalid('ssnBadSerial', 'Social-security number serial must be 100-999.');
  }
  let sum = 0;
  for (let i = 0; i < 10; i++) {
    sum += (compact.charCodeAt(i) - 48) * WEIGHTS[i];
  }
  const remainder = sum % 11;
  if (remainder === 10 || remainder !== compact.charCodeAt(3) - 48) {
    return invalid('ssnBadChecksum', 'Social-security number check digit is wrong.');
  }
  return valid(compact);
}

// True when validate returns a valid result.
function isValid(input: string, o: SsnOptions): boolean {
  return validate(input, o).ok;
}

// Returns the ten bare digits. Throws FormatError if invalid.
function normalize(input: string, o: SsnOptions): string {
  const r = validate(input, o);
  if (!r.ok) throw new FormatError(r.issues[0].message);
  return r.normalized;
}

// Returns the conventional NNNP TTMMJJ form. Throws FormatError if invalid.
function format(input: string, o: SsnOptions): string {
  const n = normalize(input, o);
  return `${n.substring(0, 4)} ${n.substring(4)}`;
}

// Like format but returns null instead of throwing on invalid input.
function tryFormat(input: string, o: SsnOptions): string | null {
  try {
    return format(input, o);
  } catch (e) {
    if (e instanceof FormatError) return null;
    throw e;
  }
}

// Parses input into a SocialSecurityInfo, or null when it is not valid.
function parse(input: string, o: SsnOptions): SocialSecurityInfo | null {
  const r = validate(input, o);
  if (!r.ok) return null;
  const n = r.normalized;
  const day = Number(n.substring(4, 6));
  const month = Number(n.substring(6, 8));
  const real = month >= 1 && month <= 12 && day >= 1 && day <= DAYS_IN_MONTH[month - 1];
  const birthDate: SsnBirthDate | null = real
    ? { day, month, twoDigitYear: Number(n.substring(8, 10)) }
    : null;
  return { serial: n.substring(0, 3), checkDigit: n[3], birthDate };
}

// Describes a social-security-number input field. maxLength is the length of
// the formatted text, the separating space included.
function fieldDescriptor(o: SsnFieldOptions = {}): FieldDescriptor {
  if (!isAustria(o.country)) {
    return {
      keyboard: 'digits',
      autofill: null,
      capitalization: 'none',
      maxLength: null,
      example: null,
      allowedChars: '0-9 ',
    };
  }
  return {
    keyboard: 'digits',
    autofill: null,
    capitalization: 'none',
    maxLength: 11,
    example: '1238 010190',
    allowedChars: '0-9 ',
  };
}

// Formats partially typed input: non-digits dropped, the separating space
// inserted once four digits exist, capped at ten digits. Never throws.
function formatPartial(input: string, o: SsnFieldOptions = {}): string {
  const s = prepare(input, fieldDescriptor(o), { separators: ' ', maxSignificant: 10 });
  if (!isAustria(o.country)) return s;
  if (s.length <= 4) return s;
  return `${s.substring(0, 4)} ${s.substring(4)}`;
}

export const SocialSecurityNumber = {
  isValid, validate, normalize, format, tryFormat, parse, fieldDescriptor, formatPartial,
};
export type { SocialSecurityInfo, SsnBirthDate };
