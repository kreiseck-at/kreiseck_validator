# `FieldDescriptor` + `formatPartial` — Design

**Status:** approved for implementation planning
**Applies to both packages:** Dart `kreiseck_validator` and TS `@kreiseck/validator`,
built together, verified against shared JSON vectors.

## Goal

Every validator already knows the shape of the value it accepts. Today that
knowledge is locked inside `validate`, so callers hand-wire the input field for
each type: which keyboard to raise, which autofill hint to attach, whether to
upper-case, how long the field may get, which characters to reject, and how to
group separators while the user types.

Two additions expose that knowledge:

1. **`FieldDescriptor`** — a per-type (and, where relevant, per-country) record
   of the input characteristics a text field needs.
2. **`formatPartial`** — as-you-type formatting: the same grouping `format`
   produces, but defined on incomplete input, so it can drive an input formatter.

Both are additive; no existing behaviour changes.

## Non-goals

- **No Flutter or DOM types in the core.** The package stays zero-dependency.
  `FieldDescriptor` carries platform-neutral enums; the README documents the
  1:1 mapping to Flutter and to HTML.
- **No labels, placeholders or hint texts.** Field wording is the app's job and
  its i18n's job. The descriptor is technical only.
- **No widgets.** A Flutter companion package is planned as a separate spec
  (see "Follow-up"); this spec covers only the pure core in both languages.

## Part 1 — `FieldDescriptor`

New file `lib/src/common/field_descriptor.dart` (TS: `js/src/common/field.ts`),
exported from the package root.

```dart
class FieldDescriptor {
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

  /// Maximum length of the FORMATTED text (separators included), or null
  /// when no useful hard bound exists.
  final int? maxLength;

  /// A valid example value in formatted form, or null when the type has no
  /// meaningful single example.
  final String? example;

  /// Body of a regex character class listing the characters the field may
  /// contain, e.g. `0-9A-Z ` — null means "no filtering" (free-form text).
  final String? allowedChars;
}

enum KeyboardType { text, digits, phone, email, url }

enum Capitalization { none, characters, words, sentences }

enum AutofillHint { email, telephoneNumber, postalCode, creditCardNumber, url }
```

`allowedChars` is a character-class *body*, not a full regex: the consumer wraps
it (`RegExp('[^$allowedChars]')` to filter, or `[$allowedChars]` to test). This
keeps it usable verbatim from both Dart and TypeScript.

### Platform mapping (documentation only, not code)

| `KeyboardType` | Flutter | HTML |
| --- | --- | --- |
| `text` | `TextInputType.text` | `inputmode="text"` |
| `digits` | `TextInputType.number` | `inputmode="numeric"` |
| `phone` | `TextInputType.phone` | `inputmode="tel"` |
| `email` | `TextInputType.emailAddress` | `inputmode="email"` |
| `url` | `TextInputType.url` | `inputmode="url"` |

| `Capitalization` | Flutter | HTML |
| --- | --- | --- |
| `none` | `TextCapitalization.none` | `autocapitalize="off"` |
| `characters` | `TextCapitalization.characters` | `autocapitalize="characters"` |
| `words` | `TextCapitalization.words` | `autocapitalize="words"` |
| `sentences` | `TextCapitalization.sentences` | `autocapitalize="sentences"` |

| `AutofillHint` | Flutter | HTML |
| --- | --- | --- |
| `email` | `AutofillHints.email` | `autocomplete="email"` |
| `telephoneNumber` | `AutofillHints.telephoneNumber` | `autocomplete="tel"` |
| `postalCode` | `AutofillHints.postalCode` | `autocomplete="postal-code"` |
| `creditCardNumber` | `AutofillHints.creditCardNumber` | `autocomplete="cc-number"` |
| `url` | `AutofillHints.url` | `autocomplete="url"` |

IBAN, VIN, IMEI, ICCID, MAC and license plate have **no** standard autofill
category on either platform. Their `autofill` is `null`; nothing is invented.

### API shape

Each validator gains a static `fieldDescriptor` taking **the same named
parameters as its `validate`**, all optional:

