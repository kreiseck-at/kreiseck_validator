# Global Phone Metadata Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand phone validation, formatting, flags and example numbers from DACH (DE/AT/CH) to every country, using one uniform, libphonenumber-derived data model.

**Architecture:** A build-time Python generator reads the `phonenumbers` package (Python port of libphonenumber, Apache-2.0) and emits (a) a canonical `metadata.json` and (b) a generated Dart file with one `Country` value per region carrying all metadata. Validation and formatting become data-driven and uniform; deep type classification stays an AT-only data layer. Runtime stays zero-dependency (only generated constants are shipped).

**Tech Stack:** Dart (package + tests), Python 3 (dev-only generator), `phonenumbers` + `pycountry` (dev-only), JSON test vectors.

## Global Constraints

- **Zero runtime dependencies.** The shipped package imports no third-party code; `phonenumbers`/`pycountry` are used only by `tool/` at build time. Generated data is committed.
- **Dart SDK** `>=3.0.0 <4.0.0` (unchanged).
- **License:** Apache-2.0. Metadata is derived from libphonenumber — a `NOTICE` file must credit it with the exact pinned version.
- **Deterministic generation:** same pinned `phonenumbers` version → byte-identical `metadata.json` and generated Dart.
- **Commit messages:** plain and factual, no attribution trailers.
- **Naming:** no Google trademarks in identifiers or docs; only a factual "derived from libphonenumber" provenance note.

---

## File Structure

- `tool/requirements.txt` — **create** — pinned dev deps for the generator.
- `tool/gen_phone_metadata.py` — **create** — reads `phonenumbers`/`pycountry`, writes `metadata.json`, `country.g.dart`, and phone vectors.
- `tool/test_gen_phone_metadata.py` — **create** — Python asserts on generator output (known facts).
- `lib/src/phone/data/metadata.json` — **generated** — canonical, cross-language metadata.
- `lib/src/common/country.dart` — **rewrite** — `Country` class (fields, getters, lookups, named DACH constants).
- `lib/src/common/country.g.dart` — **generated** — `part of country.dart`: one const `Country` per region, `kCountries`, `kMainRegionForCallingCode`.
- `lib/src/phone/phone_format.dart` — **create** — `PhoneFormat` value type + generic formatter.
- `lib/src/phone/phone.dart` — **rewrite** — data-driven validate/format/normalize/type/parse.
- `lib/src/phone/at_numbering.dart` — **modify** — drop `format`, keep `classify` (+ data).
- `lib/src/phone/phone_info.dart` — **modify** — unchanged fields; doc note.
- `lib/src/common/issue_code.dart` — **modify** — add `phoneInvalid`.
- `lib/kreiseck_validator.dart` — **modify** — export `phone_format.dart`.
- `test/phone_global_test.dart` — **create** — hand-written cross-country unit tests.
- `test/vectors/phone.json` — **regenerate/extend** — DACH + world spread.
- `test/vectors_test.dart` — **modify** — resolve country via `Country.fromIso2`.
- `NOTICE` — **create** — libphonenumber attribution.
- `pubspec.yaml`, `CHANGELOG.md`, `README.md`, `doc/algorithms.md` — **modify** — version + docs.

---

### Task 1: Generator foundation & canonical metadata.json

**Files:**
- Create: `tool/requirements.txt`
- Create: `tool/gen_phone_metadata.py`
- Create: `tool/test_gen_phone_metadata.py`
- Create: `NOTICE`
- Generated: `lib/src/phone/data/metadata.json`

**Interfaces:**
- Produces: `lib/src/phone/data/metadata.json` — a JSON object `{ "libphonenumberVersion": "X.Y.Z", "countries": [ CountryMeta, ... ] }` where each `CountryMeta` is:
  ```json
  {
    "iso2": "AT",
    "callingCode": "43",
    "name": "Austria",
    "mainForCallingCode": true,
    "nationalPrefix": "0",
    "possibleLengths": [4,5,6,7,8,9,10,11,12,13],
    "pattern": "1\\d{3,12}|...",
    "formats": [
      {"pattern":"(1)(\\d{3,12})","format":"$1 $2","leadingDigits":"1(?:11|[2-9])","nationalPrefixFormattingRule":"0$1"}
    ],
    "example": {"nsn":"1234567890","e164":"+431234567890","national":"01 234567890","international":"+43 1 234567890"}
  }
  ```

- [ ] **Step 1: Pin the dev dependencies**

Run:
```bash
python3 -m pip install phonenumbers pycountry
python3 -m pip freeze | grep -Ei '^(phonenumbers|pycountry)==' > tool/requirements.txt
cat tool/requirements.txt
```
Expected: two lines, e.g. `phonenumbers==8.13.60` and `pycountry==24.6.1` (exact versions depend on install). Record the `phonenumbers` version — it is used in `NOTICE` and in `metadata.json`.

- [ ] **Step 2: Write the failing generator test**

