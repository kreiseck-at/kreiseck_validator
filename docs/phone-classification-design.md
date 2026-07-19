# Phone number classification & type-aware formatting (AT) — Design

Status: approved
Date: 2026-07-19
Target version: 0.2.0

## Goal

Extend the `Phone` type so it can, **for Austria (AT) only**:

1. Classify a valid number by **type** (mobile, landline, VoIP, freephone,
   shared-cost, premium, corporate, unknown).
2. Format it with **type-aware spacing** (mobile keeps its prefix grouping,
   landline uses the area-code length, special numbers use their conventional
   grouping).
3. Expose a convenience bundle (`PhoneInfo`) with the type plus the E.164,
   national and international forms in one call.

Explicit **non-goals**: no operator/carrier detection (number portability makes
an offline, allocation-based guess misleading), no online HLR/MNP lookup, no
DE/CH classification yet.

## Legality / data source

All classification uses the **public Austrian numbering plan** published by the
regulator **RTR (Rundfunk & Telekom Regulierungs-GmbH / KommAustria)**.
Classifying a number's prefix is **not** processing of personal data (a prefix
range is not a person; GDPR is not engaged). The prefix tables MUST be sourced
from official RTR data during implementation — not from memory.

## Key domain facts (must be honored)

- **Mobile is an explicit prefix allow-list, not a numeric range.** Geographic
  codes fall inside the same numeric span — e.g. **`0662` = Salzburg (landline)**
  sits between mobile `0660` and `0699`. A range check would misclassify it.
  Mobile prefixes are the RTR-assigned 3-digit codes (e.g. 650, 660, 664, 676,
  680, 681, 688, 699, 670, 677, 678, …) — the exact set comes from RTR.
- **Number portability (MNP):** a mobile prefix reflects only the *original*
  allocation block, never the current operator. This is why operator detection
  is out of scope.
- **Geographic area codes vary in length** (Vienna `1`; most cities 3 digits
  like Graz `316`, Linz `732`, Salzburg `662`, Innsbruck `512`; rural up to 4).
- **Special/service ranges:** `800` freephone, `810/820/821` shared-cost,
  `900/901/930` premium, `720` VoIP/nomadic, `5xx`/`59x` corporate/private
  networks. Exact ranges from RTR.

## Public API (additions — all backward compatible)

```dart
/// The kind of number, derived from the Austrian numbering plan.
enum PhoneNumberType {
  mobile, landline, voip, freephone, sharedCost, premium, corporate, unknown,
}

/// A parsed, classified phone number.
class PhoneInfo {
  final String e164;              // '+43316123456'
  final Country country;          // Country.at
  final PhoneNumberType type;     // PhoneNumberType.landline
  final String national;          // '0316 123456'   (type-aware spacing)
  final String international;      // '+43 316 123456'
}
```

- `static PhoneNumberType Phone.type(String input, {Country? country})`
  — classifies a number; returns `PhoneNumberType.unknown` if the input is
  invalid or the country is not AT (classification is AT-only for now).
- `static PhoneInfo? Phone.parse(String input, {Country? country})`
  — returns the full bundle, or `null` if the input is invalid (mirrors
  `tryFormat`'s null-on-invalid contract).

Existing methods (`isValid`/`validate`/`normalize`/`format`/`tryFormat`) keep
their signatures. `Phone.format` becomes **type-aware for AT** (see below);
its output for **mobile** numbers is unchanged, so existing tests/vectors stay
green.

## Formatting rules (AT)

Given the E.164 national significant number:

- **mobile** — `0<prefix> <rest>` / `+43 <prefix> <rest>` (unchanged from today,
  3-digit prefix, e.g. `0664 1234567`).
- **landline (known area code)** — split off the exact area code:
  `01 5321234` / `+43 1 5321234` (Vienna), `0316 123456` / `+43 316 123456` (Graz).
- **landline (unknown area code)** — best-effort fallback grouping, documented
  as **approximate** (a fixed assumed area-code length); still produces readable
  output, never throws.
- **freephone / shared-cost / premium / voip** — `0<prefix> <rest>` with the
  service prefix split off.
- **corporate (5xx/59x)** — conventional grouping of the block prefix + rest.

The area-code table is a **curated set of the most common AT codes** (Wien,
Graz, Linz, Salzburg, Innsbruck, Klagenfurt, Villach, Wels, St. Pölten,
Dornbirn, Bregenz, Wiener Neustadt, Steyr, Feldkirch, Eisenstadt, …) sourced
from RTR, plus the documented fallback. Full ~1300-entry coverage is out of
scope for 0.2.0.

## Country scope & extensibility

Classification and geo-spacing are **AT-only**. Internals are structured per
country (a classifier + tables keyed by `Country`) so DE/CH can be added later.
For DE/CH today: `Phone.type` returns `unknown`, `Phone.parse` still returns a
`PhoneInfo` with `type: unknown` and the existing simple spacing, and
`Phone.format` keeps its current behavior. This is documented.

## File structure

```
lib/src/phone/
  phone.dart                 # existing class; format() becomes type-aware
  phone_number_type.dart     # enum PhoneNumberType
  phone_info.dart            # class PhoneInfo
  at_numbering.dart          # AT prefix tables (mobile, special, area codes) + classifier + formatter, sourced from RTR
```

Rationale: the AT numbering data and its classifier/formatter live in one
focused file (`at_numbering.dart`), separate from the country-agnostic `Phone`
orchestration, so adding DE/CH later means adding a sibling file, not growing
`phone.dart`.

## Testing

- New unit tests: `Phone.type` for one representative number per category
  (mobile 0664, landline Vienna `01…`, landline Graz `0316…`, freephone `0800…`,
  premium `0900…`, voip `0720…`, corporate `05…`, and the Salzburg `0662…`
  landline that must NOT be classified mobile).
- Type-aware `format` tests for mobile (unchanged), Vienna and Graz landline,
  and an unknown area code (fallback).
- **Vectors:** extend the JSON case schema with an optional `type` field
  (string = `PhoneNumberType.name`); add representative phone cases. The runner
  asserts `type` when present. Same cross-language contract as the other fields.

## Docs & release

- README phone section: document `type`/`parse`, the AT-only scope, and the
  portability caveat ("we classify the number *type*, not the current operator").
- `doc/algorithms.md`: a short section on the AT numbering plan, the explicit
  mobile allow-list (with the `0662` Salzburg example), and the RTR source.
- Release as **0.2.0** (additive minor version); CHANGELOG entry.
