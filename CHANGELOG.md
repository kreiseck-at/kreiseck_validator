# Changelog

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
