# IBAN bank enrichment for DE and CH — Design

**Status:** approved for implementation planning
**Builds on:** `2026-07-22-iban-info-design.md` (the AT enrichment / `IbanInfo`
feature already shipped in 0.4.0). This stage extends bank-name + BIC
resolution to German and Swiss IBANs, from first-party sources.

## Goal

Populate `IbanInfo.bankName` and `IbanInfo.bic` for German (DE) and Swiss (CH)
IBANs, in addition to the Austrian coverage already present. No public API
change: `Iban.parse` keeps its signature and `IbanInfo` its fields — only the
enrichment coverage grows.

## Data model change (generalisation)

Today the enrichment is Austria-specific: an `AtBank` type, a single
`const Map<String, AtBank> kAtBanks`, and a hard-coded `code == 'AT'` branch in
`Iban.parse`. Generalise this so any country can carry a bank directory:

- Rename `AtBank` → `Bank` (fields unchanged: `String name`, `String bic`).
- Replace `kAtBanks` with a nested map:
  `const Map<String, Map<String, Bank>> kBanks` — outer key is the ISO2 country
  code, inner key is the national bank code (BLZ / BC number), value is `Bank`.
  Populated for `AT`, `DE`, `CH`.
- In `Iban.parse`, replace the `if (code == 'AT' && bankCode != null)` block with
  a country-agnostic lookup:
  ```dart
  if (bankCode != null) {
    final bank = kBanks[code]?[bankCode];
    if (bank != null) {
      bankName = bank.name;
      bic = bank.bic;
    }
  }
  ```
  This removes the AT special-case and scales to any future country.

`IbanInfo` is untouched. The `bic` normalisation rule is unchanged: the `XXX`
head-office filler is stripped (8-char result), genuine branch BICs stay 11.

## Data sources & generation

Both are first-party, publicly downloadable, and parsed by the existing
`tool/gen_iban_metadata.py` generator, which is extended to emit the nested
`kBanks` map instead of the flat `kAtBanks`. AT keeps its OeNB source unchanged.
All snapshots stay offline-bundled with no runtime dependency.

### DE — Deutsche Bundesbank Bankleitzahlendatei (CSV)

- Landing page: `https://www.bundesbank.de/de/startseite/bankleitzahlendateien-csv--926194`.
  The actual file is a ZIP whose blob URL carries a per-release hash that rotates
  quarterly, e.g.
  `https://www.bundesbank.de/resource/blob/926194/<hash1>/<hash2>/blz-aktuell-csv-zip-data.zip`.
  The generator fetches the landing page and extracts the current
  `…/blz-aktuell-csv-zip-data.zip` link with a regex, then downloads + unzips it
  (`BLZ.CSV`). Fallback: `--de-csv PATH` to parse a locally supplied `BLZ.CSV`.
- `BLZ.CSV`: ISO-8859-1, `;`-delimited, every field double-quoted. Columns:
  `Bankleitzahl;Merkmal;Bezeichnung;PLZ;Ort;Kurzbezeichnung;PAN;BIC;`
  `Prüfzifferberechnungsmethode;Datensatznummer;Änderungskennzeichen;`
  `Bankleitzahllöschung;Nachfolge-Bankleitzahl`.
- Rule: keep rows where `Merkmal == '1'` (Hauptstelle / head office) with a
  non-empty `BIC`; map `Bankleitzahl` (8 digits) → (`Bezeichnung`, BIC). First
  row per BLZ wins. ~3500 banks. `XXX` filler stripped.
- Snapshot date: the landing page states a `gültig vom DD.MM.YYYY` validity
  start; capture it for the generated-file header (fall back to "unknown").

### CH — SIX Bank Master (CSV)

- URL (stable, versioned, free/public):
  `https://api.six-group.com/api/epcd/bankmaster/v3/bankmaster_V3.csv`.
  Fallback: `--ch-csv PATH`.
- Format: UTF-8, `;`-delimited, CRLF, unquoted. Relevant columns:
  `IID/QR-IID` (the bank clearing / BC number, 3–5 digits),
  `Name of bank/institution`, `BIC`, and a `Valid on` date column.
- Rule: for each row with a non-empty `BIC`, zero-pad `IID/QR-IID` to 5 digits
  (to match the 5-digit bank-code field in a CH IBAN) → (name, BIC). First row
  per padded code wins. ~1100 entries. `XXX` filler stripped.
- Snapshot date: the `Valid on` column (e.g. `2026-07-23`).

### Licensing

Add attribution lines to `NOTICE` for the Deutsche Bundesbank Bankleitzahlen
directory and the SIX Bank Master, alongside the existing OeNB and schwifty
lines. Snapshot dates + source URLs go in the generated file's header comment.

## Behaviour consequences

- DE/CH IBANs with a known bank code now resolve `bankName` / `bic`; unknown
  codes stay null; structural fields unchanged.
- The DE example in the earlier feature (`DE89 3704 0044 0532 0130 00`, BLZ
  `37040044`) now enriches to `Commerzbank` / `COBADEFF` — previously null. The
  existing DE parse test and the `test/vectors/iban.json` DE vector must be
  updated to expect this enrichment.
- AT behaviour is unchanged (still OeNB, `12000` → `UniCredit Bank Austria AG` /
  `BKAUATWW`).

## Tests

- `test/iban_metadata_test.dart`: update AT assertions from `kAtBanks['12000']`
  to `kBanks['AT']!['12000']`; add `kBanks['DE']!['37040044']` →
  (`Commerzbank`, `COBADEFF`) and `kBanks['CH']!['00100']` →
  (`Schweizerische Nationalbank`, `SNBZCHZZ`).
- `test/iban_info_test.dart`: update the DE parse test to expect
  `bankName == 'Commerzbank'`, `bic == 'COBADEFF'`; add a CH parse test using
  `CH25 0010 0000 0012 3456 7` (bank code `00100`, account `000001234567`) →
  bankName `Schweizerische Nationalbank`, bic `SNBZCHZZ`.
- `test/vectors/iban.json`: update the DE vector's `parse` block to the enriched
  values; optionally add a CH vector.

## Out of scope

- Enrichment for countries other than AT/DE/CH.
- Branch-level (non-head-office) BIC selection for DE — head office only.
- Additional SIX/Bundesbank columns (LEI, addresses, etc.).

## Version

Release `0.5.0` (additive data coverage; no API change).
