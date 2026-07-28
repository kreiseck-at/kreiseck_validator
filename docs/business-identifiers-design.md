# Business identifiers & DOM field binding — Design

Status: approved
Date: 2026-07-28
Target version: 0.11.0

## Goal

Two additions, driven by real consumers that currently hand-write this logic:

1. **Six new types** covering the identifiers a business application asks for:
   VAT ID, BIC, GTIN, social-security number, company-register number and tax
   number.
2. **A `dom` subpath for the TypeScript port** that turns a `FieldDescriptor`
   into HTML input attributes and — optionally — binds a live input element.
   Today that mapping exists only as a table in the README, so every consumer
   retypes it.

## Non-goals

- **No network calls anywhere**, including VAT validation. The package stays
  offline-only; see "VIES" below for the seam it offers instead.
- **No new countries for existing types.** This release adds types, not
  coverage.
- **No Flutter/React adapters.** The Dart library stays Flutter-free and the
  npm package stays dependency-free; `dom` uses only standard DOM lib types.
- **No name/address lookup** from any identifier (no company-register search,
  no GS1 product database, no bank directory beyond the existing IBAN data).

## Source-of-truth rule

Every check digit in this release MUST be implemented from a primary
specification consulted during implementation — never reconstructed from
memory. This mirrors how the phone numbering plan was handled in 0.2.0.

| Type | Primary source to consult |
|---|---|
| VAT ID structure | EU Commission VIES "VAT number formats" reference |
| VAT ID check digits | Each member state's tax administration specification |
| BIC | ISO 9362 |
| GTIN | GS1 General Specifications (mod-10 check digit) |
| AT social-security number | Dachverband der Sozialversicherungsträger |
| AT company-register number | Justiz / Firmenbuch (`FN` check character) |
| AT tax number | BMF (Finanzamt number list + check digit) |

**Fallback rule:** if no primary source can be obtained for a check digit, that
country ships **structure-only** validation, the omission is stated in the
doc comment and in the README, and no invented algorithm is committed. A
structure-only country must never emit `…BadChecksum`.

## New types

All six follow the existing contract: `isValid` / `validate` / `normalize` /
`format` / `tryFormat` / `parse` / `fieldDescriptor` / `formatPartial`, with
options as named parameters identical across every method of the type.
`normalize` and `format` throw `FormatException` (Dart) / `FormatError` (TS) on
invalid input; `fieldDescriptor` and `formatPartial` never throw.

### `VatId({String? country})`

The largest of the six. Replaces a consumer-side regex table that has no check
digits at all.

- **Structure** for the 27 EU member states plus CH and GB, from bundled
  metadata (`vat_metadata.g.dart` / `js/src/data/vat-metadata.json`), generated
  by a `tool/` script in the same style as the IBAN and postal tables.
- **Check digits** for the countries whose algorithm is documented and stable:
  AT, DE, BE, ES, FR, IT, NL, PL, PT, CH, GB. Others are structure-only.
- **Country resolution:** a value carrying its prefix (`ATU12345678`) resolves
  itself; a bare body requires `country:`, otherwise
  `Invalid(IssueCode.vatAmbiguousCountry)`. Greece is the known trap — the ISO
  country is `GR`, the VAT prefix is `EL`; both MUST be accepted as `country:`
  input and `normalize` MUST emit `EL`.
- **`normalize`** → prefix + body, upper-cased, all spaces, dots and hyphens
  removed. **`format`** → the country's conventional display grouping where one
  exists, otherwise the normalized form.
- **`parse` → `VatInfo`**: `country` (ISO 3166-1 alpha-2, so `GR` for an `EL`
  number), `prefix` (as written, so `EL`), `number` (body without prefix),
  `checksumVerified` (bool — false for structure-only countries).
- **Known caveat to document:** Dutch sole traders received randomly generated
  BTW-identificatienummers in 2020 that do not satisfy the classic mod-11
  check. NL therefore validates structure plus the `B\d{2}` suffix and treats
  the mod-11 result as advisory only — it MUST NOT reject.

**VIES seam.** The package performs no request. It exposes:

- `VatId.viesRequest(String value)` → a plain descriptor
  (`{ url, method, headers, body }`) for the EU VIES REST endpoint, or null
  when the value is not structurally valid or the country is outside VIES.
- `VatId.parseViesResponse(String body)` → `VatRegistration?` with `valid`,
  `name`, `address` — a pure parser over the response the caller fetched.

That keeps the offline guarantee intact while removing the part consumers
usually get wrong.

Issue codes: `vatEmpty`, `vatBadFormat`, `vatBadChecksum`,
`vatUnknownCountry`, `vatAmbiguousCountry`.

### `Bic`

ISO 9362. Natural companion to `Iban`, and the smallest of the six.

