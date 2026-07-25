import type { FieldDescriptor } from './field';

export interface PrepareOptions {
  // Character-class body of separators to remove before truncating.
  separators?: string;
  // Maximum number of significant (separator-free) characters to keep.
  maxSignificant?: number;
}

// Applies the first three steps of a formatPartial pipeline: capitalization,
// character filtering, and truncation. Grouping is the caller's job.
//
// Casing runs before filtering on purpose: VIN allows 0-9A-HJ-NPR-Z, so
// filtering a freshly typed lower-case `h` first would delete it instead of
// upper-casing it into a valid character.
export function prepare(input: string, d: FieldDescriptor, opts: PrepareOptions = {}): string {
  let s = input;
  if (d.capitalization === 'characters') s = s.toUpperCase();
  if (d.allowedChars !== null) s = s.replace(new RegExp(`[^${d.allowedChars}]`, 'g'), '');
  if (opts.separators !== undefined) s = s.replace(new RegExp(`[${opts.separators}]`, 'g'), '');
  if (opts.maxSignificant !== undefined && s.length > opts.maxSignificant) {
    s = s.substring(0, opts.maxSignificant);
  }
  return s;
}

// Inserts sep after every `size` characters, never trailing.
export function groupEvery(s: string, size: number, sep: string): string {
  if (s.length <= size) return s;
  const out: string[] = [];
  for (let i = 0; i < s.length; i += size) {
    out.push(s.substring(i, Math.min(i + size, s.length)));
  }
  return out.join(sep);
}

// Inserts sep between runs of the given widths. Characters left over after
// the last width are appended without a further separator.
export function groupWidths(s: string, widths: number[], sep: string): string {
  const out: string[] = [];
  let i = 0;
  for (const w of widths) {
    if (i >= s.length) break;
    const end = Math.min(i + w, s.length);
    out.push(s.substring(i, end));
    i = end;
  }
  if (i < s.length) return out.join(sep) + s.substring(i);
  return out.join(sep);
}
