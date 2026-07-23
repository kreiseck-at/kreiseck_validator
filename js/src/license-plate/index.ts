import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';
import { kPlateRegions } from './metadata';
import type { PlateInfo, PlateOptions, PlateType } from './types';

// Validation, normalization, formatting and parsing of vehicle license
// plates ("Kennzeichen").
//
// Currently only Austria (AT) is modelled; other countries resolve to
// 'plateUnknownCountry'.

const ALLOWED_CHARS_RE = /^[A-Z0-9 \-.]+$/;

// Code (1-2 letters, greedily matched) + serial (letters/digits). Because
// the code and serial character classes are disjoint (letters vs. the mixed
// alphanumeric serial always follows a purely-alphabetic prefix boundary),
// the greedy `{1,2}` deterministically captures both known 2-letter codes
// (e.g. GU) and 1-letter codes (e.g. W) without needing a region-table
// lookup to disambiguate.
const STRUCTURE_RE = /^([A-Z]{1,2})([A-Z0-9]+)$/;

// State-level diplomatic-corps convention: a single state letter + D.
const DIPLOMATIC_RE = /^[A-Z]D$/;

const SEPARATOR_RE = /[\s\-.]/g;

function compact(upperTrimmed: string): string {
  return upperTrimmed.replace(SEPARATOR_RE, '');
}

// Resolves the country to validate against. Stage 1 only knows AT, so an
// omitted country infers AT; any other explicit code is unsupported.
function resolveCountry(country?: string): string {
  return country === undefined ? 'AT' : country.toUpperCase();
}

// Validates input, returning the compact upper-case form on success.
function validate(input: string, options: PlateOptions = {}): ValidationResult {
  const trimmedUpper = input.trim().toUpperCase();
  if (trimmedUpper.length === 0) {
    return invalid('plateEmpty', 'Plate is empty.');
  }
  if (!ALLOWED_CHARS_RE.test(trimmedUpper)) {
    return invalid('plateBadChars', 'Plate has invalid characters.');
  }
  const resolved = resolveCountry(options.country);
  if (resolved !== 'AT') {
    return invalid('plateUnknownCountry', 'Unknown country.');
  }
  const compacted = compact(trimmedUpper);
  if (!STRUCTURE_RE.test(compacted)) {
    return invalid('plateBadFormat', 'Plate has invalid format.');
  }
  return valid(compacted);
}

// True when validate returns a valid result.
function isValid(input: string, options: PlateOptions = {}): boolean {
  return validate(input, options).ok;
}

// Returns the compact upper-case canonical form. Throws FormatError.
function normalize(input: string, options: PlateOptions = {}): string {
  const r = validate(input, options);
  if (!r.ok) {
    throw new FormatError(r.issues[0].message);
  }
  return r.normalized;
}

// Returns the canonical CODE-SERIAL display form. Throws FormatError.
function format(input: string, options: PlateOptions = {}): string {
  const compacted = normalize(input, options);
  const m = STRUCTURE_RE.exec(compacted)!;
  return `${m[1]}-${m[2]}`;
}

// Like format but returns null instead of throwing on invalid input.
function tryFormat(input: string, options: PlateOptions = {}): string | null {
  try {
    return format(input, options);
  } catch (e) {
    if (e instanceof FormatError) return null;
    throw e;
  }
}

// Classifies a valid districtCode into a PlateType. AT: a state letter
// followed by D is the diplomatic-corps convention; everything else is a
// standard civilian plate.
function classify(districtCode: string): PlateType {
  return DIPLOMATIC_RE.test(districtCode) ? 'diplomatic' : 'standard';
}

// Parses input into a PlateInfo, or null when it is not a valid plate.
function parse(input: string, options: PlateOptions = {}): PlateInfo | null {
  const r = validate(input, options);
  if (!r.ok) return null;
  const compacted = r.normalized;
  const m = STRUCTURE_RE.exec(compacted)!;
  const code = m[1];
  const serial = m[2];
  const resolved = resolveCountry(options.country);
  return {
    country: resolved,
    districtCode: code,
    region: kPlateRegions[resolved]?.[code] ?? null,
    serial,
    type: classify(code),
    formatted: format(input, options),
  };
}

export const LicensePlate = { isValid, validate, normalize, format, tryFormat, parse };