```dart
FieldDescriptor Email.fieldDescriptor();
FieldDescriptor Phone.fieldDescriptor({String? country});
FieldDescriptor Url.fieldDescriptor();
FieldDescriptor Host.fieldDescriptor();
FieldDescriptor Iban.fieldDescriptor({String? country});
FieldDescriptor CreditCard.fieldDescriptor();
FieldDescriptor LicensePlate.fieldDescriptor({String? country});
FieldDescriptor Imei.fieldDescriptor({bool allowSv = false});
FieldDescriptor Iccid.fieldDescriptor();
FieldDescriptor MacAddress.fieldDescriptor({
  MacNotation notation = MacNotation.colon,
  bool upperCase = false,
});
FieldDescriptor Vin.fieldDescriptor();
FieldDescriptor PostalCode.fieldDescriptor({String? country});
```

TypeScript mirrors this with an options object, matching each module's existing
convention: `PostalCode.fieldDescriptor({ country: 'NL' })`.

Called without arguments, a country-dependent type returns a **generic
descriptor**: the widest sensible values across the countries it supports, with
`example` and any per-country `maxLength` set to `null`. Called with a country
it does not know, it returns the same generic descriptor rather than throwing —
a descriptor is a UI hint, and failing a text field over an unknown country is
worse than a slightly loose keyboard.

`PostalCode.fieldDescriptor()` without a country is the one case where the
generic form is notably weaker than the specific one (`text` instead of
`digits`); the doc comment says so and points at the country parameter.

### Values per type

Generic (no country) unless stated:

| Type | `keyboard` | `autofill` | `capitalization` | `maxLength` | `allowedChars` |
| --- | --- | --- | --- | --- | --- |
| `Email` | `email` | `email` | `none` | null | null |
| `Phone` | `phone` | `telephoneNumber` | `none` | null | `0-9+ ()-` |
| `Url` | `url` | `url` | `none` | null | null |
| `Host` | `url` | null | `none` | 259 | `0-9A-Za-z.:\[\]-` |
| `Iban` | `text` | null | `characters` | null / per country | `0-9A-Z ` |
| `CreditCard` | `digits` | `creditCardNumber` | `none` | 23 | `0-9 ` |
| `LicensePlate` | `text` | null | `characters` | null / per country | `0-9A-Z -` |
| `Imei` | `digits` | null | `none` | 15, or 16 with `allowSv` | `0-9` |
| `Iccid` | `digits` | null | `none` | 20 | `0-9` |
| `MacAddress` | `text` | null | per `upperCase` | per `notation` | per `notation` |
| `Vin` | `text` | null | `characters` | 17 | `0-9A-HJ-NPR-Z` |
| `PostalCode` | `text` | `postalCode` | `characters` | null | `0-9A-Z -` |

Notes on individual values:

- **`maxLength` counts the formatted text**, separators included. An Austrian
  IBAN is 20 characters plus 4 group separators = 24; a field capped at 20
  would swallow the last group.
- **`Host` = 259**: 253 (RFC 1035 maximum hostname length) + `:` + up to 5 port
  digits. A bracketed IPv6 literal with port is shorter.
- **`CreditCard` = 23**: the module accepts PANs up to 19 digits (ISO/IEC 7812),
  which `format` groups as `4-4-4-4-3` = 19 + 4 separators.
- **`Vin` = `0-9A-HJ-NPR-Z`**: ISO 3779 forbids `I`, `O` and `Q`. Filtering them
  at the keyboard removes the single most common VIN typo before validation
  ever runs.
- **`Host` keyboard = `url`**: there is no dedicated host keyboard; the URL
  keyboard is the closest fit (dot and slash reachable, no auto-capitalisation).
- **`Phone` `maxLength` = null**: E.164 caps the digits at 15, but the number of
  separators varies per national format, so no honest single bound exists.
- **`MacAddress` is fully option-dependent.** The module supports EUI-48 (12 hex)
  *and* EUI-64 (16 hex), and `format` defaults to **lower-case**, so a blanket
  `characters` capitalisation would contradict it. Per option:

  | `notation` | `maxLength` (EUI-64 worst case) | `allowedChars` |
  | --- | --- | --- |
  | `colon` | 23 (16 + 7) | `0-9A-Fa-f:` |
  | `hyphen` | 23 (16 + 7) | `0-9A-Fa-f-` |
  | `dot` | 19 (16 + 3, groups of **4**) | `0-9A-Fa-f.` |
  | `bare` | 16 | `0-9A-Fa-f` |

  `capitalization` is `characters` when `upperCase: true`, otherwise `none`,
  matching what `format` actually produces.

Country-dependent values:

