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

## How the algorithms in this document were established

Every check digit below was researched before this design was written, not
during implementation. Each one is either a named public standard (ISO 7064,
Luhn, ISO 9362, GS1 mod-10) or was read off a specific documented
implementation and, where a folk algorithm circulates, **falsified against real
published numbers**. Nothing here is reconstructed from memory.

Two consequences for implementation:

- **Write the code from the algorithm description, not from anyone's source.**
  The reference implementation consulted for the VAT algorithms
  (`python-stdnum`) is LGPL; this package is Apache-2.0. Algorithms and
  standards are not copyrightable, source code is. Cite the standard where one
  is named; do not copy code or test files.
- **Every type needs vectors built from real, publicly published numbers** —
  company imprints, official examples — not from numbers we generated with our
  own implementation. A vector produced by the code under test proves nothing.

## New types

All six follow the existing contract: `isValid` / `validate` / `normalize` /
`format` / `tryFormat` / `parse` / `fieldDescriptor` / `formatPartial`, with
options as named parameters identical across every method of the type.
`normalize` and `format` throw `FormatException` (Dart) / `FormatError` (TS) on
invalid input; `fieldDescriptor` and `formatPartial` never throw.

### `VatId({String? country})`

The largest of the six. Replaces a consumer-side regex table that has no check
digits at all.

**Every supported country gets a real check-digit verification.** The research
found a documented algorithm for all 27 EU member states plus CH, GB and XI, so
there is no structure-only tier and `validate` can reject a wrong digit
everywhere. `vatBadChecksum` is therefore always meaningful.

| Country | Prefix | Structure | Check |
|---|---|---|---|
| AT | `ATU` | `U` + 8 digits | Luhn over the 7 digits after `U`; check = (6 − luhn) mod 10 |
| BE | `BE` | 10 digits (legacy 9 digits gets a leading `0`) | (first 8 + last 2) mod 97 = 0 |
| BG | `BG` | 9 digits (legal) or 10 (natural person) | legal: Σ(i+1)·dᵢ mod 11, on 10 retry with Σ(i+3)·dᵢ mod 11, then mod 10 — person: weights 4,3,2,7,6,5,4,3,2, (11 − Σ) mod 11 |
| CY | `CY` | 8 digits + 1 letter | even positions mapped through {0→1,1→0,2→5,3→7,4→9,5→13,6→15,7→17,8→19,9→21}, plus odd digits, mod 26 → `A`–`Z` |
| CZ | `CZ` | 8, 9 or 10 digits | 8: (11 − Σ(8−i)·dᵢ) mod 11, 0→1, then mod 10 — 9 starting with `6`: variant formula — 10: validates as a rodné číslo |
| DE | `DE` | 9 digits | ISO 7064 MOD 11,10 |
| DK | `DK` | 8 digits | weights 2,7,6,5,4,3,2,1 mod 11 = 0 |
| EE | `EE` | 9 digits | weights 3,7,1,3,7,1,3,7,1 mod 10 = 0 |
| GR | `EL` | 9 digits | c ← 0, then c ← 2c + dᵢ over the first 8; check = 2c mod 11 mod 10 |
| ES | `ES` | 9 chars, letter first and/or last | three sub-algorithms: DNI, NIE, CIF |
| FI | `FI` | 8 digits | weights 7,9,10,5,8,4,2,1 mod 11 = 0 |
| FR | `FR` | 2 chars + 9-digit SIREN | numeric prefix: int(SIREN + `"12"`) mod 97 = prefix — alphanumeric prefix: the alphabet-index formula; SIREN itself Luhn unless `000` |
| HR | `HR` | 11 digits (OIB) | ISO 7064 MOD 11,10 |
| HU | `HU` | 8 digits | weights 9,7,3,1,9,7,3,1 mod 10 = 0 |
| IE | `IE` | 8 or 9 chars | alphabet `WABCDEFGHIJKLMNOPQRSTUV`; (Σ(8−i)·dᵢ + 9·index(2nd letter)) mod 23 |
| IT | `IT` | 11 digits | Luhn = 0, province code `001`–`100` or `120`/`121`/`888`/`999`, first 7 not all zero |
| LT | `LT` | 9 or 12 digits | Σ(1+i mod 9)·dᵢ mod 11; on 10 retry shifted by 2; then mod 11 mod 10 |
| LU | `LU` | 8 digits | int(first 6) mod 89 = last 2 |
| LV | `LV` | 11 digits | first digit > 3: weights 9,1,4,8,3,10,2,5,7,6,1 mod 11 = 3 — otherwise the personal-code algorithm |
| MT | `MT` | 8 digits | weights 3,4,6,7,8,9,10,1 mod 37 = 0 |
| NL | `NL` | 9 digits + `B` + 2 digits | BSN 11-proef on the first 9 **or** ISO 7064 MOD 97,10 over `"NL"` + number |
| PL | `PL` | 10 digits | weights 6,5,7,2,3,4,5,6,7,−1 mod 11 = 0 |
| PT | `PT` | 9 digits | weights 9…1; (11 − Σ) mod 11 mod 10 |
| RO | `RO` | 2–10 digits | zero-fill to 9, weights 7,5,3,2,1,7,5,3,2; 10·Σ mod 11 mod 10 |
| SE | `SE` | 12 digits ending in `01` | first 10 digits Luhn |
| SI | `SI` | 8 digits | weights 8…2; (11 − Σ mod 11), a result of 10 becomes 0 |
| SK | `SK` | 10 digits | int(number) mod 11 = 0 |
| CH | `CHE` | `CHE` + 9 digits | weights 5,4,3,2,7,6,5,4; (11 − Σ) mod 11, a result of 10 is invalid |
| GB | `GB` | 9 or 12 digits, plus `GD`/`HA` forms | weights 8,7,6,5,4,3,2,10,1 mod 97 ∈ {0, 42, 55} |
| XI | `XI` | as GB | GB algorithm; ISO country stays `GB` |

