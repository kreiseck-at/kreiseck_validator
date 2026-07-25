# FieldDescriptor + formatPartial Implementation Plan

**Goal:** Expose each validator's input characteristics as a `FieldDescriptor`, and add `formatPartial` for as-you-type formatting, in both the Dart and the TypeScript package.

**Architecture:** Two new files per language hold the shared pieces — a public `FieldDescriptor` value type with three small enums, and a non-exported helper module with the four-step pipeline (case → filter → truncate → group). Each of the 12 validator modules then adds two statics, `fieldDescriptor(...)` and `formatPartial(...)`, taking the same options as `validate`. Cross-language agreement is pinned by two new JSON vector files consumed by both test suites.

**Tech Stack:** Dart (package `kreiseck_validator`, `dart test`), TypeScript (package `@kreiseck/validator`, vitest), Python 3 stdlib for the postal metadata generator.

**Spec:** `docs/design/specs/2026-07-25-field-descriptor-design.md` — read it before starting. Where this plan and the spec disagree, the spec is wrong and should be corrected.

## Global Constraints

- **Zero runtime dependencies** in both packages. No Flutter types, no DOM types, no new npm/pub dependencies.
- **Both languages, always.** Every behaviour added to Dart is added to TypeScript in the same task, and pinned by a shared vector file under `test/vectors/`.
- **Dart enum member names are character-identical to the TS string-literal union members** (`digits`, `characters`, `telephoneNumber`, …). The vectors compare against these strings.
- **Absent values are `null`, never `undefined`**, in both languages, so JSON comparison matches.
- **Naming:** `fieldDescriptor`, `formatPartial`, `FieldDescriptor`, `KeyboardType`, `Capitalization`, `AutofillHint`.
- **Comment style:** Dart uses `///` doc comments on every public member (the package has `public_member_api_docs` expectations); TypeScript uses `//` line comments above declarations.
- **Version target:** `0.10.0` in `pubspec.yaml` and `js/package.json`, bumped once in the final task.
- **No trailing separators** in any `formatPartial` output.
- **Test commands:** Dart `dart test <file>`; TypeScript `cd js && npx vitest run <file>` (full suite: `npm test`).

---

### Task 1: Core descriptor types and pipeline helpers (Dart)

**Files:**
- Create: `lib/src/common/field_descriptor.dart`
- Create: `lib/src/common/partial_format.dart`
- Modify: `lib/kreiseck_validator.dart`
- Test: `test/field_descriptor_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class FieldDescriptor` with final fields `keyboard` (`KeyboardType`), `autofill` (`AutofillHint?`), `capitalization` (`Capitalization`), `maxLength` (`int?`), `example` (`String?`), `allowedChars` (`String?`); const constructor with named params, `keyboard` required, `capitalization` defaulting to `Capitalization.none`, the rest defaulting to null.
  - `enum KeyboardType { text, digits, phone, email, url }`
  - `enum Capitalization { none, characters, words, sentences }`
  - `enum AutofillHint { email, telephoneNumber, postalCode, creditCardNumber, url }`
  - `String prepare(String input, FieldDescriptor d, {String? separators, int? maxSignificant})` — steps 1–3.
  - `String groupEvery(String s, int size, String sep)`
  - `String groupWidths(String s, List<int> widths, String sep)`

`partial_format.dart` is **not** exported from `lib/kreiseck_validator.dart` — it is internal, like `lib/src/common/luhn.dart`.

- [ ] **Step 1: Write the failing test**

Create `test/field_descriptor_test.dart`:

```dart
import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:kreiseck_validator/src/common/partial_format.dart';
import 'package:test/test.dart';

void main() {
  group('groupEvery', () {
    test('leaves short input untouched', () {
      expect(groupEvery('AT6', 4, ' '), 'AT6');
      expect(groupEvery('AT61', 4, ' '), 'AT61');
    });

    test('inserts separators without a trailing one', () {
      expect(groupEvery('AT611', 4, ' '), 'AT61 1');
      expect(groupEvery('AT611904', 4, ' '), 'AT61 1904');
      expect(groupEvery('AABBCC', 2, ':'), 'AA:BB:CC');
    });

    test('handles empty input', () {
      expect(groupEvery('', 4, ' '), '');
    });
  });

  group('groupWidths', () {
    test('applies widths in order', () {
      expect(groupWidths('378282246310005', const [4, 6, 5], ' '),
          '3782 822463 10005');
      expect(groupWidths('37828', const [4, 6, 5], ' '), '3782 8');
    });

    test('appends characters beyond the last width', () {
      expect(groupWidths('3782822463100051', const [4, 6, 5], ' '),
          '3782 822463 100051');
    });
  });

  group('prepare', () {
    const vin = FieldDescriptor(
      keyboard: KeyboardType.text,
      capitalization: Capitalization.characters,
      allowedChars: '0-9A-HJ-NPR-Z',
    );

    test('upper-cases before filtering', () {
      expect(prepare('1hgcm8', vin), '1HGCM8');
    });

    test('drops characters outside allowedChars', () {
      expect(prepare('1HGC-M8', vin), '1HGCM8');
      expect(prepare('1HGCIOQ', vin), '1HGC');
    });

    test('removes separators when asked', () {
      const iban = FieldDescriptor(
        keyboard: KeyboardType.text,
        capitalization: Capitalization.characters,
        allowedChars: '0-9A-Z ',
      );
      expect(prepare('AT61 1904', iban, separators: ' '), 'AT611904');
    });

    test('truncates to maxSignificant', () {
      expect(prepare('1HGCM82633A004352XYZ', vin, maxSignificant: 17),
          '1HGCM82633A004352');
    });

    test('leaves case alone when capitalization is none', () {
      const host = FieldDescriptor(keyboard: KeyboardType.url);
      expect(prepare('Example.COM', host), 'Example.COM');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/field_descriptor_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'kreiseck_validator' … field_descriptor.dart` / undefined names `FieldDescriptor`, `prepare`.

- [ ] **Step 3: Create the descriptor types**

Create `lib/src/common/field_descriptor.dart`:

```dart
/// Which on-screen keyboard a field should raise.
///
/// Platform-neutral by design: the package has no Flutter or DOM dependency.
/// See the README for the mapping to `TextInputType` and to `inputmode`.
enum KeyboardType {
  /// A normal text keyboard.
  text,

  /// A digits-only keypad.
  digits,

  /// A telephone keypad.
  phone,

  /// A text keyboard optimized for email addresses.
  email,

  /// A text keyboard optimized for URLs.
  url,
}

/// How typed characters should be cased.
enum Capitalization {
  /// Leave input as typed.
  none,

  /// Upper-case every character.
  characters,

  /// Upper-case the first character of each word.
  words,

  /// Upper-case the first character of each sentence.
  sentences,
}

/// Platform autofill category for a field.
///
/// Only categories that exist on both Flutter and the web are listed; value
/// types without a standard category (IBAN, VIN, IMEI, ICCID, MAC, license
/// plate) carry a null [FieldDescriptor.autofill] rather than an invented one.
enum AutofillHint {
  /// An email address.
  email,

  /// A telephone number.
  telephoneNumber,

  /// A postal code.
  postalCode,

  /// A payment-card number.
  creditCardNumber,

  /// A URL.
  url,
}

/// The input characteristics of a field holding one kind of value.
///
/// Obtained from any validator's `fieldDescriptor` method, which takes the
/// same options as its `validate`. Everything here is a hint for building an
/// input field; none of it affects validation.
class FieldDescriptor {
  /// Creates a descriptor.
  const FieldDescriptor({
    required this.keyboard,
    this.autofill,
    this.capitalization = Capitalization.none,
    this.maxLength,
    this.example,
    this.allowedChars,
  });

  /// Which on-screen keyboard the field should raise.
  final KeyboardType keyboard;

  /// Platform autofill category, or null when neither platform defines one
  /// for this kind of value.
  final AutofillHint? autofill;

  /// How typed characters should be cased.
  final Capitalization capitalization;

  /// Maximum length of the *formatted* text, separators included, or null
  /// when the value has no useful hard bound.
  final int? maxLength;

  /// A valid example value in formatted form, or null when the type has no
  /// meaningful single example.
  final String? example;

  /// The body of a regex character class listing the characters the field
  /// may contain, e.g. `0-9A-Z `. Null means no filtering.
  ///
  /// Use it directly: `RegExp('[^${d.allowedChars}]')` to strip rejected
  /// characters, `RegExp('[${d.allowedChars}]')` to test one.
  final String? allowedChars;
}
```

- [ ] **Step 4: Create the pipeline helpers**

Create `lib/src/common/partial_format.dart`:

```dart
import 'field_descriptor.dart';

/// Applies the first three steps of a `formatPartial` pipeline to [input]:
/// capitalization, character filtering, and truncation to [maxSignificant]
/// characters. Grouping (step four) is the caller's job.
///
/// Casing runs before filtering on purpose: VIN allows `0-9A-HJ-NPR-Z`, so
/// filtering a freshly typed lower-case `h` first would delete it instead of
/// upper-casing it into a valid character.
///
/// [separators] is a character-class body of separator characters to remove
/// before truncating, for types whose [FieldDescriptor.allowedChars] admits
/// the separators the grouping step re-inserts.
String prepare(
  String input,
  FieldDescriptor d, {
  String? separators,
  int? maxSignificant,
}) {
  var s = input;
  if (d.capitalization == Capitalization.characters) s = s.toUpperCase();
  final allowed = d.allowedChars;
  if (allowed != null) s = s.replaceAll(RegExp('[^$allowed]'), '');
  if (separators != null) s = s.replaceAll(RegExp('[$separators]'), '');
  if (maxSignificant != null && s.length > maxSignificant) {
    s = s.substring(0, maxSignificant);
  }
  return s;
}

/// Inserts [sep] after every [size] characters of [s], never trailing.
String groupEvery(String s, int size, String sep) {
  if (s.length <= size) return s;
  final b = StringBuffer();
  for (var i = 0; i < s.length; i += size) {
    if (i > 0) b.write(sep);
    b.write(s.substring(i, i + size < s.length ? i + size : s.length));
  }
  return b.toString();
}

/// Inserts [sep] between runs of [s] of the given [widths]. Characters left
/// over after the last width are appended without a further separator.
String groupWidths(String s, List<int> widths, String sep) {
  final b = StringBuffer();
  var i = 0;
  for (final w in widths) {
    if (i >= s.length) break;
    if (i > 0) b.write(sep);
    final end = i + w < s.length ? i + w : s.length;
    b.write(s.substring(i, end));
    i = end;
  }
  if (i < s.length) b.write(s.substring(i));
  return b.toString();
}
```

- [ ] **Step 5: Export the public types**

In `lib/kreiseck_validator.dart`, add one line to the export block, keeping alphabetical order among the `src/common/` exports:

```dart
export 'src/common/country.dart';
export 'src/common/field_descriptor.dart';
export 'src/common/issue_code.dart';
```

Do **not** export `src/common/partial_format.dart`.

- [ ] **Step 6: Run test to verify it passes**

Run: `dart test test/field_descriptor_test.dart`
Expected: PASS, all groups green.

- [ ] **Step 7: Run the analyzer**

Run: `dart analyze`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/src/common/field_descriptor.dart lib/src/common/partial_format.dart lib/kreiseck_validator.dart test/field_descriptor_test.dart
git commit -m "Add FieldDescriptor and partial-format helpers"
```

---

### Task 2: Core descriptor types and pipeline helpers (TypeScript)

**Files:**
- Create: `js/src/common/field.ts`
- Create: `js/src/common/partial.ts`
- Modify: `js/src/index.ts`
- Test: `js/test/partial.spec.ts`

**Interfaces:**
- Consumes: the Dart shapes from Task 1 (mirrored, not imported).
- Produces:
  - `export type KeyboardType = 'text' | 'digits' | 'phone' | 'email' | 'url'`
  - `export type Capitalization = 'none' | 'characters' | 'words' | 'sentences'`
  - `export type AutofillHint = 'email' | 'telephoneNumber' | 'postalCode' | 'creditCardNumber' | 'url'`
  - `export interface FieldDescriptor` with the six readonly fields, nullable ones typed `X | null`.
  - `export function prepare(input: string, d: FieldDescriptor, opts?: { separators?: string; maxSignificant?: number }): string`
  - `export function groupEvery(s: string, size: number, sep: string): string`
  - `export function groupWidths(s: string, widths: number[], sep: string): string`

- [ ] **Step 1: Write the failing test**

Create `js/test/partial.spec.ts`:

```ts
import { describe, it, expect } from 'vitest';
import { prepare, groupEvery, groupWidths } from '../src/common/partial';
import type { FieldDescriptor } from '../src/common/field';

