import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';
import { kPlateRegions } from './metadata';
import type { PlateInfo, PlateOptions, PlateType } from './types';

// Validation, normalization, formatting and parsing of vehicle license
// plates ("Kennzeichen").
//
// Currently AT, DE, CH and HR are modelled; other countries resolve to
// 'plateUnknownCountry'.

const ALLOWED_CHARS_RE = /^[A-ZÄÖÜČŠŽ0-9 \-.]+$/;

const KNOWN_COUNTRIES = new Set(['AT', 'DE', 'CH', 'HR']);

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
// letter runs sitting back-to-back once separators are stripped), so which
// substring is the code vs. the serial prefix is ambiguous from the compact
// form alone (e.g. `MAB1234` could split as `MA`+`B`+`1234` just as validly
// as `M`+`AB`+`1234`). This pattern is used only to decide overall
// well-formedness (accept/reject); the actual code/serial boundary is
// resolved separately by splitDe, which is separator- and table-aware.
const DE_STRUCTURE_RE = /^([A-ZÄÖÜ]{1,3})([A-Z]{1,2})(\d{1,4})([HE]?)$/;

// DE: nationwide authority codes that are not Stadt/Kreis codes (see
// tool/data/de-kennzeichen.csv, which deliberately omits them).
const DE_AUTHORITY_CODES = new Set(['BW', 'BP', 'BD', 'THW']);

// DE: leading letter run followed by an explicit separator, used to resolve
// the code/serial boundary unambiguously when the caller wrote one in (e.g.
// `GG-A 1234`, `BOR-X 1234`). Because the letter class and the separator
// class are disjoint, the greedy `{1,3}` here is deterministic: it can only
// ever match as many letters as actually precede the separator (up to 3),
// unlike the compact-form ambiguity above.
const DE_SEPARATOR_SPLIT_RE = /^([A-ZÄÖÜ]{1,3})[-. ]+(.+)$/;

// DE: a bare serial (letters + digits + optional suffix), used both to
// validate the tail of a separator-aware split and to validate candidate
// remainders in the table-aware fallback.
const DE_SERIAL_RE = /^([A-Z]{1,2})(\d{1,4})([HE]?)$/;

const DE_LETTERS_ONLY_RE = /^[A-ZÄÖÜ]+$/;

// CH: canton code (2 letters) + serial (1-6 digits), e.g. `ZH123456`. Unlike
// AT/DE, the canton set is closed and small (26 entries): a 2-letter prefix
// that structurally matches but is not a known canton is rejected as
// plateBadFormat rather than accepted with a null region -- see
// matchesChStructure.
const CH_STRUCTURE_RE = /^([A-Z]{2})(\d{1,6})$/;

// HR: registration-area code (2 letters, may include Č/Š/Ž) + serial digits
// (3-4) + serial letters (1-2), e.g. `ZG1234AB`. Like CH, the
// registration-area set is closed and small (34 entries): a 2-letter prefix
// that structurally matches but is not a known code is rejected as
// plateBadFormat -- see matchesHrStructure. Unlike DE, the digit and letter
// groups are disjoint character classes, so the split is always
// unambiguous.
const HR_STRUCTURE_RE = /^([A-ZČŠŽ]{2})(\d{3,4})([A-Z]{1,2})$/;

const SEPARATOR_RE = /[\s\-.]/g;

function compact(upperTrimmed: string): string {
  return upperTrimmed.replace(SEPARATOR_RE, '');
}

interface DeSplit {
  code: string;
  serialLetters: string;
  digits: string;
  suffix: string;
}

// Resolves the DE code/serial split when trimmedUpper (the original,
// pre-compaction input) has an explicit separator right after the leading
// letter run, e.g. `GG-A 1234` or `BOR-X 1234`. Returns null when there is
// no such separator, or the remainder is not a valid serial -- callers then
// fall back to deSplitTableAware.
function deSplitSeparatorAware(trimmedUpper: string): DeSplit | null {
  const m = DE_SEPARATOR_SPLIT_RE.exec(trimmedUpper);
  if (m === null) return null;
  const rest = compact(m[2]);
  const sm = DE_SERIAL_RE.exec(rest);
  if (sm === null) return null;
  return { code: m[1], serialLetters: sm[1], digits: sm[2], suffix: sm[3] ?? '' };
}

// Resolves the DE code/serial split from the compact form alone (no
// separator to go by, e.g. `MAB1234`). Tries code lengths 3, 2, 1 -- longest
// first -- among splits whose remainder is a valid serial, and prefers the
// longest one whose code is a known DE district (in kPlateRegions); falls
// back to the longest merely-valid split if none of them is known.
function deSplitTableAware(compacted: string): DeSplit | null {
  let firstValid: DeSplit | null = null;
  for (const len of [3, 2, 1]) {
    if (len >= compacted.length) continue;
    const codeCandidate = compacted.slice(0, len);
    if (!DE_LETTERS_ONLY_RE.test(codeCandidate)) continue;
    const sm = DE_SERIAL_RE.exec(compacted.slice(len));
    if (sm === null) continue;
    const candidate: DeSplit = {
      code: codeCandidate,
      serialLetters: sm[1],
      digits: sm[2],
      suffix: sm[3] ?? '',
    };
    if (kPlateRegions['DE']?.[codeCandidate] !== undefined) return candidate;
    if (firstValid === null) firstValid = candidate;
  }
  return firstValid;
}

