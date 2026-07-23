import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';
import { countries, fromIso2, fromCallingCode } from './metadata';
import type { Country, PhoneFormat, PhoneInfo, PhoneNumberType } from './types';
import { classify } from './at-numbering';

// Validation, normalization (to E.164) and formatting of phone numbers for
// every country, using libphonenumber-derived metadata.

const ALLOWED_CHARS = /^\+?[0-9\s\-/().]+$/;
const NON_DIGIT = /[^0-9]/g;

interface PhoneOptions {
  country?: string;
}

function digitsOnly(s: string): string {
  return s.replace(NON_DIGIT, '');
}

function matchesPattern(c: Country, nsn: string): boolean {
  return new RegExp(`^(?:${c.pattern})$`).test(nsn);
}

function lengthOk(c: Country, nsn: string): boolean {
  return c.possibleLengths.length === 0 || c.possibleLengths.includes(nsn.length);
}

// Formats a national significant number using the given format rules.
// Returns null if no format rule matches.
function formatNsn(
  formats: PhoneFormat[],
  nsn: string,
  international: boolean,
  nationalPrefix: string | null,
): string | null {
  for (const f of formats) {
    if (f.leadingDigits !== null && !new RegExp(`^(?:${f.leadingDigits})`).test(nsn)) {
      continue;
    }
    const m = new RegExp(`^(?:${f.pattern})$`).exec(nsn);
    if (m === null) continue;
    const groupCount = m.length - 1;
    let out = f.format;
    for (let i = groupCount; i >= 1; i--) {
      out = out.split(`$${i}`).join(m[i] ?? '');
    }
    if (!international) {
      const rule = f.nationalPrefixFormattingRule;
      if (rule !== null && rule.length > 0) {
        const np = nationalPrefix ?? '';
        // Pragmatic subset: `$1`/`$FG` = the whole grouped number, `$NP` = the
        // national prefix. Reproduces the common `0$1` case (DACH and most
        // European national forms). Carrier codes (`$CC`) are not supported.
        out = rule.split('$NP').join(np).split('$FG').join(out).split('$1').join(out);
      }
    }
    return out;
  }
  return null;
}

// Resolves the (country, nationalSignificantNumber) for the input. Returns a
// null country when it cannot be determined.
function resolve(trimmed: string, hint: Country | null): [Country | null, string] {
  if (trimmed.startsWith('+')) {
    const d = digitsOnly(trimmed);
    // Longest matching calling code (1-3 digits).
    for (const len of [3, 2, 1]) {
      if (d.length <= len) continue;
      const cc = d.substring(0, len);
      const candidates = countries.filter((c) => c.callingCode === cc);
      if (candidates.length === 0) continue;
      const nsn = d.substring(len);
      // Among candidates sharing a calling code, prefer the main region
      // (e.g. US for +1) so an ambiguous number is not attributed to an
      // alphabetically-earlier co-tenant (e.g. CA).
      const main = fromCallingCode(cc);
      const ordered: Country[] = [];
      if (main !== null && candidates.includes(main)) ordered.push(main);
      for (const c of candidates) {
        if (c !== main) ordered.push(c);
      }
      for (const c of ordered) {
        if (lengthOk(c, nsn) && matchesPattern(c, nsn)) return [c, nsn];
      }
      // Tolerate an accidentally-included trunk "0" from the international
      // "(0)" display convention, e.g. "+43 (0) 660 ...". Only a single
      // leading zero is stripped, and only when the raw number matched no
      // candidate, so strict validation is preserved for real numbers.
      if (nsn.startsWith('0')) {
        const stripped = nsn.substring(1);
        for (const c of ordered) {
          if (lengthOk(c, stripped) && matchesPattern(c, stripped)) {
            return [c, stripped];
          }
        }
      }
      // No candidate validates: return the main region (or first) with the raw
      // nsn so the caller can report the specific length/pattern error.
      return [main ?? candidates[0], nsn];
    }
    return [null, ''];
  }
  // National input: needs a country hint; strip the trunk prefix.
  if (hint === null) return [null, ''];
  let d = digitsOnly(trimmed);
  const np = hint.nationalPrefix;
  if (np !== null && d.startsWith(np)) d = d.substring(np.length);
  return [hint, d];
}

