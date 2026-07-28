import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';
import type { FieldDescriptor } from '../common/field';
import { prepare } from '../common/partial';
import { checkVat, vatSubtypeOf } from './checks';
import { kVatFormats } from './metadata';
import type { VatFormat } from './metadata';
import type { VatInfo, VatSubtype, ViesRequest, VatRegistration } from './types';

// Validation, normalization, formatting and parsing of European VAT
// identification numbers.
//
// Covers the 27 EU member states plus Switzerland, the United Kingdom and
// Northern Ireland. EVERY one of them is checked arithmetically, not just
// structurally: a documented check-digit algorithm exists for all of them, so
// 'vatBadChecksum' is always meaningful and a transposed digit is always
// caught.
//
// Two spellings differ between the tax world and ISO 3166, and both are
// handled explicitly:
//
// - Greece writes 'EL', ISO says 'GR'. Either is accepted as country,
//   normalize emits 'EL', and VatInfo.country reports 'GR'.
// - Northern Ireland writes 'XI' post-Brexit; VatInfo.country reports 'GB'.
//
// A value carrying its own prefix resolves itself and that prefix wins over
// the country option; compare VatInfo.country against your own expectation if
// the distinction matters. A bare number needs country, otherwise it is
// genuinely ambiguous -- plain nine-digit bodies are valid in half a dozen
// member states at once.
//
// No network access. VAT registration is a fact about a company, not about the
// string, and only the EU's VIES service knows it -- see viesRequest.

export interface VatOptions { country?: string }

const SEPARATORS_RE = /[\s.\-/]/g;
const TWO_LETTERS_RE = /^[A-Z]{2}/;

const compiled = new Map<string, RegExp>();
function bodyRe(f: VatFormat): RegExp {
  let re = compiled.get(f.body);
  if (re === undefined) {
    re = new RegExp(f.body);
    compiled.set(f.body, re);
  }
  return re;
}

// VAT prefixes longest-first, so 'ATU' is tried before any two-letter code.
const PREFIXES: [string, string][] = Object.entries(kVatFormats)
  .map(([iso2, f]): [string, string] => [f.prefix, iso2])
  .sort((a, b) => b[0].length - a[0].length);

// Resolves an explicit country to a key of kVatFormats, accepting the tax
// spelling 'EL' (Greece) alongside the ISO ones.
function keyForCountry(country: string | undefined): string | null {
  if (country === undefined) return null;
  const upper = country.toUpperCase();
  if (upper === 'EL') return 'GR';
  return upper in kVatFormats ? upper : null;
}

// Belgium's pre-2008 nine-digit numbers are the same number without their
// leading zero; everything downstream expects ten digits.
function padBody(key: string, body: string): string {
  return key === 'BE' && body.length === 9 ? `0${body}` : body;
}

// Validates input, returning the prefixed, separator-free canonical form.
function validate(input: string, o: VatOptions = {}): ValidationResult {
  const compact = input.toUpperCase().replace(SEPARATORS_RE, '');
  if (compact.length === 0) {
    return invalid('vatEmpty', 'VAT ID is empty.');
  }

  let key: string | null = null;
  let body = compact;
  for (const [prefix, iso2] of PREFIXES) {
    if (compact.startsWith(prefix)) {
      key = iso2;
      body = compact.substring(prefix.length);
      break;
    }
  }

  if (key === null) {
    if (TWO_LETTERS_RE.test(compact)) {
      return invalid('vatUnknownCountry', 'Unknown VAT country prefix.');
    }
    key = keyForCountry(o.country);
    if (key === null) {
      return o.country === undefined
        ? invalid('vatAmbiguousCountry', 'VAT ID has no country prefix; pass country.')
        : invalid('vatUnknownCountry', 'Unknown VAT country.');
    }
  }

  const format = kVatFormats[key];
  body = padBody(key, body);
  if (!bodyRe(format).test(body)) {
    return invalid('vatBadFormat', 'VAT ID has invalid format.');
  }
  if (!checkVat(key, body)) {
    return invalid('vatBadChecksum', 'VAT ID check digit is wrong.');
  }
  return valid(`${format.prefix}${body}`);
}

// True when validate returns a valid result.
function isValid(input: string, o: VatOptions = {}): boolean {
  return validate(input, o).ok;
}

// Returns the prefixed, separator-free canonical form. Throws FormatError if
// input is not a valid VAT ID.
function normalize(input: string, o: VatOptions = {}): string {
  const r = validate(input, o);
  if (!r.ok) throw new FormatError(r.issues[0].message);
  return r.normalized;
}

