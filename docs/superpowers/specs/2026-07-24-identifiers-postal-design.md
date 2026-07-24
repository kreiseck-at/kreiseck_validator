# Identifier + postal-code validators (IMEI/ICCID/MAC/VIN/PostalCode) — Design

**Status:** approved for implementation planning
**Applies to both packages:** Dart `kreiseck_validator` and TS `@kreiseck/validator`,
built together, verified against shared JSON vectors.

## Goal

Add five new modules — `Imei`, `Iccid`, `MacAddress`, `Vin`, `PostalCode` —
each with the standard four-operation API plus `parse` for structural
extraction. Scope is **checksum/format validation + structural parse only** — NO
external/licensed databases (no IMEI-TAC→brand, no MAC OUI→vendor, no
postal→city). The one algorithmic enrichment explicitly wanted: **`Vin.parse`
computes the model year** from position 10.

## Shared additions

- **Luhn helper:** IMEI and ICCID reuse the Luhn checksum. Extract the existing
  credit-card Luhn into a small shared internal helper (Dart:
  `lib/src/common/luhn.dart`; TS: `js/src/common/luhn.ts`) used by CreditCard,
  Imei, Iccid. Behaviour of CreditCard must not change.
- **New IssueCodes** (identical Dart enum + TS union): `imeiEmpty`,
  `imeiBadChars`, `imeiBadLength`, `imeiBadChecksum`; `iccidEmpty`,
  `iccidBadChars`, `iccidBadLength`, `iccidBadChecksum`; `macEmpty`,
  `macBadFormat`; `vinEmpty`, `vinBadChars`, `vinBadLength`; `postalEmpty`,
  `postalBadFormat`, `postalUnknownCountry`.
- Each module is exported from both barrels and (TS) gets a subpath export
  (`@kreiseck/validator/imei`, `/iccid`, `/mac-address`, `/vin`, `/postal-code`)
  + a tsup entry, following the existing per-module pattern.

## Modules

### Imei — International Mobile Equipment Identity
- **Validate:** normalize = strip non-digits; must be exactly **15 digits**;
  Luhn checksum over all 15 (last digit is the check). Errors: `imeiEmpty` /
  `imeiBadChars` (non-digit after strip) / `imeiBadLength` (≠15) /
  `imeiBadChecksum`.
- **parse → `ImeiInfo`:** `{ tac: first 8, serialNumber: next 6, checkDigit:
  last, reportingBodyIdentifier: first 2 of tac }`.
- `format` = the compact 15 digits (or grouped `AA-BBBBBB-CCCCCC-D`); `normalize`
  = compact digits. IMEISV (16-digit, no checksum) is out of scope.

### Iccid — SIM card identifier (ITU-T E.118)
- **Validate:** strip non-digits; **19 or 20 digits**; must start with `89`
  (telecom MII). When length is 20, the last digit is a Luhn check → validate
  it; when 19, no check digit. Errors: `iccidEmpty` / `iccidBadChars` /
  `iccidBadLength` / `iccidBadChecksum`.
- **parse → `IccidInfo`:** `{ mii: '89', country: resolved from the E.164 code
  after `89` (best-effort longest-match against the phone module's
  calling-code map — REUSE `Country.fromCallingCode` / the calling-code table),
  issuerIdentifier, checkDigit: last digit if length 20 else null }`.
  `country` is the resolved `Country` (or null if unresolved).

### MacAddress — EUI-48 / EUI-64 hardware address
- **Accepted notations:** colon `AA:BB:CC:DD:EE:FF`, hyphen `AA-BB-…`, Cisco dot
  `AABB.CCDD.EEFF`, and bare `AABBCCDDEEFF`. **12 hex** (EUI-48) or **16 hex**
  (EUI-64). Case-insensitive.
- **Validate:** input matches one recognized notation with the right hex count.
  Errors: `macEmpty` / `macBadFormat`.
- **normalize:** canonical lower-case colon-separated (e.g. `aa:bb:cc:dd:ee:ff`).
- **format(input, { notation })** where notation ∈ `colon | hyphen | dot | bare`
  (default colon), optional upper-case; throws on invalid.
- **parse → `MacInfo`:** `{ oui: first 3 octets, nic: remaining octets,
  isUnicast, isMulticast (LSB of first octet), isUniversal, isLocal (2nd LSB of
  first octet), type: 'eui48' | 'eui64' }`.