const vin: FieldDescriptor = {
  keyboard: 'text',
  autofill: null,
  capitalization: 'characters',
  maxLength: 17,
  example: null,
  allowedChars: '0-9A-HJ-NPR-Z',
};

describe('groupEvery', () => {
  it('leaves short input untouched', () => {
    expect(groupEvery('AT6', 4, ' ')).toBe('AT6');
    expect(groupEvery('AT61', 4, ' ')).toBe('AT61');
  });

  it('inserts separators without a trailing one', () => {
    expect(groupEvery('AT611', 4, ' ')).toBe('AT61 1');
    expect(groupEvery('AABBCC', 2, ':')).toBe('AA:BB:CC');
  });

  it('handles empty input', () => {
    expect(groupEvery('', 4, ' ')).toBe('');
  });
});

describe('groupWidths', () => {
  it('applies widths in order', () => {
    expect(groupWidths('378282246310005', [4, 6, 5], ' ')).toBe('3782 822463 10005');
    expect(groupWidths('37828', [4, 6, 5], ' ')).toBe('3782 8');
  });

  it('appends characters beyond the last width', () => {
    expect(groupWidths('3782822463100051', [4, 6, 5], ' ')).toBe('3782 822463 100051');
  });
});

describe('prepare', () => {
  it('upper-cases before filtering', () => {
    expect(prepare('1hgcm8', vin)).toBe('1HGCM8');
  });

  it('drops characters outside allowedChars', () => {
    expect(prepare('1HGC-M8', vin)).toBe('1HGCM8');
    expect(prepare('1HGCIOQ', vin)).toBe('1HGC');
  });

  it('removes separators when asked', () => {
    const iban: FieldDescriptor = { ...vin, allowedChars: '0-9A-Z ' };
    expect(prepare('AT61 1904', iban, { separators: ' ' })).toBe('AT611904');
  });

  it('truncates to maxSignificant', () => {
    expect(prepare('1HGCM82633A004352XYZ', vin, { maxSignificant: 17 })).toBe('1HGCM82633A004352');
  });

  it('leaves case alone when capitalization is none', () => {
    const host: FieldDescriptor = { ...vin, capitalization: 'none', allowedChars: null };
    expect(prepare('Example.COM', host)).toBe('Example.COM');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd js && npx vitest run test/partial.spec.ts`
Expected: FAIL — `Failed to resolve import "../src/common/partial"`.

- [ ] **Step 3: Create the descriptor types**

Create `js/src/common/field.ts`:

```ts
// Which on-screen keyboard a field should raise. Platform-neutral by design:
// the package has no DOM or framework dependency. See the README for the
// mapping to `inputmode` and to Flutter's TextInputType.
export type KeyboardType = 'text' | 'digits' | 'phone' | 'email' | 'url';

// How typed characters should be cased.
export type Capitalization = 'none' | 'characters' | 'words' | 'sentences';

// Platform autofill category. Only categories that exist on both the web and
// Flutter are listed; value types without a standard category (IBAN, VIN,
// IMEI, ICCID, MAC, license plate) carry a null autofill instead.
export type AutofillHint =
  | 'email'
  | 'telephoneNumber'
  | 'postalCode'
  | 'creditCardNumber'
  | 'url';

// The input characteristics of a field holding one kind of value. Obtained
// from any validator's fieldDescriptor, which takes the same options as its
// validate. Everything here is a hint for building an input field; none of it
// affects validation.
export interface FieldDescriptor {
  // Which on-screen keyboard the field should raise.
  readonly keyboard: KeyboardType;
  // Platform autofill category, or null when neither platform defines one.
  readonly autofill: AutofillHint | null;
  // How typed characters should be cased.
  readonly capitalization: Capitalization;
  // Maximum length of the FORMATTED text, separators included, or null when
  // the value has no useful hard bound.
  readonly maxLength: number | null;
  // A valid example value in formatted form, or null.
  readonly example: string | null;
  // Body of a regex character class listing the characters the field may
  // contain, e.g. `0-9A-Z `. Null means no filtering.
  readonly allowedChars: string | null;
}
```

- [ ] **Step 4: Create the pipeline helpers**

Create `js/src/common/partial.ts`:

```ts
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
```

- [ ] **Step 5: Export the public types**

In `js/src/index.ts`, add after the existing `export * from './common/types';` line:

```ts
export type { FieldDescriptor, KeyboardType, Capitalization, AutofillHint } from './common/field';
```

Do **not** export `./common/partial`.

- [ ] **Step 6: Run test to verify it passes**

Run: `cd js && npx vitest run test/partial.spec.ts`
Expected: PASS, 11 tests.

- [ ] **Step 7: Lint and type-check**

Run: `cd js && npm run lint && npx tsc --noEmit -p tsconfig.json`
Expected: no errors.

- [ ] **Step 8: Commit**

```bash
git add js/src/common/field.ts js/src/common/partial.ts js/src/index.ts js/test/partial.spec.ts
git commit -m "Add FieldDescriptor and partial-format helpers to the TS package"
```

---

### Task 3: Imei, Iccid and Vin + the shared vector harness

This task adds the first three validators *and* the vector harness both
languages use for the remaining nine. The three types are the simplest: no
grouping, so `formatPartial` is `prepare` alone.

**Files:**
- Modify: `lib/src/imei/imei.dart`, `lib/src/iccid/iccid.dart`, `lib/src/vin/vin.dart`
- Modify: `js/src/imei/index.ts`, `js/src/iccid/index.ts`, `js/src/vin/index.ts`
- Create: `test/vectors/field_descriptor.json`, `test/vectors/format_partial.json`
- Modify: `test/vectors_test.dart`
- Create: `js/test/field.conformance.spec.ts`

**Interfaces:**
- Consumes: `FieldDescriptor`, `KeyboardType`, `Capitalization`, `AutofillHint`, `prepare` (Tasks 1–2).
- Produces:
  - Dart: `Imei.fieldDescriptor({bool allowSv = false})`, `Imei.formatPartial(String input, {bool allowSv = false})`, `Iccid.fieldDescriptor()`, `Iccid.formatPartial(String)`, `Vin.fieldDescriptor()`, `Vin.formatPartial(String)`.
  - TS: the same names on the `Imei`, `Iccid` and `Vin` const objects, options-object style (`Imei.fieldDescriptor({ allowSv: true })`).
  - Vector format, consumed by every later task:
    - `field_descriptor.json`: array of `{ "type": string, "options": object, "keyboard": string, "autofill": string|null, "capitalization": string, "maxLength": number|null, "example": string|null, "allowedChars": string|null }`
    - `format_partial.json`: array of `{ "type": string, "options": object, "input": string, "output": string }`

- [ ] **Step 1: Write the failing vectors**

Create `test/vectors/field_descriptor.json`:

```json
[
  {
    "type": "imei",
    "options": {},
    "keyboard": "digits",
    "autofill": null,
    "capitalization": "none",
    "maxLength": 15,
    "example": "490154203237518",
    "allowedChars": "0-9"
  },
  {
    "type": "imei",
    "options": { "allowSv": true },
    "keyboard": "digits",
    "autofill": null,
    "capitalization": "none",
    "maxLength": 16,
    "example": "490154203237518",
    "allowedChars": "0-9"
  },
  {
    "type": "iccid",
    "options": {},
    "keyboard": "digits",
    "autofill": null,
    "capitalization": "none",
    "maxLength": 20,
    "example": "8949012345678901234",
    "allowedChars": "0-9"
  },
  {
    "type": "vin",
    "options": {},
    "keyboard": "text",
    "autofill": null,
    "capitalization": "characters",
    "maxLength": 17,
    "example": "1HGCM82633A004352",
    "allowedChars": "0-9A-HJ-NPR-Z"
  }
]
```

Create `test/vectors/format_partial.json`:

```json
[
  { "type": "imei", "options": {}, "input": "", "output": "" },
  { "type": "imei", "options": {}, "input": "4901 542", "output": "4901542" },
  { "type": "imei", "options": {}, "input": "49-01-54", "output": "490154" },
  { "type": "imei", "options": {}, "input": "490154203237518999", "output": "490154203237518" },
  { "type": "imei", "options": { "allowSv": true }, "input": "4901542032375189", "output": "4901542032375189" },
  { "type": "iccid", "options": {}, "input": "8949 0123", "output": "89490123" },
  { "type": "iccid", "options": {}, "input": "894901234567890123499", "output": "89490123456789012349" },
  { "type": "vin", "options": {}, "input": "1hgcm8", "output": "1HGCM8" },
  { "type": "vin", "options": {}, "input": "1hgc-m8", "output": "1HGCM8" },
  { "type": "vin", "options": {}, "input": "1hgcm82633a004352xx", "output": "1HGCM82633A004352" },
  { "type": "vin", "options": {}, "input": "iqo", "output": "" }
]
```

- [ ] **Step 2: Extend the Dart vector harness**

In `test/vectors_test.dart`, add these helpers above `void main()`:

```dart
String _descriptorField(FieldDescriptor d, String key) => switch (key) {
      'keyboard' => d.keyboard.name,
      'capitalization' => d.capitalization.name,
      _ => throw ArgumentError(key),
    };

FieldDescriptor _descriptorFor(String type, Map<String, Object?> o) =>
    switch (type) {
      'imei' => Imei.fieldDescriptor(allowSv: o['allowSv'] as bool? ?? false),
      'iccid' => Iccid.fieldDescriptor(),
      'vin' => Vin.fieldDescriptor(),
      _ => throw ArgumentError('unknown type $type'),
    };

String _partialFor(String type, String input, Map<String, Object?> o) =>
    switch (type) {
      'imei' =>
        Imei.formatPartial(input, allowSv: o['allowSv'] as bool? ?? false),
      'iccid' => Iccid.formatPartial(input),
      'vin' => Vin.formatPartial(input),
      _ => throw ArgumentError('unknown type $type'),
    };
```

and these two groups inside `main()`, after the existing `phone_global` group:

```dart
  group('field_descriptor', () {
    for (final c in _load('field_descriptor.json')) {
      final type = c['type']! as String;
      final options = (c['options'] as Map?)?.cast<String, Object?>() ?? {};
      test('field_descriptor $type ${jsonEncode(options)}', () {
        final d = _descriptorFor(type, options);
        expect(_descriptorField(d, 'keyboard'), c['keyboard']);
        expect(d.autofill?.name, c['autofill']);
        expect(_descriptorField(d, 'capitalization'), c['capitalization']);
        expect(d.maxLength, c['maxLength']);
        expect(d.example, c['example']);
        expect(d.allowedChars, c['allowedChars']);
      });
    }
  });

  group('format_partial', () {
    for (final c in _load('format_partial.json')) {
      final type = c['type']! as String;
      final input = c['input']! as String;
      final options = (c['options'] as Map?)?.cast<String, Object?>() ?? {};
      test('format_partial $type: "$input"', () {
        final once = _partialFor(type, input, options);
        expect(once, c['output']);
        // Idempotence, checked for every type on every vector: re-running
        // the formatter on its own output must change nothing, or a field
        // re-formatting on each keystroke would oscillate.
        expect(_partialFor(type, once, options), once,
            reason: '$type is not idempotent on "$once"');
      });
    }
  });
```

Every later task extends the two `switch` statements with its own case and
appends entries to the two JSON files. Nothing else in the harness changes.

- [ ] **Step 3: Run the Dart vectors to verify they fail**

Run: `dart test test/vectors_test.dart -n field_descriptor`
Expected: FAIL — `The method 'fieldDescriptor' isn't defined for the class 'Imei'`.

- [ ] **Step 4: Implement the three Dart validators**

In `lib/src/imei/imei.dart`, add the import and the two statics after `format`:

```dart
import '../common/field_descriptor.dart';
import '../common/partial_format.dart';
```

```dart
  /// Describes an IMEI input field. With [allowSv] the field accepts the
  /// 16-digit IMEISV form.
  static FieldDescriptor fieldDescriptor({bool allowSv = false}) =>
      FieldDescriptor(
        keyboard: KeyboardType.digits,
        maxLength: allowSv ? 16 : 15,
        example: '490154203237518',
        allowedChars: '0-9',
      );

  /// Formats partially typed [input] for display in a field: digits only,
  /// capped at 15 digits (16 with [allowSv]). Never throws.
  static String formatPartial(String input, {bool allowSv = false}) => prepare(
        input,
        fieldDescriptor(allowSv: allowSv),
        maxSignificant: allowSv ? 16 : 15,
      );
```

In `lib/src/iccid/iccid.dart`, same imports plus:

```dart
  /// Describes an ICCID input field.
  static FieldDescriptor fieldDescriptor() => const FieldDescriptor(
        keyboard: KeyboardType.digits,
        maxLength: 20,
        example: '8949012345678901234',
        allowedChars: '0-9',
      );

  /// Formats partially typed [input] for display in a field: digits only,
  /// capped at 20. Never throws.
  static String formatPartial(String input) =>
      prepare(input, fieldDescriptor(), maxSignificant: 20);
```

In `lib/src/vin/vin.dart`, same imports plus:

```dart
  /// Describes a VIN input field. `I`, `O` and `Q` are excluded from
  /// [FieldDescriptor.allowedChars]: ISO 3779 forbids them, so filtering
  /// them at the keyboard removes the most common VIN typo before
  /// validation runs.
  static FieldDescriptor fieldDescriptor() => const FieldDescriptor(
        keyboard: KeyboardType.text,
        capitalization: Capitalization.characters,
        maxLength: 17,
        example: '1HGCM82633A004352',
        allowedChars: '0-9A-HJ-NPR-Z',
      );

  /// Formats partially typed [input] for display in a field: upper-cased,
  /// forbidden characters dropped, capped at 17. Never throws.
  static String formatPartial(String input) =>
      prepare(input, fieldDescriptor(), maxSignificant: 17);
```

- [ ] **Step 5: Run the Dart vectors to verify they pass**

Run: `dart test test/vectors_test.dart && dart analyze`
Expected: PASS, `No issues found!`

- [ ] **Step 6: Write the failing TS conformance test**

Create `js/test/field.conformance.spec.ts`:

```ts
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import type { FieldDescriptor } from '../src/common/field';
import { Imei } from '../src/imei/index';
import { Iccid } from '../src/iccid/index';
import { Vin } from '../src/vin/index';

type Options = Record<string, unknown>;
type DescriptorVec = Options & { type: string; options?: Options };
type PartialVec = { type: string; options?: Options; input: string; output: string };

function load<T>(name: string): T[] {
  return JSON.parse(
    readFileSync(fileURLToPath(new URL(`../../test/vectors/${name}`, import.meta.url)), 'utf8'),
  );
}

function descriptorFor(type: string, o: Options): FieldDescriptor {
  switch (type) {
    case 'imei':
      return Imei.fieldDescriptor({ allowSv: (o.allowSv as boolean) ?? false });
    case 'iccid':
      return Iccid.fieldDescriptor();
    case 'vin':
      return Vin.fieldDescriptor();
    default:
      throw new Error(`unknown type ${type}`);
  }
}

function partialFor(type: string, input: string, o: Options): string {
  switch (type) {
    case 'imei':
      return Imei.formatPartial(input, { allowSv: (o.allowSv as boolean) ?? false });
    case 'iccid':
      return Iccid.formatPartial(input);
    case 'vin':
      return Vin.formatPartial(input);
    default:
      throw new Error(`unknown type ${type}`);
  }
}

describe('field descriptor conformance', () => {
  for (const v of load<DescriptorVec>('field_descriptor.json')) {
    it(`${v.type} ${JSON.stringify(v.options ?? {})}`, () => {
      const d = descriptorFor(v.type, v.options ?? {});
      expect(d.keyboard).toBe(v.keyboard);
      expect(d.autofill).toBe(v.autofill);
      expect(d.capitalization).toBe(v.capitalization);
      expect(d.maxLength).toBe(v.maxLength);
      expect(d.example).toBe(v.example);
      expect(d.allowedChars).toBe(v.allowedChars);
    });
  }
});

describe('format partial conformance', () => {
  for (const v of load<PartialVec>('format_partial.json')) {
    it(`${v.type}: "${v.input}"`, () => {
      const once = partialFor(v.type, v.input, v.options ?? {});
      expect(once).toBe(v.output);
      // Idempotence, checked for every type on every vector.
      expect(partialFor(v.type, once, v.options ?? {})).toBe(once);
    });
  }
});
```

Run: `cd js && npx vitest run test/field.conformance.spec.ts`
Expected: FAIL — `Imei.fieldDescriptor is not a function`.

- [ ] **Step 7: Implement the three TS validators**

In `js/src/imei/index.ts`, add the imports and functions, then extend the exported const:

```ts
import type { FieldDescriptor } from '../common/field';
import { prepare } from '../common/partial';
```

```ts
// Describes an IMEI input field. With allowSv the field accepts the 16-digit
// IMEISV form.
function fieldDescriptor(options: ImeiOptions = {}): FieldDescriptor {
  const allowSv = options.allowSv ?? false;
  return {
    keyboard: 'digits',
    autofill: null,
    capitalization: 'none',
    maxLength: allowSv ? 16 : 15,
    example: '490154203237518',
    allowedChars: '0-9',
  };
}

// Formats partially typed input for display in a field: digits only, capped
// at 15 digits (16 with allowSv). Never throws.
function formatPartial(input: string, options: ImeiOptions = {}): string {
  const allowSv = options.allowSv ?? false;
  return prepare(input, fieldDescriptor(options), { maxSignificant: allowSv ? 16 : 15 });
}

export const Imei = { isValid, validate, normalize, format, tryFormat, parse, fieldDescriptor, formatPartial };
```

In `js/src/iccid/index.ts`:

```ts
// Describes an ICCID input field.
function fieldDescriptor(): FieldDescriptor {
  return {
    keyboard: 'digits',
    autofill: null,
    capitalization: 'none',
    maxLength: 20,
    example: '8949012345678901234',
    allowedChars: '0-9',
  };
}

// Formats partially typed input: digits only, capped at 20. Never throws.
function formatPartial(input: string): string {
  return prepare(input, fieldDescriptor(), { maxSignificant: 20 });
}
```

In `js/src/vin/index.ts`:

```ts
// Describes a VIN input field. I, O and Q are excluded from allowedChars:
// ISO 3779 forbids them, so filtering them at the keyboard removes the most
// common VIN typo before validation runs.
function fieldDescriptor(): FieldDescriptor {
  return {
    keyboard: 'text',
    autofill: null,
    capitalization: 'characters',
    maxLength: 17,
    example: '1HGCM82633A004352',
    allowedChars: '0-9A-HJ-NPR-Z',
  };
}

// Formats partially typed input: upper-cased, forbidden characters dropped,
// capped at 17. Never throws.
function formatPartial(input: string): string {
  return prepare(input, fieldDescriptor(), { maxSignificant: 17 });
}
```

Add `fieldDescriptor, formatPartial` to each module's exported const, matching the `Imei` line above.

- [ ] **Step 8: Run both suites**

Run: `dart test && cd js && npm test && npm run lint`
Expected: all green.

- [ ] **Step 9: Commit**

```bash
git add lib/src/imei lib/src/iccid lib/src/vin js/src/imei js/src/iccid js/src/vin test/vectors test/vectors_test.dart js/test/field.conformance.spec.ts
git commit -m "Add field descriptors and formatPartial for IMEI, ICCID and VIN"
```

---

### Task 4: Iban

**Files:**
- Modify: `lib/src/iban/iban.dart`, `js/src/iban/index.ts`
- Modify: `test/vectors/field_descriptor.json`, `test/vectors/format_partial.json`, `test/vectors_test.dart`, `js/test/field.conformance.spec.ts`

**Interfaces:**
- Consumes: `IbanCountry.of(String iso2)` → `IbanCountry?` with fields `length` (int) and `example` (String, already 4-grouped); `prepare`, `groupEvery`.
- Produces: `Iban.fieldDescriptor({String? country})`, `Iban.formatPartial(String input, {String? country})`; TS `Iban.fieldDescriptor({ country })`, `Iban.formatPartial(input, { country })`.

Without a country the descriptor is generic: `maxLength` and `example` null,
34 significant characters allowed (the ISO 13616 maximum). With an unknown
country, the same generic descriptor — a descriptor is a UI hint, and throwing
over an unknown country would take a text field down.

- [ ] **Step 1: Add the failing vectors**

Append to `test/vectors/field_descriptor.json`:

```json
  {
    "type": "iban",
    "options": {},
    "keyboard": "text",
    "autofill": null,
    "capitalization": "characters",
    "maxLength": null,
    "example": null,
    "allowedChars": "0-9A-Z "
  },
  {
    "type": "iban",
    "options": { "country": "AT" },
    "keyboard": "text",
    "autofill": null,
    "capitalization": "characters",
    "maxLength": 24,
    "example": "AT61 1904 3002 3457 3201",
    "allowedChars": "0-9A-Z "
  },
  {
    "type": "iban",
    "options": { "country": "ZZ" },
    "keyboard": "text",
    "autofill": null,
    "capitalization": "characters",
    "maxLength": null,
    "example": null,
    "allowedChars": "0-9A-Z "
  }
```

Append to `test/vectors/format_partial.json`:

```json
  { "type": "iban", "options": { "country": "AT" }, "input": "a", "output": "A" },
  { "type": "iban", "options": { "country": "AT" }, "input": "at61", "output": "AT61" },
  { "type": "iban", "options": { "country": "AT" }, "input": "at611", "output": "AT61 1" },
  { "type": "iban", "options": { "country": "AT" }, "input": "AT61 1904", "output": "AT61 1904" },
  { "type": "iban", "options": { "country": "AT" }, "input": "at61190a", "output": "AT61 190A" },
  { "type": "iban", "options": { "country": "AT" }, "input": "AT611904300234573201999", "output": "AT61 1904 3002 3457 3201" },
  { "type": "iban", "options": {}, "input": "at61190", "output": "AT61 190" }
```

Note the AT truncation case: 20 significant characters is the AT length, so
the three extra digits are dropped *before* grouping and the result is exactly
24 characters with no dangling separator.

- [ ] **Step 2: Extend both harness dispatchers**

Dart, in `_descriptorFor`: `'iban' => Iban.fieldDescriptor(country: o['country'] as String?),`
Dart, in `_partialFor`: `'iban' => Iban.formatPartial(input, country: o['country'] as String?),`

TS, in `descriptorFor`: `case 'iban': return Iban.fieldDescriptor({ country: o.country as string | undefined });`
TS, in `partialFor`: `case 'iban': return Iban.formatPartial(input, { country: o.country as string | undefined });`

Add `import { Iban } from '../src/iban/index';` to the TS spec.

- [ ] **Step 3: Run to verify failure**

Run: `dart test test/vectors_test.dart -n iban`
Expected: FAIL — `The method 'fieldDescriptor' isn't defined for the class 'Iban'`.

- [ ] **Step 4: Implement in Dart**

In `lib/src/iban/iban.dart` add the imports (`../common/field_descriptor.dart`, `../common/partial_format.dart`, `iban_country.dart` if not already imported) and:

```dart
  /// Describes an IBAN input field. With [country] the descriptor is exact
  /// (length and example for that country); without it, or for a country
  /// with no bundled metadata, it is generic.
  static FieldDescriptor fieldDescriptor({String? country}) {
    final c = country == null ? null : IbanCountry.of(country);
    return FieldDescriptor(
      keyboard: KeyboardType.text,
      capitalization: Capitalization.characters,
      maxLength: c == null ? null : c.length + (c.length - 1) ~/ 4,
      example: c?.example,
      allowedChars: '0-9A-Z ',
    );
  }

  /// Formats partially typed [input] in groups of four, upper-cased, capped
  /// at [country]'s IBAN length (34, the ISO 13616 maximum, without one).
  /// Never throws.
  static String formatPartial(String input, {String? country}) {
    final c = country == null ? null : IbanCountry.of(country);
    final s = prepare(
      input,
      fieldDescriptor(country: country),
      separators: ' ',
      maxSignificant: c?.length ?? 34,
    );
    return groupEvery(s, 4, ' ');
  }
```

- [ ] **Step 5: Implement in TypeScript**

In `js/src/iban/index.ts`:

```ts
// Describes an IBAN input field. With country the descriptor is exact
// (length and example for that country); without it, or for a country with
// no bundled metadata, it is generic.
function fieldDescriptor(options: IbanOptions = {}): FieldDescriptor {
  const c = options.country === undefined ? null : IbanCountry.of(options.country);
  return {
    keyboard: 'text',
    autofill: null,
    capitalization: 'characters',
    maxLength: c === null ? null : c.length + Math.floor((c.length - 1) / 4),
    example: c === null ? null : c.example,
    allowedChars: '0-9A-Z ',
  };
}

// Formats partially typed input in groups of four, upper-cased, capped at
// the country's IBAN length (34 without one). Never throws.
function formatPartial(input: string, options: IbanOptions = {}): string {
  const c = options.country === undefined ? null : IbanCountry.of(options.country);
  const s = prepare(input, fieldDescriptor(options), {
    separators: ' ',
    maxSignificant: c === null ? 34 : c.length,
  });
  return groupEvery(s, 4, ' ');
}
```

`js/src/iban/index.ts` has no options interface today (every function takes a
bare `input`), so declare `export interface IbanOptions { country?: string }`
next to these two functions and leave every existing signature alone. Import
`IbanCountry` from `./country` — it is the const `{ of, values }` at
`js/src/iban/country.ts:66`, and `of` returns `IbanCountry | null` — and
`prepare`/`groupEvery` from `../common/partial`.

- [ ] **Step 6: Run both suites**

Run: `dart test && dart analyze && cd js && npm test && npm run lint`
Expected: all green.

- [ ] **Step 7: Commit**

```bash
git add lib/src/iban js/src/iban test/vectors test/vectors_test.dart js/test/field.conformance.spec.ts
git commit -m "Add field descriptor and formatPartial for IBAN"
```

---

### Task 5: CreditCard

**Files:**
- Modify: `lib/src/credit_card/credit_card.dart`, `js/src/credit-card/index.ts`
- Modify: the two vector files and both harness dispatchers.

**Interfaces:**
- Consumes: `CreditCard.network(String)` → `CardNetwork?` (prefix-based, works on partial input); `prepare`, `groupEvery`, `groupWidths`.
- Produces: `CreditCard.fieldDescriptor()`, `CreditCard.formatPartial(String)`; same two names on the TS `CreditCard` const.

`maxLength` is 23: the module accepts PANs up to 19 digits, grouped `4-4-4-4-3`.
Amex truncates to 15 significant digits instead of 19, so a long paste never
lands leftover digits after the `4-6-5` groups.

- [ ] **Step 1: Add the failing vectors**

Append to `test/vectors/field_descriptor.json`:

```json
  {
    "type": "credit_card",
    "options": {},
    "keyboard": "digits",
    "autofill": "creditCardNumber",
    "capitalization": "none",
    "maxLength": 23,
    "example": "4242 4242 4242 4242",
    "allowedChars": "0-9 "
  }
```

Append to `test/vectors/format_partial.json`:

```json
  { "type": "credit_card", "options": {}, "input": "4242", "output": "4242" },
  { "type": "credit_card", "options": {}, "input": "42424", "output": "4242 4" },
  { "type": "credit_card", "options": {}, "input": "4242424242424242", "output": "4242 4242 4242 4242" },
  { "type": "credit_card", "options": {}, "input": "3782", "output": "3782" },
  { "type": "credit_card", "options": {}, "input": "378282", "output": "3782 82" },
  { "type": "credit_card", "options": {}, "input": "378282246310005", "output": "3782 822463 10005" },
  { "type": "credit_card", "options": {}, "input": "3782 8224 6310 005", "output": "3782 822463 10005" },
  { "type": "credit_card", "options": {}, "input": "37828224631000599", "output": "3782 822463 10005" },
  { "type": "credit_card", "options": {}, "input": "4242-4242", "output": "4242 4242" }
```

The `4242-4242` case matters: `-` is not in `allowedChars`, so it is dropped
by the filter, not treated as a separator.

- [ ] **Step 2: Extend both dispatchers**

Dart: `'credit_card' => CreditCard.fieldDescriptor(),` and `'credit_card' => CreditCard.formatPartial(input),`
TS: `case 'credit_card': return CreditCard.fieldDescriptor();` and `case 'credit_card': return CreditCard.formatPartial(input);` plus the import.

- [ ] **Step 3: Run to verify failure**

Run: `dart test test/vectors_test.dart -n credit_card`
Expected: FAIL — `The method 'fieldDescriptor' isn't defined for the class 'CreditCard'`.

- [ ] **Step 4: Implement in Dart**

```dart
  /// Describes a payment-card input field. [FieldDescriptor.maxLength] is 23:
  /// 19 digits (the ISO/IEC 7812 maximum this module accepts) plus the four
  /// separators [format] inserts.
  static FieldDescriptor fieldDescriptor() => const FieldDescriptor(
        keyboard: KeyboardType.digits,
        autofill: AutofillHint.creditCardNumber,
        maxLength: 23,
        example: '4242 4242 4242 4242',
        allowedChars: '0-9 ',
      );

  /// Formats partially typed [input] the way [format] would: `4-6-5` once the
  /// prefix identifies Amex, otherwise groups of four. Never throws.
  static String formatPartial(String input) {
    var s = prepare(input, fieldDescriptor(),
        separators: ' ', maxSignificant: 19);
    if (network(s) == CardNetwork.amex) {
      if (s.length > 15) s = s.substring(0, 15);
      return groupWidths(s, const [4, 6, 5], ' ');
    }
    return groupEvery(s, 4, ' ');
  }
```

- [ ] **Step 5: Implement in TypeScript**

```ts
// Describes a payment-card input field. maxLength is 23: 19 digits (the
// ISO/IEC 7812 maximum this module accepts) plus the four separators format
// inserts.
function fieldDescriptor(): FieldDescriptor {
  return {
    keyboard: 'digits',
    autofill: 'creditCardNumber',
    capitalization: 'none',
    maxLength: 23,
    example: '4242 4242 4242 4242',
    allowedChars: '0-9 ',
  };
}

// Formats partially typed input the way format would: 4-6-5 once the prefix
// identifies Amex, otherwise groups of four. Never throws.
function formatPartial(input: string): string {
  let s = prepare(input, fieldDescriptor(), { separators: ' ', maxSignificant: 19 });
  if (network(s) === 'amex') {
    if (s.length > 15) s = s.substring(0, 15);
    return groupWidths(s, [4, 6, 5], ' ');
  }
  return groupEvery(s, 4, ' ');
}
```

`CardNetwork` is the string-literal union
`'visa' | 'mastercard' | 'amex' | 'discover' | 'unknown'`, so `=== 'amex'` is
correct, and `network` here is the module-local function (`js/src/credit-card/index.ts:21`),
not the member on the exported const.

- [ ] **Step 6: Run both suites**

Run: `dart test && dart analyze && cd js && npm test && npm run lint`
Expected: all green.

- [ ] **Step 7: Commit**

```bash
git add lib/src/credit_card js/src/credit-card test/vectors test/vectors_test.dart js/test/field.conformance.spec.ts
git commit -m "Add field descriptor and formatPartial for credit cards"
```

---

### Task 6: MacAddress

**Files:**
- Modify: `lib/src/mac_address/mac_address.dart`, `js/src/mac-address/index.ts`
- Modify: the two vector files and both harness dispatchers.

**Interfaces:**
- Consumes: `MacNotation` (`colon`, `hyphen`, `dot`, `bare`), `MacAddress.format(input, {notation, upperCase})`; `prepare`, `groupEvery`.
- Produces: `MacAddress.fieldDescriptor({MacNotation notation = MacNotation.colon, bool upperCase = false})`, `MacAddress.formatPartial(String input, {MacNotation notation = MacNotation.colon, bool upperCase = false})`.

Two module facts drive this task: `format` defaults to **lower-case**, and
`dot` notation groups in **fours**, not twos. The module also accepts EUI-64
(16 hex characters), so every bound is computed for 16, not 12.

`capitalization` describes the keyboard only. `formatPartial` additionally
normalises hex case to whatever `format` produces, which is lower-case unless
`upperCase` is set — otherwise the agreement guarantee would fail.

- [ ] **Step 1: Add the failing vectors**

Append to `test/vectors/field_descriptor.json`:

```json
  {
    "type": "mac_address",
    "options": {},
    "keyboard": "text",
    "autofill": null,
    "capitalization": "none",
    "maxLength": 23,
    "example": "aa:bb:cc:dd:ee:ff",
    "allowedChars": "0-9A-Fa-f:"
  },
  {
    "type": "mac_address",
    "options": { "notation": "hyphen", "upperCase": true },
    "keyboard": "text",
    "autofill": null,
    "capitalization": "characters",
    "maxLength": 23,
    "example": "AA-BB-CC-DD-EE-FF",
    "allowedChars": "0-9A-Fa-f-"
  },
  {
    "type": "mac_address",
    "options": { "notation": "dot" },
    "keyboard": "text",
    "autofill": null,
    "capitalization": "none",
    "maxLength": 19,
    "example": "aabb.ccdd.eeff",
    "allowedChars": "0-9A-Fa-f."
  },
  {
    "type": "mac_address",
    "options": { "notation": "bare" },
    "keyboard": "text",
    "autofill": null,
    "capitalization": "none",
    "maxLength": 16,
    "example": "aabbccddeeff",
    "allowedChars": "0-9A-Fa-f"
  }
```

Append to `test/vectors/format_partial.json`:

```json
  { "type": "mac_address", "options": {}, "input": "aabbcc", "output": "aa:bb:cc" },
  { "type": "mac_address", "options": {}, "input": "AABBC", "output": "aa:bb:c" },
  { "type": "mac_address", "options": {}, "input": "aa:bb:cc:dd:ee:ff", "output": "aa:bb:cc:dd:ee:ff" },
  { "type": "mac_address", "options": {}, "input": "zzaabb", "output": "aa:bb" },
  { "type": "mac_address", "options": { "upperCase": true }, "input": "aabbcc", "output": "AA:BB:CC" },
  { "type": "mac_address", "options": { "notation": "hyphen" }, "input": "aabbcc", "output": "aa-bb-cc" },
  { "type": "mac_address", "options": { "notation": "dot" }, "input": "aabbcc", "output": "aabb.cc" },
  { "type": "mac_address", "options": { "notation": "bare" }, "input": "aabbcc", "output": "aabbcc" },
  { "type": "mac_address", "options": {}, "input": "aabbccddeeffaabbccdd", "output": "aa:bb:cc:dd:ee:ff:aa:bb" }
```

- [ ] **Step 2: Extend both dispatchers**

Dart `_descriptorFor`:
```dart
      'mac_address' => MacAddress.fieldDescriptor(
          notation: _notation(o['notation'] as String?),
          upperCase: o['upperCase'] as bool? ?? false,
        ),
```
Dart `_partialFor`:
```dart
      'mac_address' => MacAddress.formatPartial(
          input,
          notation: _notation(o['notation'] as String?),
          upperCase: o['upperCase'] as bool? ?? false,
        ),
```
`_notation` already exists in the harness.

TS: `case 'mac_address': return MacAddress.fieldDescriptor({ notation: (o.notation as MacNotation) ?? 'colon', upperCase: (o.upperCase as boolean) ?? false });` and the analogous `formatPartial` case, plus the imports.

- [ ] **Step 3: Run to verify failure**

Run: `dart test test/vectors_test.dart -n mac_address`
Expected: FAIL — `The method 'fieldDescriptor' isn't defined for the class 'MacAddress'`.

- [ ] **Step 4: Implement in Dart**

```dart
  /// Describes a MAC-address input field for the given [notation] and case.
  ///
  /// Every bound covers EUI-64 (16 hex characters), the longer of the two
  /// families this module accepts. [FieldDescriptor.capitalization] describes
  /// the keyboard; [formatPartial] additionally normalises hex case to match
  /// [format], which is lower-case unless [upperCase] is set.
  static FieldDescriptor fieldDescriptor({
    MacNotation notation = MacNotation.colon,
    bool upperCase = false,
  }) {
    final (int max, String chars) = switch (notation) {
      MacNotation.colon => (23, '0-9A-Fa-f:'),
      MacNotation.hyphen => (23, '0-9A-Fa-f-'),
      MacNotation.dot => (19, '0-9A-Fa-f.'),
      MacNotation.bare => (16, '0-9A-Fa-f'),
    };
    return FieldDescriptor(
      keyboard: KeyboardType.text,
      capitalization:
          upperCase ? Capitalization.characters : Capitalization.none,
      maxLength: max,
      example: format('aabbccddeeff', notation: notation, upperCase: upperCase),
      allowedChars: chars,
    );
  }

  /// Formats partially typed [input] in [notation]: hex characters only,
  /// separators re-inserted, capped at 16 hex characters. Never throws.
  static String formatPartial(
    String input, {
    MacNotation notation = MacNotation.colon,
    bool upperCase = false,
  }) {
    final d = fieldDescriptor(notation: notation, upperCase: upperCase);
    var s = prepare(input, d, separators: ':.-', maxSignificant: 16);
    s = upperCase ? s.toUpperCase() : s.toLowerCase();
    return switch (notation) {
      MacNotation.colon => groupEvery(s, 2, ':'),
      MacNotation.hyphen => groupEvery(s, 2, '-'),
      MacNotation.dot => groupEvery(s, 4, '.'),
      MacNotation.bare => s,
    };
  }
```

- [ ] **Step 5: Implement in TypeScript**

```ts
// Describes a MAC-address input field for the given notation and case.
// Every bound covers EUI-64 (16 hex characters). capitalization describes the
// keyboard; formatPartial additionally normalises hex case to match format,
// which is lower-case unless upperCase is set.
function fieldDescriptor(options: MacFormatOptions = {}): FieldDescriptor {
  const notation = options.notation ?? 'colon';
  const upperCase = options.upperCase ?? false;
  const bounds: Record<MacNotation, [number, string]> = {
    colon: [23, '0-9A-Fa-f:'],
    hyphen: [23, '0-9A-Fa-f-'],
    dot: [19, '0-9A-Fa-f.'],
    bare: [16, '0-9A-Fa-f'],
  };
  const [maxLength, allowedChars] = bounds[notation];
  return {
    keyboard: 'text',
    autofill: null,
    capitalization: upperCase ? 'characters' : 'none',
    maxLength,
    example: format('aabbccddeeff', { notation, upperCase }),
    allowedChars,
  };
}

// Formats partially typed input in the given notation: hex only, separators
// re-inserted, capped at 16 hex characters. Never throws.
function formatPartial(input: string, options: MacFormatOptions = {}): string {
  const notation = options.notation ?? 'colon';
  const upperCase = options.upperCase ?? false;
  let s = prepare(input, fieldDescriptor(options), { separators: ':.-', maxSignificant: 16 });
  s = upperCase ? s.toUpperCase() : s.toLowerCase();
  switch (notation) {
    case 'colon':
      return groupEvery(s, 2, ':');
    case 'hyphen':
      return groupEvery(s, 2, '-');
    case 'dot':
      return groupEvery(s, 4, '.');
    case 'bare':
      return s;
  }
}
```

- [ ] **Step 6: Run both suites**

Run: `dart test && dart analyze && cd js && npm test && npm run lint`
Expected: all green.

- [ ] **Step 7: Commit**

```bash
git add lib/src/mac_address js/src/mac-address test/vectors test/vectors_test.dart js/test/field.conformance.spec.ts
git commit -m "Add field descriptor and formatPartial for MAC addresses"
```

---

### Task 7: Postal metadata generator + PostalCode

**Files:**
- Modify: `tool/gen_postal_metadata.py`
- Regenerate: `lib/src/postal_code/postal_metadata.g.dart`, `js/src/data/postal-metadata.json`
- Modify: `lib/src/postal_code/postal_pattern.dart`, `lib/src/postal_code/postal_code.dart`
- Modify: `js/src/postal-code/metadata.ts` (if it declares the `PostalPattern` shape), `js/src/postal-code/index.ts`
- Modify: the two vector files and both harness dispatchers.

**Interfaces:**
- Consumes: `kPostalPatterns` (country → `PostalPattern`), `PostalPattern.pattern`, `PostalPattern.format`.
- Produces:
  - `PostalPattern` gains `final String? example` and `final String charset` (values `'digits'` or `'alnum'`), both after the existing positional parameters: `const PostalPattern(this.pattern, this.format, [this.example, this.charset = 'digits'])`.
  - `PostalCode.fieldDescriptor({String? country})`, `PostalCode.formatPartial(String input, {String? country})`.

`charset` is derived mechanically from the pattern, so it covers all 51
countries. `example` is curated and stays null elsewhere — an invented postal
code is worse than none. `maxLength` is the example's length, which for every
curated country is the longest canonical form (GB's `SW1A 1AA` at 8 is the UK
maximum).

- [ ] **Step 1: Extend the generator**

In `tool/gen_postal_metadata.py`, add an `example` key to these entries in the
`patterns` dict, leaving every other country's entry unchanged:

```python
"AT": {"pattern": r"^\d{4}$", "format": "", "example": "1010"},
"BE": {"pattern": r"^\d{4}$", "format": "", "example": "1000"},
"CH": {"pattern": r"^\d{4}$", "format": "", "example": "8001"},
"CZ": {"pattern": r"^\d{3} \d{2}$", "format": "3: ", "example": "110 00"},
"DE": {"pattern": r"^\d{5}$", "format": "", "example": "10115"},
"DK": {"pattern": r"^\d{4}$", "format": "", "example": "1050"},
"ES": {"pattern": r"^\d{5}$", "format": "", "example": "28001"},
"FI": {"pattern": r"^\d{5}$", "format": "", "example": "00100"},
"FR": {"pattern": r"^\d{5}$", "format": "", "example": "75008"},
"GB": {"pattern": r"^(?:GIR|[A-Z]{1,2}\d[A-Z0-9]?) \d[ABD-HJLN-UW-Z]{2}$", "format": "U", "example": "SW1A 1AA"},
"GR": {"pattern": r"^\d{3} \d{2}$", "format": "3: ", "example": "104 31"},
"HR": {"pattern": r"^\d{5}$", "format": "", "example": "10000"},
"HU": {"pattern": r"^\d{4}$", "format": "", "example": "1011"},
"IE": {"pattern": r"^[0-9A-Z]{3} [0-9A-Z]{4}$", "format": "3: ", "example": "D02 AF30"},
"IT": {"pattern": r"^\d{5}$", "format": "", "example": "00184"},
"NL": {"pattern": r"^[1-9]\d{3} (?:[A-RT-Z][A-Z]|S[BCE-RT-Z])$", "format": "4: ", "example": "1234 AB"},
"NO": {"pattern": r"^\d{4}$", "format": "", "example": "0010"},
"PL": {"pattern": r"^\d{2}-\d{3}$", "format": "2:-", "example": "00-950"},
"PT": {"pattern": r"^\d{4}-\d{3}$", "format": "4:-", "example": "1000-001"},
"SE": {"pattern": r"^\d{5}$", "format": "", "example": "11120"},
"SI": {"pattern": r"^\d{4}$", "format": "", "example": "1000"},
"SK": {"pattern": r"^\d{3} \d{2}$", "format": "3: ", "example": "811 01"},
"TR": {"pattern": r"^\d{5}$", "format": "", "example": "34000"},
```

Copy each existing `pattern` verbatim from the file rather than retyping it —
the values above are quoted from the current file, but the file is the truth.

Add the charset derivation and emit both new fields. Below the existing
`dart_str` helper:

```python
def charset_of(pattern: str) -> str:
    """'digits' when the pattern can only match digits and separators."""
    stripped = re.sub(r"\\d|\{\d+(,\d+)?\}|[\^\$\(\)\?\:\|]", "", pattern)
    return "alnum" if re.search(r"[A-Za-z]", stripped) else "digits"
```

In `self_check()`, after the existing format validation, add:

```python
        example = meta.get("example")
        if example is not None and not re.match(meta["pattern"], example):
            raise ValueError(f"{cc}: example {example!r} does not match its pattern")
```

In `main()`, replace the Dart emission line with:

```python
        example = meta.get("example")
        example_lit = dart_str(example) if example is not None else "null"
        buf.append(
            f"  '{cc}': PostalPattern({dart_str(meta['pattern'])}, "
            f"{dart_str(meta['format'])}, {example_lit}, "
            f"{dart_str(charset_of(meta['pattern']))}),\n"
        )
```

and, before the JSON dump, materialise the derived field so both outputs agree:

```python
    for cc, meta in patterns.items():
        meta.setdefault("example", None)
        meta["charset"] = charset_of(meta["pattern"])
```

- [ ] **Step 2: Widen `PostalPattern` and regenerate**

In `lib/src/postal_code/postal_pattern.dart`:

```dart
  /// Creates a postal pattern from its [pattern], [format] rule, optional
  /// [example] and [charset].
  const PostalPattern(this.pattern, this.format,
      [this.example, this.charset = 'digits']);

  /// A real postal code of this country in canonical form, or null when no
  /// verified example is on hand. Never invented.
  final String? example;

  /// `'digits'` when the code can only contain digits and separators,
  /// `'alnum'` when letters are possible.
  final String charset;
```

Then run: `python3 tool/gen_postal_metadata.py`
Expected: `Wrote …/postal_metadata.g.dart and …/postal-metadata.json: 51 countries`

Mirror the two new fields in the TS `PostalPattern` type (in
`js/src/postal-code/metadata.ts` — read it first; if the type is inferred from
the JSON import, only the interface needs `example: string | null; charset: string`).

- [ ] **Step 3: Add the failing vectors**

Append to `test/vectors/field_descriptor.json`:

```json
  {
    "type": "postal_code",
    "options": {},
    "keyboard": "text",
    "autofill": "postalCode",
    "capitalization": "characters",
    "maxLength": null,
    "example": null,
    "allowedChars": "0-9A-Z -"
  },
  {
    "type": "postal_code",
    "options": { "country": "DE" },
    "keyboard": "digits",
    "autofill": "postalCode",
    "capitalization": "none",
    "maxLength": 5,
    "example": "10115",
    "allowedChars": "0-9"
  },
  {
    "type": "postal_code",
    "options": { "country": "NL" },
    "keyboard": "text",
    "autofill": "postalCode",
    "capitalization": "characters",
    "maxLength": 7,
    "example": "1234 AB",
    "allowedChars": "0-9A-Z "
  },
  {
    "type": "postal_code",
    "options": { "country": "PL" },
    "keyboard": "digits",
    "autofill": "postalCode",
    "capitalization": "none",
    "maxLength": 6,
    "example": "00-950",
    "allowedChars": "0-9-"
  },
  {
    "type": "postal_code",
    "options": { "country": "GB" },
    "keyboard": "text",
    "autofill": "postalCode",
    "capitalization": "characters",
    "maxLength": 8,
    "example": "SW1A 1AA",
    "allowedChars": "0-9A-Z "
  }
```

Append to `test/vectors/format_partial.json`:

```json
  { "type": "postal_code", "options": { "country": "DE" }, "input": "101", "output": "101" },
  { "type": "postal_code", "options": { "country": "DE" }, "input": "10115", "output": "10115" },
  { "type": "postal_code", "options": { "country": "DE" }, "input": "10115999", "output": "10115" },
  { "type": "postal_code", "options": { "country": "PL" }, "input": "009", "output": "00-9" },
  { "type": "postal_code", "options": { "country": "PL" }, "input": "00950", "output": "00-950" },
  { "type": "postal_code", "options": { "country": "NL" }, "input": "1234ab", "output": "1234 AB" },
  { "type": "postal_code", "options": { "country": "NL" }, "input": "123", "output": "123" },
  { "type": "postal_code", "options": { "country": "GB" }, "input": "sw1a", "output": "SW1A" },
  { "type": "postal_code", "options": { "country": "GB" }, "input": "sw1a1aa", "output": "SW1A 1AA" }
```

The two GB cases are the point of the snap-on-valid rule: `SW1A` stays plain
because the UK separator sits three characters from the *end*, which is unknown
until the code is complete.

- [ ] **Step 4: Extend both dispatchers, run to verify failure**

Dart: `'postal_code' => PostalCode.fieldDescriptor(country: o['country'] as String?),` and the `formatPartial` twin.
TS: the analogous cases plus the import.

Run: `dart test test/vectors_test.dart -n postal_code`
Expected: FAIL — `The method 'fieldDescriptor' isn't defined for the class 'PostalCode'`.

- [ ] **Step 5: Implement in Dart**

```dart
  /// The separator this country's canonical form inserts, or `''` when it
  /// has none.
  static String _separatorOf(PostalPattern meta) {
    if (meta.format.isEmpty) return '';
    if (meta.format == 'U') return ' ';
    return meta.format.split(':')[1];
  }

  /// Describes a postal-code input field. Without [country] — or for a
  /// country with no curated pattern — the descriptor is generic and
  /// noticeably weaker than the country-specific one: pass a country
  /// whenever you have one.
  static FieldDescriptor fieldDescriptor({String? country}) {
    final meta = country == null ? null : kPostalPatterns[country.toUpperCase()];
    if (meta == null) {
      return const FieldDescriptor(
        keyboard: KeyboardType.text,
        autofill: AutofillHint.postalCode,
        capitalization: Capitalization.characters,
        allowedChars: '0-9A-Z -',
      );
    }
    final digitsOnly = meta.charset == 'digits';
    return FieldDescriptor(
      keyboard: digitsOnly ? KeyboardType.digits : KeyboardType.text,
      autofill: AutofillHint.postalCode,
      capitalization:
          digitsOnly ? Capitalization.none : Capitalization.characters,
      maxLength: meta.example?.length,
      example: meta.example,
      allowedChars:
          '${digitsOnly ? '0-9' : '0-9A-Z'}${_separatorOf(meta)}',
    );
  }

  /// Formats partially typed [input] for [country]. Fixed-offset spacing
  /// rules are applied as soon as enough characters exist; the UK-style rule,
  /// whose separator is positioned from the end, is applied only once the
  /// value is valid. Never throws.
  static String formatPartial(String input, {String? country}) {
    final meta = country == null ? null : kPostalPatterns[country.toUpperCase()];
    final d = fieldDescriptor(country: country);
    final sep = meta == null ? ' -' : _separatorOf(meta);
    final s = prepare(input, d,
        separators: sep.isEmpty ? null : sep,
        maxSignificant: meta?.example == null
            ? null
            : meta!.example!.length - _separatorOf(meta).length);
    if (meta == null) return s;
    if (meta.format == 'U') {
      final snapped = tryFormat(s, country: country!);
      return snapped ?? s;
    }
    if (meta.format.isEmpty) return s;
    final parts = meta.format.split(':');
    final n = int.parse(parts[0]);
    if (s.length <= n) return s;
    return '${s.substring(0, n)}${parts[1]}${s.substring(n)}';
  }
```

Note the `maxSignificant` arithmetic: the example's length minus its separator
gives the significant-character count (DE 5, PL 5, NL 6, GB 7).

- [ ] **Step 6: Implement in TypeScript**

Mirror the Dart implementation exactly, using the module's existing
`kPostalPatterns` import and `PostalOptions`:

```ts
function separatorOf(meta: PostalPattern): string {
  if (meta.format.length === 0) return '';
  if (meta.format === 'U') return ' ';
  return meta.format.split(':')[1];
}

// Describes a postal-code input field. Without a country — or for a country
// with no curated pattern — the descriptor is generic and noticeably weaker
// than the country-specific one: pass a country whenever you have one.
function fieldDescriptor(options: PostalOptions = {}): FieldDescriptor {
  const meta = options.country === undefined ? undefined : kPostalPatterns[options.country.toUpperCase()];
  if (meta === undefined) {
    return {
      keyboard: 'text',
      autofill: 'postalCode',
      capitalization: 'characters',
      maxLength: null,
      example: null,
      allowedChars: '0-9A-Z -',
    };
  }
  const digitsOnly = meta.charset === 'digits';
  return {
    keyboard: digitsOnly ? 'digits' : 'text',
    autofill: 'postalCode',
    capitalization: digitsOnly ? 'none' : 'characters',
    maxLength: meta.example === null ? null : meta.example.length,
    example: meta.example,
    allowedChars: `${digitsOnly ? '0-9' : '0-9A-Z'}${separatorOf(meta)}`,
  };
}

// Formats partially typed input for a country. Fixed-offset spacing rules are
// applied as soon as enough characters exist; the UK-style rule, whose
// separator is positioned from the end, is applied only once the value is
// valid. Never throws.
function formatPartial(input: string, options: PostalOptions = {}): string {
  const meta = options.country === undefined ? undefined : kPostalPatterns[options.country.toUpperCase()];
  const d = fieldDescriptor(options);
  const sep = meta === undefined ? ' -' : separatorOf(meta);
  const maxSignificant =
    meta === undefined || meta.example === null ? undefined : meta.example.length - separatorOf(meta).length;
  const s = prepare(input, d, { separators: sep.length === 0 ? undefined : sep, maxSignificant });
  if (meta === undefined) return s;
  if (meta.format === 'U') return tryFormat(s, { country: options.country! }) ?? s;
  if (meta.format.length === 0) return s;
  const [nRaw, char] = meta.format.split(':');
  const n = Number(nRaw);
  if (s.length <= n) return s;
  return `${s.substring(0, n)}${char}${s.substring(n)}`;
}
```

- [ ] **Step 7: Run both suites**

Run: `dart test && dart analyze && cd js && npm test && npm run lint`
Expected: all green, including the pre-existing `postal_code` and `data.spec.ts` groups — a regression there means the regenerated metadata changed something it should not have.

- [ ] **Step 8: Commit**

```bash
git add tool/gen_postal_metadata.py lib/src/postal_code js/src/postal-code js/src/data/postal-metadata.json test/vectors test/vectors_test.dart js/test/field.conformance.spec.ts
git commit -m "Add postal examples and charsets, plus field descriptor and formatPartial"
```

---

### Task 8: LicensePlate

**Files:**
- Modify: `lib/src/license_plate/license_plate.dart`, `js/src/license-plate/index.ts`
- Modify: the two vector files and both harness dispatchers.

**Interfaces:**
- Consumes: `LicensePlate.tryFormat(String input, {String? country})` → `String?`.
- Produces: `LicensePlate.fieldDescriptor({String? country})`, `LicensePlate.formatPartial(String input, {String? country})`.

`maxLength` is **null for every country**. The implemented AT grammar is
`^([A-Z]{1,2})([A-Z0-9]+)$` — an unbounded serial — so any cap risks rejecting
a plate `validate` accepts. Grouping is snap-on-valid: separator positions
depend on the whole value (`W-12345A`, `B-XY 1234`, `ZH 123456`).

- [ ] **Step 1: Add the failing vectors**

Append to `test/vectors/field_descriptor.json`:

```json
  {
    "type": "license_plate",
    "options": {},
    "keyboard": "text",
    "autofill": null,
    "capitalization": "characters",
    "maxLength": null,
    "example": null,
    "allowedChars": "0-9A-Z -"
  },
  {
    "type": "license_plate",
    "options": { "country": "AT" },
    "keyboard": "text",
    "autofill": null,
    "capitalization": "characters",
    "maxLength": null,
    "example": "W-12345A",
    "allowedChars": "0-9A-Z -"
  },
  {
    "type": "license_plate",
    "options": { "country": "DE" },
    "keyboard": "text",
    "autofill": null,
    "capitalization": "characters",
    "maxLength": null,
    "example": "B-XY 1234",
    "allowedChars": "0-9A-Z -"
  }
```

Before writing these two examples, confirm each one against the module:
`dart run --enable-asserts` is unnecessary — run
`dart test test/license_plate_test.dart` after implementing, and rely on the
example-validity invariant added in Task 11, which asserts every non-null
`example` passes its own `validate`. If either example turns out invalid,
replace it with one from `test/vectors/license_plate.json`.

Append to `test/vectors/format_partial.json`:

```json
  { "type": "license_plate", "options": { "country": "AT" }, "input": "w", "output": "W" },
  { "type": "license_plate", "options": { "country": "AT" }, "input": "w12345a", "output": "W-12345A" },
  { "type": "license_plate", "options": { "country": "AT" }, "input": "w-12345a", "output": "W-12345A" },
  { "type": "license_plate", "options": { "country": "AT" }, "input": "w 12345a!", "output": "W-12345A" }
```

- [ ] **Step 2: Extend both dispatchers, run to verify failure**

Dart: `'license_plate' => LicensePlate.fieldDescriptor(country: o['country'] as String?),` and the `formatPartial` twin. TS likewise.

Run: `dart test test/vectors_test.dart -n license_plate`
Expected: FAIL — `The method 'fieldDescriptor' isn't defined for the class 'LicensePlate'`.

- [ ] **Step 3: Implement in Dart**

```dart
  /// A representative plate per supported country, for
  /// [FieldDescriptor.example].
  static const Map<String, String> _examples = {
    'AT': 'W-12345A',
    'DE': 'B-XY 1234',
    'CH': 'ZH 123456',
    'HR': 'ZG 123-A',
    'TR': '34 ABC 123',
  };

  /// Describes a license-plate input field.
  ///
  /// [FieldDescriptor.maxLength] is null for every country on purpose: the
  /// implemented AT grammar accepts an unbounded serial, so any cap could
  /// reject a plate [validate] accepts.
  static FieldDescriptor fieldDescriptor({String? country}) => FieldDescriptor(
        keyboard: KeyboardType.text,
        capitalization: Capitalization.characters,
        example: country == null ? null : _examples[country.toUpperCase()],
        allowedChars: '0-9A-Z -',
      );

  /// Formats partially typed [input]: upper-cased and stripped of separators
  /// until the value is a valid plate, at which point it snaps into the
  /// canonical display form. Separator positions depend on the whole value,
  /// so there is nothing meaningful to insert earlier. Never throws.
  static String formatPartial(String input, {String? country}) {
    final s = prepare(input, fieldDescriptor(country: country),
        separators: ' -');
    return tryFormat(s, country: country) ?? s;
  }
```

- [ ] **Step 4: Implement in TypeScript**

```ts
// A representative plate per supported country, for FieldDescriptor.example.
const EXAMPLES: Record<string, string> = {
  AT: 'W-12345A',
  DE: 'B-XY 1234',
  CH: 'ZH 123456',
  HR: 'ZG 123-A',
  TR: '34 ABC 123',
};

// Describes a license-plate input field. maxLength is null for every country
// on purpose: the implemented AT grammar accepts an unbounded serial, so any
// cap could reject a plate validate accepts.
function fieldDescriptor(options: PlateOptions = {}): FieldDescriptor {
  return {
    keyboard: 'text',
    autofill: null,
    capitalization: 'characters',
    maxLength: null,
    example: options.country === undefined ? null : (EXAMPLES[options.country.toUpperCase()] ?? null),
    allowedChars: '0-9A-Z -',
  };
}

// Formats partially typed input: upper-cased and stripped of separators until
// the value is a valid plate, at which point it snaps into the canonical
// display form. Never throws.
function formatPartial(input: string, options: PlateOptions = {}): string {
  const s = prepare(input, fieldDescriptor(options), { separators: ' -' });
  return tryFormat(s, options) ?? s;
}
```

`PlateOptions` is the module's existing options interface, imported from
`./types` at `js/src/license-plate/index.ts:5` — reuse it, and add
`fieldDescriptor, formatPartial` to the exported `LicensePlate` const.

- [ ] **Step 5: Run both suites**

Run: `dart test && dart analyze && cd js && npm test && npm run lint`
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add lib/src/license_plate js/src/license-plate test/vectors test/vectors_test.dart js/test/field.conformance.spec.ts
git commit -m "Add field descriptor and formatPartial for license plates"
```

---

### Task 9: Phone

**Files:**
- Modify: `lib/src/phone/phone.dart`, `js/src/phone/index.ts`
- Modify: the two vector files and both harness dispatchers.

**Interfaces:**
- Consumes: `Phone.tryFormat(String input, {Country? country, bool international = true})` → `String?`; `Country.fromIso2(String)`.
- Produces: `Phone.fieldDescriptor({Country? country})`, `Phone.formatPartial(String input, {Country? country})`.

Snap-on-valid, for the reason the spec gives: reproducing libphonenumber's
as-you-type formatter in both languages would mean re-deriving national
grouping for partial input, and a wrong guess mid-number is more disruptive
than no grouping. The formatted branch *is* `format`, so every guarantee holds
by construction. The international form is used when the input starts with `+`,
the national form otherwise.

`maxLength` is null: E.164 caps the digits at 15, but the separator count
varies per national format, so no honest single bound exists.

- [ ] **Step 1: Add the failing vectors**

Append to `test/vectors/field_descriptor.json`:

```json
  {
    "type": "phone",
    "options": {},
    "keyboard": "phone",
    "autofill": "telephoneNumber",
    "capitalization": "none",
    "maxLength": null,
    "example": null,
    "allowedChars": "0-9+ ()-"
  },
  {
    "type": "phone",
    "options": { "country": "AT" },
    "keyboard": "phone",
    "autofill": "telephoneNumber",
    "capitalization": "none",
    "maxLength": null,
    "example": "+43 1 234567",
    "allowedChars": "0-9+ ()-"
  }
```

Append to `test/vectors/format_partial.json`:

```json
  { "type": "phone", "options": { "country": "AT" }, "input": "+43", "output": "+43" },
  { "type": "phone", "options": { "country": "AT" }, "input": "+43 664", "output": "+43664" },
  { "type": "phone", "options": { "country": "AT" }, "input": "abc+43", "output": "+43" },
  { "type": "phone", "options": {}, "input": "", "output": "" }
```

Add one snapping case only after checking a known-valid number from
`test/vectors/phone.json`: take an entry with `"isValid": true` and a `format`
value, and add
`{ "type": "phone", "options": { "country": "<its country>" }, "input": "<its input>", "output": "<its format>" }`.
That case is what proves the snap branch works; do not invent the number.

- [ ] **Step 2: Extend both dispatchers, run to verify failure**

Dart `_descriptorFor`: `'phone' => Phone.fieldDescriptor(country: _country(o['country'] as String?)),`
Dart `_partialFor`: `'phone' => Phone.formatPartial(input, country: _country(o['country'] as String?)),`
`_country` already exists in the harness. TS likewise, matching that module's country option type.

Run: `dart test test/vectors_test.dart -n phone`
Expected: FAIL — `The method 'fieldDescriptor' isn't defined for the class 'Phone'`.

- [ ] **Step 3: Implement in Dart**

```dart
  /// Describes a phone-number input field.
  ///
  /// [FieldDescriptor.maxLength] is null: E.164 caps the digits at 15, but
  /// the number of separators varies per national format, so no honest
  /// single bound exists.
  static FieldDescriptor fieldDescriptor({Country? country}) => FieldDescriptor(
        keyboard: KeyboardType.phone,
        autofill: AutofillHint.telephoneNumber,
        example: country == null
            ? null
            : tryFormat('+${country.callingCode}1234567', country: country),
        allowedChars: '0-9+ ()-',
      );

  /// Formats partially typed [input]: digits and `+` only, snapping into the
  /// canonical form as soon as the number is valid. Reproducing a full
  /// as-you-type formatter would mean guessing national grouping on partial
  /// input, and a wrong guess mid-number is worse than none. Never throws.
  static String formatPartial(String input, {Country? country}) {
    var s = prepare(input, fieldDescriptor(country: country),
        separators: ' ()-');
    final plus = s.startsWith('+');
    s = s.replaceAll('+', '');
    if (s.length > 15) s = s.substring(0, 15);
    if (plus) s = '+$s';
    return tryFormat(s, country: country, international: plus) ?? s;
  }
```

If `tryFormat('+${country.callingCode}1234567', …)` returns null for some
country (no format rule matches that synthetic number), `example` is simply
null — acceptable, and the Task 11 invariant only checks non-null examples.
If it returns null for **AT**, replace the descriptor's `example` expression
with a lookup of the number used in the vector above.

- [ ] **Step 4: Implement in TypeScript**

Mirror it exactly, using the module's own `tryFormat` and country option shape:

```ts
// Describes a phone-number input field. maxLength is null: E.164 caps the
// digits at 15, but the number of separators varies per national format, so
// no honest single bound exists.
function fieldDescriptor(options: PhoneOptions = {}): FieldDescriptor {
  const country = options.country;
  return {
    keyboard: 'phone',
    autofill: 'telephoneNumber',
    capitalization: 'none',
    maxLength: null,
    example:
      country === undefined
        ? null
        : (tryFormat(`+${fromIso2(country)?.callingCode ?? ''}1234567`, { country }) ?? null),
    allowedChars: '0-9+ ()-',
  };
}

// Formats partially typed input: digits and + only, snapping into the
// canonical form as soon as the number is valid. Never throws.
function formatPartial(input: string, options: PhoneOptions = {}): string {
  let s = prepare(input, fieldDescriptor(options), { separators: ' ()-' });
  const plus = s.startsWith('+');
  s = s.replace(/\+/g, '');
  if (s.length > 15) s = s.substring(0, 15);
  if (plus) s = `+${s}`;
  return tryFormat(s, { ...options, international: plus }) ?? s;
}
```

`fromIso2` is already imported at `js/src/phone/index.ts:4` and returns the
country record carrying `callingCode`. Note the deliberate asymmetry between
the languages here: Dart's `PhoneOptions` equivalent takes a `Country` object,
while the TS `PhoneOptions` (`js/src/phone/index.ts:14`) takes an ISO-2
`string`. Both `fieldDescriptor` and `formatPartial` follow their own
language's existing convention; the vector harness converts.

- [ ] **Step 5: Run both suites**

Run: `dart test && dart analyze && cd js && npm test && npm run lint`
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add lib/src/phone js/src/phone test/vectors test/vectors_test.dart js/test/field.conformance.spec.ts
git commit -m "Add field descriptor and formatPartial for phone numbers"
```

---

### Task 10: Email, Url and Host

**Files:**
- Modify: `lib/src/email/email.dart`, `lib/src/url/url.dart`, `lib/src/host/host.dart`
- Modify: `js/src/email/index.ts`, `js/src/url/index.ts`, `js/src/host/index.ts`
- Modify: the two vector files and both harness dispatchers.

**Interfaces:**
- Produces: `fieldDescriptor()` and `formatPartial(String)` on all three, both languages.

These three do **not** agree with `format`, and must not: `Url.format` strips
the scheme and `www.`, `Host.format` canonicalises and lower-cases, and `Email`
has no `format` at all. Applying any of that while the user types would delete
what they are typing. `Email` and `Url` therefore come out as identity
functions — not by special-casing, but because their descriptors carry no
filter and no length bound, so every pipeline step is a no-op. `Host` filters
and truncates but does not case.

- [ ] **Step 1: Add the failing vectors**

Append to `test/vectors/field_descriptor.json`:

```json
  {
    "type": "email",
    "options": {},
    "keyboard": "email",
    "autofill": "email",
    "capitalization": "none",
    "maxLength": null,
    "example": "user@example.com",
    "allowedChars": null
  },
  {
    "type": "url",
    "options": {},
    "keyboard": "url",
    "autofill": "url",
    "capitalization": "none",
    "maxLength": null,
    "example": "https://example.com",
    "allowedChars": null
  },
  {
    "type": "host",
    "options": {},
    "keyboard": "url",
    "autofill": null,
    "capitalization": "none",
    "maxLength": 259,
    "example": "example.com",
    "allowedChars": "0-9A-Za-z.:\\[\\]-"
  }
```

Append to `test/vectors/format_partial.json`:

```json
  { "type": "email", "options": {}, "input": "Foo@Bar", "output": "Foo@Bar" },
  { "type": "email", "options": {}, "input": "  x  ", "output": "  x  " },
  { "type": "url", "options": {}, "input": "https://www.Example.com/", "output": "https://www.Example.com/" },
  { "type": "host", "options": {}, "input": "Example.com", "output": "Example.com" },
  { "type": "host", "options": {}, "input": "example.com:8080", "output": "example.com:8080" },
  { "type": "host", "options": {}, "input": "exa mple.com", "output": "example.com" }
```

`Host`'s 259 is 253 (the RFC 1035 hostname maximum) plus `:` plus five port
digits. In JSON the `allowedChars` backslashes are escaped, so the value the
code carries is `0-9A-Za-z.:\[\]-` — the brackets are escaped because the
string is spliced into a regex character class.

- [ ] **Step 2: Extend both dispatchers, run to verify failure**

Dart: `'email' => Email.fieldDescriptor(),`, `'url' => Url.fieldDescriptor(),`, `'host' => Host.fieldDescriptor(),` and the three `formatPartial` twins. TS likewise plus imports.

Run: `dart test test/vectors_test.dart -n email`
Expected: FAIL — `The method 'fieldDescriptor' isn't defined for the class 'Email'`.

- [ ] **Step 3: Implement in Dart**

`lib/src/email/email.dart`:

```dart
  /// Describes an email input field.
  static FieldDescriptor fieldDescriptor() => const FieldDescriptor(
        keyboard: KeyboardType.email,
        autofill: AutofillHint.email,
        example: 'user@example.com',
      );

  /// Returns [input] unchanged. An email address has no grouping and no
  /// character set narrow enough to filter safely while typing; the method
  /// exists so every type carries the same operations. Never throws.
  static String formatPartial(String input) =>
      prepare(input, fieldDescriptor());
```

`lib/src/url/url.dart`:

```dart
  /// Describes a URL input field.
  static FieldDescriptor fieldDescriptor() => const FieldDescriptor(
        keyboard: KeyboardType.url,
        autofill: AutofillHint.url,
        example: 'https://example.com',
      );

  /// Returns [input] unchanged. Unlike [format] — which is a display form
  /// that strips the scheme and `www.` — nothing may be removed while the
  /// user is still typing. Never throws.
  static String formatPartial(String input) =>
      prepare(input, fieldDescriptor());
```

`lib/src/host/host.dart`:

```dart
  /// Describes a host input field. [FieldDescriptor.maxLength] is 259: 253
  /// (the RFC 1035 hostname maximum) plus `:` plus five port digits.
  static FieldDescriptor fieldDescriptor() => const FieldDescriptor(
        keyboard: KeyboardType.url,
        maxLength: 259,
        example: 'example.com',
        allowedChars: r'0-9A-Za-z.:\[\]-',
      );

  /// Drops characters a host cannot contain and caps the length. Case is
  /// left alone: [format] lower-cases, but doing that while the user types
  /// would fight them. Never throws.
  static String formatPartial(String input) =>
      prepare(input, fieldDescriptor(), maxSignificant: 259);
```

- [ ] **Step 4: Implement in TypeScript**

```ts
// Describes an email input field.
function fieldDescriptor(): FieldDescriptor {
  return {
    keyboard: 'email',
    autofill: 'email',
    capitalization: 'none',
    maxLength: null,
    example: 'user@example.com',
    allowedChars: null,
  };
}

// Returns input unchanged; the method exists so every type carries the same
// operations. Never throws.
function formatPartial(input: string): string {
  return prepare(input, fieldDescriptor());
}
```

`js/src/url/index.ts` — same shape with `keyboard: 'url'`, `autofill: 'url'`, `example: 'https://example.com'`.

`js/src/host/index.ts`:

```ts
// Describes a host input field. maxLength is 259: 253 (the RFC 1035 hostname
// maximum) plus ':' plus five port digits.
function fieldDescriptor(): FieldDescriptor {
  return {
    keyboard: 'url',
    autofill: null,
    capitalization: 'none',
    maxLength: 259,
    example: 'example.com',
    allowedChars: '0-9A-Za-z.:\\[\\]-',
  };
}

// Drops characters a host cannot contain and caps the length. Case is left
// alone: format lower-cases, but doing that while the user types would fight
// them. Never throws.
function formatPartial(input: string): string {
  return prepare(input, fieldDescriptor(), { maxSignificant: 259 });
}
```

- [ ] **Step 5: Run both suites**

Run: `dart test && dart analyze && cd js && npm test && npm run lint`
Expected: all green — all 12 types now covered by both vector files.

- [ ] **Step 6: Commit**

```bash
git add lib/src/email lib/src/url lib/src/host js/src/email js/src/url js/src/host test/vectors test/vectors_test.dart js/test/field.conformance.spec.ts
git commit -m "Add field descriptors and formatPartial for email, URL and host"
```

---

### Task 11: Cross-cutting invariant tests

**Files:**
- Create: `test/field_invariants_test.dart`
- Create: `js/test/field-invariants.spec.ts`

**Interfaces:**
- Consumes: every `fieldDescriptor` and `formatPartial` from Tasks 3–10, and the existing vector files.
- Produces: nothing new in the API.

These tests are where the design's guarantees are actually enforced. They are
written last because they need all 12 types, but a failure here is a defect in
an earlier task, not in this one.

Idempotence is **not** here — it is asserted inline in the vector harness
(Task 3, Step 2), which covers every type on every vector including the
country-dependent ones this file's type list cannot reach.

The nine **grouping types** — `iban`, `credit_card`, `mac_address`,
`postal_code`, `phone`, `license_plate`, `imei`, `iccid`, `vin` — must agree
with `format`. `email`, `url` and `host` are excluded from that check only.

- [ ] **Step 1: Write the invariant tests (Dart)**

Create `test/field_invariants_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:test/test.dart';

List<Map<String, Object?>> _load(String file) =>
    (jsonDecode(File('test/vectors/$file').readAsStringSync()) as List)
        .cast<Map<String, Object?>>();

/// Every (type, options) pair covered by the descriptor vectors, paired with
/// its descriptor and its partial formatter.
class _Type {
  const _Type(this.name, this.descriptor, this.partial, this.formatValid);

  final String name;
  final FieldDescriptor Function() descriptor;
  final String Function(String) partial;

  /// Formats an already-valid value, or null when the type has no `format`
  /// that a partial formatter is expected to agree with.
  final String? Function(String)? formatValid;
}

final List<_Type> _types = [
  _Type('imei', Imei.fieldDescriptor, Imei.formatPartial, Imei.tryFormat),
  _Type('iccid', Iccid.fieldDescriptor, Iccid.formatPartial, Iccid.tryFormat),
  _Type('vin', Vin.fieldDescriptor, Vin.formatPartial, Vin.tryFormat),
  _Type('credit_card', CreditCard.fieldDescriptor, CreditCard.formatPartial,
      CreditCard.tryFormat),
  _Type('iban', Iban.fieldDescriptor, Iban.formatPartial, Iban.tryFormat),
  _Type('mac_address', MacAddress.fieldDescriptor, MacAddress.formatPartial,
      MacAddress.tryFormat),
  _Type('email', Email.fieldDescriptor, Email.formatPartial, null),
  _Type('url', Url.fieldDescriptor, Url.formatPartial, null),
  _Type('host', Host.fieldDescriptor, Host.formatPartial, null),
];

void main() {
  group('example validity', () {
    for (final t in _types) {
      test('${t.name} example is valid', () {
        final example = t.descriptor().example;
        if (example == null) return;
        final formatted = t.formatValid?.call(example);
        if (t.formatValid != null) {
          expect(formatted, isNotNull,
              reason: '${t.name} example "$example" does not validate');
        }
      });
    }
  });

  group('example fits maxLength', () {
    for (final t in _types) {
      test('${t.name}', () {
        final d = t.descriptor();
        final example = d.example;
        final max = d.maxLength;
        if (example == null || max == null) return;
        expect(example.length, lessThanOrEqualTo(max));
      });
    }
  });

  group('filter soundness', () {
    for (final t in _types) {
      test('${t.name} allowedChars admits its own example', () {
        final d = t.descriptor();
        final example = d.example;
        final allowed = d.allowedChars;
        if (example == null || allowed == null) return;
        expect(example.replaceAll(RegExp('[$allowed]'), ''), '',
            reason:
                '${t.name} example "$example" contains characters its own '
                'allowedChars rejects');
      });
    }
  });

  group('agreement with format', () {
    for (final c in _load('credit_card.json')) {
      if (c['isValid'] != true || !c.containsKey('format')) continue;
      final input = c['input']! as String;
      test('credit_card: $input', () {
        expect(CreditCard.formatPartial(input), c['format']);
      });
    }
    for (final c in _load('iban.json')) {
      if (c['isValid'] != true || !c.containsKey('format')) continue;
      final input = c['input']! as String;
      final country = (c['normalized']! as String).substring(0, 2);
      test('iban: $input', () {
        expect(Iban.formatPartial(input, country: country), c['format']);
      });
    }
    for (final c in _load('imei.json')) {
      if (c['isValid'] != true || !c.containsKey('format')) continue;
      final input = c['input']! as String;
      final allowSv = c['allowSv'] as bool? ?? false;
      test('imei: $input', () {
        expect(Imei.formatPartial(input, allowSv: allowSv), c['format']);
      });
    }
    for (final c in _load('vin.json')) {
      if (c['isValid'] != true || !c.containsKey('format')) continue;
      final input = c['input']! as String;
      test('vin: $input', () {
        expect(Vin.formatPartial(input), c['format']);
      });
    }
    for (final c in _load('postal_code.json')) {
      if (c['isValid'] != true || !c.containsKey('format')) continue;
      final input = c['input']! as String;
      final country = c['country']! as String;
      test('postal_code $country: $input', () {
        expect(PostalCode.formatPartial(input, country: country), c['format']);
      });
    }
    for (final c in _load('license_plate.json')) {
      if (c['isValid'] != true || !c.containsKey('format')) continue;
      final input = c['input']! as String;
      final country = c['country'] as String?;
      test('license_plate: $input', () {
        expect(LicensePlate.formatPartial(input, country: country), c['format']);
      });
    }
  });
}
```

`iccid.json` and `mac.json` are covered by the `_types` loops above; `phone.json`
is deliberately absent from the agreement group because its vectors carry an
`international` flag that `formatPartial` derives from the leading `+` instead —
its agreement is pinned by the snapping vector added in Task 9.

- [ ] **Step 2: Run the Dart invariants**

Run: `dart test test/field_invariants_test.dart`
Expected: PASS. A failure here means an earlier task's descriptor or partial
formatter is wrong — fix that task's code, not this test.

- [ ] **Step 3: Mirror the invariants in TypeScript**

Create `js/test/field-invariants.spec.ts` with the same five groups, reading
the same vector files via the `load` helper from
`js/test/field.conformance.spec.ts` (copy it; the two specs are independent
files). Use the module const objects (`Imei`, `Iban`, …) and their
`tryFormat`/`fieldDescriptor`/`formatPartial` members.

Run: `cd js && npx vitest run test/field-invariants.spec.ts`
Expected: PASS, same test names as the Dart side.

- [ ] **Step 4: Run everything**

Run: `dart test && dart analyze && cd js && npm test && npm run lint`
Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add test/field_invariants_test.dart js/test/field-invariants.spec.ts
git commit -m "Add field-descriptor and formatPartial invariant tests"
```

---

### Task 12: Documentation, changelog and version

**Files:**
- Modify: `README.md`, `js/README.md`, `CHANGELOG.md`, `js/CHANGELOG.md` (create if absent), `pubspec.yaml`, `js/package.json`, `llms.txt`

**Interfaces:**
- Consumes: everything above. Produces no code.

- [ ] **Step 1: Add the README section (Dart)**

In `README.md`, after the feature list and before the per-type sections, add a
section titled `## 🎹 Input fields`. It must contain:

1. One short paragraph: every validator exposes `fieldDescriptor(...)` and
   `formatPartial(...)` taking the same options as `validate`.
2. A worked Flutter example — the package has no Flutter dependency, so this is
   the code the caller writes:

```dart
final d = Iban.fieldDescriptor(country: 'AT');

TextField(
  keyboardType: switch (d.keyboard) {
    KeyboardType.digits => TextInputType.number,
    KeyboardType.phone => TextInputType.phone,
    KeyboardType.email => TextInputType.emailAddress,
    KeyboardType.url => TextInputType.url,
    KeyboardType.text => TextInputType.text,
  },
  textCapitalization: TextCapitalization.characters,
  maxLength: d.maxLength,
  decoration: InputDecoration(hintText: d.example),
  onChanged: (v) => controller.value = TextEditingValue(
    text: Iban.formatPartial(v, country: 'AT'),
  ),
);
```

3. The three mapping tables from the spec (`KeyboardType`, `Capitalization`,
   `AutofillHint` → Flutter and HTML), copied verbatim.
4. Two sentences on what `formatPartial` guarantees: it never throws, and for
   the nine grouping types it produces exactly what `format` produces once the
   value is valid. Name the exception: `Email`, `Url` and `Host` return the
   text essentially untouched, because their `format` is a display transform.

- [ ] **Step 2: Add the README section (TypeScript)**

In `js/README.md`, the same section with the web idiom:

```ts
const d = PostalCode.fieldDescriptor({ country: 'NL' });

input.inputMode = d.keyboard === 'digits' ? 'numeric' : 'text';
input.autocomplete = d.autofill === 'postalCode' ? 'postal-code' : 'off';
input.maxLength = d.maxLength ?? 524288;
input.placeholder = d.example ?? '';
input.addEventListener('input', () => {
  input.value = PostalCode.formatPartial(input.value, { country: 'NL' });
});
```

plus the same three mapping tables.

- [ ] **Step 3: Update `llms.txt`**

Add `fieldDescriptor` and `formatPartial` to the API summary alongside
`isValid` / `validate` / `normalize` / `format`, in the same terse style the
file already uses.

- [ ] **Step 4: Changelog and version**

`CHANGELOG.md`, new top entry:

```markdown
## 0.10.0

- Added `FieldDescriptor` (`keyboard`, `autofill`, `capitalization`,
  `maxLength`, `example`, `allowedChars`) and a `fieldDescriptor(...)` method
  on every type, taking the same options as `validate`.
- Added `formatPartial(...)` on every type: as-you-type formatting that never
  throws and, for the nine grouping types, agrees with `format` on valid input.
- `PostalPattern` gained `example` and `charset`; the postal metadata table was
  regenerated.
```

Mirror it in `js/CHANGELOG.md`. Set `version: 0.10.0` in `pubspec.yaml` and
`"version": "0.10.0"` in `js/package.json`.

- [ ] **Step 5: Verify the whole build**

Run:
```bash
dart analyze && dart test && dart pub publish --dry-run
cd js && npm test && npm run lint && npm run build
```
Expected: all green; `pub publish --dry-run` reports no warnings other than any
that already existed before this work.

- [ ] **Step 6: Commit**

```bash
git add README.md js/README.md CHANGELOG.md js/CHANGELOG.md pubspec.yaml js/package.json llms.txt
git commit -m "Document field descriptors and formatPartial, release 0.10.0"
```

---

## Deferred to a separate plan

The Flutter companion package (`flutter/kreiseck_validator_flutter`) — the
`TextInputFormatter` wrapper with cursor mapping and the per-type `TextField`
constructors — is specified in the spec's "Follow-up" section and gets its own
spec and plan once this lands. Nothing in this plan may add a Flutter
dependency to either package.
