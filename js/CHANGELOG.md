# Changelog

## 0.11.0

Six new types and, for the TypeScript port, a `dom` subpath.

- **`VatId`** — VAT identification numbers for the 27 EU member states plus
  Switzerland, the United Kingdom and Northern Ireland. Every one of them is
  verified with its real check-digit algorithm; there is no structure-only
  tier, and the dispatch throws rather than silently degrading. `parse` reports
  the ISO country, the tax-side prefix (`EL` for Greece, `XI` for Northern
  Ireland) and a `subtype` for the countries that pack several identifiers into
  one field. `viesRequest` / `parseViesResponse` are an offline seam around the
  EU's VIES service — the package still makes no network call.
- **`Bic`** — ISO 9362, with the country segment checked against the bundled
  country table and the location code's second character parsed into
  `BicInfo.kind`, so a test-and-training BIC cannot slip into a payment file
  unnoticed. `Bic.matchesIban` cross-checks a BIC against an IBAN.
- **`Gtin`** — GS1 mod-10 for EAN-8, UPC-A, EAN-13 and ITF-14, plus the
  zero-padded `gtin14` form and `Gtin.checkDigit` for completing a scan.
- **`SocialSecurityNumber`** — Austria. The checksum alone decides validity:
  months 13-15 and placeholder birthdays are genuinely issued, so `birthDate`
  is simply null for them. The century is never inferred.
- **`CompanyRegister`** — Austria. The Firmenbuchnummer check letter, verified
  against twelve published numbers. The widely repeated `mod 26` rule turns out
  to be wrong; see `doc/algorithms.md`.
- **`TaxNumber`** — Austria. The Abgabenkontonummer's Luhn check digit and
  `12-345/6789` formatting. The Finanzamt number is reported but never used to
  reject.
- Every new type ships `fieldDescriptor` and `formatPartial` like the rest.

**Breaking-ish:** `IssueCode` gained 27 members. Adding enum values is
source-breaking for an exhaustive Dart `switch` over it — add a default branch
if you have one.

The TypeScript port additionally gains:

- **`@kreiseck/validator/dom`** — `fieldAttrs(descriptor)` maps a
  `FieldDescriptor` onto HTML input attributes (the mapping that until now
  existed only as a table in the README), `filterValue` applies its character
  filter, and `bindInput(el, …)` binds a live element: attributes, as-you-type
  formatting with caret preservation, and an `empty` / `valid` / `invalid`
  callback on blur. It is a separate subpath and is not re-exported from the
  main entry, which stays platform-neutral.


## 0.10.0

- Added `FieldDescriptor` (`keyboard`, `autofill`, `capitalization`,
  `maxLength`, `example`, `allowedChars`) and a `fieldDescriptor(...)` method
  on every type, taking the same options as `validate`.
- Added `formatPartial(...)` on every type: as-you-type formatting that never
  throws and, for the nine grouping types, agrees with `format` on valid input.
- `PostalPattern` gained `example`, `charset` and `length`; the postal metadata
  table was regenerated. `length` (the canonical formatted length, separators
  included) is mechanically derived from each country's pattern, so
  `PostalCode.fieldDescriptor({ country }).maxLength` and `formatPartial`'s
  truncation are now set for all 51 countries instead of only the 23 with a
  curated `example`.
- `Phone.fieldDescriptor(...).example` is now always `null`: the previous
  synthetic construction (`+{callingCode}1234567`) produced a plausible-
  looking but fabricated example for most countries and `null` for the rest,
  contradicting the never-invented-example principle applied to postal codes.
- `Host.formatPartial` no longer drops non-ASCII characters (e.g.
  `münchen.de` previously became the different, plausible-looking
  `mnchen.de`); it now leaves them in place since the module is ASCII-only
  and would reject the value either way.
- `Phone.formatPartial`'s options type no longer structurally accepts an
  `international` property (it was silently ignored — the value is always
  derived from a leading `+`).