- **`Iban.fieldDescriptor(country:)`** reads `IbanCountry.of(country)`:
  `maxLength` = `length` + number of group separators
  (`(length - 1) ~/ 4`), `example` = the existing `example` field (already
  4-grouped).
- **`PostalCode.fieldDescriptor(country:)`** reads `kPostalPatterns[country]`:
  `keyboard` = `digits` when the country's character set is digits-only, else
  `text`; `capitalization` = `none` for digits-only, else `characters`;
  `maxLength` = canonical length including any separator; `allowedChars` and
  `example` from the metadata (see "Generated data").
- **`LicensePlate.fieldDescriptor(country:)`** returns per-country
  `maxLength`, `example` and `allowedChars` derived from that country's already
  implemented grammar. These are hand-written constants next to the grammar,
  guarded by the length invariant test below rather than by eyeballing.

## Part 2 — `formatPartial`

```dart
static String formatPartial(String input, { /* same named params as validate */ });
```

Never throws. Accepts anything: empty, half-typed, garbage, already-formatted.

Four steps, in this order:

1. **Filter** — drop every character not in `allowedChars` (no-op when null).
2. **Case** — apply `capitalization` (`characters` → upper-case; `none` →
   leave as typed).
3. **Truncate** — cut to the type's maximum number of *significant* characters
   (no-op when unbounded).
4. **Group** — insert the type's canonical separators.

Truncation deliberately runs **before** grouping, on the separator-free form.
Cutting the grouped text at `maxLength` instead would sometimes land on a
separator and leave one dangling at the end. Both orders cap the result at
`maxLength`, since `maxLength` is by definition the significant maximum plus
the separators grouping inserts.

### Guarantees

Three properties, each covered by a test:

1. **Agreement with `format`** — for every input `v` where `validate(v)` is
   valid: `formatPartial(v) == format(v)`, using the same options. The new
   method can never drift from the established one.

   This holds for the nine **grouping types** — `Iban`, `CreditCard`,
   `MacAddress`, `PostalCode`, `Phone`, `LicensePlate`, `Imei`, `Iccid`, `Vin` —
   whose `format` is a canonical regrouping of the value itself. It explicitly
   does **not** hold for `Email`, `Url` and `Host`, and must not:
   `Url.format` is a *display* transform that strips the scheme and `www.`
   (`https://www.example.com/` → `example.com`), `Host.format` canonicalises and
   lower-cases, and `Email` has no `format` at all. Applying any of those to a
   field while the user types would delete what they are typing. For these three
   the guarantee is instead: `formatPartial` never removes a character that a
   valid value may contain.

   For `Phone`, agreement is asserted against `format(v, international: true)`
   when the input starts with `+`, and against
   `format(v, country: …, international: false)` otherwise.
2. **Idempotence** — `formatPartial(formatPartial(x)) == formatPartial(x)` for
   every `x`. Re-running the formatter on its own output must be a no-op, or a
   text field re-formatting on each keystroke would oscillate.
3. **Character fidelity** — the sequence of *significant* characters (everything
   that is not a separator inserted by step 3) is preserved in order. Only
   filtering (step 1) removes characters and only truncation (step 4) removes a
   suffix; nothing is reordered, and no significant character is invented.

Guarantee 3 is what makes correct **cursor mapping** possible for a consumer:
count the significant characters left of the caret, format, then place the caret
after the significant character with the same index. Without it, the only
available behaviour is "caret to end of text", which makes mid-string
corrections unusable. The Flutter companion package depends on this property.

### No trailing separators

`CreditCard.formatPartial('3782')` returns `'3782'`, **not** `'3782 '`. A
trailing separator makes backspace fight the formatter: the user deletes the
space, the formatter re-adds it, and the field appears stuck. Separators are
only inserted *between* significant characters that are already present.

### Behaviour per type

| Type | Grouping applied |
| --- | --- |
| `Iban` | groups of 4 |
| `CreditCard` | `4-6-5` once the prefix identifies Amex, otherwise `4-4-4-4` |
| `MacAddress` | separator per `notation`: `colon`/`hyphen` every 2 hex characters, `dot` every 4, `bare` none |
| `PostalCode` | the country's `PostalPattern.format` rule, applied as soon as enough characters exist |
| `Phone` | leading `+`: detect the calling code, then group nationally; no `+`: group nationally using `country` |
| `LicensePlate` | the country's display grouping, best effort on partial input |
| `Imei`, `Iccid`, `Vin` | none — filter, case and truncate only |
| `Host` | none — filter and truncate only (no casing: `format` lower-cases, typing must not) |
| `Email`, `Url` | identity: with `allowedChars` and `maxLength` both null, all four steps are no-ops |

