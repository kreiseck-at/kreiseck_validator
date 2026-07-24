# IMEI/ICCID/MAC/VIN/PostalCode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add five validator modules — `Imei`, `Iccid`, `MacAddress`, `Vin`, `PostalCode` — to BOTH the Dart package and the TS port, checksum/format + structural parse only (no external DBs), with `Vin.parse` computing the model year. Proven by shared JSON vectors.

**Architecture:** One module per package per stage (`lib/src/<m>/`, `js/src/<m>/`), mirroring the existing modules (study `lib/src/iban/` + `js/src/iban/` and the license-plate module for the exact shape). IMEI/ICCID reuse a shared Luhn helper extracted from CreditCard; ICCID reuses the phone calling-code map. Only PostalCode bundles data (a per-country pattern table, generated to Dart + JSON).

**Tech Stack:** Dart + TypeScript (mirrored logic), Python 3 generator (stdlib) for the postal table.

## Global Constraints

- **Two packages, same behaviour.** Every module lands in Dart AND TypeScript and passes the same `test/vectors/<m>.json` in both.
- **Zero runtime dependencies** in both published packages.
- **No AI/tool attribution** anywhere — code, comments, data, docs, commit messages, package metadata. Generated-file header is the only allowed exception.
- **API parity:** `isValid/validate/normalize/format/tryFormat/parse` where applicable; option objects match between languages. `normalize`/`format` throw (FormatException/FormatError) on invalid; `tryFormat` returns null.
- **New IssueCodes** identical in the Dart enum and the TS union (added per stage).
- No behaviour change to existing modules (Email/Phone/Url/Iban/CreditCard/LicensePlate) — except CreditCard is refactored to call the shared Luhn helper with identical results.
- Module names: `Imei`, `Iccid`, `MacAddress`, `Vin`, `PostalCode`; TS subpaths `@kreiseck/validator/{imei,iccid,mac-address,vin,postal-code}`.

---

### Task 1: Shared Luhn helper + `Imei`

**Files:**
- Dart: create `lib/src/common/luhn.dart`, `lib/src/imei/imei.dart`, `lib/src/imei/imei_info.dart`; modify `lib/src/credit_card/credit_card.dart` (use the shared Luhn), `lib/src/common/issue_code.dart`, `lib/kreiseck_validator.dart`.
- TS: create `js/src/common/luhn.ts`, `js/src/imei/index.ts`, `js/src/imei/types.ts`; modify `js/src/credit-card/index.ts`, `js/src/common/types.ts`, `js/src/index.ts`, `js/package.json`, `js/tsup.config.ts`.
- Tests: `test/vectors/imei.json` + wire into `test/vectors_test.dart`; `js/test/imei.conformance.spec.ts`. Existing credit-card tests must still pass (Luhn refactor).

**Interfaces:**
- Produces: `luhnOk(String digits) -> bool` (Dart `lib/src/common/luhn.dart`; TS `luhnOk(digits: string): boolean` in `js/src/common/luhn.ts`); `Imei` namespace (`isValid/validate/normalize/format/tryFormat/parse`); `ImeiInfo { tac; serialNumber; checkDigit; reportingBodyIdentifier }`.

- [ ] **Step 1: Extract the Luhn helper (behaviour-preserving)**

Dart `lib/src/common/luhn.dart`:
```dart
/// Returns true when [digits] (all `0-9`) satisfies the Luhn checksum
/// (rightmost digit is the check digit; every second digit doubled).
bool luhnOk(String digits) {
  var sum = 0;
  var alt = false;
  for (var i = digits.length - 1; i >= 0; i--) {
    var d = digits.codeUnitAt(i) - 0x30;
    if (alt) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
    alt = !alt;
  }
  return sum % 10 == 0;
}
```
TS `js/src/common/luhn.ts`:
```ts
export function luhnOk(digits: string): boolean {
  let sum = 0;
  let alt = false;
  for (let i = digits.length - 1; i >= 0; i--) {
    let d = digits.charCodeAt(i) - 48;
    if (alt) { d *= 2; if (d > 9) d -= 9; }
    sum += d;
    alt = !alt;
  }
  return sum % 10 === 0;
}
```
In `lib/src/credit_card/credit_card.dart`: remove the private `_luhnOk`, `import '../common/luhn.dart';`, and replace `_luhnOk(s)` with `luhnOk(s)`. In `js/src/credit-card/index.ts`: import `luhnOk` from `../common/luhn` and replace the local Luhn. Run credit-card vectors — must be unchanged.