- 8 or 11 characters: 4 letters institution, 2 letters country, 2
  alphanumeric location, optional 3 alphanumeric branch.
- The country segment MUST resolve via the existing `Country` table;
  `XX`-style placeholders are rejected.
- `normalize` upper-cases and strips whitespace. `format` returns the 8- or
  11-character form; a `XXX` branch is **preserved**, not stripped — it is
  meaningful in SEPA payloads.
- `parse` → `BicInfo { institution, country, location, branch, isTest }`.
  `isTest` is true when the location suffix is `0`, per ISO 9362.
- Cross-check helper: `Bic.matchesIban(bic, iban)` → bool, comparing only the
  country segments. Cheap, and it catches a common paste error.

Issue codes: `bicEmpty`, `bicBadLength`, `bicBadChars`, `bicUnknownCountry`.

### `Gtin`

GS1 GTIN-8/12/13/14 (EAN, UPC, ITF-14).

- Digits only, length ∈ {8, 12, 13, 14}, mod-10 check digit.
- `normalize` strips separators; **no zero-padding to 14** — the input length
  is information the caller may need. `format` returns the normalized digits.
- `parse` → `GtinInfo { length, indicator, gs1Prefix, checkDigit }`.
  `gs1Prefix` is the leading 3-digit GS1 prefix as written; it is **not**
  mapped to a country, because a GS1 prefix identifies the issuing member
  organisation, not the origin of the goods. That distinction goes in the doc
  comment — it is the single most common misuse of the field.
- `Gtin.checkDigit(String body)` → the expected check digit for a body one
  digit short, so a UI can complete a scanned partial.

Issue codes: `gtinEmpty`, `gtinBadChars`, `gtinBadLength`, `gtinBadChecksum`.

### `SocialSecurityNumber({required String country})`

Austria only in this release; the country parameter is required so DE and CH
can be added later without a breaking rename.

- **AT:** 10 digits `NNNP TTMMJJ` — three serial digits, a check digit at
  position 4, then the date of birth. Weights `[3,7,9,0,5,8,4,2,1,6]`, sum
  mod 11; a remainder of 10 is never issued and MUST be rejected.
- The date part MUST be a real calendar date. Fictitious day/month components
  are in circulation for people whose birth date is unknown; those are
  **valid numbers** and the checksum decides — so `validate` accepts them and
  `parse` reports `birthDate: null`. This split is deliberate and must be
  covered by vectors.
- `format` → `NNNP TTMMJJ` with one space. `parse` →
  `SocialSecurityInfo { serial, checkDigit, birthDate }` where `birthDate` is
  `SsnBirthDate { day, month, twoDigitYear }` or null.
- **The century is not inferred.** A two-digit year is genuinely ambiguous, and
  the only way to resolve it is an age heuristic that belongs to the calling
  application. `parse` therefore hands back the raw components; a consumer that
  needs a four-digit year applies its own rule. A library that guesses the
  century is how wrong birth dates get stored.

Issue codes: `ssnEmpty`, `ssnBadChars`, `ssnBadLength`, `ssnBadChecksum`,
`ssnBadDate`, `ssnUnknownCountry`.

### `CompanyRegister({required String country})`

Austria only. `FN 123456a` — up to six digits plus one lower-case check letter.

- The canonical written form keeps the check letter **lower-case**, so this is
  the one type whose `normalize` does not upper-case: `normalize` → `123456a`
  (identifier only), `format` → `FN 123456a`. The `FN` prefix is presentation
  and is accepted but not stored.
- Check letter per the Firmenbuch specification, subject to the
  source-of-truth rule above; structure-only if unobtainable.
- `parse` → `CompanyRegisterInfo { number, checkChar, court }` where `court`
  is null — the registering court is not encoded in the number and MUST NOT be
  guessed.

Issue codes: `companyRegisterEmpty`, `companyRegisterBadFormat`,
`companyRegisterBadChecksum`, `companyRegisterUnknownCountry`.

### `TaxNumber({required String country})`

Austria only. Nine digits: a two-digit Finanzamt number, then seven digits of
which the last is a check digit.

- The Finanzamt number MUST be validated against the BMF list of currently
  and formerly assigned office numbers, bundled as generated metadata.
  Historical numbers stay valid — old documents carry them.
- `format` → `12-345/6789`. `normalize` → the nine bare digits.
- `parse` → `TaxNumberInfo { office, officeName, number, checkDigit }`.

Issue codes: `taxNumberEmpty`, `taxNumberBadChars`, `taxNumberBadLength`,
`taxNumberBadChecksum`, `taxNumberUnknownOffice`, `taxNumberUnknownCountry`.

## `@kreiseck/validator/dom`

