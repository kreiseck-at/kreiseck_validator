# Per-country IBAN descriptor (`IbanCountry`) — Design

**Status:** approved for implementation planning
**Builds on:** the `IbanInfo` / `kIbanBban` metadata already shipped (0.4.0–0.5.0).

## Goal

Expose, for each country whose IBAN format is known, a small public descriptor:
the total length, the bank / branch / account field lengths, whether a branch
code exists, and a valid example IBAN. This mirrors the per-country example
data the phone side already offers on `Country`. Purely additive — `Iban.parse`
and `IbanInfo` are unchanged.

## Public API

New type `IbanCountry` (new file `lib/src/iban/iban_country.dart`, exported from
the barrel):

```dart
class IbanCountry {
  final String iso2;            // 'AT'
  final int length;             // total IBAN length, e.g. 20
  final int bankCodeLength;     // bank identifier length (0 if the country has none)
  final int? branchCodeLength;  // branch identifier length, null if none
  final int accountLength;      // account-number length
  final String example;         // valid, 4-grouped example, e.g. 'AT61 1904 3002 3457 3201'

  bool get hasBranchCode => branchCodeLength != null;

  /// The descriptor for [code] (case-insensitive ISO2), or null if the country
  /// has no known IBAN format.
  static IbanCountry? of(String code);

  /// All known IBAN countries, sorted by ISO2.
  static List<IbanCountry> get values;
}
```

### Example

```dart
final at = IbanCountry.of('AT')!;
// iso2 'AT', length 20, bankCodeLength 5, branchCodeLength null,
// accountLength 11, hasBranchCode false, example 'AT61 1904 3002 3457 3201'

final it = IbanCountry.of('IT')!;
// length 27, bankCodeLength 5, branchCodeLength 5, accountLength 12,
// hasBranchCode true

IbanCountry.of('US'); // null — US has no IBAN
```

## Data & derivation

Single source of truth stays `kIbanBban` (the internal BBAN offset table). It
gains one field per entry — a compact example IBAN string — and `IbanCountry`
derives everything else from the existing offsets:

- `bankCodeLength   = bankEnd - bankStart`
- `branchCodeLength = branchStart == null ? null : branchEnd - branchStart`
- `accountLength    = length - (branchEnd ?? bankEnd)`
- `example` = the stored compact IBAN, grouped in blocks of four for display.

`IbanBban` (in `lib/src/iban/iban_metadata.dart`) gains
`final String example;` (compact, e.g. `'AT611904300234573201'`). It stays an
internal type; `IbanCountry` is the public view built on the fly in `of` /
`values`.

### Example IBANs

- **AT / DE / CH:** canonical, well-known real examples, verified valid:
  - `AT61 1904 3002 3457 3201`
  - `DE89 3704 0044 0532 0130 00`
  - `CH93 0076 2011 6238 5295 7`
- **All other countries:** deterministically synthesised in the generator from
  schwifty's `bban_spec` (tokens `<len>!<type>` with `n`=digit, `a`=letter,
  `c`=alphanumeric), filled with a fixed repeating pattern, then completed with
  correct ISO 13616 Mod-97 check digits. Offline, no extra data source. Verified:
  all 126 country examples pass `Iban.isValid`.

## Generator changes

`tool/gen_iban_metadata.py`:
- Add a self-contained `_iban_check_digits` helper (Mod-97) and a
  `_synth_bban(bban_spec)` helper.
- Add a `DACH_EXAMPLES` override map with the three canonical compact IBANs.
- In `bban_structures()`, compute `example` per country (DACH override, else
  synthesised) and emit it as `example: '<compact>'` in each `IbanBban(...)`.

## Tests

- `test/iban_country_test.dart`:
  - `IbanCountry.of('AT')` → all fields as above; `example` == the AT canonical.
  - A branch country (`IbanCountry.of('IT')`) → `branchCodeLength == 5`,
    `hasBranchCode == true`.
  - Case-insensitive: `IbanCountry.of('at')` resolves the same descriptor as
    `IbanCountry.of('AT')` (e.g. equal `iso2` / `length`).
  - `IbanCountry.of('XX')` → null (unknown), `IbanCountry.of('US')` → null
    (real country, no IBAN).
  - **Invariant:** every `IbanCountry.values` entry's `example` passes
    `Iban.isValid`, and `values` is non-empty (126 entries) and sorted.
- `test/iban_metadata_test.dart`: add an assertion that `kIbanBban['AT'].example`
  is the AT canonical compact string.

## Out of scope

- Curated real examples for non-DACH countries.
- Exposing raw BBAN offsets publicly (only lengths are surfaced).
- Any change to `Iban.parse` / `IbanInfo`.

## Version

Release `0.6.0` (additive API).