- [ ] **Step 2: Add IMEI IssueCodes**

Dart `issue_code.dart` (after the plate codes): `imeiEmpty, imeiBadChars, imeiBadLength, imeiBadChecksum,`. TS union: `| 'imeiEmpty' | 'imeiBadChars' | 'imeiBadLength' | 'imeiBadChecksum'`.

- [ ] **Step 3: Write the IMEI conformance vectors**

`test/vectors/imei.json`. Use a REAL Luhn-valid IMEI. Compute one: `35 3880 08 007874 0` → verify Luhn; adjust the check digit so it passes. (During implementation, generate a valid 15-digit IMEI whose last digit makes Luhn pass, e.g. TAC `35388008` + serial `007874` + correct check.)
```json
[
  {"input": "<VALID_15_DIGIT_IMEI>", "isValid": true, "normalized": "<same digits>",
   "parse": {"tac": "<first8>", "serialNumber": "<next6>", "checkDigit": "<last>", "reportingBodyIdentifier": "<first2>"}},
  {"input": "3538 8008 0078 740", "isValid": true},
  {"input": "353880080078741", "isValid": false, "code": "imeiBadChecksum"},
  {"input": "12345", "isValid": false, "code": "imeiBadLength"},
  {"input": "35388008007874X", "isValid": false, "code": "imeiBadChars"}
]
```
(Replace placeholders with a real Luhn-valid IMEI and its structural split; make the "bad checksum" case exactly one digit off.)

- [ ] **Step 4: Implement `Imei` (Dart + TS, identical)**

`normalize` = strip all non-digits. `validate`: empty → `imeiEmpty`; non-digit chars present (in the trimmed input, i.e. anything other than digits/spaces/dashes) → `imeiBadChars`; digit count ≠ 15 → `imeiBadLength`; `!luhnOk` → `imeiBadChecksum`; else valid(compact). `format` = compact 15 digits. `parse` → `ImeiInfo { tac: s.substring(0,8), serialNumber: s.substring(8,14), checkDigit: s[14], reportingBodyIdentifier: s.substring(0,2) }`. Export from both barrels; add `./imei` to `js/package.json` exports + `js/tsup.config.ts`.

- [ ] **Step 5: Wire vectors + verify both languages**

Add an `imei` group to `test/vectors_test.dart` (mirror `iban`); create `js/test/imei.conformance.spec.ts`. Run `dart test`, `dart analyze`, `cd js && npm run build && npm test` — all green, credit-card unchanged.

- [ ] **Step 6: Commit**

```bash
git add lib/src/common/luhn.dart lib/src/imei lib/src/credit_card/credit_card.dart \
        lib/src/common/issue_code.dart lib/kreiseck_validator.dart \
        js/src/common/luhn.ts js/src/imei js/src/credit-card/index.ts js/src/common/types.ts \
        js/src/index.ts js/package.json js/tsup.config.ts \
        test/vectors/imei.json test/vectors_test.dart js/test/imei.conformance.spec.ts
git commit -m "Add shared Luhn helper and IMEI validator"
```

---

### Task 2: `Iccid`

**Files:** Dart `lib/src/iccid/iccid.dart` + `iccid_info.dart`; TS `js/src/iccid/index.ts` + `types.ts`; issue codes, barrels, exports map, tsup entry; `test/vectors/iccid.json` + wiring + `js/test/iccid.conformance.spec.ts`.

**Interfaces:** consumes `luhnOk` (Task 1) + the phone calling-code resolution (`Country.fromCallingCode` in Dart; the phone metadata `fromCallingCode` in TS). Produces `Iccid` namespace + `IccidInfo { mii; country; issuerIdentifier; checkDigit }` (country is a resolved `Country`/`Country`-shaped object or null).

