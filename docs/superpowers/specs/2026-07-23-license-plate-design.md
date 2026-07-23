# License-plate validation (`LicensePlate`) — Design

**Status:** approved for implementation planning
**Applies to both packages:** the Dart `kreiseck_validator` and the TypeScript
`@kreiseck/validator`, built together, verified against shared JSON vectors.

## Goal

Add a new `LicensePlate` module that validates, normalizes, formats, and
**parses** vehicle registration plates ("Kennzeichen") for **AT, DE, CH, HR and
TR**. `parse` returns a structured `PlateInfo`: the country, the
district/canton/province code, the official region name, the serial part, and a
**classification** (`PlateType`) of special plates (diplomatic, authority,
seasonal, historic, …). Same four-operation API as every other module.

## Public API

New module `LicensePlate` (Dart: `lib/src/license_plate/`; TS:
`js/src/license-plate/`; subpath `@kreiseck/validator/license-plate`).

```ts
LicensePlate.isValid(input, { country? }): boolean;
LicensePlate.validate(input, { country? }): ValidationResult;
LicensePlate.normalize(input, { country? }): string;   // throws on invalid
LicensePlate.format(input, { country? }): string;       // canonical display form
LicensePlate.tryFormat(input, { country? }): string | null;
LicensePlate.parse(input, { country? }): PlateInfo | null;
```

