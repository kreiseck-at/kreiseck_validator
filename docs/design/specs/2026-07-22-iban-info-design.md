# IBAN info extraction (`IbanInfo`) — Design

**Status:** approved for implementation planning
**Scope:** Stage 1 — structural extraction for all countries + Austrian enrichment
(bank name and BIC). Other countries' enrichment is out of scope.

## Goal

Extend the existing `Iban` type so it can return structured data parsed out of an
IBAN, mirroring the `Phone.parse` → `PhoneInfo` pattern. For every country whose
BBAN structure is known, split the IBAN into bank code, branch code and account
number. For Austrian IBANs, additionally resolve the bank name and BIC from a
bundled snapshot of the OeNB SEPA directory.

`validate` / `normalize` / `format` / `isValid` / `tryFormat` keep their current
behaviour and signatures. This is a purely additive change.

## Public API

New entry point on the existing `Iban` class:

```dart
IbanInfo? Iban.parse(String input);
```

Returns `null` when the input is not a valid IBAN (same acceptance rule as
`validate`). On success returns an `IbanInfo`:

```dart
class IbanInfo {
  final Country country;        // resolved from the country code
  final String checkDigits;     // characters 3-4
  final String? bankCode;       // BBAN bank identifier, null if country structure unknown
  final String? branchCode;     // BBAN branch identifier, null if country has none / unknown
  final String? accountNumber;  // remaining BBAN, null if country structure unknown
  final String? bankName;       // AT only, null otherwise / unknown BLZ
  final String? bic;            // AT only, null otherwise / unknown BLZ
  final String formatted;       // 4-group pretty form, e.g. 'AT72 1200 0002 3457 3201'
}
```

New file `lib/src/iban/iban_info.dart`, exported from
`lib/kreiseck_validator.dart` alongside the existing IBAN export.

### Example

```dart
final info = Iban.parse('AT72 1200 0002 3457 3201');
// country       → Country.at
// checkDigits   → '72'
// bankCode      → '12000'
// branchCode    → null
// accountNumber → '00234573201'
// bankName      → 'UniCredit Bank Austria AG'
// bic           → 'BKAUATWW'
// formatted     → 'AT72 1200 0002 3457 3201'
```

Note: BLZ `12000` is Bank Austria's real sort code. The classic textbook IBAN
`AT61 1904 3002 3457 3201` uses the fictional BLZ `19043`, which is not in the
OeNB directory — it parses with valid structure but `bankName` / `bic` are null.

## Behaviour rules

- Invalid IBAN → `parse` returns `null`.
- Valid IBAN, country **with** a BBAN structure → `bankCode` / `branchCode` /
  `accountNumber` filled per the structure (`branchCode` is `null` for countries
  that have no branch identifier, e.g. AT and DE).
- Valid IBAN, country **without** a BBAN structure in the bundled registry →
  structural fields are all `null`; `country` / `checkDigits` / `formatted` still
  filled.
- Valid AT IBAN, **known** BLZ → `bankName` / `bic` filled.
- Valid AT IBAN, **unknown** BLZ → `bankName` / `bic` are `null`, structural
  fields still filled.
- `bic` is the OeNB SWIFT code with the `XXX` head-office filler stripped
  (`BKAUATWWXXX` → `BKAUATWW`). Codes that carry a genuine branch identifier
  (not `XXX`) stay 11 characters, so `bic` is 8 or 11 characters.

## Data sources & generation

Two lookup tables, both produced by a Python generator and committed as generated
Dart, following the existing `tool/gen_phone_metadata.py` →
`lib/src/common/country.g.dart` pattern. Everything is an offline, dated snapshot;
no network access at runtime.

### a) BBAN structure (all countries)