Two entries need a source consulted a second time during implementation
because the research did not reach the leaf algorithm: **CZ** for the 10-digit
individual form (rodné číslo) and **ES** for the DNI/NIE/CIF trio. Both are
named, locatable specifications — not gaps to be filled by guessing. If either
cannot be obtained, that *sub-form* validates structurally and the limitation
goes in the README; the country as a whole still checks its main form.

Further details:

- **Metadata** lives in generated tables (`vat_metadata.g.dart` /
  `js/src/data/vat-metadata.json`) with a generator under `tool/`, like the
  IBAN and postal tables. Structure and prefix are data; the check algorithms
  are code, dispatched per country.
- **Country resolution:** a value carrying its prefix resolves itself; a bare
  body requires `country:`, otherwise `Invalid(IssueCode.vatAmbiguousCountry)`.
- **Greece:** the ISO 3166 country is `GR`, the VAT prefix is `EL`. Both MUST
  be accepted as `country:`, `normalize` MUST emit `EL`, and `VatInfo.country`
  MUST report `GR`. This mismatch is a documented, long-standing source of
  breakage in ERP systems and gets its own vectors.
- **Northern Ireland:** `XI` is a VAT prefix, not an ISO country.
  `VatInfo.country` reports `GB`, `VatInfo.prefix` reports `XI`.
- **`normalize`** → prefix + body, upper-cased, spaces/dots/hyphens removed.
  **`format`** → the country's conventional grouping where one exists,
  otherwise the normalized form.
- **`parse` → `VatInfo`**: `country` (ISO 3166-1 alpha-2), `prefix` (as used
  for VAT), `number` (body without prefix) and `subtype` — a small enum that
  says which branch validated, because several countries encode genuinely
  different entities in one field: BG legal/person, CZ legal/special/individual,
  ES dni/nie/cif, LV legal/person, LT standard/temporary, GB
  standard/branch/government/healthAuthority, NL bsn/btwId. Consumers that care
  (invoice layout, reverse charge) get the answer without re-parsing.

**VIES seam.** The package performs no request. Verified live during research:
the Commission exposes a REST endpoint,
`GET https://ec.europa.eu/taxation_customs/vies/rest-api/ms/{MS}/vat/{number}`,
answering with `isValid`, `requestDate`, `userError`, `name`, `address`,
`requestIdentifier`, `originalVatNumber`, `vatNumber` and a `viesApproximate`
object. The package therefore exposes:

- `VatId.viesRequest(String value)` → `{ url, method, headers }`, or null when
  the value is not structurally valid or the country is outside VIES.
- `VatId.parseViesResponse(String body)` → `VatRegistration?` with `valid`,
  `name`, `address`, `requestDate` — a pure parser over a response the caller
  fetched.

Documented alongside: the endpoint is rate-limited and occasionally returns
`userError` values that mean "member state unavailable", not "invalid". Callers
must not treat an unavailable member state as a rejection. This is why the
offline structural check stays the primary gate.

Issue codes: `vatEmpty`, `vatBadFormat`, `vatBadChecksum`,
`vatUnknownCountry`, `vatAmbiguousCountry`.

### `Bic`

ISO 9362. Natural companion to `Iban`, and the smallest of the six.

- 8 or 11 characters: 4 letters institution, 2 letters country, 2
  alphanumeric location, optional 3 alphanumeric branch.
- The country segment MUST resolve via the existing `Country` table.
- **The second location character is meaningful** and gets parsed rather than
  ignored: `0` marks a test-and-training BIC, `1` a passive participant (a
  "BIC1", an institution not connected to the network), `2` a reverse-billing
  BIC. A test BIC in a production SEPA payload is a real, silent failure — so
  `parse` reports it and the README says to check it.
