# Changelog

## 0.12.0

**Breaking — social-security numbers with a serial below 100 are now rejected.**
The Austrian Laufnummer is only ever issued in the range 100-999, so its first
digit is never zero. Validation checked the mod-11 check digit alone, which let
through 90.909.091 numbers that cannot have been issued, `0000000000` among
them — a tenth of everything it accepted. `0000TTMMJJ` in particular is the
form written on Austrian paperwork to mean "insurance number unknown, birth
date follows", so this was the likeliest wrong answer in practice, not a
theoretical one. The new `ssnBadSerial` code is reported before the checksum,
so a number wrong on both counts reports the serial it cannot have rather than
a check-digit failure that would send you looking in the wrong place.

**`SocialSecurityInfo.birthDate` is documented for what it is.** No behaviour
changed. The field was described as null whenever the digits do not form a real
calendar date, which is accurate but reads as a promise that a non-null value is
the person's date of birth. It is not: someone whose birthday is unknown is
registered as 1 January or 1 July of their birth year, and that is an ordinary
calendar date no inspection can tell from a real one. § 358 ASVG is explicit
that the date carried in the number has no civil-status quality. Collect a date
of birth separately if you need one.


## 0.11.2

**Fix — Irish VAT IDs could not be typed.** The historical Irish form carries a
`+` or `*` in second position, which `validate` accepts but the field
descriptor's `allowedChars` did not list — so `formatPartial` deleted the
character again on every keystroke and the number was impossible to enter into
a field built from the descriptor.

**Swiss numbers with their usual suffix are accepted.**
`CHE-116.281.710 MWST` is how a Swiss UID is normally written (the marker says
the holder is VAT-registered) and is exactly what gets copied out of an
imprint; the suffix is now dropped instead of rejected. `HR/MWST`, `TVA` and
`IVA` likewise.

**Three more countries, each with its real check digit:** Norway (`NO`,
Organisasjonsnummer + `MVA`), Serbia (`RS`, ISO 7064 MOD 11,10) and Türkiye
(`TR`, Vergi Kimlik Numarası). 33 prefixes in total.

**UK government and health-authority numbers in their long form**
(`GD8888nnn` plus two check digits) are recognised; previously only the short
`GD001`/`HA599` spelling was.

Still rejected, and deliberately so for now: Liechtenstein, Iceland and the
EU one-stop-shop numbers (`EU…`/`IM…`). None of them carries a check digit, so
accepting them would mean introducing a structure-only tier — a design
decision rather than a patch, since this package promises that a valid result
means the arithmetic was verified.


## 0.11.1

- `VatId.prefixFor(country)` — the VAT prefix a country writes in front of its
  number (`ATU`, `CHE`, `EL`, `XI` and otherwise the ISO code), or null when the
  country has no VAT ID here. A form that shows the prefix beside the input, or
  re-prefixes a number when the user switches country, could not get at this;
  deriving it from the ISO code is wrong for four countries.


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
