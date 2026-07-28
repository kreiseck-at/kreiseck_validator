# Changelog

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


## 0.10.0

- Added `FieldDescriptor` (`keyboard`, `autofill`, `capitalization`,
  `maxLength`, `example`, `allowedChars`) and a `fieldDescriptor(...)` method
  on every type, taking the same options as `validate`.
- Added `formatPartial(...)` on every type: as-you-type formatting that never
  throws and, for the nine grouping types, agrees with `format` on valid input.
- `PostalPattern` gained `example`, `charset` and `length`; the postal metadata
  table was regenerated. `length` (the canonical formatted length, separators
  included) is mechanically derived from each country's pattern, so
  `PostalCode.fieldDescriptor(country:).maxLength` and `formatPartial`'s
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

## 0.9.0

- `Imei` gains an opt-in `allowSv` option (default `false`, backward-compatible)
  accepting a 16-digit **IMEISV** (the 15-digit IMEI structure plus a 2-digit
  software version number) alongside the existing 15-digit Luhn IMEI. A
  16-digit value is never Luhn-checked — IMEISV has no check digit. `ImeiInfo`
  gains `softwareVersion` (set for a 16-digit IMEISV, `null` otherwise) and
  `checkDigit` becomes nullable (`null` for a 16-digit IMEISV, unchanged for a
  15-digit IMEI). With the default `allowSv == false`, every existing IMEI
  vector and behavior is unchanged.
- New `Host` module: validation, normalization, formatting and `parse` for a
  bare host — hostname (RFC 1123), IPv4 or IPv6 address — with an optional
  port. Classification tries IPv4, then IPv6, then hostname. A port is only
  recognized for IPv6 in the bracketed form (`[::1]:8080`); for hostname/IPv4
  a single trailing `:port` is split off. `Host.parse` returns a `HostInfo`
  (`host`, `type`, `port`, `hasPort`). More lenient than `Url` — no scheme
  required, accepts `localhost` and IP literals — and independent of it.
- Three new `IssueCode`s: `hostEmpty`, `hostBadFormat`, `hostBadPort`.

## 0.8.0

- Five new modules: `Imei`, `Iccid`, `MacAddress`, `Vin` and `PostalCode`,
  each with the standard `isValid` / `validate` / `normalize` / `format` (+
  `tryFormat`) API plus `parse` for structural extraction.
- `Imei`: 15-digit **Luhn** checksum, `parse` into an `ImeiInfo` (TAC, serial
  number, check digit, reporting-body identifier). IMEISV (16-digit) is out
  of scope.
- `Iccid`: 19- or 20-digit SIM identifiers (ITU-T E.118) starting with the
  telecom MII `89`; 20-digit ICCIDs carry a **Luhn** check digit, 19-digit
  ones don't. `parse` returns an `IccidInfo` resolving the issuing
  **country** from the embedded E.164 calling code.
- `MacAddress`: EUI-48/64 hardware addresses across colon, hyphen,
  Cisco-dot and bare notation, with `format(..., notation:)` conversion
  between them and `parse` exposing the OUI/NIC split plus the
  unicast/multicast and universal/local bits.
- `Vin`: ISO 3779 structure validation (17 chars, `I`/`O`/`Q` forbidden).
  `validate` is **structure-only** — the check digit is mandatory only for
  North American VINs — so `parse`'s `VinInfo` exposes `checkDigitValid`
  (ISO 3779 mod-11 weighted checksum) and the decoded **`modelYear`** from
  character 10, disambiguated by whether character 7 is a letter (2010-2039
  cycle) or a digit (1980-2009 cycle).
- `PostalCode`: a curated per-country pattern table covering **Europe plus
  Turkey (51 countries)**, with canonical per-country spacing (e.g. NL
  `1234ab` → `1234 AB`, PL `00950` → `00-950`, GB `sw1a1aa` → `SW1A 1AA`)
  and `parse` into a `PostalInfo`. `country` (ISO2) is required on every
  operation since a bare code is ambiguous across countries.
- Internal refactor: `CreditCard`'s Luhn checksum is now a small shared
  helper (`lib/src/common/luhn.dart`, `js/src/common/luhn.ts`) reused by
  `Imei` and `Iccid`; `CreditCard`'s own validation behavior is unchanged.
- Sixteen new `IssueCode`s: `imeiEmpty`, `imeiBadChars`, `imeiBadLength`,
  `imeiBadChecksum`; `iccidEmpty`, `iccidBadChars`, `iccidBadLength`,
  `iccidBadChecksum`; `macEmpty`, `macBadFormat`; `vinEmpty`, `vinBadChars`,
  `vinBadLength`; `postalEmpty`, `postalBadFormat`, `postalUnknownCountry`.

