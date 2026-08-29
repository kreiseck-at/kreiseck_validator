import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';
import type { FieldDescriptor } from '../common/field';
import { prepare } from '../common/partial';

// Validation, normalization and display formatting of web URLs / domains.
//
// This is a pragmatic plausibility check (scheme, host, TLD), not a full
// URL grammar. Only `http` and `https` schemes are accepted.

const SCHEME_RE = /^([a-zA-Z][a-zA-Z0-9+.-]*):\/\/(.*)$/;
const HOST_RE = /^([a-z0-9](-?[a-z0-9])*\.)+[a-z]{2,}$/;

interface Options {
  defaultScheme?: string;
  // Strict options for addresses a machine will call (see `webhook`):
  requireProtocol?: boolean; // missing `scheme://` -> urlProtocolMissing
  protocols?: string[]; // schemes outside the list -> urlProtocolNotAllowed
  allowCredentials?: boolean; // `user:pass@` -> urlCredentials when false
  allowLocalhost?: boolean; // localhost / IP literals / private ranges -> urlHostNotPublic when false
}

const WHITESPACE_RE = /[\s\x00-\x1f\x7f]/;
const IPV4_RE = /^\d{1,3}(\.\d{1,3}){3}$/;

// True for hosts that are never reachable from the public internet:
// localhost, *.localhost, IPv6 literals and IPv4 loopback/private/link-local.
function isNonPublicHost(host: string): boolean {
  if (host === 'localhost' || host.endsWith('.localhost')) return true;
  if (host.startsWith('[')) return true;
  if (!IPV4_RE.test(host)) return false;
  const o = host.split('.').map((n) => parseInt(n, 10));
  if (o.some((n) => n > 255)) return false;
  return (
    o[0] === 127 ||
    o[0] === 10 ||
    o[0] === 0 ||
    (o[0] === 172 && o[1] >= 16 && o[1] <= 31) ||
    (o[0] === 192 && o[1] === 168) ||
    (o[0] === 169 && o[1] === 254)
  );
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
  if (hostToken.startsWith('[')) {
    const j = hostToken.indexOf(']');
    return (j === -1 ? hostToken : hostToken.substring(0, j + 1)).toLowerCase();
  }
  const i = hostToken.indexOf(':');
  return (i === -1 ? hostToken : hostToken.substring(0, i)).toLowerCase();
}

// Validates input, returning a valid result with the normalize form. The
// defaults keep the lenient behaviour (scheme optional, http and https both
// fine); the strict options are for addresses a machine will call.
function validate(input: string, options: Options = {}): ValidationResult {
  const defaultScheme = options.defaultScheme ?? 'https';
  const requireProtocol = options.requireProtocol ?? false;
  const protocols = options.protocols ?? null;
  const allowCredentials = options.allowCredentials ?? true;
  const allowLocalhost = options.allowLocalhost ?? true;
  const trimmed = input.trim();
  if (trimmed.length === 0) {
    return invalid('urlEmpty', 'URL is empty.');
  }
  if (WHITESPACE_RE.test(trimmed)) {
    return invalid('urlWhitespace', 'URL contains whitespace.');
  }
  const [scheme, hostToken] = parts(trimmed);
  if (scheme === null && requireProtocol) {
    return invalid('urlProtocolMissing', 'Protocol (https://) is missing.');
  }
  if (scheme !== null && scheme !== 'http' && scheme !== 'https') {
    return invalid('urlBadScheme', 'Only http/https allowed.');
  }
  if (scheme !== null && protocols !== null && !protocols.includes(scheme)) {
    return invalid('urlProtocolNotAllowed', `Only ${protocols.join('/')} allowed.`);
  }
  if (!allowCredentials && hostToken.includes('@')) {
    return invalid('urlCredentials', 'Credentials in the URL are not allowed.');
  }
  const host = hostname(hostToken);
  if (!allowLocalhost && isNonPublicHost(host)) {
    return invalid('urlHostNotPublic', 'Host is not reachable from the public internet.');
  }
  if (!HOST_RE.test(host)) {
    return invalid('urlBadHost', 'Invalid host.');
  }
  return valid(normalize(trimmed, { defaultScheme }));
}

// Strict check for addresses a server will call: https:// required, no other
// scheme, no credentials, no localhost/private hosts.
function webhook(input: string): ValidationResult {
  return validate(input, {
    requireProtocol: true,
    protocols: ['https'],
    allowCredentials: false,
    allowLocalhost: false,
  });
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

// Describes a URL input field.
function fieldDescriptor(): FieldDescriptor {
  return {
    keyboard: 'url',
    autofill: 'url',
    capitalization: 'none',
    maxLength: null,
    example: 'https://example.com',
    allowedChars: null,
  };
}

// Returns input unchanged. Unlike format — which is a display form that
// strips the scheme and `www.` — nothing may be removed while the user is
// still typing. Never throws.
function formatPartial(input: string): string {
  return prepare(input, fieldDescriptor());
}

export const Url = { isValid, validate, webhook, normalize, format, tryFormat, fieldDescriptor, formatPartial };
