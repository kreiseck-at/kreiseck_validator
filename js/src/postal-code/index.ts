import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';
import { kPostalPatterns } from './metadata';
import type { PostalPattern } from './metadata';
import type { PostalInfo, PostalOptions } from './types';

// Validation, normalization, formatting and parsing of postal codes for
// European countries plus Turkey.
//
// The country is required: a bare postal code is ambiguous across
// countries (e.g. plain 4-digit codes are valid in a dozen countries), so
// every operation takes `country` (an ISO 3166-1 alpha-2 code). Countries
// without a curated pattern in kPostalPatterns resolve to
// 'postalUnknownCountry'.

const SEPARATORS_RE = /[\s-]/g;

const compiledCache = new Map<string, RegExp>();

function regexFor(meta: PostalPattern): RegExp {
  let re = compiledCache.get(meta.pattern);
  if (re === undefined) {
    re = new RegExp(meta.pattern);
    compiledCache.set(meta.pattern, re);
  }
  return re;
}

function compact(upper: string): string {
  return upper.replace(SEPARATORS_RE, '');
}

// Applies a country's canonical spacing rule (see PostalPattern) to its
// separator-free compacted form.
function canonicalize(compacted: string, format: string): string {
  if (format.length === 0) return compacted;
  if (format === 'U') {
    if (compacted.length <= 3) return compacted;
    const split = compacted.length - 3;
    return `${compacted.slice(0, split)} ${compacted.slice(split)}`;
  }
  const [nStr, sep] = format.split(':');
  const n = Number(nStr);
  if (n >= compacted.length) return compacted;
  return `${compacted.slice(0, n)}${sep}${compacted.slice(n)}`;
}

// Validates input against country's pattern, returning a valid result with
// the canonical (spacing-applied) form.
function validate(input: string, options: PostalOptions): ValidationResult {
  const resolved = options.country.toUpperCase();
  const meta = kPostalPatterns[resolved];
  if (meta === undefined) {
    return invalid('postalUnknownCountry', 'Unknown country.');
  }
  const trimmedUpper = input.trim().toUpperCase();
  if (trimmedUpper.length === 0) {
    return invalid('postalEmpty', 'Postal code is empty.');
  }
  const canonical = canonicalize(compact(trimmedUpper), meta.format);
  if (!regexFor(meta).test(canonical)) {
    return invalid('postalBadFormat', 'Postal code has invalid format.');
  }
  return valid(canonical);
}

// True when validate returns a valid result.
function isValid(input: string, options: PostalOptions): boolean {
  return validate(input, options).ok;
}

// Returns the canonical form. Throws FormatError if input is not a valid
// postal code for options.country.
function normalize(input: string, options: PostalOptions): string {
  const r = validate(input, options);
  if (!r.ok) {
    throw new FormatError(r.issues[0].message);
  }
  return r.normalized;
}

// Returns the canonical form. Throws FormatError if invalid.
function format(input: string, options: PostalOptions): string {
  return normalize(input, options);
}

// Like format but returns null instead of throwing on invalid input.
function tryFormat(input: string, options: PostalOptions): string | null {
  try {
    return format(input, options);
  } catch (e) {
    if (e instanceof FormatError) return null;
    throw e;
  }
}

// Parses input into a PostalInfo, or null when it is not a valid postal
// code for options.country.
function parse(input: string, options: PostalOptions): PostalInfo | null {
  const r = validate(input, options);
  if (!r.ok) return null;
  return { country: options.country.toUpperCase(), code: r.normalized };
}

export const PostalCode = { isValid, validate, normalize, format, tryFormat, parse };
export type { PostalInfo, PostalOptions };