### Vin — Vehicle Identification Number (ISO 3779)
- **Charset:** 17 chars from `A-HJ-NPR-Z0-9` (letters `I`, `O`, `Q` are
  forbidden). **Validate = structure only:** exactly 17 valid chars. Errors:
  `vinEmpty` / `vinBadChars` (contains I/O/Q or other) / `vinBadLength` (≠17).
  The check digit is **NOT** enforced by `validate` (mandatory only in North
  America; European VINs often have no valid check digit) — its result is
  exposed in `parse` instead.
- **parse → `VinInfo`:** `{ wmi: chars 1-3, vds: chars 4-9, vis: chars 10-17,
  checkDigit: char 9, checkDigitValid: bool, modelYear: int, plantCode: char 11 }`.
  - `checkDigitValid`: transliterate each char to its value, apply weights
    `[8,7,6,5,4,3,2,10,0,9,8,7,6,5,4,3,2]`, sum mod 11 (10 → `X`), compare to
    char 9.
  - **`modelYear`**: decode char 10 via the standard code table (1980=A … 2000=Y,
    2001=1 … 2009=9, then the 30-year cycle repeats), disambiguated by
    position 7: if char 7 is a **letter** → the 2010–2039 cycle, if a **digit**
    → the 1980–2009 cycle. Return the resolved calendar year.
- `normalize` = upper-case 17 chars; `format` = the normalized VIN.

### PostalCode — European postal codes + Turkey
- **Per-country format table:** a curated `country → { pattern, canonical
  format }` map for European countries + `TR` (~50 entries), from the public
  i18n postal-pattern data (Google libaddressinput format rules; patterns are
  facts). Countries without a postal-code system are marked (validation of a
  non-empty code for them fails / or accepts empty per the data).
- **API takes `{ country }`** (ISO2, required — a bare code is ambiguous across
  countries). `validate(input, { country })`: unknown country →
  `postalUnknownCountry`; empty → `postalEmpty`; pattern mismatch →
  `postalBadFormat`.
- **normalize / format:** canonical per country (e.g. NL `1234AB`→`1234 AB`,
  GB `sw1a1aa`→`SW1A 1AA`, PL `12345`→`12-345`, PT `1234567`→`1234-567`).
- **parse → `PostalCodeInfo`:** `{ country, code: normalized }`. No city/region
  lookup (that is the database we deliberately exclude).

## Data & generation

The only bundled data is the PostalCode per-country pattern table. A small
generator `tool/gen_postal_metadata.py` (stdlib-only) emits it to Dart
(`lib/src/postal_code/postal_metadata.g.dart`, const map) and TS
(`js/src/data/postal-metadata.json`) in one run — same single-source-of-truth
pattern as the plate/iban generators. IMEI/ICCID/MAC/VIN need no bundled data
(pure algorithms; the VIN year-code table is a small in-code constant).

## Conformance

Shared vectors `test/vectors/{imei,iccid,mac,vin,postal_code}.json`, consumed by
both `test/vectors_test.dart` and new TS `*.conformance.spec.ts` files. Each
carries `input`, optional options (`country` for postal; `notation` for mac
format), and expected `isValid` / `code` / `normalized` / `format` / a `parse`
object. Include real-world valid examples (a real IMEI passing Luhn, a real VIN
with a known model year, MACs in each notation, postal codes for a spread of
countries) and invalid ones (bad checksum, wrong length, I/O/Q in VIN, wrong
postal format).

## Staged delivery

One plan, one module per stage, each landing in **both** languages + its
vectors:
1. Shared Luhn helper (refactor CreditCard to use it) + **Imei**.
2. **Iccid** (reuses Luhn + the calling-code map).
3. **MacAddress**.
4. **Vin** (incl. `checkDigitValid` + `modelYear`).
5. **PostalCode** (+ the postal generator, Europe + TR).
6. Docs (both READMEs, CHANGELOG, `doc/algorithms.md`), version bump to `0.8.0`
   in both packages.

Each stage is independently shippable.

## No-footprint

No AI/assistant/tooling references anywhere — code, comments, data, docs, commit
messages, package metadata — in either package. The generated-file header is the
only allowed provenance line.

## Version

Both packages bump to `0.8.0` when the modules ship.

## Out of scope

- Enrichment DBs: IMEI-TAC→brand/model (GSMA, licensed), MAC-OUI→vendor (IEEE,
  ~35k), postal→city/region (postal DBs). These are deliberate future stages.
- IMEISV (16-digit), VIN manufacturer/plant name lookup, ICCID operator lookup.
- Module naming: `Imei`, `Iccid`, `MacAddress`, `Vin`, `PostalCode` (English,
  consistent with the existing modules).