- `normalize` upper-cases and strips whitespace. `format` returns the 8- or
  11-character form; an `XXX` branch is **preserved**, not stripped — it is
  meaningful in SEPA payloads.
- `parse` → `BicInfo { institution, country, location, branch, kind }` with
  `kind` ∈ `{ live, test, passive, reverseBilling }`.
- `Bic.matchesIban(bic, iban)` → bool, comparing the country segments. Cheap,
  and it catches a common paste error.

Issue codes: `bicEmpty`, `bicBadLength`, `bicBadChars`, `bicUnknownCountry`.

### `Gtin`

GS1 GTIN-8/12/13/14 (EAN, UPC, ITF-14).

- Digits only, length ∈ {8, 12, 13, 14}, GS1 mod-10 check digit.
- `normalize` strips separators and keeps the input length; **no zero-padding**
  — the length is information the caller may need. `format` returns the
  normalized digits.
- `parse` → `GtinInfo { length, checkDigit, gtin14 }`, where `gtin14` is the
  zero-padded 14-digit form GS1 recommends for storage and comparison, so
  callers can match an EAN-13 against an ITF-14 without writing that
  themselves.
- **No GS1 prefix or country field.** A GS1 prefix identifies the member
  organisation that issued the number, not the origin of the goods, and every
  API that exposes it gets misread as country-of-origin. Leaving it out is the
  decision, and the doc comment says why.
- `Gtin.checkDigit(String body)` → the expected check digit for a body one
  digit short, so a UI can complete a partial scan.

Issue codes: `gtinEmpty`, `gtinBadChars`, `gtinBadLength`, `gtinBadChecksum`.

### `SocialSecurityNumber({required String country})`

Austria only in this release; the country parameter is required so DE and CH
can be added later without a breaking rename.

- **AT:** 10 digits `NNNP TTMMJJ` — three serial digits, a check digit at
  position 4, then the date of birth. The nine non-check digits are weighted
  left to right with **3, 7, 9, 5, 8, 4, 2, 1, 6**, the sum taken mod 11. A
  remainder of 10 is never issued: such a serial is skipped in favour of the
  next one, so the package MUST reject it rather than accept it as an edge case.
- The date part MUST be a real calendar date **only when it is one**:
  placeholder day/month components are in circulation for people whose birth
  date is unknown, and those are validly issued numbers. So the checksum
  decides validity, and `parse` reports `birthDate: null` for a placeholder
  date. This split is deliberate and gets its own vectors.
- `format` → `NNNP TTMMJJ` with one space. `parse` →
  `SocialSecurityInfo { serial, checkDigit, birthDate }` where `birthDate` is
  `SsnBirthDate { day, month, twoDigitYear }` or null.
- **The century is not inferred.** A two-digit year is genuinely ambiguous, and
  resolving it needs an age heuristic that belongs to the calling application.
  `parse` hands back the raw components; a consumer that needs a four-digit
  year applies its own rule. A library that guesses the century is how wrong
  birth dates get stored.

Issue codes: `ssnEmpty`, `ssnBadChars`, `ssnBadLength`, `ssnBadChecksum`,
`ssnBadDate`, `ssnUnknownCountry`.

### `CompanyRegister({required String country})`

Austria only. Up to six digits plus one check letter, written `FN 123456a`.

**The widely repeated "number mod 26 → letter" rule is wrong.** It fails on
three of four real Firmenbuchnummern taken from company imprints. The actual
algorithm — verified against those four plus the example shipped by an existing
checker — is:

1. Weight the digits **left to right** with `6, 4, 14, 15, 10, 1`. Shorter
   numbers use the leading weights, i.e. a five-digit number uses `6, 4, 14,
   15, 10`; it is **not** zero-padded on the left. Right-aligning the weights
   reproduces none of the samples.
2. Sum, take mod 17.
3. Index into `A B D F G H I K M P S T V W X Y Z` — 17 letters, with the
   confusable `C E J L N O Q R U` deliberately absent.

Verification data used (all published in company imprints):
`415772 f`, `187010 s`, `536480 t`, `512160 b`, plus the five-digit `92754 f`.
All five match; the mod-26 rule matches only `187010 s`, by coincidence.

Because only one of the samples has fewer than six digits, **implementation
MUST first collect at least two more real four- or five-digit numbers and
confirm the left-aligned weighting before the checksum is enabled.** If they
disagree, the type falls back to structure-only for short numbers and says so
in the README — a length-dependent false rejection on a company register field
is worse than a missing check.

- The canonical written form keeps the check letter lower-case, so this is the
  one type whose `normalize` does not upper-case: `normalize` → `123456a`,
  `format` → `FN 123456a`. The `FN` prefix is presentation; it is accepted on
  input but not stored.