Derived from the SWIFT IBAN Registry via the `schwifty` package (dev-only, added
to `tool/requirements.txt`), which bundles the registry. The generator enumerates
every ISO alpha-2 code from `pycountry` (already a dev dep) and calls
`schwifty.registry.get_iban_spec(cc)`; countries with a spec (126 in the pinned
version) contribute an entry. Per country we store the total IBAN length and the
BBAN-relative `(start, end)` ranges of the bank identifier and branch identifier,
read from `spec.positions[Component.BANK_CODE]` / `[Component.BRANCH_CODE]`
(a zero-width range, `start == end`, means "no branch"). The Dart side adds the
4-character `country + check` prefix to turn these into absolute string offsets.

This table also replaces the hard-coded `_dachLengths` map in `iban.dart`, so
length validation covers all registry countries instead of only DE/AT/CH.
Behaviour for the existing DE/AT/CH lengths must not change (DE=22, AT=20, CH=21).

### b) Austrian bank directory (BLZ → name + BIC)

Source: **OeNB SEPA-Zahlungsverkehrs-Verzeichnis (gesamt)**, CSV.

- URL: `https://www.oenb.at/docroot/downloads_observ/sepa-zv-vz_gesamt.csv`
- Encoding: ISO-8859-1. Delimiter: `;`. Updated daily by OeNB.
- Header row is preceded by 5 lines: 3 disclaimer lines, a
  `SEPA-Verzeichnis-Abfrage vom DD.MM.YYYY` line (use as snapshot date), and a
  blank line. The header row starts with `Kennzeichen;`.
- Parsed with `csv.DictReader` by column name: `Bankleitzahl`, `Bankenname`,
  `SWIFT-Code`. The generator builds a `{BLZ: (name, bic)}` map, keeping the
  first row per BLZ, skipping rows with an empty SWIFT code, and stripping a
  trailing `XXX` from the SWIFT code.
- ~860 Austrian sort codes carry a BIC in the current snapshot.
- Network note: fetch via `curl`/`urllib`; some environments lack CA certs for
  `urllib`, so the generator accepts a `--csv PATH` override to parse a locally
  downloaded copy.

**Licensing:** OeNB data is provided under the OeNB liability disclaimer and
copyright. We bundle a dated snapshot of factual bank-reference data and add an
OeNB attribution line to the existing `NOTICE` file, mirroring how the
libphonenumber-derived phone metadata is handled. The snapshot date and source
URL are written as a comment header in the generated Dart file.

### Tooling

- New `tool/gen_iban_metadata.py` → generates
  `lib/src/iban/iban_metadata.g.dart` containing both tables (BBAN structure map
  and the AT BLZ map), with a snapshot-date + source-URL header comment.
- `tool/requirements.txt` gains `schwifty` (dev-only, pinned).
- Extend `tool/gen_vectors.py` so `test/vectors/iban.json` gains the expected
  `parse` output fields, preserving cross-language vector consistency.

## Tests

- New `test/iban_info_test.dart` covering:
  - AT IBAN, known BLZ → correct split + enrichment
    (`AT72 1200 0002 3457 3201` → bankCode `12000`, bankName
    `UniCredit Bank Austria AG`, bic `BKAUATWW`).
  - AT IBAN, unknown BLZ (`AT61 1904 3002 3457 3201`, BLZ `19043`) → structural
    fields set, `bankName` / `bic` null.
  - Non-AT country with structure (`DE89 3704 0044 0532 0130 00`) → bankCode
    `37040044`, accountNumber `0532013000`, branchCode null, enrichment null.
  - Country without a structure entry → structural fields null, `country` /
    `checkDigits` / `formatted` set.
  - Invalid IBAN → `parse` returns `null`.
  - `_dachLengths` replacement does not change existing validation outcomes.
- `test/vectors/iban.json` extended with `parse` expectation fields; the existing
  vector test consumes them.

## Out of scope (later stages)

- Bank-name / BIC enrichment for countries other than AT (DE Bundesbank, CH SIX).
- `LEI` and other OeNB columns (available in the source, not surfaced now).