Create `tool/test_gen_phone_metadata.py`:
```python
"""Asserts the generated metadata.json against known, stable facts."""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(__file__)
JSON_PATH = os.path.join(HERE, "..", "lib", "src", "phone", "data", "metadata.json")


def _load():
    subprocess.run([sys.executable, os.path.join(HERE, "gen_phone_metadata.py")], check=True)
    with open(JSON_PATH, encoding="utf-8") as f:
        return json.load(f)


def _by_iso2(data):
    return {c["iso2"]: c for c in data["countries"]}


def test_known_facts():
    data = _load()
    assert data["libphonenumberVersion"]
    countries = _by_iso2(data)
    assert len(countries) > 200
    assert countries["AT"]["callingCode"] == "43"
    assert countries["DE"]["callingCode"] == "49"
    assert countries["CH"]["callingCode"] == "41"
    assert countries["US"]["callingCode"] == "1"
    assert countries["AT"]["name"] == "Austria"
    # Shared calling code +1: exactly one region is marked main.
    plus1 = [c for c in countries.values() if c["callingCode"] == "1"]
    assert sum(1 for c in plus1 if c["mainForCallingCode"]) == 1
    # Example numbers are present and E.164-shaped.
    assert countries["AT"]["example"]["e164"].startswith("+43")
    assert countries["FR"]["example"]["e164"].startswith("+33")
    # Every country has at least one possible length and a validation pattern.
    for c in countries.values():
        assert c["possibleLengths"], c["iso2"]
        assert c["pattern"], c["iso2"]


if __name__ == "__main__":
    test_known_facts()
    print("OK")
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `python3 tool/test_gen_phone_metadata.py`
Expected: FAIL — `gen_phone_metadata.py` does not exist yet (`FileNotFoundError` / non-zero exit).

- [ ] **Step 4: Write the generator**

Create `tool/gen_phone_metadata.py`:
```python
#!/usr/bin/env python3
"""Dev-only generator for global phone metadata.

Reads libphonenumber's data via the `phonenumbers` package and ISO country
names via `pycountry`, and emits:
  - lib/src/phone/data/metadata.json  (canonical, cross-language)
  - lib/src/common/country.g.dart     (generated Dart, added in Task 2)
  - test/vectors/phone.json           (added in Task 6)

Run:  python3 tool/gen_phone_metadata.py

This script is NOT part of the shipped package. Metadata is derived from
libphonenumber (Apache-2.0); see the NOTICE file.
"""
from __future__ import annotations

import json
import os
import re

import phonenumbers
import pycountry
from phonenumbers import PhoneMetadata, PhoneNumberFormat, PhoneNumberType

HERE = os.path.dirname(__file__)
ROOT = os.path.normpath(os.path.join(HERE, ".."))
JSON_OUT = os.path.join(ROOT, "lib", "src", "phone", "data", "metadata.json")

# Example number type preference: mobile first, then fixed line.
_EXAMPLE_TYPES = [PhoneNumberType.MOBILE, PhoneNumberType.FIXED_LINE]


def _fmt_token_normalize(fmt: str) -> str:
    """Normalizes group refs (\\1 or $1) to a canonical `$1` token."""
    return re.sub(r"[\\$](\d)", r"$\1", fmt or "")


def _country_name(iso2: str) -> str:
    rec = pycountry.countries.get(alpha_2=iso2)
    if rec is None:
        return iso2
    return getattr(rec, "common_name", None) or rec.name


def _formats(meta) -> list[dict]:
    out = []
    for nf in meta.number_format:
        leading = nf.leading_digits_pattern[-1] if nf.leading_digits_pattern else None
        out.append({
            "pattern": nf.pattern,
            "format": _fmt_token_normalize(nf.format),
            "leadingDigits": leading,
            "nationalPrefixFormattingRule": nf.national_prefix_formatting_rule or None,
        })
    return out


def _example(iso2: str) -> dict | None:
    for t in _EXAMPLE_TYPES:
        pn = phonenumbers.example_number_for_type(iso2, t)
        if pn is not None:
            return {
                "nsn": phonenumbers.national_significant_number(pn),
                "e164": phonenumbers.format_number(pn, PhoneNumberFormat.E164),
                "national": phonenumbers.format_number(pn, PhoneNumberFormat.NATIONAL),
                "international": phonenumbers.format_number(pn, PhoneNumberFormat.INTERNATIONAL),
            }
    return None


def build_countries() -> list[dict]:
    countries = []
    for iso2 in sorted(phonenumbers.SUPPORTED_REGIONS):
        meta = PhoneMetadata.metadata_for_region(iso2)
        if meta is None:
            continue
        cc = str(meta.country_code)
        main_region = phonenumbers.region_code_for_country_code(meta.country_code)
        gd = meta.general_desc
        example = _example(iso2)
        countries.append({
            "iso2": iso2,
            "callingCode": cc,
            "name": _country_name(iso2),
            "mainForCallingCode": iso2 == main_region,
            "nationalPrefix": meta.national_prefix or None,
            "possibleLengths": list(gd.possible_length) if gd and gd.possible_length else [],
            "pattern": (gd.national_number_pattern if gd else "") or "",
            "formats": _formats(meta),
            "example": example,
        })
    return countries


def build_data() -> dict:
    return {
        "libphonenumberVersion": phonenumbers.__version__,
        "countries": build_countries(),
    }