// Returns the canonical form. VAT IDs have no conventional grouping, so this
// equals normalize. Throws FormatError if invalid.
function format(input: string, o: VatOptions = {}): string {
  return normalize(input, o);
}

// Like format but returns null instead of throwing on invalid input.
function tryFormat(input: string, o: VatOptions = {}): string | null {
  try {
    return format(input, o);
  } catch (e) {
    if (e instanceof FormatError) return null;
    throw e;
  }
}

// Parses input into a VatInfo, or null when it is not a valid VAT ID.
function parse(input: string, o: VatOptions = {}): VatInfo | null {
  const r = validate(input, o);
  if (!r.ok) return null;
  const normalized = r.normalized;
  for (const [prefix, key] of PREFIXES) {
    if (normalized.startsWith(prefix)) {
      const body = normalized.substring(prefix.length);
      return {
        country: key === 'XI' ? 'GB' : key,
        prefix,
        number: body,
        subtype: vatSubtypeOf(key, body),
      };
    }
  }
  return null;
}

const VIES_BASE = 'https://ec.europa.eu/taxation_customs/vies/rest-api/ms';

// Builds the VIES request for value, or null when value is not a valid VAT ID
// or its country is outside VIES.
//
// Switzerland is the one supported country VIES does not cover -- it is not an
// EU member state -- so a Swiss number always yields null.
//
// The package performs no request. Send the ViesRequest yourself and hand the
// response body to parseViesResponse.
function viesRequest(value: string, o: VatOptions = {}): ViesRequest | null {
  const r = validate(value, o);
  if (!r.ok) return null;
  const ms = r.normalized.substring(0, 2);
  if (ms === 'CH') return null;
  return {
    url: `${VIES_BASE}/${ms}/vat/${r.normalized.substring(2)}`,
    method: 'GET',
    headers: { Accept: 'application/json' },
  };
}

// VIES writes '---' for a value the member state withholds, and an empty
// string when there is nothing to say. Neither is a name.
function disclosed(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length === 0 || trimmed === '---' ? null : trimmed;
}

// Parses a VIES response body into a VatRegistration, or null when the service
// gave no conclusive answer.
//
// NULL DOES NOT MEAN "NOT REGISTERED". VIES forwards the question to the
// member state, and that state is regularly busy or down; the service then
// answers with isValid: false and a userError such as MS_MAX_CONCURRENT_REQ or
// MS_UNAVAILABLE. Treating that as a rejection would refuse perfectly good
// customers whenever a tax office is having a bad afternoon, so only VALID and
// INVALID produce a result here and everything else -- including malformed
// JSON -- produces null. Callers should read null as "ask again later" and
// fall back to the offline structural check, which validate already gave them.
function parseViesResponse(body: string): VatRegistration | null {
  let decoded: unknown;
  try {
    decoded = JSON.parse(body);
  } catch {
    return null;
  }
  if (typeof decoded !== 'object' || decoded === null || Array.isArray(decoded)) {
    return null;
  }
  const o = decoded as Record<string, unknown>;
  if (o.userError !== 'VALID' && o.userError !== 'INVALID') return null;
  return {
    valid: o.userError === 'VALID',
    name: disclosed(o.name),
    address: disclosed(o.address),
    requestDate: typeof o.requestDate === 'string' ? o.requestDate : null,
  };
}

// Describes a VAT-ID input field.
//
// The field is assumed to hold the whole VAT ID including its prefix, so the
// keyboard is always textual and the character set always alphanumeric --
// several countries put letters in the body (CY, ES, FR, GB, NL). Only
// maxLength and example vary by country.
function fieldDescriptor(o: VatOptions = {}): FieldDescriptor {
  const key = keyForCountry(o.country);
  const f = key === null ? null : kVatFormats[key];
  return {
    keyboard: 'text',
    autofill: null,
    capitalization: 'characters',
    maxLength: f === null ? null : f.prefix.length + f.maxLen,
    example: f === null ? null : f.example,
    allowedChars: '0-9A-Z',
  };
}

// Formats partially typed input: upper-cased, non-alphanumerics dropped,
// capped at the country's length when one is known. VAT IDs have no grouping,
// so nothing is inserted. Never throws.
function formatPartial(input: string, o: VatOptions = {}): string {
  const d = fieldDescriptor(o);
  return prepare(input, d, d.maxLength === null ? {} : { maxSignificant: d.maxLength });
}

export const VatId = {
  isValid, validate, normalize, format, tryFormat, parse, viesRequest,
  parseViesResponse, fieldDescriptor, formatPartial,
};
export type { VatInfo, VatSubtype, ViesRequest, VatRegistration };
