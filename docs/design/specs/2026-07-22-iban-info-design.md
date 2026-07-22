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
  final String? bic;            // AT only, 8-char BIC, null otherwise / unknown BLZ
  final String formatted;       // 4-group pretty form, e.g. 'AT61 1904 3002 3457 3201'
}
```

New file `lib/src/iban/iban_info.dart`, exported from
`lib/kreiseck_validator.dart` alongside the existing IBAN export.

### Example

```dart
final info = Iban.parse('AT61 1904 3002 3457 3201');
// country       → Country.at
// checkDigits   → '61'
// bankCode      → '19043'
// branchCode    → null
// accountNumber → '00234573201'
// bankName      → 'UniCredit Bank Austria AG'
// bic           → 'BKAUATWW'
// formatted     → 'AT61 1904 3002 3457 3201'
```

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
- `bic` is normalised to 8 characters: the OeNB SWIFT code carries an `XXX`
  branch filler (`BKAUATWWXXX`), which is stripped.

## Data sources & generation

Two lookup tables, both produced by a Python generator and committed as generated
Dart, following the existing `tool/gen_phone_metadata.py` →
`lib/src/common/country.g.dart` pattern. Everything is an offline, dated snapshot;
no network access at runtime.

### a) BBAN structure (all countries)

Derived from the SWIFT IBAN Registry. Per country: total IBAN length, and the
position + length of the bank identifier and of the branch identifier. This table
drives the structural split for every country and also replaces the currently
hard-coded `_dachLengths` map in `iban.dart`, so length validation covers all
registry countries instead of only DE/AT/CH. Behaviour for countries already in
`_dachLengths` must not change.

Small table (~90 entries).

### b) Austrian bank directory (BLZ → name + BIC)

Source: **OeNB SEPA-Zahlungsverkehrs-Verzeichnis (gesamt)**, CSV.

- URL: `https://www.oenb.at/docroot/downloads_observ/sepa-zv-vz_gesamt.csv`
- Encoding: ISO-8859-1. Delimiter: `;`. Updated daily by OeNB.
- File starts with 3 disclaimer lines, then a line
  `SEPA-Verzeichnis-Abfrage vom DD.MM.YYYY` (use this as the snapshot date), then
  a blank line, then the header row.
- Relevant columns: `Bankleitzahl` (col 3), `Bankenname` (col 7),
  `SWIFT-Code` (col 19). The generator builds a `{BLZ: (name, bic8)}` map,
  stripping the trailing `XXX` from the SWIFT code.
- ~600–700 active Austrian sort codes.

**Licensing:** OeNB data is provided under the OeNB liability disclaimer and
copyright. We bundle a dated snapshot of factual bank-reference data and add an
OeNB attribution line to the existing `NOTICE` file, mirroring how the
libphonenumber-derived phone metadata is handled. The snapshot date and source
URL are written as a comment header in the generated Dart file.

### Tooling

- New `tool/gen_iban_metadata.py` → generates
  `lib/src/iban/iban_metadata.g.dart` containing both tables (BBAN structure map
  and the AT BLZ map), with a snapshot-date + source-URL header comment.
- Extend `tool/gen_vectors.py` so `test/vectors/iban.json` gains the expected
  `parse` output fields, preserving cross-language vector consistency.

## Tests

- New `test/iban_info_test.dart` covering:
  - AT IBAN, known BLZ → correct `bankCode` / `bankName` / `bic`
    (e.g. Bank Austria → `BKAUATWW`).
  - AT IBAN, unknown BLZ → structural fields set, `bankName` / `bic` null.
  - Non-AT country with structure (e.g. a DE IBAN) → correct bank-code split,
    `bankName` / `bic` null.
  - Country without a structure entry → structural fields null, `country` /
    `checkDigits` / `formatted` set.
  - Invalid IBAN → `parse` returns `null`.
  - `_dachLengths` replacement does not change existing validation outcomes.
- `test/vectors/iban.json` extended with `parse` expectation fields; the existing
  vector test consumes them.

## Out of scope (later stages)

- Bank-name / BIC enrichment for countries other than AT (DE Bundesbank, CH SIX).
- `LEI` and other OeNB columns (available in the source, not surfaced now).
