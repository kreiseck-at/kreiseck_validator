import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';
import type { MacFormatOptions, MacInfo, MacNotation } from './types';

// Validation, normalization and formatting of MAC hardware addresses (IEEE
// EUI-48 and EUI-64), accepting colon, hyphen, Cisco-dot and bare notations.

const COLON_48 = /^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/;
const COLON_64 = /^([0-9A-Fa-f]{2}:){7}[0-9A-Fa-f]{2}$/;
const HYPHEN_48 = /^([0-9A-Fa-f]{2}-){5}[0-9A-Fa-f]{2}$/;
const HYPHEN_64 = /^([0-9A-Fa-f]{2}-){7}[0-9A-Fa-f]{2}$/;
const DOT_48 = /^([0-9A-Fa-f]{4}\.){2}[0-9A-Fa-f]{4}$/;
const DOT_64 = /^([0-9A-Fa-f]{4}\.){3}[0-9A-Fa-f]{4}$/;
const BARE_48 = /^[0-9A-Fa-f]{12}$/;
const BARE_64 = /^[0-9A-Fa-f]{16}$/;

// Extracts the bare hex digits (12 or 16, in input order) from trimmed when
// it matches one of the recognized notations, or returns null otherwise.
function extractHex(trimmed: string): string | null {
  if (COLON_48.test(trimmed) || COLON_64.test(trimmed)) {
    return trimmed.split(':').join('');
  }
  if (HYPHEN_48.test(trimmed) || HYPHEN_64.test(trimmed)) {
    return trimmed.split('-').join('');
  }
  if (DOT_48.test(trimmed) || DOT_64.test(trimmed)) {
    return trimmed.split('.').join('');
  }
  if (BARE_48.test(trimmed) || BARE_64.test(trimmed)) {
    return trimmed;
  }
  return null;
}

// Joins lower-cased hex into groups of size characters separated by sep.
function grouped(hex: string, size: number, sep: string): string {
  const lower = hex.toLowerCase();
  const groups: string[] = [];
  for (let i = 0; i < lower.length; i += size) {
    groups.push(lower.substring(i, i + size));
  }
  return groups.join(sep);
}

// Validates input, returning a valid result with the canonical lower-case
// colon-separated form or an invalid result describing why it was rejected.
function validate(input: string): ValidationResult {
  const trimmed = input.trim();
  if (trimmed.length === 0) {
    return invalid('macEmpty', 'MAC address is empty.');
  }
  const hex = extractHex(trimmed);
  if (hex === null) {
    return invalid('macBadFormat', 'MAC address has an unrecognized format.');
  }
  return valid(grouped(hex, 2, ':'));
}

// True when validate returns a valid result.
function isValid(input: string): boolean {
  return validate(input).ok;
}

// Returns the canonical lower-case colon-separated form. Throws FormatError
// if input is not a valid MAC address.
function normalize(input: string): string {
  const r = validate(input);
  if (!r.ok) {
    throw new FormatError(r.issues[0].message);
  }
  return r.normalized;
}

// Formats input using opts.notation (default 'colon'), optionally
// upper-cased. Throws FormatError if input is not a valid MAC address.
function format(input: string, opts: MacFormatOptions = {}): string {
  const notation: MacNotation = opts.notation ?? 'colon';
  const upperCase = opts.upperCase ?? false;
  const hex = normalize(input).split(':').join('');
  let out: string;
  switch (notation) {
    case 'colon':
      out = grouped(hex, 2, ':');
      break;
    case 'hyphen':
      out = grouped(hex, 2, '-');
      break;
    case 'dot':
      out = grouped(hex, 4, '.');
      break;
    case 'bare':
      out = hex.toLowerCase();
      break;
  }
  return upperCase ? out.toUpperCase() : out;
}

// Like format but returns null instead of throwing on invalid input.
function tryFormat(input: string, opts: MacFormatOptions = {}): string | null {
  try {
    return format(input, opts);
  } catch (e) {
    if (e instanceof FormatError) return null;
    throw e;
  }
}

// Parses input into a MacInfo, or null when it is not a valid MAC address.
function parse(input: string): MacInfo | null {
  const r = validate(input);
  if (!r.ok) return null;
  const octets = r.normalized.split(':');
  const b0 = parseInt(octets[0], 16);
  const isMulticast = (b0 & 1) === 1;
  const isLocal = (b0 & 2) === 2;
  return {
    oui: octets.slice(0, 3).join(':'),
    nic: octets.slice(3).join(':'),
    isUnicast: !isMulticast,
    isMulticast,
    isUniversal: !isLocal,
    isLocal,
    type: octets.length === 8 ? 'eui64' : 'eui48',
  };
}

export const MacAddress = { isValid, validate, normalize, format, tryFormat, parse };
export type { MacInfo };
