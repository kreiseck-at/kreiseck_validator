import type { FieldDescriptor, KeyboardType, Capitalization, AutofillHint } from '../common/field';
import type { ValidationResult } from '../common/types';

// Turning a FieldDescriptor into an actual input field.
//
// The mapping below used to live only as a table in the README, which meant
// every consumer transcribed it by hand. It is code here so there is one
// answer, shared by React, Vue, Svelte and plain DOM alike.
//
// This subpath is TypeScript-only and uses DOM lib types; the main entry point
// stays platform-neutral. There is no Dart counterpart on purpose -- one would
// need a Flutter dependency, and the Dart library is deliberately Flutter-free.

const INPUT_MODE: Record<KeyboardType, string> = {
  text: 'text',
  digits: 'numeric',
  phone: 'tel',
  email: 'email',
  url: 'url',
};

const AUTOCOMPLETE: Record<AutofillHint, string> = {
  email: 'email',
  telephoneNumber: 'tel',
  postalCode: 'postal-code',
  creditCardNumber: 'cc-number',
  url: 'url',
};

// HTML input attributes expressing a FieldDescriptor. Keys are camelCase, so
// the object can be spread straight onto a React input; bindInput translates
// to DOM attribute names internally, so no consumer has to know both
// spellings.
export interface FieldAttrs {
  inputMode: string;
  autoCapitalize: Capitalization;
  autoComplete?: string;
  maxLength?: number;
  placeholder?: string;
}

export interface FieldAttrsOptions {
  // Set false to leave the placeholder to the caller. Default: use the
  // descriptor's example when it has one.
  placeholder?: boolean;
}

// Maps a FieldDescriptor onto the HTML input attributes that express it.
export function fieldAttrs(d: FieldDescriptor, opts: FieldAttrsOptions = {}): FieldAttrs {
  const attrs: FieldAttrs = {
    inputMode: INPUT_MODE[d.keyboard],
    autoCapitalize: d.capitalization,
  };
  if (d.autofill !== null) attrs.autoComplete = AUTOCOMPLETE[d.autofill];
  if (d.maxLength !== null) attrs.maxLength = d.maxLength;
  if (opts.placeholder !== false && d.example !== null) attrs.placeholder = d.example;
  return attrs;
}

// Drops characters the descriptor does not allow and truncates to its
// maxLength. Exported separately because a controlled React input needs this
// without any element being involved.
export function filterValue(value: string, d: FieldDescriptor): string {
  let s = value;
  if (d.capitalization === 'characters') s = s.toUpperCase();
  if (d.allowedChars !== null) s = s.replace(new RegExp(`[^${d.allowedChars}]`, 'g'), '');
  if (d.maxLength !== null && s.length > d.maxLength) s = s.substring(0, d.maxLength);
  return s;
}

// What a bound field currently is.
//
// 'incomplete' is part of the union but bindInput never emits it: telling
// "too short" apart from "wrong" needs per-type knowledge this function does
// not have. A consumer that wants the distinction compares the value's
// significant length against descriptor.maxLength itself. The member exists so
// that a form layer can model the state without inventing its own enum.
export interface FieldState {
  state: 'empty' | 'incomplete' | 'valid' | 'invalid';
  normalized: string | null;
  issue: string | null;
}

export interface BindOptions {
  descriptor: FieldDescriptor;
  formatPartial: (value: string) => string;
  validate: (value: string) => ValidationResult;
  onState?: (s: FieldState) => void;
}

// Binds an input element to one validator type: applies the attributes,
// formats as the user types, validates on blur, and reports the result through
// onState. Returns a function that unbinds.
//
// options takes the three functions directly rather than a type name, so this
// stays decoupled from the list of types and needs no registry.
export function bindInput(el: HTMLInputElement, o: BindOptions): () => void {
  const a = fieldAttrs(o.descriptor);
  el.inputMode = a.inputMode;
  el.setAttribute('autocapitalize', a.autoCapitalize);
  // Set through the attribute rather than the property: the DOM types declare
  // `autocomplete` as a closed AutoFill union, and the descriptor's hint is a
  // plain string by design (the package has no DOM types in its core).
  if (a.autoComplete !== undefined) el.setAttribute('autocomplete', a.autoComplete);
  if (a.maxLength !== undefined) el.maxLength = a.maxLength;
  if (a.placeholder !== undefined && el.placeholder === '') el.placeholder = a.placeholder;

  const allowed = o.descriptor.allowedChars === null
    ? null
    : new RegExp(`[${o.descriptor.allowedChars}]`);

  // A character the user actually typed, as opposed to a separator the
  // formatter inserted. Whitespace is never significant: every grouping
  // separator in this package is a space, a hyphen or a slash, and those are
  // exactly what must not be counted when restoring the caret.
  function isSignificant(ch: string): boolean {
    if (ch.trim().length === 0) return false;
    return allowed === null ? true : allowed.test(ch);
  }

  function onInput(): void {
    const caret = el.selectionStart ?? el.value.length;
    let significantBefore = 0;
    for (const ch of el.value.slice(0, caret)) {
      if (isSignificant(ch)) significantBefore++;
    }
    const formatted = o.formatPartial(el.value);
    if (formatted === el.value) return;
    el.value = formatted;
    // Rewriting the value would otherwise drop the caret at the end, making it
    // impossible to edit the middle of a formatted IBAN. Walk forward until as
    // many significant characters have been passed as there were before.
    let pos = 0;
    let seen = 0;
    while (pos < formatted.length && seen < significantBefore) {
      if (isSignificant(formatted[pos])) seen++;
      pos++;
    }
    el.setSelectionRange(pos, pos);
  }

  function onBlur(): void {
    if (o.onState === undefined) return;
    if (el.value.trim().length === 0) {
      o.onState({ state: 'empty', normalized: null, issue: null });
      return;
    }
    const r = o.validate(el.value);
    o.onState(r.ok
      ? { state: 'valid', normalized: r.normalized, issue: null }
      : { state: 'invalid', normalized: null, issue: r.issues[0].code });
  }

  el.addEventListener('input', onInput);
  el.addEventListener('blur', onBlur);
  return () => {
    el.removeEventListener('input', onInput);
    el.removeEventListener('blur', onBlur);
  };
}