A TypeScript-only subpath. No dependencies, no framework, DOM lib types only.
The main entry point stays platform-neutral.

```ts
import { fieldAttrs, bindInput } from '@kreiseck/validator/dom'
```

- **`fieldAttrs(descriptor, opts?)` → `FieldAttrs`** — a pure function, usable
  from React, Vue, Svelte or plain DOM:

  | FieldDescriptor | HTML |
  |---|---|
  | `keyboard` | `inputMode`: text / numeric / tel / email / url |
  | `capitalization` | `autoCapitalize`: none / characters / words / sentences |
  | `autofill` | `autoComplete`: email / tel / postal-code / cc-number / url |
  | `maxLength` | `maxLength` (omitted when null) |
  | `example` | `placeholder` (opt-out via `opts.placeholder: false`) |
  | `allowedChars` | not an attribute — see `filterValue` |

  It returns camelCase keys (React-shaped). `bindInput` handles the DOM
  attribute names internally, so no consumer has to know both spellings.

- **`filterValue(value, descriptor)` → string** — drops characters outside
  `allowedChars` and truncates to `maxLength`. Exported because a controlled
  React input needs it without any element being involved.

- **`bindInput(el, options)` → `() => void`** — for plain DOM. Applies the
  attributes, formats as the user types, validates on `blur`, and reports
  state through `options.onState({ state, normalized, issue })` where `state`
  is `'empty' | 'incomplete' | 'valid' | 'invalid'`. The returned function
  unbinds. `options` takes `descriptor`, `formatPartial` and `validate`
  directly, so it is not coupled to the list of types and needs no registry.

  **Caret handling is the whole difficulty here.** Rewriting `el.value` on
  every keystroke moves the cursor to the end, which makes editing the middle
  of a formatted IBAN impossible. `bindInput` MUST restore the caret by
  counting *significant* characters (those inside `allowedChars`) before the
  caret, reformatting, then walking forward to the same significant offset.
  A dedicated spec file covers this — it is the one part of `dom` that cannot
  be verified by the shared vectors.

There is no Dart counterpart. A Flutter adapter would require a Flutter
dependency, and the package's platform neutrality is a deliberate property;
the README's Flutter mapping table stays the Dart-side answer. This asymmetry
is stated in `llms.txt` so it does not read as an oversight.

## Cross-language parity

The existing invariant holds: Dart and TS must not drift.

- One vector file per new type in `test/vectors/`: `vat_id.json`, `bic.json`,
  `gtin.json`, `social_security.json`, `company_register.json`,
  `tax_number.json`.
- New entries in `field_descriptor.json` and `format_partial.json` for all
  six, including the country-parameterised variants.
- `test/vectors_test.dart` gets the six new `_descriptorFor` / `_check`
  branches; `js/test/*.conformance.spec.ts` gets one spec per type loading the
  same files.
- `test/field_invariants_test.dart` and `js/test/field-invariants.spec.ts` get
  the six new `_Type` entries, which enforces the existing invariants:
  `example` must validate, `example` must fit `maxLength`, and `formatPartial`
  of a valid value must equal `format`.
- `js/test/dom.spec.ts` is new and Dart-less by nature: attribute mapping,
  filtering, caret preservation, unbind.
- `js/test/treeshaking.spec.ts` must be extended so the new subpath and types
  stay individually importable.

## Public surface changes

- Dart: six directories under `lib/src/`, six pairs of exports in
  `lib/kreiseck_validator.dart`, new members in `lib/src/common/issue_code.dart`.
- TS: six directories under `js/src/`, exports in `js/src/index.ts`, six new
  entries plus `./dom` in the `exports` map of `js/package.json`.
- Generated metadata: `vat_metadata.g.dart` + `js/src/data/vat-metadata.json`,
  `tax_office_metadata.g.dart` + `js/src/data/tax-office-metadata.json`, each
  with its generator under `tool/`.

Adding enum members to `IssueCode` is source-breaking for exhaustive Dart
switches. At 0.x that is acceptable; the CHANGELOG must call it out.

## Docs

`README.md` (twelve → eighteen types, the new `dom` section, the HTML mapping
table now pointing at `fieldAttrs`), `llms.txt` (same, plus the Dart/TS
asymmetry), `js/README.md`, `CHANGELOG.md` + `js/CHANGELOG.md`, new keywords
(`vat`, `ust-id`, `bic`, `swift`, `gtin`, `ean`, `barcode`) in both manifests,
and the package description in `pubspec.yaml` + `js/package.json`.

## Release

Version 0.11.0 in `pubspec.yaml` and `js/package.json` in the same commit.
Published to pub.dev and npm together; a version that exists on only one
registry breaks the parity promise the README makes.

Consumers integrate against a local link during development and switch to
`^0.11.0` before their branches merge.
