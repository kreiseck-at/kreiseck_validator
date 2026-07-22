# Changelog

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
