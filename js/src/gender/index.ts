import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';

// Gender as recorded in the Austrian civil register (Personenstand): male,
// female, diverse, inter, open. "No entry" is deliberately not a value: forms
// that require a gender (payroll: the L16 wage slip) have no way to report it.
// Codes are single lower-case letters. validate also accepts the German and
// English words and "w" (weiblich), case-insensitive, surrounding blanks
// ignored.

export type GenderCode = 'm' | 'f' | 'd' | 'i' | 'o';
export type GenderLocale = 'de' | 'en';
export interface GenderOption {
  readonly value: GenderCode;
  readonly label: string;
}

const VALUES: readonly GenderCode[] = Object.freeze(['m', 'f', 'd', 'i', 'o']);

const LABELS: Readonly<Record<GenderLocale, Readonly<Record<GenderCode, string>>>> = {
  de: { m: 'männlich', f: 'weiblich', d: 'divers', i: 'inter', o: 'offen' },
  en: { m: 'male', f: 'female', d: 'diverse', i: 'inter', o: 'open' },
};

// A Map, not an object literal: keys like "constructor" must not resolve.
const ALIASES: ReadonlyMap<string, GenderCode> = new Map<string, GenderCode>([
  ['m', 'm'], ['männlich', 'm'], ['maennlich', 'm'], ['male', 'm'],
  ['f', 'f'], ['w', 'f'], ['weiblich', 'f'], ['female', 'f'],
  ['d', 'd'], ['divers', 'd'], ['diverse', 'd'],
  ['i', 'i'], ['inter', 'i'],
  ['o', 'o'], ['offen', 'o'], ['open', 'o'],
]);

// Validates input, returning a valid result with the one-letter code or an
// invalid result describing why it was rejected.
function validate(input: string): ValidationResult {
  const s = input.trim().toLowerCase();
  if (s.length === 0) {
    return invalid('genderEmpty', 'Gender is empty.');
  }
  const code = ALIASES.get(s);
  if (code === undefined) {
    return invalid('genderUnknown', 'Unknown gender.');
  }
  return valid(code);
}

// True when validate returns a valid result.
function isValid(input: string): boolean {
  return validate(input).ok;
}

// Returns the one-letter code. Throws FormatError if input is not a gender.
function normalize(input: string): GenderCode {
  const r = validate(input);
  if (!r.ok) {
    throw new FormatError(r.issues[0].message);
  }
  return r.normalized as GenderCode;
}

// Display label of a gender (German by default). Throws FormatError if input
// is not a gender.
function label(input: string, locale: GenderLocale = 'de'): string {
  return LABELS[locale][normalize(input)];
}

// The values with their labels, in the order of `values` – for a select.
function options(locale: GenderLocale = 'de'): GenderOption[] {
  return VALUES.map((value) => ({ value, label: LABELS[locale][value] }));
}

export const Gender = {
  values: VALUES,
  isValid,
  validate,
  normalize,
  label,
  options,
};
