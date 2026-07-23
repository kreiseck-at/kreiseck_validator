import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';
import { kPlateRegions } from './metadata';
import type { PlateInfo, PlateOptions, PlateType } from './types';

// Validation, normalization, formatting and parsing of vehicle license
// plates ("Kennzeichen").
//
// Currently AT and DE are modelled; other countries resolve to
// 'plateUnknownCountry'.

const ALLOWED_CHARS_RE = /^[A-ZÄÖÜ0-9 \-.]+$/;

const KNOWN_COUNTRIES = new Set(['AT', 'DE']);

// AT: code (1-2 letters, greedily matched) + serial (letters/digits).
// Because the code and serial character classes are disjoint (letters vs.
// the mixed alphanumeric serial always follows a purely-alphabetic prefix
// boundary), the greedy `{1,2}` deterministically captures both known
// 2-letter codes (e.g. GU) and 1-letter codes (e.g. W) without needing a
// region-table lookup to disambiguate.
const AT_STRUCTURE_RE = /^([A-Z]{1,2})([A-Z0-9]+)$/;

// AT: state-level diplomatic-corps convention: a single state letter + D.
const AT_DIPLOMATIC_RE = /^[A-Z]D$/;

// DE: district code (1-3 letters) + serial letters (1-2) + serial digits
// (1-4) + optional historic/electric suffix. Unlike AT, the code and
// serial-letters groups are NOT disjoint character classes (both are pure
// letter runs sitting back-to-back once separators are stripped), so a
// greedy first group would over-consume (e.g. `MAB1234` could split as
// `MA`+`B`+`1234` just as validly as `M`+`AB`+`1234`). The district-code
// group is therefore made *lazy* (`{1,3}?`) so it claims as few letters as
// possible, leaving the greedy serial-letters group to claim up to 2 --
// matching the overwhelmingly common real-world shape (short code, 1-2
// letter serial prefix). A three-letter code followed by a single-letter
// serial is the one shape this cannot disambiguate without a table lookup;
// accepted as a known limitation (out of scope per the design doc).
const DE_STRUCTURE_RE = /^([A-ZÄÖÜ]{1,3}?)([A-Z]{1,2})(\d{1,4})([HE]?)$/;

// DE: nationwide authority codes that are not Stadt/Kreis codes (see
// tool/data/de-kennzeichen.csv, which deliberately omits them).
const DE_AUTHORITY_CODES = new Set(['BW', 'BP', 'BD', 'THW']);

const SEPARATOR_RE = /[\s\-.]/g;

function compact(upperTrimmed: string): string {
  return upperTrimmed.replace(SEPARATOR_RE, '');
}

// Resolves the country to validate against. An omitted country infers AT;
// any other explicit code is looked up against KNOWN_COUNTRIES.
function resolveCountry(country?: string): string {
  return country === undefined ? 'AT' : country.toUpperCase();
}

function matchesStructure(country: string, compacted: string): boolean {
  switch (country) {
    case 'AT':
      return AT_STRUCTURE_RE.test(compacted);
    case 'DE':
      return DE_STRUCTURE_RE.test(compacted);
    default:
      return false;
  }
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
  if (!KNOWN_COUNTRIES.has(resolved)) {
    return invalid('plateUnknownCountry', 'Unknown country.');
  }
  const compacted = compact(trimmedUpper);
  if (!matchesStructure(resolved, compacted)) {
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

function formatAt(compacted: string): string {
  const m = AT_STRUCTURE_RE.exec(compacted)!;
  return `${m[1]}-${m[2]}`;
}

function formatDe(compacted: string): string {
  const m = DE_STRUCTURE_RE.exec(compacted)!;
  return `${m[1]}-${m[2]} ${m[3]}${m[4]}`;
}

// Returns the canonical display form. Throws FormatError.
function format(input: string, options: PlateOptions = {}): string {
  const compacted = normalize(input, options);
  const resolved = resolveCountry(options.country);
  switch (resolved) {
    case 'AT':
      return formatAt(compacted);
    case 'DE':
      return formatDe(compacted);
    default:
      throw new Error(`unreachable: ${resolved}`);
  }
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

// Classifies an AT districtCode into a PlateType. Known district codes
// (present in kPlateRegions) are always standard, even when they happen to
// match the diplomatic pattern (e.g. MD is Mödling, not a diplomatic code);
// only when the code is unknown does a state letter followed by D fall back
// to the diplomatic-corps convention.
function classifyAt(districtCode: string, region: string | null): PlateType {
  if (region !== null) return 'standard';
  return AT_DIPLOMATIC_RE.test(districtCode) ? 'diplomatic' : 'standard';
}

// Classifies a DE plate from its district code and H/E suffix. The suffix
// takes priority over the code-based rules (a historic/electric plate on an
// authority code is still classified by its suffix).
function classifyDe(code: string, suffix: string): PlateType {
  if (suffix === 'H') return 'historic';
  if (suffix === 'E') return 'electric';
  if (code === 'Y') return 'military';
  if (DE_AUTHORITY_CODES.has(code)) return 'authority';
  return 'standard';
}

// Parses input into a PlateInfo, or null when it is not a valid plate.
function parse(input: string, options: PlateOptions = {}): PlateInfo | null {
  const r = validate(input, options);
  if (!r.ok) return null;
  const compacted = r.normalized;
  const resolved = resolveCountry(options.country);
  switch (resolved) {
    case 'AT': {
      const m = AT_STRUCTURE_RE.exec(compacted)!;
      const code = m[1];
      const serial = m[2];
      const region = kPlateRegions['AT']?.[code] ?? null;
      return {
        country: 'AT',
        districtCode: code,
        region,
        serial,
        type: classifyAt(code, region),
        formatted: formatAt(compacted),
      };
    }
    case 'DE': {
      const m = DE_STRUCTURE_RE.exec(compacted)!;
      const code = m[1];
      const serialLetters = m[2];
      const digits = m[3];
      const suffix = m[4] ?? '';
      const region = kPlateRegions['DE']?.[code] ?? null;
      return {
        country: 'DE',
        districtCode: code,
        region,
        serial: `${serialLetters} ${digits}`,
        type: classifyDe(code, suffix),
        formatted: formatDe(compacted),
      };
    }
    default:
      return null;
  }
}

export const LicensePlate = { isValid, validate, normalize, format, tryFormat, parse };
