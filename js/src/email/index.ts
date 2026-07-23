import { valid, invalid } from '../common/types';
import type { ValidationResult, Suggestion } from '../common/types';

// Validation, normalization and typo-hinting for email addresses.
//
// Validation is pragmatic (one `@`, non-empty local part, dotted domain with
// a plausible TLD) rather than full RFC 5322. Typo hinting is offline only.

const LOCAL_RE = /^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+$/;
const DOMAIN_RE = /^([a-z0-9](-?[a-z0-9])*\.)+[a-z]{2,}$/;

// Popular domains used as targets for the typo heuristic.
const KNOWN_DOMAINS: string[] = [
  'gmail.com',
  'googlemail.com',
  'yahoo.com',
  'hotmail.com',
  'outlook.com',
  'icloud.com',
  'live.com',
  'gmx.net',
  'gmx.de',
  'gmx.at',
  'gmx.ch',
  'web.de',
  't-online.de',
  'a1.net',
  'aon.at',
  'bluewin.ch',
];

// Trims and lower-cases input.
function normalize(input: string): string {
  return input.trim().toLowerCase();
}

// Optimal string alignment (Damerau) distance between a and b. Unlike
// plain Levenshtein it counts an adjacent transposition (e.g. `gmial` vs
// `gmail`) as a single edit, which matches how people mistype domains.
function distance(a: string, b: string): number {
  const n = a.length;
  const m = b.length;
  const d: number[][] = Array.from({ length: n + 1 }, () => new Array<number>(m + 1).fill(0));
  for (let i = 0; i <= n; i++) {
    d[i][0] = i;
  }
  for (let j = 0; j <= m; j++) {
    d[0][j] = j;
  }
  for (let i = 1; i <= n; i++) {
    for (let j = 1; j <= m; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      let v = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost);
      if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) {
        const transposed = d[i - 2][j - 2] + 1;
        if (transposed < v) v = transposed;
      }
      d[i][j] = v;
    }
  }
  return d[n][m];
}

// Returns a close known domain within edit distance 1, or null.
function closeDomain(domain: string): string | null {
  if (KNOWN_DOMAINS.includes(domain)) return null;
  for (const known of KNOWN_DOMAINS) {
    if (distance(domain, known) === 1) return known;
  }
  return null;
}

// Validates input. On success returns a valid result (with a typo
// suggestion when the domain is a near-miss of a popular provider).
function validate(input: string): ValidationResult {
  const s = normalize(input);
  if (s.length === 0) {
    return invalid('emailEmpty', 'Email is empty.');
  }
  const at = (s.match(/@/g) ?? []).length;
  if (at === 0) {
    return invalid('emailMissingAt', 'Missing @.');
  }
  if (at > 1) {
    return invalid('emailMultipleAt', 'Multiple @.');
  }
  const i = s.indexOf('@');
  const local = s.substring(0, i);
  const domain = s.substring(i + 1);
  if (local.length === 0 || !LOCAL_RE.test(local)) {
    return invalid('emailEmptyLocal', 'Bad local part.');
  }
  if (!DOMAIN_RE.test(domain)) {
    return invalid('emailBadDomain', 'Bad domain.');
  }
  const close = closeDomain(domain);
  const suggestions: Suggestion[] = close === null ? [] : [{ value: `${local}@${close}`, reason: 'typo-domain' }];
  return valid(s, suggestions);
}

// True when validate returns a valid result.
function isValid(input: string): boolean {
  return validate(input).ok;
}

export const Email = { isValid, validate, normalize };