// Resolves the DE code/serial split for an already-validated plate.
// Separator-aware splitting takes priority; the table-aware fallback is
// only consulted when no explicit separator disambiguates the code.
function splitDe(trimmedUpper: string, compacted: string): DeSplit {
  return deSplitSeparatorAware(trimmedUpper) ?? deSplitTableAware(compacted)!;
}

// Resolves the country to validate against. An omitted country infers AT;
// any other explicit code is looked up against KNOWN_COUNTRIES.
function resolveCountry(country?: string): string {
  return country === undefined ? 'AT' : country.toUpperCase();
}

// CH's canton set is closed and small: unlike AT/DE (where an unknown
// district/Unterscheidungszeichen still validates with a null region), a CH
// plate whose 2-letter prefix is not one of the 26 cantons in kPlateRegions
// is plateBadFormat, not merely unresolved.
function matchesChStructure(compacted: string): boolean {
  const m = CH_STRUCTURE_RE.exec(compacted);
  if (m === null) return false;
  return kPlateRegions['CH']?.[m[1]] !== undefined;
}

// HR's registration-area set is closed and small, same as CH: an HR plate
// whose 2-letter prefix is not one of the 34 codes in kPlateRegions is
// plateBadFormat, not merely unresolved.
function matchesHrStructure(compacted: string): boolean {
  const m = HR_STRUCTURE_RE.exec(compacted);
  if (m === null) return false;
  return kPlateRegions['HR']?.[m[1]] !== undefined;
}

function matchesStructure(country: string, compacted: string): boolean {
  switch (country) {
    case 'AT':
      return AT_STRUCTURE_RE.test(compacted);
    case 'DE':
      return DE_STRUCTURE_RE.test(compacted);
    case 'CH':
      return matchesChStructure(compacted);
    case 'HR':
      return matchesHrStructure(compacted);
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

function formatDe(trimmedUpper: string, compacted: string): string {
  const s = splitDe(trimmedUpper, compacted);
  return `${s.code}-${s.serialLetters} ${s.digits}${s.suffix}`;
}

function formatCh(compacted: string): string {
  const m = CH_STRUCTURE_RE.exec(compacted)!;
  return `${m[1]} ${m[2]}`;
}

function formatHr(compacted: string): string {
  const m = HR_STRUCTURE_RE.exec(compacted)!;
  return `${m[1]} ${m[2]}-${m[3]}`;
}

// Returns the canonical display form. Throws FormatError.
function format(input: string, options: PlateOptions = {}): string {
  const compacted = normalize(input, options);
  const resolved = resolveCountry(options.country);
  switch (resolved) {
    case 'AT':
      return formatAt(compacted);
    case 'DE':
      return formatDe(input.trim().toUpperCase(), compacted);
    case 'CH':
      return formatCh(compacted);
    case 'HR':
      return formatHr(compacted);
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

// Classifies a CH plate. There is no reliable text-only signal to
// distinguish federal/diplomatic CH plates from civilian ones, so every
// (structurally valid, known-canton) CH plate classifies as standard.
function classifyCh(_districtCode: string): PlateType {
  return 'standard';
}

// Classifies an HR plate. As with CH, there is no reliable text-only signal
// to distinguish special (diplomatic, military, ...) HR plates from
// civilian ones, so every (structurally valid, known-code) HR plate
// classifies as standard.
function classifyHr(_districtCode: string): PlateType {
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
      const trimmedUpper = input.trim().toUpperCase();
      const s = splitDe(trimmedUpper, compacted);
      const region = kPlateRegions['DE']?.[s.code] ?? null;
      return {
        country: 'DE',
        districtCode: s.code,
        region,
        serial: `${s.serialLetters} ${s.digits}`,
        type: classifyDe(s.code, s.suffix),
        formatted: formatDe(trimmedUpper, compacted),
      };
    }
    case 'CH': {
      const m = CH_STRUCTURE_RE.exec(compacted)!;
      const code = m[1];
      const serial = m[2];
      const region = kPlateRegions['CH']?.[code] ?? null;
      return {
        country: 'CH',
        districtCode: code,
        region,
        serial,
        type: classifyCh(code),
        formatted: formatCh(compacted),
      };
    }
    case 'HR': {
      const m = HR_STRUCTURE_RE.exec(compacted)!;
      const code = m[1];
      const digits = m[2];
      const letters = m[3];
      return {
        country: 'HR',
        districtCode: code,
        region: kPlateRegions['HR']?.[code] ?? null,
        serial: `${digits}-${letters}`,
        type: classifyHr(code),
        formatted: formatHr(compacted),
      };
    }
    default:
      return null;
  }
}

export const LicensePlate = { isValid, validate, normalize, format, tryFormat, parse };