- The 17-letter table is itself a validation rule: a `c` or `q` can never be a
  valid check letter.
- `parse` → `CompanyRegisterInfo { number, checkChar }`. **No court field** —
  the registering court is not encoded in the number and MUST NOT be guessed.

Issue codes: `companyRegisterEmpty`, `companyRegisterBadFormat`,
`companyRegisterBadChecksum`, `companyRegisterUnknownCountry`.

### `TaxNumber({required String country})`

Austria only. The Abgabenkontonummer: nine digits, written `12-345/6789` — a
two-digit Finanzamt number followed by seven digits of which the last is the
check digit.

- **The check is plain Luhn over all nine digits** (checksum ≡ 0 mod 10). The
  official description states it as
  `S = F + Q(A) + N₁ + Q(N₂) + N₃ + Q(N₄) + N₅ + Q(N₆)` with `Q(z)` the digit
  sum of `2z`, and `P = (80 − S) mod 10`; that is the Luhn algorithm written
  out. Verified against the documented worked example `98-123/4560`
  (S = 40, P = 0), which the existing `luhn` helper reproduces. The
  implementation reuses that helper rather than restating the formula.
- **The Finanzamt number is reported, never a rejection reason.** Austria
  reorganised its tax administration on 2021-01-01 into Finanzamt Österreich
  and Finanzamt für Großbetriebe; existing account numbers were frozen and
  keep their historical office prefix forever. Any bundled list of office
  numbers is therefore a snapshot that will be incomplete, and rejecting on it
  would refuse valid numbers from real documents. `parse` exposes
  `office` and a nullable `officeName`; `validate` looks only at the digits and
  the check digit. There is consequently **no** `taxNumberUnknownOffice` code.
- `format` → `12-345/6789`. `normalize` → the nine bare digits.
- `parse` → `TaxNumberInfo { office, officeName, number, checkDigit }`.

Issue codes: `taxNumberEmpty`, `taxNumberBadChars`, `taxNumberBadLength`,
`taxNumberBadChecksum`, `taxNumberUnknownCountry`.

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
  attributes, formats as the user types, validates on `blur`, and reports state
  through `options.onState({ state, normalized, issue })` where `state` is
  `'empty' | 'incomplete' | 'valid' | 'invalid'`. The returned function
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
dependency, and the package's platform neutrality is a deliberate property; the
README's Flutter mapping table stays the Dart-side answer. This asymmetry is
stated in `llms.txt` so it does not read as an oversight.

## Cross-language parity

The existing invariant holds: Dart and TS must not drift.

- One vector file per new type in `test/vectors/`: `vat_id.json`, `bic.json`,
  `gtin.json`, `social_security.json`, `company_register.json`,
  `tax_number.json`.
- `vat_id.json` needs at least one valid and one checksum-broken vector **per
  country**, drawn from published numbers — 29 prefixes, so this is the bulk of
  the test work and it is where a wrong weight table gets caught.
- New entries in `field_descriptor.json` and `format_partial.json` for all six,
  including the country-parameterised variants.
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
- Generated metadata: `vat_metadata.g.dart` + `js/src/data/vat-metadata.json`
  and the Finanzamt table, each with its generator under `tool/`.

Adding enum members to `IssueCode` is source-breaking for exhaustive Dart
switches. At 0.x that is acceptable; the CHANGELOG must call it out.

## Docs

`README.md` (twelve → eighteen types, the new `dom` section, the HTML mapping
table now pointing at `fieldAttrs`), `llms.txt` (same, plus the Dart/TS
asymmetry), `js/README.md`, `CHANGELOG.md` + `js/CHANGELOG.md`, new keywords
(`vat`, `ust-id`, `bic`, `swift`, `gtin`, `ean`, `barcode`) in both manifests,
and the package description in `pubspec.yaml` + `js/package.json`.

`doc/algorithms.md` gains a section per new type naming the standard or the
verification data — including the falsified Firmenbuch mod-26 rule, so nobody
"fixes" the implementation back to it later.

## Release

Version 0.11.0 in `pubspec.yaml` and `js/package.json` in the same commit.
Published to pub.dev and npm together; a version that exists on only one
registry breaks the parity promise the README makes.

Consumers integrate against a local link during development and switch to
`^0.11.0` before their branches merge.

## Candidates for later

Identifiers that came up during research and were deliberately left out:

- **BE enterprise number, HR OIB, CH UID, RO CUI** as first-class types. In
  each of these countries the VAT number *is* a general company identifier with
  a prefix, so a separate type would share the algorithm and add real value
  outside VAT.
- **EU OSS numbers** (`EU` + 9 digits) for one-stop-shop registrations.
- **GLN**, **EORI**, **Peppol participant IDs** for e-invoicing.
- **DE and CH social-security numbers**, so the country parameter earns its
  keep.
