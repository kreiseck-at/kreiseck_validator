import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';
import type { FieldDescriptor } from '../common/field';
import { prepare } from '../common/partial';
import { isIsoCountry } from './iso-countries';
import type { BicInfo, BicKind } from './types';

// Validation, normalization, formatting and parsing of Business Identifier
// Codes (ISO 9362) -- the codes commonly called SWIFT codes.
//
// Structure: 4 letters institution, 2 letters ISO country, 2 alphanumerics
// location, optionally 3 alphanumerics branch. The country segment is checked
// against the bundled country table, so a typo that lands on a non-country is
// caught rather than accepted.
//
// An 'XXX' branch code is preserved rather than stripped: it is meaningful in
// SEPA payloads. The location code's second character is parsed rather than
// ignored -- a test-and-training BIC in a production payment file is a silent
// failure, so BicInfo.kind surfaces it.
//
// No check digit exists: ISO 9362 has none. Everything here is structural.

const SHAPE_RE = /^[A-Z]{4}[A-Z]{2}[A-Z0-9]{2}([A-Z0-9]{3})?$/;
const SPACE_RE = /\s/g;
const NON_ALNUM_RE = /[^A-Z0-9]/g;

// Validates input, returning the compact upper-case form or an invalid result
// describing why it was rejected.
function validate(input: string): ValidationResult {
  const upper = input.toUpperCase().replace(SPACE_RE, '');
  if (upper.length === 0) {
    return invalid('bicEmpty', 'BIC is empty.');
  }
  if (upper.length !== 8 && upper.length !== 11) {
    return invalid('bicBadLength', 'BIC must be 8 or 11 characters.');
  }
  if (!SHAPE_RE.test(upper)) {
    return invalid('bicBadChars', 'BIC has invalid characters.');
  }
  if (!isIsoCountry(upper.substring(4, 6))) {
    return invalid('bicUnknownCountry', 'BIC has an unknown country code.');
  }
  return valid(upper);
}

// True when validate returns a valid result.
function isValid(input: string): boolean {
  return validate(input).ok;
}

// Returns the compact upper-case form. Throws FormatError if input is not a
// valid BIC.
function normalize(input: string): string {
  const r = validate(input);
  if (!r.ok) throw new FormatError(r.issues[0].message);
  return r.normalized;
}

// Returns the 8- or 11-character form. Throws FormatError if invalid.
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

// Parses input into a BicInfo, or null when it is not a valid BIC.
function parse(input: string): BicInfo | null {
  const r = validate(input);
  if (!r.ok) return null;
  const b = r.normalized;
  let kind: BicKind;
  switch (b[7]) {
    case '0': kind = 'test'; break;
    case '1': kind = 'passive'; break;
    case '2': kind = 'reverseBilling'; break;
    default: kind = 'live';
  }
  return {
    institution: b.substring(0, 4),
    country: b.substring(4, 6),
    location: b.substring(6, 8),
    branch: b.length === 11 ? b.substring(8, 11) : null,
    kind,
  };
}

// True when bic and iban agree on their country segment.
//
// Only the countries are compared -- a BIC carries no account information --
// but a mismatch reliably means one of the two fields was pasted from the
// wrong account. Returns false when either value is unusable.
function matchesIban(bic: string, iban: string): boolean {
  const b = parse(bic);
  if (b === null) return false;
  const i = iban.toUpperCase().replace(NON_ALNUM_RE, '');
  if (i.length < 2) return false;
  return b.country === i.substring(0, 2);
}

// Describes a BIC input field.
function fieldDescriptor(): FieldDescriptor {
  return {
    keyboard: 'text',
    autofill: null,
    capitalization: 'characters',
    maxLength: 11,
    example: 'BKAUATWW',
    allowedChars: '0-9A-Z',
  };
}

// Formats partially typed input: upper-cased, non-alphanumerics dropped,
// capped at 11. A BIC is written as one run, so there is no grouping step.
// Never throws.
function formatPartial(input: string): string {
  return prepare(input, fieldDescriptor(), { maxSignificant: 11 });
}

export const Bic = {
  isValid, validate, normalize, format, tryFormat, parse, matchesIban,
  fieldDescriptor, formatPartial,
};
export type { BicInfo, BicKind };
