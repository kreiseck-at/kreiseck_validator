# Global Phone Metadata — Design

Date: 2026-07-22
Status: Approved (brainstorming); pending implementation plan
Target version: 0.3.0 (contains a breaking change to `Country`)

## Goal

Expand phone support from the DACH scope (DE/AT/CH) to **every country**, in a
single **uniform** model. Every country — DACH or not — gets:

- correct national + international **formatting**,
- strict **validation** (per-country national-number pattern + possible lengths),
- a synthetic **example number** (explicitly not a real subscriber number),
- a **flag** emoji,
- basic metadata (`iso2`, `callingCode`, `name`).

The deep **type classification** (mobile/landline/regional/area-code semantics)
stays a *data layer*: currently filled only for AT, `unknown` elsewhere. Same
mechanism everywhere, different data depth — not a structural special case.

Non-goals (YAGNI for now): localized country names (English name only),
type classification for non-AT countries, runtime auto-update of metadata,
carrier/timezone/geocoding data.

## Data source & licensing

Metadata is **derived from libphonenumber** (Apache-2.0), which is compatible
with this package's Apache-2.0 license.

- **Build-time only:** a generator uses the `phonenumbers` PyPI package (the
  Python port of libphonenumber, Apache-2.0), pinned to a specific version.
  It is a dev dependency of the generator, never a runtime dependency.
- **Runtime stays zero-dep:** the generator emits committed data; no network,
  no file IO, no third-party runtime package.
- **Attribution:** add a `NOTICE` file:
  `"Contains data derived from libphonenumber (© The libphonenumber Authors,
  licensed under Apache-2.0), version X.Y.Z."` The pinned version is recorded in
  the generator and the `NOTICE`. No Google trademarks are used in naming.
- **Version pinning:** metadata is regenerated deliberately (never auto), so
  test vectors stay stable across libphonenumber releases.

## Data pipeline

New tool: `tool/gen_phone_metadata.py`.

Per country it extracts:
- `iso2`, `callingCode`, English `name`,
- `possibleLengths` (national),
- national-number **validation pattern** (regex),
- **format patterns** (each: leading-digits condition, match pattern, output
  format), for national and international rendering,
- **example numbers** per type (mobile preferred as default, fixed-line fallback).

Outputs:
- `lib/src/phone/data/metadata.json` — **canonical, cross-language source**.
  The future npm port reads this same JSON.
- `lib/src/phone/data/metadata.g.dart` — generated Dart constant embedding the
  data (no runtime file IO).
- Regenerates/extends the phone test vectors (see Testing).

The generator is reproducible: same pinned `phonenumbers` version → identical
output.

## Country model (uniform)

`Country` changes from a 3-value hand-written enum to a generated type covering
**all ~245 countries**, every entry exposing the same fields:

- `iso2`, `callingCode`, `name`, `flag`, `example`
- lookup helpers: `Country.values`, `Country.fromIso2(String)`,
  `Country.fromCallingCode(String)`
- existing constants `Country.de`, `Country.at`, `Country.ch` remain by name.

`flag` is derived from `iso2` via Unicode regional-indicator symbols
(`0x1F1E6 + (letter - 'A')` per letter) — a small local function, no imported
code.

`example` is the synthetic libphonenumber example number for the country,
exposed in E.164, national, and international formatting. Default source type is
mobile, falling back to fixed-line when a country has no mobile example.

**Breaking change:** the shape/size of the public `Country` type changes. Named
DACH constants are preserved, but downstream code that assumed a 3-value enum may
need updates. Hence the 0.3.0 bump.

## Formatter & validation (one mechanism for all)

- **Validation:** for any country, check `possibleLengths` then the national
  validation regex. Uniform across DACH and the rest of the world. The existing
  `IssueCode` values (`phoneTooShort`, `phoneTooLong`, `phoneUnknownCountry`,
  `phoneAmbiguousCountry`, `phoneBadChars`, `phoneEmpty`) are reused; add codes
  only if a genuinely new failure mode appears (e.g. pattern mismatch distinct
  from length).
- **Formatting:** a single generic, data-driven formatter renders national and
  international forms from the format patterns — for every country.

### AT re-baselining decision

`AtNumbering` currently produces AT output pinned in vectors. The formatter is
**unified** (all countries go through the generic pattern-driven formatter). The
**type classification** part of `AtNumbering` is kept as an additional data layer
(feeding `Phone.type` / `PhoneInfo.type`).

- If the generic formatter reproduces the current AT output exactly → seamless,
  keep vectors.
- If minor differences appear → **re-baseline the AT vectors against
  libphonenumber** (the authoritative source), and note the change in the
  changelog. Formatting differences are resolved in favor of libphonenumber;
  classification behavior is preserved.

Classification stays AT-only for now; other countries return
`PhoneNumberType.unknown` — same call, no data yet.

## Public API surface (additions)

- `Country`: `iso2`, `callingCode`, `name`, `flag`, `example`, `values`,
  `fromIso2`, `fromCallingCode`.
- `Phone.validate/isValid/normalize/format/tryFormat/type/parse` — unchanged
  signatures, now working for all countries.
- `PhoneInfo` — unchanged fields; `country` now carries the richer metadata via
  the `Country` value (so flag/example are reachable through it).

## Testing & vectors

- Extend JSON vectors with a spread of countries (~20–30) covering: `validate`
  (valid + invalid by length and by pattern), `format` (national +
  international), and `example` correctness.
- Keep existing DACH vectors; re-baseline AT only if the unified formatter output
  differs (see AT decision above).
- All vectors are reproducibly generated by the tool. Cross-language parity is
  guaranteed by both ports consuming `metadata.json`.

## Rollout

- Version `0.3.0`.
- `CHANGELOG.md`: global country support, uniform validation/formatting, flags,
  example numbers; note the `Country` breaking change and any AT re-baseline.
- Docs (`doc/algorithms.md` / `README.md`): describe the generic
  pattern-driven formatter and validation, and the libphonenumber-derived data
  with attribution.

## Open questions / risks

- **Data size:** full per-country validation regex + format patterns increase
  the embedded constant size. Acceptable; still zero runtime deps. Monitor the
  generated file size and tree-shakeability.
- **AT output drift:** handled by the re-baseline decision above.
- **`Country` breaking change:** downstream consumers on 0.2.x must adapt; called
  out in the changelog and version bump.