- [ ] **Step 1: IssueCodes + failing vectors**

Codes: `iccidEmpty, iccidBadChars, iccidBadLength, iccidBadChecksum` (both languages). `test/vectors/iccid.json`:
```json
[
  {"input": "8949 0000 0000 0000 206", "isValid": true,
   "parse": {"mii": "89", "country": "TR", "checkDigit": null}},
  {"input": "<VALID_20_DIGIT_ICCID_LUHN>", "isValid": true,
   "parse": {"mii": "89", "country": "DE", "checkDigit": "<last>"}},
  {"input": "88900000000000000000", "isValid": false, "code": "iccidBadFormat"},
  {"input": "890", "isValid": false, "code": "iccidBadLength"}
]
```
(During implementation: verify each vector's country resolves via the E.164 code after `89` — e.g. `8949…`→CC `49`→DE, `8990…`→CC `90`→TR; pick real digit strings and, for the 20-digit case, a Luhn-valid one. Use `iccidBadFormat` only if you add that code; otherwise start-with-`89` failures map to `iccidBadChars`/`iccidBadLength` — pick and document one, keep it consistent across both languages and the spec.)

- [ ] **Step 2: Implement `Iccid` (both languages)**

`normalize` = strip non-digits. `validate`: empty → `iccidEmpty`; non-digit → `iccidBadChars`; length ∉ {19,20} or not starting `89` → `iccidBadLength` (start-with-89 failure → same length/format code; be consistent); if length 20, `!luhnOk(all 20)` → `iccidBadChecksum`. `parse`: `mii = '89'`; resolve `country` by longest-match E.164: for k in 3,2,1 take `digits.substring(2, 2+k)` and if it is a known calling code (Dart `Country.fromCallingCode`, TS phone `fromCallingCode`) use it (longest wins), else null; `issuerIdentifier` = the digits between the country code and the (optional) check digit; `checkDigit` = last digit if length 20 else null. `format`/`normalize` = compact digits.

- [ ] **Step 3: Verify both languages + commit**

`dart test`, `dart analyze`, `cd js && npm run build && npm test` green. Commit "Add ICCID validator".

---

### Task 3: `MacAddress`

**Files:** Dart `lib/src/mac_address/mac_address.dart` + `mac_info.dart`; TS `js/src/mac-address/index.ts` + `types.ts`; issue codes, barrels, exports map, tsup entry; vectors + wiring + spec.

**Interfaces:** produces `MacAddress` namespace + `MacInfo { oui; nic; isUnicast; isMulticast; isUniversal; isLocal; type }` where `type` ∈ `'eui48' | 'eui64'`.

- [ ] **Step 1: IssueCodes + failing vectors**

Codes: `macEmpty, macBadFormat`. `test/vectors/mac.json` (the format vector needs a `notation`):
```json
[
  {"input": "00:1A:2B:3C:4D:5E", "isValid": true, "normalized": "00:1a:2b:3c:4d:5e",
   "parse": {"oui": "00:1a:2b", "isUnicast": true, "isUniversal": true, "type": "eui48"}},
  {"input": "00-1A-2B-3C-4D-5E", "isValid": true, "normalized": "00:1a:2b:3c:4d:5e"},
  {"input": "001A.2B3C.4D5E", "isValid": true, "normalized": "00:1a:2b:3c:4d:5e"},
  {"input": "001a2b3c4d5e", "isValid": true, "normalized": "00:1a:2b:3c:4d:5e"},
  {"input": "01:00:5e:00:00:01", "isValid": true, "parse": {"isMulticast": true}},
  {"input": "02:00:00:00:00:01", "isValid": true, "parse": {"isLocal": true}},
  {"input": "00:1A:2B:3C:4D:5E:6F:70", "isValid": true, "parse": {"type": "eui64"}},
  {"input": "00:1A:2B:3C:4D", "isValid": false, "code": "macBadFormat"},
  {"input": "ZZ:1A:2B:3C:4D:5E", "isValid": false, "code": "macBadFormat"}
]
```
(Confirm the exact `parse` fields your `MacInfo` exposes; the conformance runner should check only the keys present in each vector's `parse` object.)

- [ ] **Step 2: Implement `MacAddress` (both languages)**

Accept notations via regexes on the trimmed input: colon `^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$` (48) / `([0-9A-Fa-f]{2}:){7}…` (64); hyphen (same with `-`); Cisco dot `^([0-9A-Fa-f]{4}\.){2}[0-9A-Fa-f]{4}$` (48) / `([0-9A-Fa-f]{4}\.){3}…` (64); bare `^[0-9A-Fa-f]{12}$` / `{16}`. `validate`: empty → `macEmpty`; no notation matches → `macBadFormat`. Extract the 12/16 hex chars → octets. `normalize` = lower-case colon form. `format(input, { notation, upperCase })` (notation ∈ colon|hyphen|dot|bare, default colon). `parse`: `oui` = first 3 octets (in the normalized notation), `nic` = rest; first octet `b0` = parseInt(octet0,16); `isMulticast = (b0 & 1) === 1`, `isUnicast = !isMulticast`, `isLocal = (b0 & 2) === 2`, `isUniversal = !isLocal`; `type` = 'eui48' (12 hex) or 'eui64' (16 hex).

- [ ] **Step 3: Verify both languages + commit** (`dart test`, `npm test`; commit "Add MAC address validator").

---

### Task 4: `Vin`

**Files:** Dart `lib/src/vin/vin.dart` + `vin_info.dart`; TS `js/src/vin/index.ts` + `types.ts`; issue codes, barrels, exports map, tsup entry; vectors + wiring + spec.

**Interfaces:** produces `Vin` namespace + `VinInfo { wmi; vds; vis; checkDigit; checkDigitValid; modelYear; plantCode }`. `validate` = structure only; the check digit is exposed via `checkDigitValid`, never rejected.

- [ ] **Step 1: IssueCodes + failing vectors**

Codes: `vinEmpty, vinBadChars, vinBadLength`. `test/vectors/vin.json` — use a REAL VIN with a known model year:
```json
[
  {"input": "1HGCM82633A004352", "isValid": true, "normalized": "1HGCM82633A004352",
   "parse": {"wmi": "1HG", "vds": "CM8263", "vis": "3A004352", "checkDigit": "3", "checkDigitValid": true, "modelYear": 2003}},
  {"input": "1hgcm82633a004352", "isValid": true, "normalized": "1HGCM82633A004352"},
  {"input": "WVWZZZ1JZXW000001", "isValid": true, "parse": {"wmi": "WVW", "modelYear": 1999}},
  {"input": "1HGCM82633A00435", "isValid": false, "code": "vinBadLength"},
  {"input": "1HGCM8263IA004352", "isValid": false, "code": "vinBadChars"}
]
```
(`1HGCM82633A004352` is the canonical NHTSA example: check digit `3` valid, model year code `3`→2003. Verify `WVWZZZ1JZXW000001`: year code `X` with position 7 letter → 1999 vs 2029 — position 7 is `1` (digit) here so 1980–2009 cycle → `X`=1999. Confirm during implementation and adjust the expected `modelYear`.)

- [ ] **Step 2: Implement `Vin` (both languages)**

Charset regex `^[A-HJ-NPR-Z0-9]{17}$` on the upper-cased input. `validate`: empty → `vinEmpty`; length ≠ 17 → `vinBadLength`; contains disallowed char (I/O/Q or non-alnum) → `vinBadChars`; else valid(upper). `normalize`/`format` = upper-case VIN.

Check digit (`checkDigitValid`): transliterate each char with
```
A1 B2 C3 D4 E5 F6 G7 H8  J1 K2 L3 M4 N5 P7 R9  S2 T3 U4 V5 W6 X7 Y8 Z9   (digits = themselves)
```
weights `[8,7,6,5,4,3,2,10,0,9,8,7,6,5,4,3,2]`; `sum = Σ value[i]*weight[i]`; `r = sum % 11`; expected = `r == 10 ? 'X' : String(r)`; `checkDigitValid = expected == vin[8]`.

Model year (`modelYear`, int): map char 10 (`vin[9]`) via the code table:
```
A1980 B1981 C1982 D1983 E1984 F1985 G1986 H1987 J1988 K1989 L1990 M1991 N1992
P1993 R1994 S1995 T1996 V1997 W1998 X1999 Y2000
1:2001 2:2002 3:2003 4:2004 5:2005 6:2006 7:2007 8:2008 9:2009
```
This is the 1980–2009 base cycle. Disambiguate the 30-year repeat by position 7 (`vin[6]`): if `vin[6]` is a LETTER → add 30 (2010–2039 cycle); if a DIGIT → keep the base year. Return the resolved year. `plantCode` = `vin[10]`. `parse` → `VinInfo` with `wmi: vin[0..3]`, `vds: vin[3..9]`, `vis: vin[9..17]`.

- [ ] **Step 3: Verify both languages + commit** (`dart test`, `npm test`; commit "Add VIN validator with model-year decoding").

---

### Task 5: `PostalCode` (Europe + Turkey)

**Files:** Dart `lib/src/postal_code/postal_code.dart` + `postal_info.dart` + `postal_metadata.g.dart` (generated); TS `js/src/postal-code/index.ts` + `types.ts` + `js/src/data/postal-metadata.json`; generator `tool/gen_postal_metadata.py`; issue codes, barrels, exports map, tsup entry; vectors + wiring + spec.

**Interfaces:** produces `PostalCode` namespace (ops take `{ country }`) + `PostalInfo { country; code }`. `kPostalPatterns` = `country → { pattern, canonicalFormat }` (Dart const / TS JSON).

- [ ] **Step 1: IssueCodes + failing vectors**

Codes: `postalEmpty, postalBadFormat, postalUnknownCountry`. `test/vectors/postal_code.json`:
```json
[
  {"input": "10115", "country": "DE", "isValid": true, "normalized": "10115",
   "parse": {"country": "DE", "code": "10115"}},
  {"input": "1010", "country": "AT", "isValid": true},
  {"input": "8001", "country": "CH", "isValid": true},
  {"input": "1234 AB", "country": "NL", "isValid": true, "normalized": "1234 AB"},
  {"input": "1234ab", "country": "NL", "isValid": true, "normalized": "1234 AB", "format": "1234 AB"},
  {"input": "00-950", "country": "PL", "isValid": true},
  {"input": "SW1A 1AA", "country": "GB", "isValid": true, "normalized": "SW1A 1AA"},
  {"input": "34000", "country": "TR", "isValid": true},
  {"input": "ABCDE", "country": "DE", "isValid": false, "code": "postalBadFormat"},
  {"input": "10115", "country": "XX", "isValid": false, "code": "postalUnknownCountry"}
]
```
(Adjust expected `normalized`/`format` to the canonical rules you implement per country. Verify each country's pattern against the curated table.)

- [ ] **Step 2: Curate the postal patterns + generator**

Create `tool/gen_postal_metadata.py` (stdlib). Embed a curated dict `patterns = { 'DE': {'pattern': r'\d{5}', 'format': '#####'}, 'AT': {...}, ... }` for the European countries + `TR`. Source the per-country postal-code patterns from the public i18n postal-format data (Google libaddressinput format rules — patterns are facts). Cover the European set (EU + EFTA + micro-states + neighbours) plus TR — roughly: AD, AL, AT, BA, BE, BG, BY, CH, CY, CZ, DE, DK, EE, ES, FI, FO, FR, GB, GG, GI, GR, HR, HU, IE, IM, IS, IT, JE, LI, LT, LU, LV, MC, MD, ME, MK, MT, NL, NO, PL, PT, RO, RS, RU, SE, SI, SK, SM, TR, UA, VA. For countries with no postal system, omit them (→ `postalUnknownCountry`). Store the regex (as a string) + a canonical normalize rule (uppercase; insert the country's separator/spacing — e.g. NL `#### AA`, GB variable, PL `##-###`, PT `####-###`). Emit Dart `postal_metadata.g.dart` (`part of 'postal_code.dart';`, `const Map<String, PostalPattern> kPostalPatterns = {...}`) and TS `js/src/data/postal-metadata.json`. Generator self-check: every pattern compiles; count ≥ 40. Run it.

- [ ] **Step 3: Implement `PostalCode` (both languages)**

`validate(input, { country })`: `country` upper-cased; not in `kPostalPatterns` → `postalUnknownCountry`; empty input → `postalEmpty`; normalize the input (uppercase, strip/collapse spaces per the country's canonical rule) and test the country regex → no match → `postalBadFormat`; else valid(normalized). `normalize`/`format(input, {country})` = the canonical form. `parse(input, {country})` → `PostalInfo { country, code: normalized }`.

- [ ] **Step 4: Verify both languages + commit** (`dart test`, `dart analyze`, `npm test`; commit "Add PostalCode validator for Europe and Turkey").

---

### Task 6: Docs, exports, and version bump (both packages)

**Files:** `README.md`, `js/README.md`, `CHANGELOG.md`, `pubspec.yaml`, `js/package.json`, `doc/algorithms.md`, `NOTICE` (if postal-data attribution is warranted).

- [ ] **Step 1: Dart docs + version**

Add feature bullets + short examples for the five new modules to `README.md` (verify outputs against the built package — e.g. `Vin.parse('1HGCM82633A004352').modelYear == 2003`, `Imei.isValid` on a Luhn-valid IMEI, a MAC round-trip, `PostalCode.isValid('1234 AB', country: 'NL')`). Add a `## 0.8.0` CHANGELOG entry listing the five modules + the checksums (Luhn, VIN mod-11) + VIN model-year decoding + PostalCode country coverage. Bump `pubspec.yaml` to `0.8.0`.

- [ ] **Step 2: TS docs + version**

Add the five modules to `js/README.md` (with subpath imports); bump `js/package.json` to `0.8.0`; matching CHANGELOG line.

- [ ] **Step 3: algorithms doc + NOTICE**

In `doc/algorithms.md`: note the Luhn reuse (IMEI/ICCID), the VIN ISO-3779 check digit + the model-year decode (position 10 + position-7 disambiguation), and that MAC/VIN/IMEI/ICCID need no bundled data while PostalCode uses a curated per-country pattern table. If the postal patterns came from a specific public source, add a one-line `NOTICE` attribution.

- [ ] **Step 4: Final verification**

`dart analyze && dart test`; `cd js && npm run build && npm test`. All green in both.

- [ ] **Step 5: Commit** (`git commit -am "Document new validators and release 0.8.0"`, staging generated/untracked files explicitly.)

---

## Self-Review

**Spec coverage:**
- Imei (Luhn + TAC/serial split) — Task 1. ✓
- Iccid (Luhn on 20-digit, MII, E.164 country resolve) — Task 2. ✓
- MacAddress (4 notations, EUI-48/64, unicast/multicast/universal/local) — Task 3. ✓
- Vin (structure-only validate, check-digit flag, **model-year decode**) — Task 4. ✓
- PostalCode (Europe + TR pattern table, country option) — Task 5. ✓
- Shared Luhn helper (CreditCard refactor, behaviour-preserving) — Task 1. ✓
- Both Dart + TS per module, shared vectors — every task. ✓
- Docs + version 0.8.0 both packages — Task 6. ✓

**Type consistency:** `luhnOk` signature identical (Dart/TS). New IssueCodes added identically to the Dart enum and TS union per stage. `Vin` validate is structure-only in both; `checkDigitValid`/`modelYear` are parse fields, not validation gates. PostalCode ops take `{ country }` in both; `kPostalPatterns` is `country → {pattern, format}` in the Dart const map and the TS JSON.

**Placeholder scan:** algorithms (Luhn, VIN transliteration/weights/year table, MAC flag bits, ICCID structure) are given in full. The IMEI/ICCID/VIN/postal DATA in the vectors (a valid IMEI, a Luhn ICCID, real VINs, per-country postal codes) is verified/curated during each task against the named standard/source, with the vector as the concrete acceptance — not left as an unfilled TODO. The postal pattern table is curated in Task 5 from the named public source; the generator self-checks (patterns compile, count ≥ 40).