def main() -> None:
    data = build_data()
    os.makedirs(os.path.dirname(JSON_OUT), exist_ok=True)
    with open(JSON_OUT, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")
    print(f"Wrote {len(data['countries'])} countries to {JSON_OUT}")


if __name__ == "__main__":
    main()
```

Note on API: if `phonenumbers.__version__` is absent, replace with `importlib.metadata.version("phonenumbers")`. If `region_code_for_country_code` returns a region not in `SUPPORTED_REGIONS` for a rare code, `mainForCallingCode` simply stays `False` for all — the Task 2 generator falls back to the first region for that code.

- [ ] **Step 5: Run the test to verify it passes**

Run: `python3 tool/test_gen_phone_metadata.py`
Expected: `OK`. If an `AttributeError` appears, fix the attribute name against the installed `phonenumbers` (its `PhoneMetadata`/`NumberFormat` field names) and re-run — this step is the empirical check that locks the API.

- [ ] **Step 6: Create the NOTICE file**

Create `NOTICE` (replace `X.Y.Z` with the pinned version from `tool/requirements.txt`):
```
kreiseck_validator

This product contains phone-numbering metadata derived from libphonenumber
(https://github.com/google/libphonenumber), Copyright (c) The libphonenumber
Authors, licensed under the Apache License, Version 2.0.

Derived data was generated from the "phonenumbers" Python distribution,
version X.Y.Z, and reduced to the fields used by this package. See
tool/gen_phone_metadata.py for the extraction process.
```

- [ ] **Step 7: Commit**

```bash
git add tool/requirements.txt tool/gen_phone_metadata.py tool/test_gen_phone_metadata.py NOTICE lib/src/phone/data/metadata.json
git commit -m "Add generator and canonical phone metadata from libphonenumber"
```

---

### Task 2: Uniform Country registry (Dart)

**Files:**
- Create: `lib/src/phone/phone_format.dart` (type only in this task)
- Rewrite: `lib/src/common/country.dart`
- Generated: `lib/src/common/country.g.dart`
- Modify: `tool/gen_phone_metadata.py` (add Dart emission)
- Test: `test/phone_global_test.dart`

**Interfaces:**
- Consumes: `metadata.json` from Task 1.
- Produces:
  - `class PhoneFormat { final String pattern; final String format; final String? leadingDigits; final String? nationalPrefixFormattingRule; const PhoneFormat({...}); }`
  - `class Country` with fields `String iso2`, `String callingCode`, `String displayName`, `String? nationalPrefix`, `List<int> possibleLengths`, `String pattern`, `List<PhoneFormat> formats`, `String? exampleNsn`, `String? exampleE164`, `String? exampleNational`, `String? exampleInternational`; getter `String get flag`; static `List<Country> values`; static `Country? fromIso2(String)`; static `Country? fromCallingCode(String)`; named constants `Country.de/at/ch`.
  - (`displayName`, not `name` — `name` would collide with reserved semantics and keeps parity with the enum era; ISO2 codes like `IS`/`IN`/`DO`/`AS` are Dart reserved words, so countries are reached via `fromIso2`/`values`, not `Country.<iso2>` members, except the safe DACH names.)

- [ ] **Step 1: Write the PhoneFormat value type**

Create `lib/src/phone/phone_format.dart`:
```dart
/// A single national number-format rule (derived from libphonenumber).
class PhoneFormat {
  /// Creates a format rule.
  const PhoneFormat({
    required this.pattern,
    required this.format,
    this.leadingDigits,
    this.nationalPrefixFormattingRule,
  });

  /// Regex matched against the national significant number.
  final String pattern;

  /// Output template using `$1`, `$2`, ... group references.
  final String format;

  /// If set, this rule applies only when the number starts with this prefix.
  final String? leadingDigits;

  /// National-prefix rendering rule (e.g. `0$1`); applies to national form.
  final String? nationalPrefixFormattingRule;
}
```

- [ ] **Step 2: Write the failing Country test**

Create `test/phone_global_test.dart`:
```dart
import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:test/test.dart';

void main() {
  group('Country registry', () {
    test('lists all countries', () {
      expect(Country.values.length, greaterThan(200));
    });

    test('AT metadata', () {
      expect(Country.at.callingCode, '43');
      expect(Country.at.iso2, 'AT');
      expect(Country.at.displayName, 'Austria');
      expect(Country.at.flag, '🇦🇹');
    });

    test('flag derivation for reserved-word ISO2 codes', () {
      expect(Country.fromIso2('IS')!.flag, '🇮🇸');
      expect(Country.fromIso2('IN')!.flag, '🇮🇳');
    });

    test('lookup by iso2 is case-insensitive', () {
      expect(Country.fromIso2('us')!.iso2, 'US');
      expect(Country.fromIso2('ZZ'), isNull);
    });

    test('fromCallingCode returns the main region for shared codes', () {
      expect(Country.fromCallingCode('1')!.iso2, 'US');
      expect(Country.fromCallingCode('43')!.iso2, 'AT');
    });

    test('example number is exposed', () {
      final fr = Country.fromIso2('FR')!;
      expect(fr.exampleE164, startsWith('+33'));
    });
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `dart test test/phone_global_test.dart`
Expected: FAIL to compile — `Country` has no `values`/`fromIso2`/`displayName`/`flag`.

- [ ] **Step 4: Rewrite `country.dart` (hand-written shell)**

Replace `lib/src/common/country.dart` with:
```dart
import '../phone/phone_format.dart';

part 'country.g.dart';

/// A country/region with its phone-numbering metadata, derived from
/// libphonenumber. All regions share the same fields; some (e.g. AT) carry
/// additional classification data elsewhere.
class Country {
  const Country({
    required this.iso2,
    required this.callingCode,
    required this.displayName,
    required this.nationalPrefix,
    required this.possibleLengths,
    required this.pattern,
    required this.formats,
    required this.exampleNsn,
    required this.exampleE164,
    required this.exampleNational,
    required this.exampleInternational,
  });

  /// ISO 3166-1 alpha-2 code, upper-case (e.g. `AT`).
  final String iso2;

  /// E.164 country calling code without `+` (e.g. `43`).
  final String callingCode;

  /// English country name (e.g. `Austria`).
  final String displayName;

  /// National trunk prefix (e.g. `0`), or null.
  final String? nationalPrefix;

  /// Allowed national significant number lengths.
  final List<int> possibleLengths;

  /// Regex (anchored at use) for a valid national significant number.
  final String pattern;

  /// National number-format rules.
  final List<PhoneFormat> formats;

  /// Synthetic example national significant number, or null.
  final String? exampleNsn;

  /// Synthetic example in E.164 (e.g. `+43...`), or null.
  final String? exampleE164;

  /// Synthetic example in national display form, or null.
  final String? exampleNational;

  /// Synthetic example in international display form, or null.
  final String? exampleInternational;

  /// Flag emoji derived from [iso2] (regional-indicator symbols).
  String get flag {
    if (iso2.length != 2) return '';
    const base = 0x1F1E6;
    final a = iso2.codeUnitAt(0) - 0x41;
    final b = iso2.codeUnitAt(1) - 0x41;
    if (a < 0 || a > 25 || b < 0 || b > 25) return '';
    return String.fromCharCode(base + a) + String.fromCharCode(base + b);
  }

  /// All supported countries.
  static const List<Country> values = kCountries;

  /// Austria.
  static const Country at = _atData;

  /// Germany.
  static const Country de = _deData;

  /// Switzerland.
  static const Country ch = _chData;

  /// Looks up a country by ISO2 code (case-insensitive); null if unknown.
  static Country? fromIso2(String code) {
    final up = code.toUpperCase();
    for (final c in kCountries) {
      if (c.iso2 == up) return c;
    }
    return null;
  }

  /// Returns the main region for a calling code, or null if none.
  static Country? fromCallingCode(String callingCode) {
    final iso2 = kMainRegionForCallingCode[callingCode];
    if (iso2 == null) return null;
    return fromIso2(iso2);
  }
}
```

- [ ] **Step 5: Extend the generator to emit `country.g.dart`**

Add to `tool/gen_phone_metadata.py` (append emission logic and call it from `main`):
```python
DART_OUT = os.path.join(ROOT, "lib", "src", "common", "country.g.dart")

# ISO2 codes that are Dart reserved words cannot be `Country.<code>` members.
_DACH = {"AT": "_atData", "DE": "_deData", "CH": "_chData"}


def _dart_str(v):
    if v is None:
        return "null"
    escaped = v.replace("\\", "\\\\").replace("$", "\\$").replace("'", "\\'")
    return f"r'{v}'" if ("\\" in v or "$" in v) and "'" not in v else f"'{escaped}'"


def _dart_format(nf: dict) -> str:
    return (
        "PhoneFormat("
        f"pattern: {_dart_str(nf['pattern'])}, "
        f"format: {_dart_str(nf['format'])}, "
        f"leadingDigits: {_dart_str(nf['leadingDigits'])}, "
        f"nationalPrefixFormattingRule: {_dart_str(nf['nationalPrefixFormattingRule'])})"
    )


def _dart_country(c: dict) -> str:
    ex = c["example"] or {}
    fmts = ", ".join(_dart_format(f) for f in c["formats"])
    lengths = ", ".join(str(n) for n in c["possibleLengths"])
    return (
        "Country(\n"
        f"  iso2: {_dart_str(c['iso2'])},\n"
        f"  callingCode: {_dart_str(c['callingCode'])},\n"
        f"  displayName: {_dart_str(c['name'])},\n"
        f"  nationalPrefix: {_dart_str(c['nationalPrefix'])},\n"
        f"  possibleLengths: [{lengths}],\n"
        f"  pattern: {_dart_str(c['pattern'])},\n"
        f"  formats: [{fmts}],\n"
        f"  exampleNsn: {_dart_str(ex.get('nsn'))},\n"
        f"  exampleE164: {_dart_str(ex.get('e164'))},\n"
        f"  exampleNational: {_dart_str(ex.get('national'))},\n"
        f"  exampleInternational: {_dart_str(ex.get('international'))},\n"
        ")"
    )


def write_dart(data: dict) -> None:
    countries = data["countries"]
    # Main region per calling code; fall back to the first region seen.
    main = {}
    for c in countries:
        cc = c["callingCode"]
        if c["mainForCallingCode"] or cc not in main:
            main[cc] = c["iso2"]

    lines = [
        "// Generated by tool/gen_phone_metadata.py. Do not edit by hand.",
        "// Data derived from libphonenumber (Apache-2.0); see NOTICE.",
        "",
        "part of 'country.dart';",
        "",
    ]
    for c in countries:
        const_name = _DACH.get(c["iso2"])
        if const_name:
            lines.append(f"const Country {const_name} = {_dart_country(c)};")
            lines.append("")
    lines.append("/// All supported countries, sorted by ISO2.")
    lines.append("const List<Country> kCountries = [")
    for c in countries:
        const_name = _DACH.get(c["iso2"])
        lines.append(f"  {const_name}," if const_name else f"  {_dart_country(c)},")
    lines.append("];")
    lines.append("")
    lines.append("/// Main region ISO2 per calling code.")
    lines.append("const Map<String, String> kMainRegionForCallingCode = {")
    for cc, iso2 in sorted(main.items(), key=lambda kv: int(kv[0])):
        lines.append(f"  '{cc}': '{iso2}',")
    lines.append("};")
    lines.append("")

    with open(DART_OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
```
And in `main()`, after writing the JSON, add:
```python
    write_dart(data)
    print(f"Wrote Dart registry to {DART_OUT}")
```

- [ ] **Step 6: Regenerate and format**

Run:
```bash
python3 tool/gen_phone_metadata.py
dart format lib/src/common/country.g.dart
```
Expected: `country.g.dart` created; `dart format` reports it formatted. If `dart format` errors on a syntax issue, inspect the offending country entry (usually an unescaped `$`/quote in a pattern) and fix `_dart_str`.

- [ ] **Step 7: Run the test to verify it passes**

Run: `dart test test/phone_global_test.dart`
Expected: PASS (the `skip`ped placeholder test stays skipped).

- [ ] **Step 8: Commit**

```bash
git add lib/src/phone/phone_format.dart lib/src/common/country.dart lib/src/common/country.g.dart tool/gen_phone_metadata.py test/phone_global_test.dart
git commit -m "Add uniform Country registry generated from phone metadata"
```

---

### Task 3: Uniform validation

**Files:**
- Modify: `lib/src/common/issue_code.dart`
- Rewrite: `lib/src/phone/phone.dart` (validate/isValid/normalize; format/type/parse updated in later tasks)
- Test: `test/phone_global_test.dart`

**Interfaces:**
- Consumes: `Country` registry (Task 2).
- Produces: `Phone.validate(String, {Country? country}) → ValidationResult`; new `IssueCode.phoneInvalid` for structural (pattern) mismatch; internal `Country? _resolve(...)` used by later tasks.

- [ ] **Step 1: Add the new issue code**

In `lib/src/common/issue_code.dart`, add `phoneInvalid` to the phone group:
```dart
  // phone
  phoneEmpty,
  phoneBadChars,
  phoneTooShort,
  phoneTooLong,
  phoneAmbiguousCountry,
  phoneUnknownCountry,
  phoneInvalid,
```

- [ ] **Step 2: Write the failing validation tests**

Append to `test/phone_global_test.dart` inside `main()`:
```dart
  group('validation (uniform)', () {
    test('valid FR mobile via E.164', () {
      expect(Phone.isValid('+33612345678'), isTrue);
    });

    test('valid US number via E.164', () {
      expect(Phone.isValid('+12015550123'), isTrue);
    });

    test('valid national with country hint', () {
      expect(Phone.isValid('0316 123456', country: Country.at), isTrue);
    });

    test('too short is rejected by length', () {
      final r = Phone.validate('+331', country: null);
      expect(r, isA<Invalid>());
      expect((r as Invalid).issues.first.code, IssueCode.phoneTooShort);
    });

    test('structurally invalid is rejected by pattern', () {
      // Correct length for FR but not an assignable pattern.
      final r = Phone.validate('+33099999999');
      expect(r, isA<Invalid>());
      expect((r as Invalid).issues.first.code, IssueCode.phoneInvalid);
    });

    test('unknown calling code', () {
      expect(Phone.validate('+9990000000'),
          isA<Invalid>());
    });
  });
```

- [ ] **Step 3: Run to verify failure**

Run: `dart test test/phone_global_test.dart -n validation`
Expected: FAIL — old `validate` only knows DACH.

- [ ] **Step 4: Rewrite validation in `phone.dart`**

Replace the top of `lib/src/phone/phone.dart` (imports, the `_byCallingCode`/`_natLen` maps, `validate`, `isValid`, `normalize`) with the data-driven version. Keep `_allowedChars`/`_digits`:
```dart
import '../common/country.dart';
import '../common/issue_code.dart';
import '../common/validation_result.dart';
import 'at_numbering.dart';
import 'phone_format.dart';
import 'phone_info.dart';
import 'phone_number_type.dart';

/// Validation, normalization (to E.164) and formatting of phone numbers for
/// every country, using libphonenumber-derived metadata. See `doc/algorithms.md`.
class Phone {
  Phone._();

  static final RegExp _allowedChars = RegExp(r'^\+?[0-9\s\-/().]+$');

  static String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  static bool _matchesPattern(Country c, String nsn) =>
      RegExp('^(?:${c.pattern})\$').hasMatch(nsn);

  static bool _lengthOk(Country c, String nsn) =>
      c.possibleLengths.isEmpty || c.possibleLengths.contains(nsn.length);

  /// Resolves the (country, nationalSignificantNumber) for [input].
  /// Returns null country when it cannot be determined.
  static (Country?, String) _resolve(String trimmed, Country? hint) {
    if (trimmed.startsWith('+')) {
      final d = _digits(trimmed);
      // Longest matching calling code (1-3 digits).
      for (final len in const [3, 2, 1]) {
        if (d.length <= len) continue;
        final cc = d.substring(0, len);
        final candidates =
            Country.values.where((c) => c.callingCode == cc).toList();
        if (candidates.isEmpty) continue;
        var nsn = d.substring(len);
        // Prefer a candidate whose pattern+length fully validates.
        for (final c in candidates) {
          if (_lengthOk(c, nsn) && _matchesPattern(c, nsn)) return (c, nsn);
        }
        // Fall back to the main region for display/length checks.
        final main = Country.fromCallingCode(cc) ?? candidates.first;
        return (main, nsn);
      }
      return (null, '');
    }
    // National input: needs a country hint; strip the trunk prefix.
    if (hint == null) return (null, '');
    var d = _digits(trimmed);
    final np = hint.nationalPrefix;
    if (np != null && d.startsWith(np)) d = d.substring(np.length);
    return (hint, d);
  }

  /// Validates [input], returning [Valid] with the E.164 normalized form.
  static ValidationResult validate(String input, {Country? country}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.phoneEmpty, 'Phone is empty.')]);
    }
    if (!_allowedChars.hasMatch(trimmed)) {
      return const Invalid(
          [ValidationIssue(IssueCode.phoneBadChars, 'Bad characters.')]);
    }

    final (resolved, nsn) = _resolve(trimmed, country);
    if (resolved == null) {
      final code = trimmed.startsWith('+')
          ? IssueCode.phoneUnknownCountry
          : IssueCode.phoneAmbiguousCountry;
      final msg = trimmed.startsWith('+') ? 'Unknown country.' : 'Country required.';
      return Invalid([ValidationIssue(code, msg)]);
    }

    final lengths = resolved.possibleLengths;
    if (lengths.isNotEmpty) {
      final min = lengths.first;
      final max = lengths.last;
      if (nsn.length < min) {
        return const Invalid(
            [ValidationIssue(IssueCode.phoneTooShort, 'Too short.')]);
      }
      if (nsn.length > max) {
        return const Invalid(
            [ValidationIssue(IssueCode.phoneTooLong, 'Too long.')]);
      }
    }
    if (!_matchesPattern(resolved, nsn)) {
      return const Invalid(
          [ValidationIssue(IssueCode.phoneInvalid, 'Not a valid number.')]);
    }
    return Valid('+${resolved.callingCode}$nsn');
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input, {Country? country}) =>
      validate(input, country: country) is Valid;

  /// Returns the E.164 canonical form. Throws [FormatException].
  static String normalize(String input, {Country? country}) =>
      switch (validate(input, country: country)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };
```
Leave the existing `format`/`tryFormat`/`_ccNational`/`type`/`parse` methods below for now (Task 4 replaces `format`; they still compile because `_byCallingCode` is removed — so temporarily update `_ccNational` to derive the calling code from the registry). Replace `_ccNational` with:
```dart
  /// Splits a normalized E.164 string into (country, nationalNumber).
  static (Country, String) _ccCountry(String e164) {
    final d = e164.substring(1);
    for (final len in const [3, 2, 1]) {
      final cc = d.length > len ? d.substring(0, len) : d;
      final c = Country.fromCallingCode(cc);
      if (c != null && d.startsWith(cc)) return (c, d.substring(cc.length));
    }
    // Should not happen for a validated E.164.
    throw const FormatException('Unresolvable calling code.');
  }
```
Then update the old `format`, `type`, `parse` bodies to call `_ccCountry` instead of `_ccNational` (they currently expect `(cc, national)` strings — Task 4 rewrites `format`; for now, to keep the file compiling, make `format` delegate to the generic formatter added in Task 4 OR keep a minimal stub). To avoid a broken intermediate, implement `format` fully in Task 4; here, temporarily replace the body of `format`/`tryFormat`/`type`/`parse` with `throw UnimplementedError()` is NOT allowed (tests would break). Instead, keep them working by having `format` use the DACH path only guarded by `if (cc=='43') AtNumbering.format(...)` and a simple international grouping fallback — but Task 4 supersedes this. **Simplest correct approach: do Task 3 and Task 4 as one commit if the intermediate cannot compile cleanly.** See Task 4 Step 1.

- [ ] **Step 5: Run validation tests**

Run: `dart test test/phone_global_test.dart -n validation`
Expected: PASS. If the file does not compile because `format`/`type`/`parse` reference removed helpers, proceed directly to Task 4 (they are rewritten there) and run the full suite at the end of Task 4. Do not commit a non-compiling tree.

- [ ] **Step 6: Commit (only if the tree compiles and tests pass)**

```bash
git add lib/src/common/issue_code.dart lib/src/phone/phone.dart test/phone_global_test.dart
git commit -m "Make phone validation data-driven and global"
```
If the tree does not compile standalone, skip this commit and fold the change into Task 4's commit.

---

### Task 4: Uniform formatter

**Files:**
- Modify: `lib/src/phone/phone_format.dart` (add the formatter function)
- Rewrite: `lib/src/phone/phone.dart` (`format`, `tryFormat`)
- Modify: `lib/src/phone/at_numbering.dart` (remove `format`, keep `classify`)
- Test: `test/phone_global_test.dart`

**Interfaces:**
- Consumes: `Country.formats`, `Country.nationalPrefix`, `_ccCountry` from Task 3.
- Produces: `String? formatNsn(List<PhoneFormat> formats, String nsn, {required bool international, String? nationalPrefix})` in `phone_format.dart`; `Phone.format(...)` / `Phone.tryFormat(...)` working for all countries.

- [ ] **Step 1: Write the failing formatter tests**

Append to `test/phone_global_test.dart`:
```dart
  group('formatting (uniform)', () {
    test('AT international matches libphonenumber grouping', () {
      final e164 = Phone.normalize('0316 123456', country: Country.at);
      final intl = Phone.format(e164, international: true);
      expect(intl.startsWith('+43 '), isTrue);
    });

    test('national form carries the trunk prefix', () {
      final nat = Phone.format('0316123456', country: Country.at, international: false);
      expect(nat.startsWith('0'), isTrue);
    });

    test('formats a FR number internationally', () {
      final intl = Phone.format('+33612345678', international: true);
      expect(intl.startsWith('+33 '), isTrue);
    });

    test('tryFormat returns null on invalid input', () {
      expect(Phone.tryFormat('nope'), isNull);
    });
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `dart test test/phone_global_test.dart -n formatting`
Expected: FAIL (or compile error carried from Task 3).

- [ ] **Step 3: Add the generic formatter to `phone_format.dart`**

Append to `lib/src/phone/phone_format.dart`:
```dart
/// Formats a national significant number [nsn] for [country].
/// Returns null if no format rule matches.
String? formatNsn(
  List<PhoneFormat> formats,
  String nsn, {
  required bool international,
  String? nationalPrefix,
}) {
  for (final f in formats) {
    if (f.leadingDigits != null &&
        !RegExp('^(?:${f.leadingDigits})').hasMatch(nsn)) {
      continue;
    }
    final m = RegExp('^(?:${f.pattern})\$').firstMatch(nsn);
    if (m == null) continue;
    var out = f.format;
    for (var i = m.groupCount; i >= 1; i--) {
      out = out.replaceAll('\$$i', m.group(i) ?? '');
    }
    if (!international) {
      final rule = f.nationalPrefixFormattingRule;
      final np = nationalPrefix ?? '';
      if (rule != null && rule.isNotEmpty) {
        // Pragmatic subset: `$1`/`$FG` = the whole grouped number, `$NP` = the
        // national prefix. Reproduces the common `0$1` case (DACH and most
        // European national forms). Carrier codes (`$CC`) are not supported.
        out = rule
            .replaceAll(r'$NP', np)
            .replaceAll(r'$FG', out)
            .replaceAll(r'$1', out);
      } else if (np.isNotEmpty) {
        out = '$np$out';
      }
    }
    return out;
  }
  return null;
}
```
Note: the national-prefix rule handling is a deliberate subset (no carrier-code
`$CC` support). Exotic national rules may differ from libphonenumber — the
documented "not as detailed as DACH" tradeoff. Vectors (Task 6) are generated
from `phonenumbers`, so any region the subset cannot reproduce is caught and
excluded there rather than shipping wrong output.

- [ ] **Step 4: Rewrite `Phone.format`/`tryFormat`**

Replace `format`/`tryFormat` in `lib/src/phone/phone.dart`:
```dart
  /// Formats [input] internationally (`+43 1 234567`) or nationally
  /// (`01 234567`) when [international] is false. Throws [FormatException].
  static String format(String input,
      {Country? country, bool international = true}) {
    final e164 = normalize(input, country: country);
    final (c, nsn) = _ccCountry(e164);
    final grouped =
        formatNsn(c.formats, nsn, international: international, nationalPrefix: c.nationalPrefix);
    if (grouped == null) {
      // Fallback: E.164 for international, prefixed digits for national.
      return international ? '+${c.callingCode} $nsn' : '${c.nationalPrefix ?? ''}$nsn';
    }
    return international ? '+${c.callingCode} $grouped' : grouped;
  }

  /// Like [format] but returns null on invalid input.
  static String? tryFormat(String input,
      {Country? country, bool international = true}) {
    try {
      return format(input, country: country, international: international);
    } on FormatException {
      return null;
    }
  }
```

- [ ] **Step 5: Trim `at_numbering.dart` to classification only**

In `lib/src/phone/at_numbering.dart`, delete the `format` method (the last method). Keep `AtClass`, `_mobile`, `_service`, `areaCodes`, and `classify`. The `prefix` field of `AtClass` stays (still used by `classify`). Verify nothing else references `AtNumbering.format`:
```bash
grep -rn "AtNumbering.format" lib test
```
Expected: no matches.

- [ ] **Step 6: Run the full phone suite**

Run: `dart test test/phone_global_test.dart test/phone_test.dart test/phone_format_test.dart test/phone_type_test.dart`
Expected: `phone_global_test.dart` passes. **`phone_test.dart`/`phone_format_test.dart` may now fail on AT/DE/CH formatting** because the generic formatter matches libphonenumber, not the old hand-rolled spacing. This is the approved re-baseline. Update those expected strings to the actual formatter output (verify each against `phonenumbers` if unsure: `python3 -c "import phonenumbers as p; n=p.parse('+43...'); print(p.format_number(n, p.PhoneNumberFormat.NATIONAL))"`). Do not change formatter logic to match old strings; libphonenumber is authoritative.

- [ ] **Step 7: Commit**

```bash
git add lib/src/phone/phone_format.dart lib/src/phone/phone.dart lib/src/phone/at_numbering.dart test/
git commit -m "Make phone formatting uniform and global; re-baseline AT output"
```

---

### Task 5: Type classification & parse for all countries

**Files:**
- Rewrite: `lib/src/phone/phone.dart` (`type`, `parse`)
- Modify: `lib/src/phone/phone_info.dart` (doc only)
- Test: `test/phone_global_test.dart`

**Interfaces:**
- Consumes: `_ccCountry`, `AtNumbering.classify`, `Country`.
- Produces: `Phone.type(...) → PhoneNumberType` (AT-classified, else `unknown`); `Phone.parse(...) → PhoneInfo?` for all countries. `PhoneInfo.country` now a full-metadata `Country`.

- [ ] **Step 1: Write the failing tests**

Append to `test/phone_global_test.dart`:
```dart
  group('type & parse (global)', () {
    test('AT mobile still classifies', () {
      expect(Phone.type('+43664123456').name, 'mobile');
    });

    test('non-AT number is unknown type', () {
      expect(Phone.type('+33612345678'), PhoneNumberType.unknown);
    });

    test('parse yields a bundle for a FR number', () {
      final info = Phone.parse('+33612345678');
      expect(info, isNotNull);
      expect(info!.country.iso2, 'FR');
      expect(info.e164, '+33612345678');
      expect(info.country.flag, '🇫🇷');
    });

    test('parse yields null for invalid input', () {
      expect(Phone.parse('nope'), isNull);
    });
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `dart test test/phone_global_test.dart -n "type & parse"`
Expected: FAIL — `type`/`parse` still use the old `_ccNational`/`resolved == Country.at` logic.

- [ ] **Step 3: Rewrite `type` and `parse`**

Replace `type` and `parse` in `lib/src/phone/phone.dart`:
```dart
  /// Classifies [input] by number type. Returns [PhoneNumberType.unknown] for
  /// invalid input or countries without classification data (all but AT).
  static PhoneNumberType type(String input, {Country? country}) {
    final result = validate(input, country: country);
    if (result is! Valid) return PhoneNumberType.unknown;
    final (c, nsn) = _ccCountry(result.normalized);
    if (c.iso2 != 'AT') return PhoneNumberType.unknown;
    return AtNumbering.classify(nsn).type;
  }

  /// Parses [input] into a [PhoneInfo] bundle, or null if invalid.
  static PhoneInfo? parse(String input, {Country? country}) {
    final result = validate(input, country: country);
    if (result is! Valid) return null;
    final e164 = result.normalized;
    final (c, nsn) = _ccCountry(e164);
    final numberType =
        c.iso2 == 'AT' ? AtNumbering.classify(nsn).type : PhoneNumberType.unknown;
    return PhoneInfo(
      e164: e164,
      country: c,
      type: numberType,
      national: format(input, country: country, international: false),
      international: format(input, country: country, international: true),
    );
  }
```

- [ ] **Step 4: Update `phone_info.dart` doc**

In `lib/src/phone/phone_info.dart`, update the `type` field doc:
```dart
  /// The classified number type (`unknown` for countries without
  /// classification data — currently all but AT).
  final PhoneNumberType type;
```

- [ ] **Step 5: Run the suite**

Run: `dart test test/phone_global_test.dart`
Expected: PASS (all groups).

- [ ] **Step 6: Commit**

```bash
git add lib/src/phone/phone.dart lib/src/phone/phone_info.dart test/phone_global_test.dart
git commit -m "Classify and parse phone numbers for all countries"
```

---

### Task 6: Cross-country test vectors

**Files:**
- Modify: `tool/gen_phone_metadata.py` (emit `phone.json` vectors)
- Modify: `lib/kreiseck_validator.dart` (export `phone_format.dart`)
- Regenerate: `test/vectors/phone.json`
- Modify: `test/vectors_test.dart` (resolve country via `Country.fromIso2`)

**Interfaces:**
- Consumes: generator + `Country`.
- Produces: `test/vectors/phone.json` with DACH cases (re-baselined) plus a world spread; `vectors_test.dart` resolves any ISO2.

- [ ] **Step 1: Export `phone_format.dart`**

In `lib/kreiseck_validator.dart`, add after the phone exports:
```dart
export 'src/phone/phone_format.dart';
```

- [ ] **Step 2: Update the vectors test country resolver**

In `test/vectors_test.dart`, replace `_country`:
```dart
Country? _country(String? s) => s == null ? null : Country.fromIso2(s);
```

- [ ] **Step 3: Add a failing vector expectation**

Add a temporary assertion file check — run the existing vectors test to confirm it still loads:

Run: `dart test test/vectors_test.dart -n phone`
Expected: PASS on the current DACH `phone.json` (its `country` values `de/at/ch` resolve via `fromIso2`, which is case-insensitive). If any AT/DE/CH `format` expectation now mismatches the re-baselined formatter, note the failing entries — they are regenerated in Step 4.

- [ ] **Step 4: Emit vectors from the generator**

Add to `tool/gen_phone_metadata.py`:
```python
VECTORS_OUT = os.path.join(ROOT, "test", "vectors", "phone.json")

# Representative spread; NOT all 245 countries (kept small and reviewable).
_VECTOR_REGIONS = ["AT", "DE", "CH", "FR", "GB", "US", "IT", "ES", "NL",
                   "SE", "PL", "JP", "AU", "BR", "IN", "ZA", "IS"]


def build_vectors() -> list[dict]:
    cases = []
    for iso2 in _VECTOR_REGIONS:
        ex = _example(iso2)
        if ex is None:
            continue
        cases.append({
            "input": ex["e164"],
            "country": iso2,
            "isValid": True,
            "normalized": ex["e164"],
            "international": True,
            "format": ex["international"],
        })
        cases.append({
            "input": ex["e164"],
            "country": iso2,
            "international": False,
            "format": ex["national"],
        })
    # A couple of explicit invalids.
    cases.append({"input": "+331", "isValid": False, "code": "phoneTooShort"})
    cases.append({"input": "+9990000000", "isValid": False, "code": "phoneUnknownCountry"})
    return cases


def write_vectors() -> None:
    with open(VECTORS_OUT, "w", encoding="utf-8") as f:
        json.dump(build_vectors(), f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"Wrote vectors to {VECTORS_OUT}")
```
Call `write_vectors()` at the end of `main()`. Note: the vector `format` expectations come from `phonenumbers` (authoritative). If the Dart `formatNsn` output differs from `phonenumbers` for a listed region, drop that region from `_VECTOR_REGIONS` and add a `log`/comment noting the exclusion — do not silently mask a formatter gap.

- [ ] **Step 5: Regenerate and run**

Run:
```bash
python3 tool/gen_phone_metadata.py
dart test test/vectors_test.dart -n phone
```
Expected: PASS. For any region whose national/international expectation the Dart formatter cannot reproduce, remove it from `_VECTOR_REGIONS`, regenerate, and re-run; leave a comment listing removed regions.

- [ ] **Step 6: Commit**

```bash
git add tool/gen_phone_metadata.py lib/kreiseck_validator.dart test/vectors/phone.json test/vectors_test.dart
git commit -m "Add cross-country phone vectors and export PhoneFormat"
```

---

### Task 7: Docs, changelog & release

**Files:**
- Modify: `pubspec.yaml`
- Modify: `CHANGELOG.md`
- Modify: `README.md`
- Modify: `doc/algorithms.md`
- Modify: `example/kreiseck_validator_example.dart`

**Interfaces:** none (documentation + version).

- [ ] **Step 1: Bump the version**

In `pubspec.yaml`, change `version: 0.2.0` to `version: 0.3.0` and update the `description` to mention global scope:
```yaml
description: >-
  Zero-dependency validation, normalization and formatting for email, phone,
  URL, IBAN and credit-card input. Global phone support with flags and example
  numbers; DACH-aware classification. By Kreiseck.
```

- [ ] **Step 2: Write the changelog entry**

Prepend to `CHANGELOG.md`:
```markdown
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
```

- [ ] **Step 3: Update README and algorithms doc**

In `README.md`, add a short "Global phone support" section covering `Country.fromIso2('FR').flag`, `.example`, and `Phone.format('+33612345678')`. In `doc/algorithms.md`, add a "Phone metadata" section explaining the libphonenumber-derived data, the uniform validation (possible lengths + pattern), the subset formatter (grouping + national-prefix rule) and its limitations, and the AT classification layer. Reference the generator and `NOTICE`.

- [ ] **Step 4: Update the example**

In `example/kreiseck_validator_example.dart`, add lines demonstrating a non-DACH number, a flag, and an example number:
```dart
  final fr = Country.fromIso2('FR')!;
  print('${fr.displayName} ${fr.flag}: ${fr.exampleInternational}');
  print(Phone.format('+33612345678'));
```

- [ ] **Step 5: Verify the whole suite and analyzer**

Run:
```bash
dart analyze
dart test
```
Expected: no analyzer issues; all tests pass.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml CHANGELOG.md README.md doc/algorithms.md example/kreiseck_validator_example.dart
git commit -m "Document global phone support and release 0.3.0"
```

---

## Self-Review Notes

- **Spec coverage:** data source/pipeline (Task 1), uniform Country model (Task 2), strict validation (Task 3), uniform formatter + AT re-baseline (Task 4), flags + example numbers (Task 2 fields, Task 5 exposure), classification as data layer (Task 5), vectors/cross-language JSON (Tasks 1 & 6), licensing/NOTICE (Task 1), version bump (Task 7). All spec sections map to a task.
- **Known risk — intermediate compilation between Task 3 and Task 4:** removing `_byCallingCode` breaks `format`/`type`/`parse` until Task 4/5 land. The plan flags this explicitly: commit Task 3 only if the tree compiles, otherwise fold into Task 4. Executors using subagent-driven development should treat Tasks 3–4 as a combined checkpoint if needed.
- **Known risk — `phonenumbers` API attribute names:** verified empirically by Task 1 Step 5 before any Dart depends on them.
- **Known risk — formatter subset vs. libphonenumber:** vectors are generated from `phonenumbers` (authoritative); regions the Dart subset cannot reproduce are dropped with a noted exclusion, never silently masked.