## 0.7.0

- New `LicensePlate` module: validation, normalization, formatting and
  `parse` for vehicle registration plates ("Kennzeichen") across **Austria,
  Germany, Switzerland, Croatia and Turkey** (`country: 'AT' | 'DE' | 'CH' |
  'HR' | 'TR'`).
- `LicensePlate.parse` returns a `PlateInfo` — district/canton/province code,
  the resolved region name (from a curated code → region table; `null` when
  the code is unrecognized), the serial part, a `PlateType` classification
  and the canonical `formatted` display form.
- Plates have no checksum: `validate` is a per-country grammar plus the
  region table. AT/DE accept a structurally valid but unlisted code (region
  `null`, still valid); CH/HR/TR require the code to be one of their known
  cantons/cities/provinces.
- `PlateType` classification (diplomatic, authority, military, temporary,
  seasonal, historic, electric) is rule-based per country and **best-effort**
  — it never blocks validation and defaults to `standard` when a country's
  special forms aren't identifiable from the plate text alone.
- Five new `IssueCode`s: `plateEmpty`, `plateBadChars`, `plateBadFormat`,
  `plateUnknownCountry`, `plateAmbiguousCountry`.
- A TypeScript port, `@kreiseck/validator`, now lives under `js/`; parity with
  this package is enforced by the shared vectors in `test/vectors/`.

## 0.6.0

- `IbanCountry.of(code)` / `IbanCountry.values` expose each country's IBAN
  format — total length, bank / branch / account field lengths, whether a
  branch code exists, and a valid example IBAN (canonical for AT/DE/CH,
  deterministically generated for the rest).

## 0.5.0

- `Iban.parse` now resolves `bankName` and `bic` for German and Swiss IBANs, in
  addition to Austrian ones, from bundled snapshots of the Deutsche Bundesbank
  Bankleitzahlen directory and the SIX Bank Master.
- The internal bank-enrichment table is now country-keyed (`AT` / `DE` / `CH`).

## 0.4.0

- `Iban.parse` returns an `IbanInfo` with the country, check digits and
  bank / branch / account codes for every country whose BBAN layout is known
  (SWIFT IBAN Registry). Austrian IBANs additionally resolve the bank name and
  BIC from a bundled snapshot of the OeNB SEPA directory.
- IBAN length validation now covers all registry countries, not only DE/AT/CH.

## 0.3.0

- Global phone support: validation, normalization and formatting for every
  country, derived from libphonenumber (Apache-2.0; see NOTICE).
- `Country` now covers all countries with uniform metadata: `iso2`,
  `callingCode`, `displayName`, `flag`, and synthetic `example` numbers.
  Look up via `Country.fromIso2` / `Country.fromCallingCode`; enumerate via
  `Country.values`. **Breaking:** `Country` changed from a 3-value enum to a
  class; only `Country.de/at/ch` remain as named constants.
- Uniform, strict validation (`possibleLengths` + national pattern) with a new
  `IssueCode.phoneInvalid` for structural mismatches.
- AT/DE/CH display formatting re-baselined to libphonenumber grouping.
- Austrian type classification unchanged; other countries report
  `PhoneNumberType.unknown`.

## 0.2.0

- `Phone.type` and `Phone.parse` (`PhoneInfo`): Austrian number-type
  classification (mobile, landline, VoIP, freephone, shared-cost, premium,
  corporate) from the public RTR numbering plan.
- Type-aware Austrian formatting: `Phone.format` now uses the geographic
  area-code length for landlines (e.g. `01 …` Vienna, `0316 …` Graz);
  mobile output is unchanged.

## 0.1.1

- Add a runnable `example/` covering all five types.

## 0.1.0

- Initial release, zero runtime dependencies:
  - `Email`: syntax validation, trim/lowercase normalization, offline
    typo-domain suggestions for popular providers.
  - `Phone`: E.164 and DACH (DE/AT/CH) national validation, normalization
    to E.164, national/international display formatting.
  - `Url`: http/https scheme, host and TLD plausibility checks,
    normalization (scheme, lower-case host, trailing slash) and a
    compact display format.
  - `Iban`: Mod-97 checksum validation with DACH (DE/AT/CH) length
    checks, upper-case normalization and 4-block formatting.
  - `CreditCard`: Luhn checksum and per-network length validation,
    network detection (Visa/Mastercard/Amex/Discover), digits-only
    normalization and network-typical block formatting.
  - Shared `ValidationResult`/`Valid`/`Invalid`/`ValidationIssue`/
    `IssueCode` result model across all five types.
