import { valid, invalid } from '../common/types';
import type { ValidationResult } from '../common/types';
import { FormatError } from '../common/errors';
import type { HostInfo, HostType } from './types';

// Validation, normalization and formatting of a bare host: a hostname
// (RFC 1123), an IPv4 address or an IPv6 address, with an optional port.
//
// This is more lenient than Url: it accepts `localhost`, single-label
// hostnames and IP literals, and does not require a scheme.

const IPV4_RE = /^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$/;
const HEX_GROUP_RE = /^[0-9a-f]{1,4}$/;
const LABEL_RE = /^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$/;
const DIGITS_RE = /^[0-9]+$/;

function isHostname(h: string): boolean {
  if (h.length === 0 || h.length > 253) return false;
  const labels = h.split('.');
  for (const l of labels) {
    if (!LABEL_RE.test(l)) return false;
  }
  return true;
}

function isIpv6(h: string): boolean {
  if (h.length === 0) return false;
  const parts = h.split('::');
  if (parts.length > 2) return false;
  const hasDouble = parts.length === 2;
  let groups: string[];
  if (hasDouble) {
    const left = parts[0];
    const right = parts[1];
    const leftGroups = left === '' ? [] : left.split(':');
    const rightGroups = right === '' ? [] : right.split(':');
    if (leftGroups.some((g) => g === '') || rightGroups.some((g) => g === '')) {
      return false;
    }
    groups = [...leftGroups, ...rightGroups];
  } else {
    groups = h.split(':');
    if (groups.some((g) => g === '')) return false;
  }
  let count = 0;
  for (let i = 0; i < groups.length; i++) {
    const g = groups[i];
    const isLast = i === groups.length - 1;
    if (g.includes('.')) {
      if (!isLast || !IPV4_RE.test(g)) return false;
      count += 2;
    } else {
      if (!HEX_GROUP_RE.test(g)) return false;
      count += 1;
    }
  }
  return hasDouble ? count <= 7 : count === 8;
}

// Classifies hostPart (already lower-cased) as 'ipv4', 'ipv6' or
// 'hostname', or returns null when it matches none.
function classify(hostPart: string): HostType | null {
  if (IPV4_RE.test(hostPart)) return 'ipv4';
  if (isIpv6(hostPart)) return 'ipv6';
  if (isHostname(hostPart)) return 'hostname';
  return null;
}

// Parses a decimal port string into 0..65535, or null when it is not a
// valid port, or -1 when it is syntactically a number but out of range.
function port(digits: string): number | null {
  if (digits.length === 0 || !DIGITS_RE.test(digits)) return null;
  if (digits.length > 15) return -1; // unmistakably out of range
  const n = Number(digits);
  return n <= 65535 ? n : -1;
}

function normalized(host: string, type: HostType, portNum: number | null): string {
  const base = type === 'ipv6' && portNum !== null ? `[${host}]` : host;
  return portNum === null ? base : `${base}:${portNum}`;
}

interface Analysis {
  host: string;
  type: HostType;
  port: number | null;
  normalized: string;
}

type HostIssueCode = 'hostEmpty' | 'hostBadFormat' | 'hostBadPort';
interface Rejection {
  code: HostIssueCode;
  message: string;
}

// Splits the port off `lower` (already trimmed and lower-cased) and
// classifies the remaining host part, returning either a rejection or the
// accepted analysis.
function analyze(lower: string): Rejection | Analysis {
  let hostPart: string;
  let portNum: number | null;

  if (lower.startsWith('[')) {
    const close = lower.indexOf(']');
    if (close === -1) {
      return { code: 'hostBadFormat', message: 'Missing closing bracket.' };
    }
    hostPart = lower.substring(1, close);
    const after = lower.substring(close + 1);
    if (after.length === 0) {
      portNum = null;
    } else if (after.startsWith(':')) {
      const digits = after.substring(1);
      if (digits.length === 0 || !DIGITS_RE.test(digits)) {
        return { code: 'hostBadFormat', message: 'Invalid port after host.' };
      }
      const p = port(digits);
      if (p === null || p < 0) {
        return { code: 'hostBadPort', message: 'Port must be 0-65535.' };
      }
      portNum = p;
    } else {
      return { code: 'hostBadFormat', message: 'Unexpected characters after host.' };
    }
  } else {
    const colonCount = lower.split(':').length - 1;
    if (colonCount === 1) {
      const idx = lower.indexOf(':');
      const after = lower.substring(idx + 1);
      if (after.length > 0 && DIGITS_RE.test(after)) {
        hostPart = lower.substring(0, idx);
        const p = port(after);
        if (p === null || p < 0) {
          return { code: 'hostBadPort', message: 'Port must be 0-65535.' };
        }
        portNum = p;
      } else {
        hostPart = lower;
        portNum = null;
      }
    } else {
      hostPart = lower;
      portNum = null;
    }
  }

  if (hostPart.length === 0) {
    return { code: 'hostEmpty', message: 'Host is empty.' };
  }

  const type = classify(hostPart);
  if (type === null) {
    return { code: 'hostBadFormat', message: 'Host has an invalid format.' };
  }

  return { host: hostPart, type, port: portNum, normalized: normalized(hostPart, type, portNum) };
}

function isAnalysis(r: Rejection | Analysis): r is Analysis {
  return (r as Analysis).type !== undefined;
}

// Validates input, returning a valid result with the normalize form or an
// invalid result describing why it was rejected.
function validate(input: string): ValidationResult {
  const trimmed = input.trim();
  if (trimmed.length === 0) {
    return invalid('hostEmpty', 'Host is empty.');
  }
  const r = analyze(trimmed.toLowerCase());
  if (!isAnalysis(r)) {
    return invalid(r.code, r.message);
  }
  return valid(r.normalized);
}

// True when validate returns a valid result.
function isValid(input: string): boolean {
  return validate(input).ok;
}

// Returns the canonical form: lower-cased host, IPv6 re-bracketed when a
// port is present, port appended. Throws FormatError if input is not a
// valid host.
function normalize(input: string): string {
  const r = validate(input);
  if (!r.ok) {
    throw new FormatError(r.issues[0].message);
  }
  return r.normalized;
}

// Returns the canonical form. Throws FormatError if input is invalid.
function format(input: string): string {
  return normalize(input);
}

// Like format but returns null instead of throwing on invalid input.
function tryFormat(input: string): string | null {
  try {
    return format(input);
  } catch (e) {
    if (e instanceof FormatError) return null;
    throw e;
  }
}

// Parses input into a HostInfo, or null when it is not a valid host.
function parse(input: string): HostInfo | null {
  const trimmed = input.trim();
  if (trimmed.length === 0) return null;
  const r = analyze(trimmed.toLowerCase());
  if (!isAnalysis(r)) return null;
  return { host: r.host, type: r.type, port: r.port, hasPort: r.port !== null };
}

export const Host = { isValid, validate, normalize, format, tryFormat, parse };
export type { HostInfo, HostType };