- The `country` option is an ISO2 string (`'AT' | 'DE' | 'CH' | 'HR' | 'TR'`).
  When omitted, the implementation infers the country from the format + code
  tables; if two countries match, `validate` still returns valid but `parse`
  reports the ambiguity by leaving `region` null (see below). Passing `country`
  is recommended for reliable region resolution and is how the vectors are
  driven (mirroring the phone module's `country` option).

```ts
interface PlateInfo {
  country: string;         // 'AT'
  districtCode: string;    // 'W'  (AT Bezirk) / 'M' (DE) / 'ZH' (CH) / 'ZG' (HR) / '34' (TR)
  region: string | null;   // 'Wien' — null if the code is unknown/ambiguous
  serial: string;          // the individual part, normalized (e.g. '12345A', 'AB 1234')
  type: PlateType;         // classification (see below)
  formatted: string;       // canonical display form, e.g. 'W-12345A', 'M-AB 1234'
}

type PlateType =
  | 'standard'
  | 'diplomatic'
  | 'authority'   // government / Behörden
  | 'military'
  | 'temporary'   // transit / Kurzzeit / Probefahrt / Überstellung
  | 'seasonal'    // Saisonkennzeichen (DE)
  | 'historic'    // Oldtimer / H
  | 'electric'    // E-plate
  | 'unknown';
```

`normalize`/`format` throw `FormatError` (TS) / `FormatException` (Dart) on
invalid input; `tryFormat` returns null. `IssueCode` gains plate codes (see
below).

### New issue codes

Add to the shared `IssueCode` enum/union: `plateEmpty`, `plateBadChars`,
`plateBadFormat`, `plateUnknownCountry`, `plateAmbiguousCountry`. (Same names in
Dart enum and TS union — the conformance harness depends on parity.)

## Per-country rules

Each country has (a) a format grammar, (b) a `code → region` table, and (c)
classification rules mapping its special forms to `PlateType`.

### AT — Austria
- Grammar: `<code 1–2 letters>` + separator + `<serial>` where serial is digits
  and letters (e.g. `W-12345A`, `GU-123AB`). Code set = the ~99 Bezirks­codes.
- Region table: Bezirkscode → district name (e.g. `W`→`Wien`, `GU`→`Graz-Umgebung`).
- Classification: state-level diplomatic codes ending in `D` (`WD`,`BD`,`OD`,…)
  → `diplomatic`; federal/authority codes (`BG`,`BH`,`BP`,`BB`, army `BH`? — use
  the official special-code list) → `authority`/`military`; Probefahrt &
  Überstellung (blue) → `temporary`; green-script E-plates → `electric`.

### DE — Germany
- Grammar: `<Unterscheidungszeichen 1–3 letters>` + `<1–2 letters>` +
  `<1–4 digits>` with optional trailing `H` (historic) or `E` (electric), and an
  optional Saison suffix `NN-NN` (months). E.g. `M-AB 1234`, `B-XY 12H`,
  `K-CV 40E`, `F-AB 123 04-10`.
- Region table: Unterscheidungszeichen → Stadt/Kreis (+ Bundesland), curated
  from the current **KBA official list** (amtliches Werk → public domain; the
  2012 Berlin-Open-Data CSV is too stale to use).
- Classification: numeric-only district (`0`,`1`,…) → `diplomatic`; `Y`
  (Bundeswehr), `X` (NATO) → `military`; `BW`,`BP`,`BD`,`THW` → `authority`;
  trailing `H` → `historic`; trailing `E` → `electric`; Saison suffix → `seasonal`;
  `04`/`05` short-term red plates → `temporary`.

### CH — Switzerland
- Grammar: `<canton 2 letters>` + `<1–6 digits>` (e.g. `ZH 123456`). 26 cantons.
- Region table: canton code → canton name (self-curated, 26 entries).
- Classification: federal `A …` (Bund) / `CD` diplomatic where applicable →
  `diplomatic`/`authority`; otherwise `standard`.

### HR — Croatia
- Grammar: `<city 2 letters>` + `<3–4 digits>` + `<1–2 letters>` (e.g.
  `ZG 1234-AB`). ~30 city codes.
- Region table: city code → city/county name (self-curated).
- Classification: diplomatic and temporary export forms → `diplomatic`/`temporary`
  where identifiable; otherwise `standard`.

### TR — Turkey
- Grammar: `<province 2 digits 01–81>` + `<1–3 letters>` + `<2–4 digits>` (e.g.
  `34 ABC 123`). Province code 01–81.
- Region table: province number → province name (self-curated, 81 entries).
- Classification: official/diplomatic/military letter conventions where
  identifiable; otherwise `standard`.

Where a country's special-plate rules are uncertain, the implementation returns
`standard` rather than guessing — classification never blocks validation.

## Data & generation

Region tables are **curated from official / public-domain sources** (KBA for DE;
official canton/province/Bezirk lists for the others) — no ODbL/openpotato data.
They are produced by a new generator `tool/gen_plate_metadata.py` that emits, in
one run:
- Dart: `lib/src/license_plate/plate_metadata.g.dart` (const `code → region`
  maps per country).
- TS: `js/src/data/plate-metadata.json` (same maps as JSON).

Small tables (AT ~99, CH 26, HR ~30, TR 81) are curated dicts embedded in the
generator. The DE table (~750) is read from a committed public-domain snapshot
`tool/data/de-kennzeichen.csv` derived from the KBA list; the generator parses
it. One generator run feeds both languages → no cross-language drift.

`NOTICE` gains a line: German plate region data derived from the KBA
Unterscheidungszeichen list (amtliches Werk); other tables compiled from public
administrative sources.

## Conformance

Shared vectors `test/vectors/license_plate.json`, consumed by both the Dart
`vectors_test.dart` and a new TS `license-plate.conformance.spec.ts`. Each vector
carries `input`, optional `country`, and expected `isValid` / `code` /
`normalized` / `format` / a `parse` object (`country`, `districtCode`, `region`,
`serial`, `type`). Coverage per country: valid standard plates (known + unknown
code), each special `type`, and invalid inputs (bad chars, bad format, wrong
length). Plus TS-only + Dart-only unit tests for the classification edge cases
the vectors can't all carry.

## Staged delivery

One spec, a plan whose tasks are **per country**, each landing in **both**
languages and its vectors before moving on:

1. Module skeleton + shared types (`PlateInfo`, `PlateType`, new `IssueCode`s) +
   the generator scaffold + **AT** (format, region table, classification, vectors)
   — Dart and TS.
2. **DE** (KBA table + the richer classification) — Dart and TS.
3. **CH** — Dart and TS.
4. **HR** — Dart and TS.
5. **TR** — Dart and TS.
6. Docs (both READMEs, CHANGELOG, `doc/algorithms.md`), barrel/exports, version
   bump in both packages.

Each country stage is independently shippable; the module is usable after stage 1.

## No-footprint

No reference to AI/assistants/tooling anywhere — code, comments, data, docs,
commit messages, package metadata — in either package. The generated-file header
(`Generated by tool/gen_plate_metadata.py`) is the intended, allowed exception.

## Version

Both packages bump a minor version together when the module first ships
(`0.7.0`), and again if later country stages ship separately.

## Out of scope

- Countries beyond AT/DE/CH/HR/TR.
- Plate-image/OCR or check-digit schemes (these plates have no checksum).
- Distinguishing every historical/regional sub-variant; classification is
  best-effort and defaults to `standard`.