// Validates input, returning a valid result with the E.164 normalized form.
function validate(input: string, opts: PhoneOptions = {}): ValidationResult {
  const hint = opts.country !== undefined ? fromIso2(opts.country) : null;
  const trimmed = input.trim();
  if (trimmed.length === 0) {
    return invalid('phoneEmpty', 'Phone is empty.');
  }
  if (!ALLOWED_CHARS.test(trimmed)) {
    return invalid('phoneBadChars', 'Bad characters.');
  }

  const [resolved, nsn] = resolve(trimmed, hint);
  if (resolved === null) {
    const startsPlus = trimmed.startsWith('+');
    return invalid(
      startsPlus ? 'phoneUnknownCountry' : 'phoneAmbiguousCountry',
      startsPlus ? 'Unknown country.' : 'Country required.',
    );
  }

  const lengths = resolved.possibleLengths;
  if (lengths.length > 0) {
    const min = lengths[0];
    const max = lengths[lengths.length - 1];
    if (nsn.length < min) {
      return invalid('phoneTooShort', 'Too short.');
    }
    if (nsn.length > max) {
      return invalid('phoneTooLong', 'Too long.');
    }
  }
  if (!matchesPattern(resolved, nsn)) {
    return invalid('phoneInvalid', 'Not a valid number.');
  }
  return valid(`+${resolved.callingCode}${nsn}`);
}

// True when validate returns a valid result.
function isValid(input: string, opts: PhoneOptions = {}): boolean {
  return validate(input, opts).ok;
}

// Returns the E.164 canonical form. Throws FormatError.
function normalize(input: string, opts: PhoneOptions = {}): string {
  const r = validate(input, opts);
  if (!r.ok) throw new FormatError(r.issues[0].message);
  return r.normalized;
}

// Splits a normalized E.164 string into (country, nationalNumber), reusing the
// same calling-code resolution (and main-region preference) as validate.
function ccCountry(e164: string): [Country, string] {
  const [c, nsn] = resolve(e164, null);
  if (c === null) {
    // Should not happen for an already-validated E.164.
    throw new FormatError('Unresolvable calling code.');
  }
  return [c, nsn];
}

// Formats input internationally (`+43 1 234567`) or nationally (`01 234567`)
// when international is false. Throws FormatError.
function format(input: string, opts: PhoneOptions & { international?: boolean } = {}): string {
  const international = opts.international ?? true;
  const e164 = normalize(input, opts);
  const [c, nsn] = ccCountry(e164);
  const formats = international && c.intlFormats.length > 0 ? c.intlFormats : c.formats;
  const grouped = formatNsn(formats, nsn, international, c.nationalPrefix);
  if (grouped === null) {
    // No format rule matched: fall back to the bare number.
    return international ? `+${c.callingCode} ${nsn}` : nsn;
  }
  return international ? `+${c.callingCode} ${grouped}` : grouped;
}

// Like format but returns null on invalid input.
function tryFormat(input: string, opts: PhoneOptions & { international?: boolean } = {}): string | null {
  try {
    return format(input, opts);
  } catch (e) {
    if (e instanceof FormatError) return null;
    throw e;
  }
}

// Classifies input by number type. Returns `unknown` for invalid input or
// countries without classification data (all but AT).
function type(input: string, opts: PhoneOptions = {}): PhoneNumberType {
  const result = validate(input, opts);
  if (!result.ok) return 'unknown';
  const [c, nsn] = ccCountry(result.normalized);
  if (c.iso2 !== 'AT') return 'unknown';
  return classify(nsn).type;
}

// Parses input into a PhoneInfo bundle, or null if invalid.
function parse(input: string, opts: PhoneOptions = {}): PhoneInfo | null {
  const result = validate(input, opts);
  if (!result.ok) return null;
  const e164 = result.normalized;
  const [c, nsn] = ccCountry(e164);
  const numberType: PhoneNumberType = c.iso2 === 'AT' ? classify(nsn).type : 'unknown';
  return {
    e164,
    country: c,
    type: numberType,
    national: format(input, { ...opts, international: false }),
    international: format(input, { ...opts, international: true }),
  };
}

export const Phone = { isValid, validate, normalize, format, tryFormat, type, parse };
