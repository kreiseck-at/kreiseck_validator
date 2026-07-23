import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';

// Validation, normalization and display formatting of web URLs / domains.
//
// This is a pragmatic plausibility check (scheme, host, TLD), not a full
// URL grammar. Only `http` and `https` schemes are accepted.

const SCHEME_RE = /^([a-zA-Z][a-zA-Z0-9+.-]*):\/\/(.*)$/;
const HOST_RE = /^([a-z0-9](-?[a-z0-9])*\.)+[a-z]{2,}$/;

interface Options {
  defaultScheme?: string;
}

// Splits input into (scheme, hostToken, tail), where scheme is lower-cased
// or null, hostToken may carry a `:port` suffix, and tail is the
// path/query/fragment beginning with its delimiter (or empty).
function parts(input: string): [string | null, string, string] {
  const m = SCHEME_RE.exec(input);
  const scheme = m ? m[1].toLowerCase() : null;
  const rest = m === null ? input : m[2];
  let cut = rest.length;
  for (const d of ['/', '?', '#']) {
    const i = rest.indexOf(d);
    if (i !== -1 && i < cut) cut = i;
  }
  return [scheme, rest.substring(0, cut), rest.substring(cut)];
}

// Returns the lower-cased hostname from a host token, dropping any `:port`.
function hostname(hostToken: string): string {
  const i = hostToken.indexOf(':');
  return (i === -1 ? hostToken : hostToken.substring(0, i)).toLowerCase();
}

// Validates input, returning a valid result with the normalize form.
function validate(input: string, options: Options = {}): ValidationResult {
  const defaultScheme = options.defaultScheme ?? 'https';
  const trimmed = input.trim();
  if (trimmed.length === 0) {
    return invalid('urlEmpty', 'URL is empty.');
  }
  const [scheme, hostToken] = parts(trimmed);
  if (scheme !== null && scheme !== 'http' && scheme !== 'https') {
    return invalid('urlBadScheme', 'Only http/https allowed.');
  }
  if (!HOST_RE.test(hostname(hostToken))) {
    return invalid('urlBadHost', 'Invalid host.');
  }
  return valid(normalize(trimmed, { defaultScheme }));
}

// True when validate returns a valid result.
function isValid(input: string): boolean {
  return validate(input).ok;
}

// Returns the canonical URL: explicit scheme (default defaultScheme),
// lower-cased host (and port), path/query/fragment preserved, with a single
// trailing slash removed from a bare path.
function normalize(input: string, options: Options = {}): string {
  const defaultScheme = options.defaultScheme ?? 'https';
  const trimmed = input.trim();
  const [scheme, hostToken, tail] = parts(trimmed);
  const host = hostToken.toLowerCase();
  let rest = tail;
  if (rest.length > 1 && rest.endsWith('/') && !rest.includes('?') && !rest.includes('#')) {
    rest = rest.substring(0, rest.length - 1);
  }
  return `${scheme ?? defaultScheme}://${host}${rest}`;
}

// Returns a compact display form: no scheme, no leading `www.`, no trailing
// slash. Throws FormatError if input is invalid.
function format(input: string): string {
  const r = validate(input);
  if (!r.ok) {
    throw new FormatError(r.issues[0].message);
  }
  let s = r.normalized.replace(/^https?:\/\//, '');
  s = s.replace(/^www\./, '');
  if (s.endsWith('/')) s = s.substring(0, s.length - 1);
  return s;
}

// Like format but returns null on invalid input.
function tryFormat(input: string): string | null {
  try {
    return format(input);
  } catch (e) {
    if (e instanceof FormatError) return null;
    throw e;
  }
}

export const Url = { isValid, validate, normalize, format, tryFormat };