`Phone` is the most involved case: with a partial number the country may not yet
be determined. Rule: while the calling code is still ambiguous, return the
digits with `+` and no grouping; once a unique calling code is matched, apply
that country's national grouping to the remainder. Never guess a country in
order to group.

`Email` and `Url` come out as identity functions, not by special-casing but
because their descriptors carry no filter and no length bound, so every step is
a no-op. They exist so callers never have to check which types support the
method — the package's promise is that every type carries the same operations.

## Cross-language consistency

- TypeScript expresses the three enums as string-literal unions, matching the
  existing `MacNotation` convention:
  `export type KeyboardType = 'text' | 'digits' | 'phone' | 'email' | 'url'`.
  The Dart enum member names are character-identical to the TS literals so a
  single vector file can assert both sides.
- `FieldDescriptor` is an `interface` in TS with the same field names; absent
  values are `null` (not `undefined`) so the JSON vectors compare equal.

## Testing

New vector files, driven by `test/vectors_test.dart` and its TS counterpart:

- **`test/vectors/field_descriptor.json`** — one entry per (type, options)
  combination, with the six expected fields. Covers each type's generic form,
  every country-specific IBAN and postal variant worth pinning (AT, DE, CH, NL,
  GB, PL, CZ), `Imei` with and without `allowSv`, and each `MacNotation`.
- **`test/vectors/format_partial.json`** — prefix sequences: for a handful of
  values per type, every prefix from length 1 up to the full value, each with
  its expected output (`A`, `AT`, `AT6`, `AT61`, `AT611`, …). Prefix-by-prefix
  coverage is what catches off-by-one errors at group boundaries.

Unit tests, per language:

- **Agreement**: for every valid input already present in the existing vector
  files of the nine grouping types, assert `formatPartial(v) == format(v)`.
- **Idempotence**: for every input in the partial vectors and every invalid
  input in the existing vectors, assert re-application changes nothing.
- **Character fidelity**: for every input in the partial vectors, assert that
  stripping the type's separators from the output equals the input with steps
  1, 2 and 3 applied and grouping skipped — i.e. grouping adds separators and
  nothing else.
- **Length invariant**: for every valid value in the vector corpus, assert
  `format(v).length <= fieldDescriptor(...).maxLength` where `maxLength` is
  non-null, and `example.length <= maxLength` for every descriptor. This is
  what validates the hand-written per-country license-plate bounds rather than
  trusting them.
- **Filter soundness**: for every valid value, assert every character of
  `format(v)` is matched by `[allowedChars]` where non-null — i.e. the filter
  can never reject a character a valid value needs.

## Generated data

`PostalPattern` gains two fields, `example` (canonical, separator-applied) and
`charset` (either digits-only or alphanumeric), and
`tool/gen_postal_metadata.py` is extended to emit them for all 51 countries.
This is the only generated table touched; every other descriptor value is
hand-written next to the validator it belongs to.

Adding fields to `PostalPattern`'s constructor is technically breaking for
anyone constructing one by hand, but the class exists to describe the bundled
table and the new parameters are optional with safe defaults, so no caller
breaks.

## Rollout

Purely additive in both packages: **0.10.0**.

- `lib/src/common/field_descriptor.dart` + export from `kreiseck_validator.dart`
- `js/src/common/field.ts` + export from `js/src/index.ts`
- `fieldDescriptor` and `formatPartial` on all 12 modules in both languages
- Extended postal metadata + generator
- Two new vector files and the tests above
- README section per language, including the platform mapping tables
- CHANGELOG entries in both packages

## Follow-up (separate spec, not in scope here)

A Flutter companion package at `flutter/` in this repository —
`kreiseck_validator_flutter`, depending on `kreiseck_validator ^0.10.0` —
wrapping `formatPartial` in a `TextInputFormatter` with proper cursor mapping
(relying on guarantee 3) and offering per-type `TextField` constructors such as
`KreiseckTextField.iban(country: 'AT')`. It is specified and built after this
core work lands, so the first pass does not straddle two packages.
