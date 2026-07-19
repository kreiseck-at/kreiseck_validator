# Changelog

## 0.1.0 (unreleased)

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
