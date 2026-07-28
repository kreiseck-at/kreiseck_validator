# kreiseck_validator 0.11.0 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add six business-identifier types (`VatId`, `Bic`, `Gtin`,
`SocialSecurityNumber`, `CompanyRegister`, `TaxNumber`) and a DOM field-binding
subpath to the TypeScript port, then release 0.11.0 on pub.dev and npm.

**Architecture:** Each type is a new directory under `lib/src/` (Dart) and
`js/src/` (TS) exposing the established static-method contract
(`isValid`/`validate`/`normalize`/`format`/`tryFormat`/`parse`/`fieldDescriptor`/`formatPartial`).
Behaviour is pinned by language-agnostic JSON vectors in `test/vectors/` that
both test suites load, so Dart and TS cannot drift. VAT structure data is
generated from one curated source file into both a Dart `part` file and a JSON
file; VAT check digits are code, dispatched per country.

**Tech Stack:** Dart ≥3.0 (zero runtime deps), TypeScript 5 + tsup + vitest
(zero runtime deps), Python 3 for the `tool/` generators.

## Global Constraints

- **Design source:** `docs/business-identifiers-design.md`. It is authoritative;
  if this plan contradicts it, the design wins.
- **Zero runtime dependencies** in both languages. `dom` may use DOM lib types
  only — no framework, no polyfill.
- **Do not copy code from `python-stdnum`.** It is LGPL, this package is
  Apache-2.0. Implement from the algorithm descriptions in the design doc. Cite
  the underlying standard (ISO 7064, Luhn, ISO 9362, GS1) where one is named.
- **No vector may be produced by the implementation under test.** Every valid
  example comes from a published source: a company imprint, an official
  example, or a documented third-party test value. Where a number was
  generated to exercise a branch, it must be a *deliberately broken* one
  (checksum off by one) derived from a published valid number.
- **Dart `normalize`/`format` throw `FormatException`; TS throw `FormatError`.**
  `fieldDescriptor` and `formatPartial` never throw, not even for an unknown
  country — they degrade to a generic descriptor.
- **`IssueCode` is a stable enum.** New members go in the existing per-type
  comment-grouped order in `lib/src/common/issue_code.dart` and the mirrored
  union in `js/src/common/types.ts`. The two lists must stay in the same order.
- **Comments and docs in English** (this is a public, English-documented
  package). Dart members need `///` doc comments — `dart analyze` enforces
  public-API documentation in this repo.
- **Every type task ends with all four suites green:** `dart analyze`,
  `dart test`, `cd js && npm run build`, `cd js && npm test`.
- **Version 0.11.0** goes into `pubspec.yaml` and `js/package.json` in the same
  commit, in the release task only — not earlier.

---

## File Structure

**New — Dart:**

| File | Responsibility |
|---|---|
| `lib/src/common/iso7064.dart` | ISO 7064 MOD 11,10 and MOD 97,10 checksums |
| `lib/src/bic/bic.dart`, `bic_info.dart` | ISO 9362 BIC |
| `lib/src/gtin/gtin.dart`, `gtin_info.dart` | GS1 GTIN-8/12/13/14 |
| `lib/src/tax_number/tax_number.dart`, `tax_number_info.dart`, `tax_office.g.dart` | AT Abgabenkontonummer |
| `lib/src/social_security/social_security.dart`, `social_security_info.dart` | AT SVNR |
| `lib/src/company_register/company_register.dart`, `company_register_info.dart` | AT Firmenbuchnummer |
| `lib/src/vat_id/vat_id.dart`, `vat_info.dart`, `vat_checks.dart`, `vat_metadata.g.dart` | VAT ID; `vat_checks.dart` holds the per-country check digits |

**New — TypeScript:**

| File | Responsibility |
|---|---|
| `js/src/common/iso7064.ts` | mirror of the Dart helper |
| `js/src/bic/index.ts`, `types.ts` | BIC |
| `js/src/gtin/index.ts`, `types.ts` | GTIN |
| `js/src/tax-number/index.ts`, `types.ts` | AT tax number |
| `js/src/social-security/index.ts`, `types.ts` | AT SVNR |
| `js/src/company-register/index.ts`, `types.ts` | AT Firmenbuchnummer |
| `js/src/vat-id/index.ts`, `types.ts`, `checks.ts`, `metadata.ts` | VAT ID |
| `js/src/data/vat-metadata.json`, `tax-office-metadata.json` | generated data |
| `js/src/dom/index.ts` | `fieldAttrs`, `filterValue`, `bindInput` |

**New — tooling & vectors:**
`tool/data/vat-formats.json`, `tool/data/at-tax-offices.json`,
`tool/gen_vat_metadata.py`, `tool/gen_tax_office_metadata.py`,
`test/vectors/{vat_id,bic,gtin,social_security,company_register,tax_number}.json`,
`js/test/{vat-id,bic,gtin,social-security,company-register,tax-number}.conformance.spec.ts`,
`js/test/dom.spec.ts`.

**Modified:** `lib/kreiseck_validator.dart`, `lib/src/common/issue_code.dart`,
`js/src/index.ts`, `js/src/common/types.ts`, `js/package.json`,
`js/tsup.config.ts`, `js/test/{field.conformance,field-invariants,treeshaking}.spec.ts`,
`test/vectors_test.dart`, `test/field_invariants_test.dart`,
`test/vectors/{field_descriptor,format_partial}.json`, `README.md`,
`js/README.md`, `llms.txt`, `doc/algorithms.md`, `CHANGELOG.md`,
`js/CHANGELOG.md`, `pubspec.yaml`.

---

## Task 1: ISO 7064 helpers and the new issue codes

Foundation for DE, HR and NL. Nothing else in this task computes anything.

**Files:**
- Create: `lib/src/common/iso7064.dart`, `js/src/common/iso7064.ts`
- Create: `test/iso7064_test.dart`, `js/test/iso7064.spec.ts`
- Modify: `lib/src/common/issue_code.dart`, `js/src/common/types.ts`

**Interfaces:**
- Produces: `mod11_10Ok(String digits) -> bool` (valid when the checksum is 1),
  `mod97_10Ok(String value) -> bool` (alphanumeric input, valid when the
  base-10 expansion mod 97 is 1). TS: `mod1110Ok`, `mod9710Ok`, same semantics.

- [ ] **Step 1: Write the failing Dart test**

`test/iso7064_test.dart`. The MOD 11,10 case is the documented worked example
`794623` (check digit 3 for the body `79462`). The MOD 97,10 case is an IBAN,
which is exactly this algorithm: `AT611904300234573201` rearranged to
`1904300234573201AT61` expands to base 10 and leaves remainder 1.

```dart
import 'package:kreiseck_validator/src/common/iso7064.dart';
import 'package:test/test.dart';

void main() {
  group('ISO 7064 MOD 11,10', () {
    test('accepts the documented example', () {
      expect(mod11_10Ok('794623'), isTrue);
    });
    test('rejects a wrong check digit', () {
      expect(mod11_10Ok('794624'), isFalse);
    });
    test('rejects a transposition', () {
      expect(mod11_10Ok('974623'), isFalse);
    });
  });

  group('ISO 7064 MOD 97,10', () {
    test('accepts a rearranged IBAN', () {
      expect(mod97_10Ok('1904300234573201AT61'), isTrue);
    });
    test('rejects a broken one', () {
      expect(mod97_10Ok('1904300234573201AT62'), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `dart test test/iso7064_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'kreiseck_validator'`-style
compile error, or `mod11_10Ok isn't defined`.

- [ ] **Step 3: Implement the Dart helper**

`lib/src/common/iso7064.dart`:

```dart
/// ISO 7064 checksum algorithms, shared by several national identifiers.
///
/// MOD 11,10 is a pure-numeric hybrid system; MOD 97,10 evaluates the whole
/// value as an integer after expanding letters to two digits (`A` -> 10).
library;

/// True when [digits] (all `0-9`, check digit included) satisfies
/// ISO 7064 MOD 11,10. Used by the German VAT number and the Croatian OIB.
bool mod11_10Ok(String digits) {
  var check = 5;
  for (var i = 0; i < digits.length; i++) {
    final d = digits.codeUnitAt(i) - 0x30;
    if (d < 0 || d > 9) return false;
    check = (((check == 0 ? 10 : check) * 2) % 11 + d) % 10;
  }
  return check == 1;
}

/// True when [value] satisfies ISO 7064 MOD 97,10. Letters expand to their
/// base-36 value (`A` -> 10 … `Z` -> 35) before the modulus is taken, so the
/// value is processed digit by digit to avoid big integers.
bool mod97_10Ok(String value) {
  var remainder = 0;
  for (var i = 0; i < value.length; i++) {
    final c = value.codeUnitAt(i);
    final int expanded;
    if (c >= 0x30 && c <= 0x39) {
      expanded = c - 0x30;
    } else if (c >= 0x41 && c <= 0x5A) {
      expanded = c - 0x41 + 10;
    } else {
      return false;
    }
    if (expanded >= 10) {
      remainder = (remainder * 100 + expanded) % 97;
    } else {
      remainder = (remainder * 10 + expanded) % 97;
    }
  }
  return remainder == 1;
}
```

- [ ] **Step 4: Run the Dart test — expect PASS**

Run: `dart test test/iso7064_test.dart`

- [ ] **Step 5: Mirror it in TypeScript with the same test**

`js/src/common/iso7064.ts` — same two functions, named `mod1110Ok` and
`mod9710Ok` (TS naming has no underscores elsewhere in this codebase):

```ts
// ISO 7064 checksum algorithms, shared by several national identifiers.

// True when digits (all 0-9, check digit included) satisfies MOD 11,10.
export function mod1110Ok(digits: string): boolean {
  let check = 5;
  for (let i = 0; i < digits.length; i++) {
    const d = digits.charCodeAt(i) - 48;
    if (d < 0 || d > 9) return false;
    check = (((check === 0 ? 10 : check) * 2) % 11 + d) % 10;
  }
  return check === 1;
}

// True when value satisfies MOD 97,10. Letters expand to base-36 values.
export function mod9710Ok(value: string): boolean {
  let remainder = 0;
  for (let i = 0; i < value.length; i++) {
    const c = value.charCodeAt(i);
    let expanded: number;
    if (c >= 48 && c <= 57) expanded = c - 48;
    else if (c >= 65 && c <= 90) expanded = c - 65 + 10;
    else return false;
    remainder = expanded >= 10
      ? (remainder * 100 + expanded) % 97
      : (remainder * 10 + expanded) % 97;
  }
  return remainder === 1;
}
```

`js/test/iso7064.spec.ts` asserts the same five cases as the Dart test.

- [ ] **Step 6: Run the TS test — expect PASS**

Run: `cd js && npx vitest run test/iso7064.spec.ts`

- [ ] **Step 7: Add every new issue code, both languages**

Append to `lib/src/common/issue_code.dart`, keeping the per-type comment style:

```dart
  // bic
  bicEmpty,
  bicBadLength,
  bicBadChars,
  bicUnknownCountry,
  // gtin
  gtinEmpty,
  gtinBadChars,
  gtinBadLength,
  gtinBadChecksum,
  // vat id
  vatEmpty,
  vatBadFormat,
  vatBadChecksum,
  vatUnknownCountry,
  vatAmbiguousCountry,
  // social security number
  ssnEmpty,
  ssnBadChars,
  ssnBadLength,
  ssnBadChecksum,
  ssnBadDate,
  ssnUnknownCountry,
  // company register
  companyRegisterEmpty,
  companyRegisterBadFormat,
  companyRegisterBadChecksum,
  companyRegisterUnknownCountry,
  // tax number
  taxNumberEmpty,
  taxNumberBadChars,
  taxNumberBadLength,
  taxNumberBadChecksum,
  taxNumberUnknownCountry,
```

Mirror the same 26 members, in the same order, into the `IssueCode` union in
`js/src/common/types.ts`.

There is deliberately **no** `taxNumberUnknownOffice`: the Finanzamt number is
reported by `parse` and never rejected (design doc, `TaxNumber` section).

- [ ] **Step 8: Add a test that the two lists agree**

`js/test/common.spec.ts` already exists; extend it so a drift in the union is
caught. Add a literal array of all codes and assert its length and that a
sample of new codes type-checks:

```ts
it('carries the 0.11 issue codes', () => {
  const codes: IssueCode[] = [
    'bicEmpty', 'bicBadLength', 'bicBadChars', 'bicUnknownCountry',
    'gtinEmpty', 'gtinBadChars', 'gtinBadLength', 'gtinBadChecksum',
    'vatEmpty', 'vatBadFormat', 'vatBadChecksum', 'vatUnknownCountry', 'vatAmbiguousCountry',
    'ssnEmpty', 'ssnBadChars', 'ssnBadLength', 'ssnBadChecksum', 'ssnBadDate', 'ssnUnknownCountry',
    'companyRegisterEmpty', 'companyRegisterBadFormat', 'companyRegisterBadChecksum', 'companyRegisterUnknownCountry',
    'taxNumberEmpty', 'taxNumberBadChars', 'taxNumberBadLength', 'taxNumberBadChecksum', 'taxNumberUnknownCountry',
  ];
  expect(new Set(codes).size).toBe(28);
});
```

- [ ] **Step 9: Run everything and commit**

```bash
dart analyze && dart test
cd js && npm run build && npm test && cd ..
git add lib/src/common/iso7064.dart lib/src/common/issue_code.dart test/iso7064_test.dart \
        js/src/common/iso7064.ts js/src/common/types.ts js/test/iso7064.spec.ts js/test/common.spec.ts
git commit -m "Add ISO 7064 helpers and the 0.11 issue codes"
```

---

## Task 2: `Bic`

**Files:**
- Create: `lib/src/bic/bic.dart`, `lib/src/bic/bic_info.dart`
- Create: `js/src/bic/index.ts`, `js/src/bic/types.ts`
- Create: `test/vectors/bic.json`, `js/test/bic.conformance.spec.ts`
- Modify: `lib/kreiseck_validator.dart`, `js/src/index.ts`, `js/tsup.config.ts`,
  `js/package.json`, `test/vectors_test.dart`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `Bic.validate/isValid/normalize/format/tryFormat/parse/fieldDescriptor/formatPartial`,
  `Bic.matchesIban(String bic, String iban) -> bool`,
  `BicInfo { institution, country, location, branch, kind }`,
  `BicKind { live, test, passive, reverseBilling }`.

- [ ] **Step 1: Write the vector file**

`test/vectors/bic.json`. `BKAUATWW` (UniCredit Bank Austria) and `COBADEFF`
(Commerzbank) are already in this repo's IBAN bank metadata, so they are
published values, not invented ones.

```json
[
  {"input": "BKAUATWW", "isValid": true, "normalized": "BKAUATWW", "format": "BKAUATWW",
   "parse": {"institution": "BKAU", "country": "AT", "location": "WW", "branch": null, "kind": "live"}},
  {"input": "bkau at ww", "isValid": true, "normalized": "BKAUATWW"},
  {"input": "COBADEFFXXX", "isValid": true, "normalized": "COBADEFFXXX", "format": "COBADEFFXXX",
   "parse": {"institution": "COBA", "country": "DE", "location": "FF", "branch": "XXX", "kind": "live"}},
  {"input": "BKAUATW0", "isValid": true, "parse": {"kind": "test"}},
  {"input": "BKAUATW1", "isValid": true, "parse": {"kind": "passive"}},
  {"input": "BKAUATW2", "isValid": true, "parse": {"kind": "reverseBilling"}},
  {"input": "", "isValid": false, "code": "bicEmpty"},
  {"input": "BKAUATW", "isValid": false, "code": "bicBadLength"},
  {"input": "BKAUATWWXX", "isValid": false, "code": "bicBadLength"},
  {"input": "BK1UATWW", "isValid": false, "code": "bicBadChars"},
  {"input": "BKAUZZWW", "isValid": false, "code": "bicUnknownCountry"}
]
```

- [ ] **Step 2: Wire the vector into both suites and watch it fail**

In `test/vectors_test.dart` add, next to the existing per-type blocks:

```dart
  for (final c in _load('bic.json')) {
    _check('bic', c, () => Bic.validate(c['input'] as String),
        () => Bic.format(c['input'] as String));
  }
```

Create `js/test/bic.conformance.spec.ts` modelled on
`js/test/vin.conformance.spec.ts` (no options object — `Bic` takes none).

Run: `dart test test/vectors_test.dart`
Expected: FAIL — `Bic` is not defined.

- [ ] **Step 3: Implement `BicInfo` and `Bic` in Dart**

`lib/src/bic/bic_info.dart`:

```dart
/// What the second character of the location code says about a BIC.
enum BicKind {
  /// A normal, connected BIC.
  live,

  /// A test-and-training BIC (location code ends in `0`). Never usable in a
  /// production payment file.
  test,

  /// A passive participant, not connected to the network (`1`), sometimes
  /// called a BIC1 or non-SWIFT BIC.
  passive,

  /// A reverse-billing BIC (`2`): the receiver pays for the message.
  reverseBilling,
}

/// Structured data parsed out of a BIC by `Bic.parse`.
class BicInfo {
  /// Creates a parsed BIC.
  const BicInfo({
    required this.institution,
    required this.country,
    required this.location,
    required this.branch,
    required this.kind,
  });

  /// Institution (bank) code, 4 letters.
  final String institution;

  /// ISO 3166-1 alpha-2 country code.
  final String country;

  /// Location code, 2 alphanumerics.
  final String location;

  /// Branch code, 3 alphanumerics, or null for the 8-character form.
  final String? branch;

  /// What the location code's second character marks this BIC as.
  final BicKind kind;
}
```

`lib/src/bic/bic.dart` — structure per ISO 9362, country resolved through the
existing `Country` table:

```dart
import '../common/country.dart';
import '../common/field_descriptor.dart';
import '../common/issue_code.dart';
import '../common/partial_format.dart';
import '../common/validation_result.dart';
import 'bic_info.dart';

/// Validation, normalization, formatting and parsing of Business Identifier
/// Codes (ISO 9362), the codes commonly called SWIFT codes.
///
/// An `XXX` branch code is preserved rather than stripped: it is meaningful
/// in SEPA payloads. The second character of the location code is parsed
/// rather than ignored — a test-and-training BIC in a production payment file
/// is a silent failure, so [BicInfo.kind] surfaces it.
class Bic {
  Bic._();

  static final RegExp _shape = RegExp(r'^[A-Z]{4}[A-Z]{2}[A-Z0-9]{2}([A-Z0-9]{3})?$');
  static final RegExp _space = RegExp(r'\s');

  /// Validates [input], returning [Valid] with the compact upper-case form.
  static ValidationResult validate(String input) {
    final upper = input.toUpperCase().replaceAll(_space, '');
    if (upper.isEmpty) {
      return const Invalid([ValidationIssue(IssueCode.bicEmpty, 'BIC is empty.')]);
    }
    if (upper.length != 8 && upper.length != 11) {
      return const Invalid([
        ValidationIssue(IssueCode.bicBadLength, 'BIC must be 8 or 11 characters.')
      ]);
    }
    if (!_shape.hasMatch(upper)) {
      return const Invalid([
        ValidationIssue(IssueCode.bicBadChars, 'BIC has invalid characters.')
      ]);
    }
    if (Country.fromIso2(upper.substring(4, 6)) == null) {
      return const Invalid([
        ValidationIssue(IssueCode.bicUnknownCountry, 'BIC has an unknown country code.')
      ]);
    }
    return Valid(upper);
  }
  // isValid / normalize / format / tryFormat follow the Vin pattern exactly:
  // format == normalize, tryFormat catches FormatException.

  /// Parses [input] into a [BicInfo], or null when [input] is not a valid BIC.
  static BicInfo? parse(String input) {
    final r = validate(input);
    if (r is! Valid) return null;
    final b = r.normalized;
    return BicInfo(
      institution: b.substring(0, 4),
      country: b.substring(4, 6),
      location: b.substring(6, 8),
      branch: b.length == 11 ? b.substring(8, 11) : null,
      kind: switch (b[7]) {
        '0' => BicKind.test,
        '1' => BicKind.passive,
        '2' => BicKind.reverseBilling,
        _ => BicKind.live,
      },
    );
  }

  /// True when [bic] and [iban] agree on their country segment. Only the
  /// countries are compared — a BIC carries no account information — but a
  /// mismatch reliably means one of the two fields was pasted wrong.
  static bool matchesIban(String bic, String iban) {
    final b = parse(bic);
    if (b == null) return false;
    final i = iban.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (i.length < 2) return false;
    return b.country == i.substring(0, 2);
  }

  /// Describes a BIC input field.
  static FieldDescriptor fieldDescriptor() => const FieldDescriptor(
        keyboard: KeyboardType.text,
        capitalization: Capitalization.characters,
        maxLength: 11,
        example: 'BKAUATWW',
        allowedChars: '0-9A-Z',
      );

  /// Formats partially typed [input]: upper-cased, non-alphanumerics dropped,
  /// capped at 11. No grouping — a BIC is written as one run. Never throws.
  static String formatPartial(String input) =>
      prepare(input, fieldDescriptor(), maxSignificant: 11);
}
```

- [ ] **Step 4: Export it and run the Dart vectors**

Add `export 'src/bic/bic.dart';` and `export 'src/bic/bic_info.dart';` to
`lib/kreiseck_validator.dart` in alphabetical position (after
`credit_card`… no: the list is alphabetical by path, so `src/bic/…` goes
before `src/common/country.dart`? It does not — re-read the file and insert so
the existing ordering convention is preserved).

Run: `dart analyze && dart test test/vectors_test.dart`
Expected: PASS.

- [ ] **Step 5: Mirror in TypeScript**

`js/src/bic/types.ts` holds `BicKind` as a string union
(`'live' | 'test' | 'passive' | 'reverseBilling'`) and `BicInfo`.
`js/src/bic/index.ts` mirrors the Dart logic and exports
`export const Bic = { isValid, validate, normalize, format, tryFormat, parse, matchesIban, fieldDescriptor, formatPartial }`.

Then:
- `js/src/index.ts`: `export { Bic } from './bic/index'; export type { BicInfo, BicKind } from './bic/types';`
- `js/tsup.config.ts`: add `'src/bic/index.ts'` to `entry`
- `js/package.json`: add the `"./bic"` entry to `exports`, mirroring `"./vin"`

- [ ] **Step 6: Run the TS suite**

Run: `cd js && npm run build && npm test`
Expected: PASS, including `bic.conformance.spec.ts`.

- [ ] **Step 7: Commit**

```bash
git add lib/src/bic js/src/bic test/vectors/bic.json js/test/bic.conformance.spec.ts \
        lib/kreiseck_validator.dart js/src/index.ts js/tsup.config.ts js/package.json test/vectors_test.dart
git commit -m "Add the Bic type (ISO 9362) with location-code classification"
```

---

## Task 3: `Gtin`

**Files:**
- Create: `lib/src/gtin/gtin.dart`, `lib/src/gtin/gtin_info.dart`
- Create: `js/src/gtin/index.ts`, `js/src/gtin/types.ts`
- Create: `test/vectors/gtin.json`, `js/test/gtin.conformance.spec.ts`
- Modify: the same five wiring files as Task 2

**Interfaces:**
- Produces: `Gtin.*` (standard contract) plus
  `Gtin.checkDigit(String body) -> String`, and
  `GtinInfo { length, checkDigit, gtin14 }`.

- [ ] **Step 1: Write the vector file**

`4006381333931` is the GS1 example already used as the placeholder in the
consuming app; `04012345123456` is a published GS1 ITF-14 example.

```json
[
  {"input": "4006381333931", "isValid": true, "normalized": "4006381333931", "format": "4006381333931",
   "parse": {"length": 13, "checkDigit": "1", "gtin14": "04006381333931"}},
  {"input": "4006-381 333931", "isValid": true, "normalized": "4006381333931"},
  {"input": "04012345123456", "isValid": true, "normalized": "04012345123456",
   "parse": {"length": 14, "checkDigit": "6", "gtin14": "04012345123456"}},
  {"input": "96385074", "isValid": true, "normalized": "96385074",
   "parse": {"length": 8, "checkDigit": "4", "gtin14": "00000096385074"}},
  {"input": "", "isValid": false, "code": "gtinEmpty"},
  {"input": "40063813339A1", "isValid": false, "code": "gtinBadChars"},
  {"input": "400638133393", "isValid": false, "code": "gtinBadLength"},
  {"input": "4006381333932", "isValid": false, "code": "gtinBadChecksum"}
]
```

Note `400638133393` is 12 digits, a permitted GTIN-12 length — so it must fail
on the **checksum**, not the length. Verify before committing the vector: if
its mod-10 digit happens to be correct, replace it with an 11-digit value such
as `40063813339`, which is genuinely a bad length.

- [ ] **Step 2: Wire both suites, watch them fail**

Same shape as Task 2, Step 2.

- [ ] **Step 3: Implement in Dart**

Validation order matters: empty → non-digits → length → checksum, so the
vector codes above are reachable.

```dart
/// GS1 GTIN-8/12/13/14 (EAN, UPC-A, ITF-14) with the GS1 mod-10 check digit.
///
/// The GS1 prefix is deliberately not exposed: it identifies the member
/// organisation that issued the number, not the origin of the goods, and every
/// API that surfaces it gets read as country-of-origin.
class Gtin {
  Gtin._();

  static const List<int> _lengths = [8, 12, 13, 14];
  static final RegExp _digits = RegExp(r'^[0-9]+$');
  static final RegExp _nonDigits = RegExp(r'[^0-9]');

  /// The GS1 mod-10 check digit for [body], a GTIN without its final digit.
  /// Weights alternate 3 and 1 from the right.
  static String checkDigit(String body) {
    var sum = 0;
    var weight = 3;
    for (var i = body.length - 1; i >= 0; i--) {
      sum += (body.codeUnitAt(i) - 0x30) * weight;
      weight = weight == 3 ? 1 : 3;
    }
    return ((10 - sum % 10) % 10).toString();
  }
  // validate: empty -> gtinEmpty; !_digits -> gtinBadChars;
  //   !_lengths.contains(len) -> gtinBadLength;
  //   checkDigit(all but last) != last -> gtinBadChecksum; else Valid(compact)
  // parse -> GtinInfo(length: n.length, checkDigit: n[last],
  //   gtin14: n.padLeft(14, '0'))
  // fieldDescriptor: keyboard digits, capitalization none, maxLength 14,
  //   example '4006381333931', allowedChars '0-9'
  // formatPartial: prepare(input, fieldDescriptor(), maxSignificant: 14)
}
```

- [ ] **Step 4: Run the Dart vectors — expect PASS**

Run: `dart analyze && dart test test/vectors_test.dart`

- [ ] **Step 5: Mirror in TypeScript, wire the four export points**

- [ ] **Step 6: Run the TS suite — expect PASS**

Run: `cd js && npm run build && npm test`

- [ ] **Step 7: Commit**

```bash
git commit -m "Add the Gtin type (GS1 mod-10, 8/12/13/14)"
```

---

## Task 4: `TaxNumber` (AT)

**Files:**
- Create: `lib/src/tax_number/tax_number.dart`, `tax_number_info.dart`,
  `tax_office.g.dart`
- Create: `tool/data/at-tax-offices.json`, `tool/gen_tax_office_metadata.py`
- Create: `js/src/tax-number/index.ts`, `types.ts`,
  `js/src/data/tax-office-metadata.json`
- Create: `test/vectors/tax_number.json`, `js/test/tax-number.conformance.spec.ts`
- Modify: the five wiring files

**Interfaces:**
- Consumes: `luhnOk` from `lib/src/common/luhn.dart` / `js/src/common/luhn.ts`.
- Produces: `TaxNumber.*({required String country})`,
  `TaxNumberInfo { office, officeName, number, checkDigit }`.

- [ ] **Step 1: Collect the Finanzamt table**

Source: the office-number table in the German Wikipedia article
*Abgabenkontonummer*, which cites BMF. Write it to
`tool/data/at-tax-offices.json` as `{"03": "Finanzamt …", …}`. Record the
retrieval date and the source URL in a `_source` key, and have the generator
strip keys beginning with `_`.

This list is **informational only**. The generator must emit a comment saying
so, because the obvious next step for a future reader is to start rejecting
unknown offices — which the design forbids (numbers were frozen in 2021 and
keep historical prefixes).

- [ ] **Step 2: Write the generator**

`tool/gen_tax_office_metadata.py`, modelled on `tool/gen_postal_metadata.py`:
reads the JSON, writes `lib/src/tax_number/tax_office.g.dart` (a
`part of 'tax_number.dart';` file with `const Map<String, String> kAtTaxOffices`)
and `js/src/data/tax-office-metadata.json`.

Run: `python3 tool/gen_tax_office_metadata.py`

- [ ] **Step 3: Write the vector file**

The documented worked example is `98-123/4560`. Derive the invalid case by
changing only the check digit.

```json
[
  {"input": "98-123/4560", "country": "AT", "isValid": true, "normalized": "981234560", "format": "98-123/4560",
   "parse": {"office": "98", "number": "1234560", "checkDigit": "0"}},
  {"input": "981234560", "country": "AT", "isValid": true, "normalized": "981234560", "format": "98-123/4560"},
  {"input": "98 123 4560", "country": "AT", "isValid": true, "normalized": "981234560"},
  {"input": "981234561", "country": "AT", "isValid": false, "code": "taxNumberBadChecksum"},
  {"input": "", "country": "AT", "isValid": false, "code": "taxNumberEmpty"},
  {"input": "98123456X", "country": "AT", "isValid": false, "code": "taxNumberBadChars"},
  {"input": "98123456", "country": "AT", "isValid": false, "code": "taxNumberBadLength"},
  {"input": "981234560", "country": "DE", "isValid": false, "code": "taxNumberUnknownCountry"}
]
```

- [ ] **Step 4: Wire both suites (country-parameterised), watch them fail**

`test/vectors_test.dart` — the country comes from the vector, like
`postal_code`:

```dart
  for (final c in _load('tax_number.json')) {
    final country = c['country'] as String;
    _check('tax_number', c,
        () => TaxNumber.validate(c['input'] as String, country: country),
        () => TaxNumber.format(c['input'] as String, country: country));
  }
```

- [ ] **Step 5: Implement in Dart**

```dart
/// Validation, normalization, formatting and parsing of tax numbers.
///
/// Austria only. The Abgabenkontonummer is nine digits — a two-digit
/// Finanzamt number, six free digits and a check digit — conventionally
/// written `12-345/6789`.
///
/// The check is the Luhn algorithm over all nine digits. The official
/// description states it as `S = F + Q(A) + N1 + Q(N2) + N3 + Q(N4) + N5 +
/// Q(N6)` with `Q(z)` the digit sum of `2z` and `P = (80 - S) mod 10`, which
/// is Luhn written out; the worked example 98-123/4560 confirms it.
///
/// The Finanzamt number is reported by [parse] but never rejected. Austria
/// reorganised its tax administration on 2021-01-01 and froze existing
/// account numbers, so historical office prefixes stay valid forever and any
/// bundled list is a snapshot. Rejecting on it would refuse valid numbers
/// from real documents.
class TaxNumber {
  TaxNumber._();

  static final RegExp _separators = RegExp(r'[\s./-]');
  static final RegExp _digits = RegExp(r'^[0-9]+$');

  static ValidationResult validate(String input, {required String country}) {
    if (country.toUpperCase() != 'AT') {
      return const Invalid([
        ValidationIssue(IssueCode.taxNumberUnknownCountry,
            'No tax-number rules for this country.')
      ]);
    }
    final compact = input.replaceAll(_separators, '');
    if (compact.isEmpty) {
      return const Invalid([
        ValidationIssue(IssueCode.taxNumberEmpty, 'Tax number is empty.')
      ]);
    }
    if (!_digits.hasMatch(compact)) {
      return const Invalid([
        ValidationIssue(IssueCode.taxNumberBadChars, 'Tax number must be digits only.')
      ]);
    }
    if (compact.length != 9) {
      return const Invalid([
        ValidationIssue(IssueCode.taxNumberBadLength, 'Tax number must be 9 digits.')
      ]);
    }
    if (!luhnOk(compact)) {
      return const Invalid([
        ValidationIssue(IssueCode.taxNumberBadChecksum, 'Tax number check digit is wrong.')
      ]);
    }
    return Valid(compact);
  }
  // format: groupWidths(normalized, [2, 3], …) does not fit — the shape is
  // `98-123/4560`, i.e. two different separators. Build it explicitly:
  //   '${n.substring(0,2)}-${n.substring(2,5)}/${n.substring(5)}'
  // parse -> TaxNumberInfo(office: n.substring(0,2),
  //   officeName: kAtTaxOffices[n.substring(0,2)],  // nullable by design
  //   number: n.substring(2), checkDigit: n[8])
  // fieldDescriptor: keyboard digits, maxLength 11 (the FORMATTED length,
  //   separators included), example '98-123/4560', allowedChars '0-9-/'
  // formatPartial: prepare(..., separators: r'\-/', maxSignificant: 9) then
  //   insert '-' after 2 and '/' after 5 as soon as enough digits exist.
}
```

`maxLength` is 11, not 9: the descriptor documents the length of the
**formatted** text. The field-invariants suite checks that `example` fits it,
so getting this wrong fails Task 12.

- [ ] **Step 6: Run the Dart vectors — expect PASS**

- [ ] **Step 7: Mirror in TypeScript, wire the four export points**

- [ ] **Step 8: Run the TS suite — expect PASS**

- [ ] **Step 9: Commit**

```bash
git commit -m "Add the TaxNumber type (AT Abgabenkontonummer)"
```

---

## Task 5: `SocialSecurityNumber` (AT)

**Files:**
- Create: `lib/src/social_security/social_security.dart`, `social_security_info.dart`
- Create: `js/src/social-security/index.ts`, `types.ts`
- Create: `test/vectors/social_security.json`,
  `js/test/social-security.conformance.spec.ts`
- Modify: the five wiring files

**Interfaces:**
- Produces: `SocialSecurityNumber.*({required String country})`,
  `SocialSecurityInfo { serial, checkDigit, birthDate }`,
  `SsnBirthDate { day, month, twoDigitYear }`.

- [ ] **Step 1: Write the vector file**

`1234010190` is the value already used in the consuming app's test fixtures.
Confirm its checksum with the weights before relying on it: weights
`3,7,9,0,5,8,4,2,1,6` over the ten positions, sum mod 11 must equal digit 4.
If it does not, adjust the serial until it does and note in the vector that it
is a constructed-but-checksum-correct number.

```json
[
  {"input": "1234 010190", "country": "AT", "isValid": true, "normalized": "1234010190", "format": "1234 010190",
   "parse": {"serial": "123", "checkDigit": "4", "birthDate": {"day": 1, "month": 1, "twoDigitYear": 90}}},
  {"input": "1234010190", "country": "AT", "isValid": true, "format": "1234 010190"},
  {"input": "", "country": "AT", "isValid": false, "code": "ssnEmpty"},
  {"input": "12340101X0", "country": "AT", "isValid": false, "code": "ssnBadChars"},
  {"input": "123401019", "country": "AT", "isValid": false, "code": "ssnBadLength"},
  {"input": "1235010190", "country": "AT", "isValid": false, "code": "ssnBadChecksum"},
  {"input": "1234010190", "country": "CH", "isValid": false, "code": "ssnUnknownCountry"}
]
```

Add one vector for a placeholder birth date once a checksum-correct example is
constructed: it must be `isValid: true` with `parse.birthDate: null`. That pair
— checksum decides validity, `parse` reports the date only when it is real — is
the behaviour most likely to be broken by a later change, so it needs a vector.

- [ ] **Step 2: Wire both suites, watch them fail**

The `parse.birthDate` field is a nested object, so `vectors_test.dart` needs a
small comparison helper rather than the flat `expect` used elsewhere. Write it
in the `_check` call site for this type, not in `_check`.

- [ ] **Step 3: Implement in Dart**

```dart
/// Validation, normalization, formatting and parsing of social-security
/// numbers. Austria only in this release; [country] is required so other
/// countries can be added without a breaking rename.
///
/// The Austrian number is ten digits, `NNNP TTMMJJ`: a three-digit serial, a
/// check digit, then the date of birth. The nine non-check digits are
/// weighted 3, 7, 9, 5, 8, 4, 2, 1, 6 from the left and the sum taken mod 11.
/// A remainder of 10 is never issued — the serial is skipped instead — so such
/// a number is rejected rather than accepted as an edge case.
///
/// Placeholder day/month components are in circulation for people whose birth
/// date is unknown, and those numbers are validly issued: the checksum decides
/// validity and [SocialSecurityInfo.birthDate] is null for a placeholder.
///
/// The century is not inferred. A two-digit year is genuinely ambiguous and
/// resolving it needs an age heuristic that belongs to the application, so
/// [SsnBirthDate] carries the raw components.
class SocialSecurityNumber {
  SocialSecurityNumber._();

  /// Position 4 (index 3) is the check digit itself and carries weight 0.
  static const List<int> _weights = [3, 7, 9, 0, 5, 8, 4, 2, 1, 6];
  // validate: country != AT -> ssnUnknownCountry; strip non-digits;
  //   empty -> ssnEmpty; contains a non-digit after stripping separators but
  //   before stripping letters -> ssnBadChars; length != 10 -> ssnBadLength;
  //   sum % 11 == 10 || sum % 11 != digit[3] -> ssnBadChecksum
  // format: '${n.substring(0,4)} ${n.substring(4)}'
  // fieldDescriptor: keyboard digits, maxLength 11 (formatted), example the
  //   vector's valid number, allowedChars '0-9 '
}
```

Care with `ssnBadChars` vs. `ssnBadLength`: strip only `[\s/-]` as separators,
then reject anything non-numeric as `ssnBadChars`. Stripping all non-digits
would turn `12340101X0` into a 9-digit value and report the wrong code.

- [ ] **Step 4: Run the Dart vectors — expect PASS**

- [ ] **Step 5: Mirror in TypeScript, wire the four export points**

- [ ] **Step 6: Run the TS suite — expect PASS**

- [ ] **Step 7: Commit**

```bash
git commit -m "Add the SocialSecurityNumber type (AT)"
```

---

## Task 6: `CompanyRegister` (AT)

**Files:**
- Create: `lib/src/company_register/company_register.dart`, `company_register_info.dart`
- Create: `js/src/company-register/index.ts`, `types.ts`
- Create: `test/vectors/company_register.json`,
  `js/test/company-register.conformance.spec.ts`
- Modify: the five wiring files, plus `doc/algorithms.md`

**Interfaces:**
- Produces: `CompanyRegister.*({required String country})`,
  `CompanyRegisterInfo { number, checkChar }`.

- [ ] **Step 1: Close the short-number gap before writing any code**

The design verified the algorithm against `415772 f`, `187010 s`, `536480 t`,
`512160 b` (six digits) and `92754 f` (five). **Find at least two more real
four- or five-digit Firmenbuchnummern from published imprints and check them by
hand** against left-aligned weights `6, 4, 14, 15, 10, 1`, sum mod 17, table
`A B D F G H I K M P S T V W X Y Z`.

- If they match: continue, and add them to the vector file.
- If they do not: implement the checksum for six-digit numbers only, return
  `Valid` on structure alone for shorter ones, and say so in the class doc
  comment and the README. A length-dependent false rejection on a company
  register field is worse than a missing check.

Record the outcome either way in `doc/algorithms.md`, together with the fact
that the widely repeated `number mod 26` rule is wrong — it matches only
`187010 s`, by coincidence — so nobody "fixes" the implementation back to it.

- [ ] **Step 2: Write the vector file**

```json
[
  {"input": "FN 415772 f", "country": "AT", "isValid": true, "normalized": "415772f", "format": "FN 415772f",
   "parse": {"number": "415772", "checkChar": "f"}},
  {"input": "415772f", "country": "AT", "isValid": true, "normalized": "415772f"},
  {"input": "415772F", "country": "AT", "isValid": true, "normalized": "415772f"},
  {"input": "187010s", "country": "AT", "isValid": true, "normalized": "187010s"},
  {"input": "536480t", "country": "AT", "isValid": true, "normalized": "536480t"},
  {"input": "512160b", "country": "AT", "isValid": true, "normalized": "512160b"},
  {"input": "92754f", "country": "AT", "isValid": true, "normalized": "92754f"},
  {"input": "415772g", "country": "AT", "isValid": false, "code": "companyRegisterBadChecksum"},
  {"input": "415772c", "country": "AT", "isValid": false, "code": "companyRegisterBadFormat"},
  {"input": "", "country": "AT", "isValid": false, "code": "companyRegisterEmpty"},
  {"input": "415772", "country": "AT", "isValid": false, "code": "companyRegisterBadFormat"},
  {"input": "1234567a", "country": "AT", "isValid": false, "code": "companyRegisterBadFormat"},
  {"input": "415772f", "country": "DE", "isValid": false, "code": "companyRegisterUnknownCountry"}
]
```

`415772c` must be `companyRegisterBadFormat`, not `BadChecksum`: `c` is not in
the 17-letter table at all, so it can never be a check letter — that is a
format error, and the distinction is worth a vector.

- [ ] **Step 3: Wire both suites, watch them fail**

- [ ] **Step 4: Implement in Dart**

```dart
/// Validation, normalization, formatting and parsing of company-register
/// numbers. Austria only; [country] is required so other countries can be
/// added later.
///
/// The Austrian Firmenbuchnummer is up to six digits plus one check letter,
/// written `FN 123456a`. The check letter is the digits weighted 6, 4, 14, 15,
/// 10, 1 **from the left** (a shorter number uses the leading weights and is
/// not zero-padded), summed, mod 17, indexed into a 17-letter table that omits
/// the confusable C, E, J, L, N, O, Q, R and U.
///
/// The widely repeated "number mod 26" rule is wrong: it reproduces only one
/// of five verified real numbers. See `doc/algorithms.md`.
///
/// This is the one type whose [normalize] does not upper-case: the canonical
/// written form keeps the check letter lower-case. The `FN` prefix is
/// presentation — accepted on input, not stored.
class CompanyRegister {
  CompanyRegister._();

  static const String _table = 'ABDFGHIKMPSTVWXYZ';
  static const List<int> _weights = [6, 4, 14, 15, 10, 1];
  static final RegExp _shape = RegExp(r'^([0-9]{1,6})([A-Z])$');

  /// The expected check letter, lower-case, for the digit string [digits].
  static String checkChar(String digits) {
    var sum = 0;
    for (var i = 0; i < digits.length; i++) {
      sum += (digits.codeUnitAt(i) - 0x30) * _weights[i];
    }
    return _table[sum % 17].toLowerCase();
  }
  // validate: country != AT -> companyRegisterUnknownCountry;
  //   strip leading 'FN' and all whitespace, upper-case for shape matching;
  //   empty -> companyRegisterEmpty;
  //   !_shape -> companyRegisterBadFormat (covers 7+ digits, missing letter);
  //   !_table.contains(letter) -> companyRegisterBadFormat;
  //   checkChar(digits) != letter.toLowerCase() -> companyRegisterBadChecksum;
  //   Valid('$digits${letter.toLowerCase()}')
  // format: 'FN ${normalized}'
  // fieldDescriptor: keyboard text, capitalization none (!), maxLength 7,
  //   example '415772f', allowedChars '0-9A-Za-z'
  // formatPartial: prepare cannot lower-case, so do it here: strip anything
  //   outside 0-9A-Za-z, cap at 7, lower-case a trailing letter.
}
```

`capitalization` is `none` for this type, unlike every other alphanumeric
identifier here — that is deliberate and the doc comment must say why, or a
future reader will "fix" it to `characters` and break `normalize`.

- [ ] **Step 5: Run the Dart vectors — expect PASS**

- [ ] **Step 6: Mirror in TypeScript, wire the four export points**

- [ ] **Step 7: Run the TS suite — expect PASS**

- [ ] **Step 8: Commit**

```bash
git add lib/src/company_register js/src/company-register test/vectors/company_register.json \
        js/test/company-register.conformance.spec.ts doc/algorithms.md \
        lib/kreiseck_validator.dart js/src/index.ts js/tsup.config.ts js/package.json test/vectors_test.dart
git commit -m "Add the CompanyRegister type (AT Firmenbuchnummer)"
```

---

## Task 7: `VatId` — metadata, structure and the Austrian check

Splits the largest type: this task builds the data table, the country
resolution and the dispatch seam, with exactly one country's check digit wired
up. Tasks 8 and 9 fill in the other 28.

**Files:**
- Create: `tool/data/vat-formats.json`, `tool/gen_vat_metadata.py`
- Create: `lib/src/vat_id/vat_id.dart`, `vat_info.dart`, `vat_checks.dart`,
  `vat_metadata.g.dart` (generated)
- Create: `js/src/vat-id/index.ts`, `types.ts`, `checks.ts`, `metadata.ts`,
  `js/src/data/vat-metadata.json` (generated)
- Create: `test/vectors/vat_id.json`, `js/test/vat-id.conformance.spec.ts`
- Modify: the five wiring files, `js/test/data.spec.ts`

**Interfaces:**
- Produces: `VatId.*({String? country})`,
  `VatInfo { country, prefix, number, subtype }`,
  `VatSubtype` enum with members `standard, legal, person, individual, special,
  dni, nie, cif, temporary, branch, government, healthAuthority, bsn, btwId`,
  and the internal dispatch `bool checkVat(String iso2, String body)` in
  `vat_checks.dart` / `checks.ts`.

- [ ] **Step 1: Curate the structure table**

`tool/data/vat-formats.json`, one entry per VAT prefix. Structure and lengths
come from the per-country table in `docs/business-identifiers-design.md`:

```json
{
  "_source": "docs/business-identifiers-design.md, table 'VatId'",
  "AT": {"prefix": "ATU", "body": "^U[0-9]{8}$", "maxLen": 9, "charset": "alnum", "example": "ATU13585627"},
  "BE": {"prefix": "BE", "body": "^0[0-9]{9}$", "maxLen": 10, "charset": "digits", "example": null},
  "…": {}
}
```

`maxLen` is the length of the **body including any leading letter**, not
counting the country prefix. `example` is null wherever no published number is
available yet — Tasks 8 and 9 fill them in as they verify each country, and the
field-invariants suite only checks non-null examples.

Greece appears once, keyed `GR`, with `"prefix": "EL"`. Northern Ireland
appears keyed `XI` with `"prefix": "XI"` and a note field
`"isoCountry": "GB"`; every other entry's ISO country equals its key.

- [ ] **Step 2: Write the generator and run it**

`tool/gen_vat_metadata.py` → `lib/src/vat_id/vat_metadata.g.dart` (a
`part of 'vat_id.dart';` file with `const Map<String, VatFormat> kVatFormats`)
and `js/src/data/vat-metadata.json`.

Run: `python3 tool/gen_vat_metadata.py`
Then extend `js/test/data.spec.ts` with an assertion that the JSON has 29 keys
and that `vat.AT.prefix === 'ATU'`.

- [ ] **Step 3: Write the first vectors — structure plus AT**

`ATU13585627` is the documented Austrian example; the invalid twin differs only
in the check digit.

```json
[
  {"input": "ATU13585627", "isValid": true, "normalized": "ATU13585627", "format": "ATU13585627",
   "parse": {"country": "AT", "prefix": "ATU", "number": "U13585627", "subtype": "standard"}},
  {"input": "atu 135 856 27", "isValid": true, "normalized": "ATU13585627"},
  {"input": "U13585627", "country": "AT", "isValid": true, "normalized": "ATU13585627"},
  {"input": "ATU13585626", "isValid": false, "code": "vatBadChecksum"},
  {"input": "ATU1358562", "isValid": false, "code": "vatBadFormat"},
  {"input": "", "isValid": false, "code": "vatEmpty"},
  {"input": "13585627", "isValid": false, "code": "vatAmbiguousCountry"},
  {"input": "ZZ13585627", "isValid": false, "code": "vatUnknownCountry"},
  {"input": "13585627", "country": "ZZ", "isValid": false, "code": "vatUnknownCountry"}
]
```

- [ ] **Step 4: Wire both suites, watch them fail**

The vector's `country` key is optional here, unlike `postal_code`:

```dart
  for (final c in _load('vat_id.json')) {
    final country = c['country'] as String?;
    _check('vat_id', c,
        () => VatId.validate(c['input'] as String, country: country),
        () => VatId.format(c['input'] as String, country: country));
  }
```

- [ ] **Step 5: Implement resolution, structure and the dispatch seam**

`lib/src/vat_id/vat_checks.dart` starts as:

```dart
/// Per-country VAT check-digit verification.
///
/// Each function receives the body **without** the country prefix, already
/// upper-cased and separator-free, and already matched against the country's
/// structure pattern — so it may assume the length and charset are right and
/// only has to do arithmetic. Returns true when the check digit is correct.
///
/// Algorithms and their sources are listed in `doc/algorithms.md`. None of
/// this code is derived from another implementation's source.
library;

bool checkVat(String iso2, String body) {
  final check = _checks[iso2];
  if (check == null) return true; // no algorithm wired up yet
  return check(body);
}

const Map<String, bool Function(String)> _checks = {
  'AT': _checkAt,
};

/// AT: Luhn over the seven digits after the leading `U`; the check digit is
/// `(6 - luhn) mod 10`.
bool _checkAt(String body) {
  final digits = body.substring(1); // drop the 'U'
  var sum = 0;
  var alt = true; // the rightmost of the seven is doubled
  for (var i = 5; i >= 0; i--) {
    var d = digits.codeUnitAt(i) - 0x30;
    if (alt) { d *= 2; if (d > 9) d -= 9; }
    sum += d;
    alt = !alt;
  }
  return (6 - sum % 10) % 10 == digits.codeUnitAt(6) - 0x30;
}
```

The `return true` default is a deliberate, temporary seam: it means an
unwired country validates on structure alone. **Task 9's final step removes
it** and makes a missing entry an assertion failure, so the seam cannot
survive the release.

`lib/src/vat_id/vat_id.dart`:
- `_compact(input)` → upper-case, strip `[\s.\-/]`.
- Country resolution: try the longest matching prefix in `kVatFormats` first
  (so `ATU…` matches `ATU`, not `AT`); if none matches and `country` is null →
  `vatAmbiguousCountry`; if `country` is given, accept both `GR` and `EL`.
- Structure: match the body against the country's `body` pattern →
  `vatBadFormat`.
- Checksum: `checkVat(iso2, body)` → `vatBadChecksum`.
- `normalize` → `prefix + body`. `format` → `normalize` for now; per-country
  display grouping is out of scope for this release, and the design says
  "otherwise the normalized form".
- `parse` → `VatInfo`; `subtype` comes from a per-country classifier that
  returns `VatSubtype.standard` for every country until Tasks 8 and 9 add the
  branching ones.
- `fieldDescriptor({country})`: without a country, generic
  (`keyboard: text`, `capitalization: characters`, `allowedChars: '0-9A-Z'`,
  `maxLength: null`). With one, `maxLength` = prefix length + `maxLen`,
  `keyboard` = digits when `charset == 'digits'` **and** the prefix ends in a
  letter that the user does not type — decide one way and encode it in the
  descriptor vectors in Task 12. Simplest consistent rule: the descriptor
  describes the field holding the **whole** VAT ID including prefix, so
  `keyboard` is always `text` and `allowedChars` is `0-9A-Z`; only `maxLength`
  and `example` vary by country. Use that rule.

- [ ] **Step 6: Run the Dart vectors — expect PASS**

- [ ] **Step 7: Mirror in TypeScript, wire the four export points**

`js/src/vat-id/metadata.ts` loads the generated JSON exactly the way
`js/src/postal-code/metadata.ts` does.

- [ ] **Step 8: Run the TS suite — expect PASS**

- [ ] **Step 9: Commit**

```bash
git commit -m "Add the VatId type with structure metadata and the AT check digit"
```

---

## Task 8: `VatId` check digits — the direct group

Fourteen countries whose check is a single weighted sum or a named standard.
Each gets its own function in `vat_checks.dart` / `checks.ts`, its own doc
comment naming the rule, and at least one valid and one broken vector.

**Files:** Modify `lib/src/vat_id/vat_checks.dart`, `js/src/vat-id/checks.ts`,
`test/vectors/vat_id.json`, `tool/data/vat-formats.json` (fill in `example`),
`doc/algorithms.md`

- [ ] **Step 1: Add the vectors first, all fourteen countries**

Known-valid published values to use:

| Country | Valid body | Source |
|---|---|---|
| DK | `13585628` | documented example |
| EE | `100594102` | documented example |
| FI | `20774740` | documented example |
| HR | `33392005961` | documented example |
| LU | `15027442` | documented example |
| MT | `11679112` | documented example |
| NL | `002455799B11` | documented example, post-2020 form |

For **DE, PL, PT, SI, SK, HU, CH** no value was captured during research.
Obtain one published number per country before writing its check — a company
imprint is the reliable source — and only then add the vector. Do **not**
generate a number with the new code and call it a vector.

Each country also gets a broken twin: take the valid number and change the
last digit to any other value, then confirm by hand that the algorithm rejects
it.

- [ ] **Step 2: Run the suites and confirm the new vectors fail**

Run: `dart test test/vectors_test.dart`
Expected: FAIL — the unwired countries currently pass structure-only, so the
**broken** twins are the ones that fail (they are accepted when they should be
rejected). That is the signal the seam is still open.

- [ ] **Step 3: Implement the fourteen checks in Dart**

Add to `_checks` and write one function each:

- `DE` — 9 digits, ISO 7064 MOD 11,10: `mod11_10Ok(body)`.
- `HR` — 11 digits (OIB), ISO 7064 MOD 11,10: `mod11_10Ok(body)`.
- `NL` — `^[0-9]{9}B[0-9]{2}$`: valid when the first nine digits satisfy the
  Dutch 11-proef (weights 9,8,7,6,5,4,3,2 over the first eight against the
  ninth) **or** `mod97_10Ok('NL' + body)`. The `or` is not optional: sole
  traders received numbers in 2020 that satisfy only the second form.
- `DK` — weights 2,7,6,5,4,3,2,1, sum mod 11 == 0.
- `EE` — weights 3,7,1,3,7,1,3,7,1, sum mod 10 == 0.
- `FI` — weights 7,9,10,5,8,4,2,1, sum mod 11 == 0.
- `HU` — weights 9,7,3,1,9,7,3,1, sum mod 10 == 0.
- `MT` — weights 3,4,6,7,8,9,10,1, sum mod 37 == 0.
- `PL` — weights 6,5,7,2,3,4,5,6,7,-1, sum mod 11 == 0.
- `PT` — weights 9,8,7,6,5,4,3,2 over the first eight; check digit is
  `(11 - sum) mod 11 mod 10`.
- `SI` — weights 8,7,6,5,4,3,2 over the first seven; check digit is
  `(11 - sum mod 11)`, a result of 10 becoming 0. A result of 11 cannot occur
  for a valid number and must be rejected.
- `SK` — the whole 10-digit value mod 11 == 0. Do not parse it as an `int`:
  10 digits overflows a 32-bit int on the JS side. Fold digit by digit:
  `r = (r * 10 + d) % 11`.
- `LU` — `int(first 6) mod 89` equals the last two digits as a number.
- `CH` — body is `E` + 9 digits (the prefix is `CHE`); weights 5,4,3,2,7,6,5,4
  over the first eight digits, check digit `(11 - sum) mod 11`, and a computed
  value of 10 makes the number invalid.

Write a shared private helper for the recurring shape rather than repeating the
loop fourteen times:

```dart
/// Sum of each digit of [digits] times the weight at the same index.
int _weighted(String digits, List<int> weights) {
  var sum = 0;
  for (var i = 0; i < weights.length && i < digits.length; i++) {
    sum += (digits.codeUnitAt(i) - 0x30) * weights[i];
  }
  return sum;
}
```

- [ ] **Step 4: Run the Dart vectors — expect PASS**

- [ ] **Step 5: Mirror all fourteen in TypeScript**

Same functions, same helper, same doc comments. The SK note about integer width
matters here specifically.

- [ ] **Step 6: Run the TS suite — expect PASS**

- [ ] **Step 7: Record the algorithms and commit**

Add a `## VAT check digits` section to `doc/algorithms.md` listing each
country, its rule and where the rule came from.

```bash
git commit -m "Add VAT check digits for the fourteen single-formula countries"
```

---

## Task 9: `VatId` check digits — the branching group

Fifteen prefixes whose validation has more than one path: BE, BG, CY, CZ, EL,
ES, FR, IE, IT, LT, LV, RO, SE, GB, XI. These are also the ones that populate
`VatSubtype`.

**Files:** Modify `lib/src/vat_id/vat_checks.dart`, `lib/src/vat_id/vat_id.dart`
(subtype classifier), `js/src/vat-id/checks.ts`, `js/src/vat-id/index.ts`,
`test/vectors/vat_id.json`, `tool/data/vat-formats.json`, `doc/algorithms.md`

- [ ] **Step 1: Add the vectors first**

Known-valid published values: BG `175074752` (legal), EL `094259216` and
`023456783`, LT `119511515` (legal), `100001919017` and `100004801610`
(temporary), RO `18547290`, IT structure per the province rule, HR already
covered. For **BE, CY, CZ, ES, FR, IE, SE, GB** obtain published numbers before
writing the checks.

Every country with more than one path needs one vector **per path**, each with
its expected `parse.subtype` — otherwise a branch can be wrong without any
test noticing.

- [ ] **Step 2: Run the suites, confirm the broken twins fail**

- [ ] **Step 3: Implement in Dart**

- `BE` — 10 digits, `(int(first 8) + int(last 2)) mod 97 == 0`. A 9-digit
  legacy number is left-padded with `0` during compaction, before the
  structure pattern runs, so the pattern only ever sees 10 digits.
- `BG` — 9 digits (`legal`): `Σ(i+1)·dᵢ mod 11` over the first eight; if that
  is 10, recompute with `Σ(i+3)·dᵢ mod 11`; the check digit is the result
  mod 10. 10 digits (`person`): weights 4,3,2,7,6,5,4,3,2, check digit
  `(11 - Σ) mod 11`.
- `CY` — 8 digits + 1 letter: map the digits at even indices through
  `{0:1, 1:0, 2:5, 3:7, 4:9, 5:13, 6:15, 7:17, 8:19, 9:21}`, add the digits at
  odd indices unchanged, and index `A`–`Z` with the sum mod 26.
- `CZ` — three paths. 8 digits (`legal`):
  `(11 - Σ(8-i)·dᵢ) mod 11` over the first seven, a result of 0 becoming 1,
  then mod 10. 9 digits starting with `6` (`special`): the variant formula
  `(8 - (10 - Σ(8-i)·dᵢ mod 11) mod 11) mod 10`. 10 digits (`individual`):
  validates as a rodné číslo — **obtain that rule from its own specification
  before implementing it**; if it cannot be obtained, accept the 10-digit form
  on structure alone, report `subtype: individual`, and note the limitation in
  the README rather than inventing a check.
- `EL` — `c = 0`, then `c = 2c + dᵢ` over the first eight digits; the check
  digit is `2c mod 11 mod 10`.
- `ES` — three paths by first character. `dni` (leading digit), `nie` (leading
  `X`, `Y` or `Z`) and `cif` (any other leading letter), plus the `K`/`L`/`M`
  prefixes which use the DNI check. **Obtain the DNI/NIE/CIF rules from their
  own specification before implementing**; the same fallback rule as CZ
  applies per path.
- `FR` — 2 characters + 9-digit SIREN. All-numeric prefix:
  `int(SIREN + '12') mod 97` equals the prefix as a number. Prefix containing a
  letter: the alphabet-index formula over `0-9A-Z` minus `I` and `O`. The SIREN
  itself must satisfy Luhn unless it is `000000000`.
- `IE` — alphabet `WABCDEFGHIJKLMNOPQRSTUV`;
  `(Σ(8-i)·dᵢ + 9 · index(second letter)) mod 23` selects the check letter.
  The trailing `W` on the married-women form is part of the structure, not the
  checksum.
- `IT` — 11 digits, `luhnOk(body)`, **and** the province code `body[7..10]`
  must be `001`–`100` or one of `120`, `121`, `888`, `999`, **and** the first
  seven digits must not be all zero. All three are structure-level truths that
  belong in the check function because the pattern cannot express the range.
- `LT` — 9 digits (`standard`) or 12 (`temporary`).
  `Σ(1 + i mod 9)·dᵢ mod 11`; if 10, recompute with the weights shifted by two;
  the check digit is the result mod 11 mod 10.
- `LV` — 11 digits. First digit > `3` (`legal`): weights
  9,1,4,8,3,10,2,5,7,6,1, sum mod 11 must equal 3. Otherwise (`person`): the
  personal-code rule, weights 10,5,8,4,2,1,6,3,7,9 over the first ten, check
  digit `(1 + Σ) mod 11 mod 10`.
- `RO` — 2 to 10 digits. Left-pad to 9, weights 7,5,3,2,1,7,5,3,2, check digit
  `10·Σ mod 11 mod 10`.
- `SE` — 12 digits, the last two must be `01`, and the first 10 must satisfy
  Luhn.
- `GB` and `XI` — weights 8,7,6,5,4,3,2,10,1 over the first nine digits, sum
  mod 97 must be 0, 42 or 55. A 12-digit number is a branch trader
  (`subtype: branch`) and only its first nine digits are checked. The
  `GD`/`HA` forms (`government`, `healthAuthority`) are structurally different
  and are matched by their own patterns in the metadata table, not by this
  function.

- [ ] **Step 4: Implement the subtype classifier**

In `vat_id.dart`, a `VatSubtype _subtypeOf(String iso2, String body)` that
mirrors the branching above and returns `VatSubtype.standard` for every
country in Task 8's group. Keep it next to `parse`, not inside the check
functions — the checks answer "is the digit right", the classifier answers
"which kind of number is this", and mixing them makes both harder to read.

- [ ] **Step 5: Run the Dart vectors — expect PASS**

- [ ] **Step 6: Mirror in TypeScript**

- [ ] **Step 7: Close the dispatch seam**

Replace the `return true` default in `checkVat` with a hard failure, so a
future country added to the metadata table without a check cannot ship
silently:

```dart
bool checkVat(String iso2, String body) {
  final check = _checks[iso2];
  assert(check != null, 'No VAT check digit implemented for $iso2');
  if (check == null) return false;
  return check(body);
}
```

Add a test asserting every key of `kVatFormats` has a `_checks` entry:

```dart
test('every VAT country has a check-digit implementation', () {
  for (final iso2 in kVatFormats.keys) {
    expect(VatId.isValid(kVatFormats[iso2]!.example ?? ''), isTrue,
        reason: 'example missing or rejected for $iso2');
  }
});
```

This test also enforces that every country got a real published example into
the metadata table — the two gaps reinforce each other.

- [ ] **Step 8: Run the TS suite and commit**

```bash
git commit -m "Add VAT check digits for the branching countries and close the dispatch seam"
```

---

## Task 10: The VIES seam

**Files:**
- Modify: `lib/src/vat_id/vat_id.dart`, `lib/src/vat_id/vat_info.dart`,
  `js/src/vat-id/index.ts`, `js/src/vat-id/types.ts`
- Create: `test/vies_test.dart`, `js/test/vies.spec.ts`

**Interfaces:**
- Produces: `VatId.viesRequest(String value) -> ViesRequest?` with
  `ViesRequest { url, method, headers }`, and
  `VatId.parseViesResponse(String body) -> VatRegistration?` with
  `VatRegistration { valid, name, address, requestDate }`.

- [ ] **Step 1: Write the failing tests**

No network access in either suite — these are pure functions over a captured
response body. The body below was captured from the live endpoint during
design research.

```dart
void main() {
  test('builds a request for a structurally valid number', () {
    final r = VatId.viesRequest('ATU13585627')!;
    expect(r.url,
        'https://ec.europa.eu/taxation_customs/vies/rest-api/ms/AT/vat/U13585627');
    expect(r.method, 'GET');
  });

  test('returns null for an invalid number', () {
    expect(VatId.viesRequest('ATU13585626'), isNull);
  });

  test('returns null for a country outside VIES', () {
    expect(VatId.viesRequest('CHE116281820'), isNull);
  });

  test('parses a negative response', () {
    const body = '{"isValid":false,"requestDate":"2026-07-28T07:33:53.625Z",'
        '"userError":"INVALID","name":"","address":"","vatNumber":"U13585627"}';
    final reg = VatId.parseViesResponse(body)!;
    expect(reg.valid, isFalse);
    expect(reg.name, isNull);
    expect(reg.requestDate, '2026-07-28T07:33:53.625Z');
  });

  test('returns null when the member state was unavailable', () {
    const body = '{"isValid":false,"userError":"MS_UNAVAILABLE"}';
    expect(VatId.parseViesResponse(body), isNull);
  });
}
```

The last case is the important one: an unavailable member state is **not** a
rejection, so `parseViesResponse` returns null rather than
`VatRegistration(valid: false)`. A caller that treats null as "unknown, try
later" and `valid: false` as "not registered" then cannot get it wrong.
`userError` values other than `VALID` and `INVALID` are all treated as
unavailable.

- [ ] **Step 2: Run and confirm failure**

- [ ] **Step 3: Implement both functions in Dart**

`viesRequest` uses the ISO country for the path segment except that Greece
uses `EL` — the endpoint's `ms` parameter takes the VAT prefix, not the ISO
code — and returns null for `CH` and any other non-VIES prefix. `XI` is a
valid `ms` value.

Empty `name`/`address` strings become null. Use `dart:convert`'s `jsonDecode`;
the TS side uses `JSON.parse`. Neither adds a dependency.

- [ ] **Step 4: Run — expect PASS. Mirror in TS, run again.**

- [ ] **Step 5: Commit**

```bash
git commit -m "Add the offline VIES request builder and response parser"
```

---

## Task 11: The `dom` subpath

**Files:**
- Create: `js/src/dom/index.ts`, `js/test/dom.spec.ts`
- Modify: `js/src/index.ts`, `js/tsup.config.ts`, `js/package.json`

**Interfaces:**
- Produces: `fieldAttrs(d, opts?) -> FieldAttrs`,
  `filterValue(value, d) -> string`,
  `bindInput(el, options) -> () => void` with
  `options: { descriptor, formatPartial, validate, onState? }` and
  `onState({ state: 'empty' | 'incomplete' | 'valid' | 'invalid', normalized, issue })`.

- [ ] **Step 1: Write the failing tests**

`js/test/dom.spec.ts`. jsdom is already a devDependency, and
`js/vitest.config.ts` may need `environment: 'jsdom'` for this file — set it
per-file with `// @vitest-environment jsdom` rather than changing the global
config, so the other suites keep running in node.

```ts
// @vitest-environment jsdom
import { describe, it, expect, vi } from 'vitest';
import { fieldAttrs, filterValue, bindInput } from '../src/dom/index';
import { Iban } from '../src/iban/index';
import { Email } from '../src/email/index';

describe('fieldAttrs', () => {
  it('maps an IBAN descriptor', () => {
    const a = fieldAttrs(Iban.fieldDescriptor({ country: 'AT' }));
    expect(a.inputMode).toBe('text');
    expect(a.autoCapitalize).toBe('characters');
    expect(a.autoComplete).toBeUndefined();
    expect(a.maxLength).toBe(24);
    expect(a.placeholder).toBe('AT61 1904 3002 3457 3201');
  });

  it('maps an email descriptor to autoComplete', () => {
    const a = fieldAttrs(Email.fieldDescriptor());
    expect(a.inputMode).toBe('email');
    expect(a.autoComplete).toBe('email');
  });

  it('omits the placeholder on request', () => {
    expect(fieldAttrs(Email.fieldDescriptor(), { placeholder: false }).placeholder)
      .toBeUndefined();
  });
});

describe('filterValue', () => {
  it('drops rejected characters and truncates', () => {
    const d = Iban.fieldDescriptor({ country: 'AT' });
    expect(filterValue('at61 1904*3002', d)).toBe('AT61 19043002');
  });
});

describe('bindInput', () => {
  it('formats as the user types and keeps the caret', () => {
    const el = document.createElement('input');
    document.body.append(el);
    bindInput(el, {
      descriptor: Iban.fieldDescriptor({ country: 'AT' }),
      formatPartial: (v) => Iban.formatPartial(v, { country: 'AT' }),
      validate: (v) => Iban.validate(v, { country: 'AT' }),
    });
    el.value = 'AT611904300234573201';
    el.dispatchEvent(new Event('input'));
    expect(el.value).toBe('AT61 1904 3002 3457 3201');
  });

  it('restores the caret by significant offset when editing mid-value', () => {
    const el = document.createElement('input');
    document.body.append(el);
    bindInput(el, {
      descriptor: Iban.fieldDescriptor({ country: 'AT' }),
      formatPartial: (v) => Iban.formatPartial(v, { country: 'AT' }),
      validate: (v) => Iban.validate(v, { country: 'AT' }),
    });
    // Value formatted, caret placed after the 6th significant character;
    // typing there must leave the caret after the 7th, not at the end.
    el.value = 'AT61 1904 3002';
    el.setSelectionRange(7, 7); // after "AT61 19"
    el.dispatchEvent(new Event('input'));
    expect(el.selectionStart).toBe(7);
  });

  it('reports state on blur and unbinds', () => {
    const el = document.createElement('input');
    document.body.append(el);
    const onState = vi.fn();
    const unbind = bindInput(el, {
      descriptor: Iban.fieldDescriptor({ country: 'AT' }),
      formatPartial: (v) => Iban.formatPartial(v, { country: 'AT' }),
      validate: (v) => Iban.validate(v, { country: 'AT' }),
      onState,
    });
    el.value = 'AT61 1904 3002 3457 3201';
    el.dispatchEvent(new Event('blur'));
    expect(onState).toHaveBeenCalledWith(
      expect.objectContaining({ state: 'valid', normalized: 'AT611904300234573201' }),
    );
    onState.mockClear();
    unbind();
    el.dispatchEvent(new Event('blur'));
    expect(onState).not.toHaveBeenCalled();
  });

  it('reports empty and invalid distinctly', () => {
    const el = document.createElement('input');
    document.body.append(el);
    const onState = vi.fn();
    bindInput(el, {
      descriptor: Iban.fieldDescriptor({ country: 'AT' }),
      formatPartial: (v) => Iban.formatPartial(v, { country: 'AT' }),
      validate: (v) => Iban.validate(v, { country: 'AT' }),
      onState,
    });
    el.dispatchEvent(new Event('blur'));
    expect(onState).toHaveBeenCalledWith(expect.objectContaining({ state: 'empty' }));
    el.value = 'AT61 1904 3002 3457 3202';
    el.dispatchEvent(new Event('blur'));
    expect(onState).toHaveBeenCalledWith(expect.objectContaining({ state: 'invalid' }));
  });
});
```

Check the expected `maxLength` and `example` for the AT IBAN descriptor against
the actual implementation before running — use whatever
`Iban.fieldDescriptor({country: 'AT'})` really returns rather than the values
above if they differ.

- [ ] **Step 2: Run and confirm failure**

Run: `cd js && npx vitest run test/dom.spec.ts`

- [ ] **Step 3: Implement `fieldAttrs` and `filterValue`**

```ts
import type { FieldDescriptor, KeyboardType, Capitalization, AutofillHint } from '../common/field';
import type { ValidationResult } from '../common/types';

const INPUT_MODE: Record<KeyboardType, string> = {
  text: 'text', digits: 'numeric', phone: 'tel', email: 'email', url: 'url',
};

const AUTOCOMPLETE: Record<AutofillHint, string> = {
  email: 'email', telephoneNumber: 'tel', postalCode: 'postal-code',
  creditCardNumber: 'cc-number', url: 'url',
};

export interface FieldAttrs {
  inputMode: string;
  autoCapitalize: Capitalization;
  autoComplete?: string;
  maxLength?: number;
  placeholder?: string;
}

export interface FieldAttrsOptions { placeholder?: boolean }

// Maps a FieldDescriptor onto the HTML input attributes that express it.
// Keys are camelCase (React-shaped); bindInput translates to DOM attribute
// names internally.
export function fieldAttrs(d: FieldDescriptor, opts: FieldAttrsOptions = {}): FieldAttrs {
  const attrs: FieldAttrs = {
    inputMode: INPUT_MODE[d.keyboard],
    autoCapitalize: d.capitalization,
  };
  if (d.autofill !== null) attrs.autoComplete = AUTOCOMPLETE[d.autofill];
  if (d.maxLength !== null) attrs.maxLength = d.maxLength;
  if (opts.placeholder !== false && d.example !== null) attrs.placeholder = d.example;
  return attrs;
}

// Drops characters outside the descriptor's allowedChars and truncates to its
// maxLength. Exported for controlled inputs, which need this without any
// element being involved.
export function filterValue(value: string, d: FieldDescriptor): string {
  let s = value;
  if (d.capitalization === 'characters') s = s.toUpperCase();
  if (d.allowedChars !== null) s = s.replace(new RegExp(`[^${d.allowedChars}]`, 'g'), '');
  if (d.maxLength !== null && s.length > d.maxLength) s = s.substring(0, d.maxLength);
  return s;
}
```

- [ ] **Step 4: Run the first three tests — expect PASS**

- [ ] **Step 5: Implement `bindInput` with caret preservation**

The caret rule: count how many *significant* characters (those matching
`allowedChars` minus the separators the formatter inserts) sit before the
caret, reformat, then walk forward through the new value until the same number
of significant characters has been passed.

```ts
export interface BindOptions {
  descriptor: FieldDescriptor;
  formatPartial: (value: string) => string;
  validate: (value: string) => ValidationResult;
  onState?: (s: FieldState) => void;
}

export interface FieldState {
  state: 'empty' | 'incomplete' | 'valid' | 'invalid';
  normalized: string | null;
  issue: string | null;
}

export function bindInput(el: HTMLInputElement, o: BindOptions): () => void {
  const a = fieldAttrs(o.descriptor);
  el.inputMode = a.inputMode;
  el.setAttribute('autocapitalize', a.autoCapitalize);
  if (a.autoComplete !== undefined) el.autocomplete = a.autoComplete;
  if (a.maxLength !== undefined) el.maxLength = a.maxLength;
  if (a.placeholder !== undefined && el.placeholder === '') el.placeholder = a.placeholder;

  const significant = o.descriptor.allowedChars === null
    ? null
    : new RegExp(`[${o.descriptor.allowedChars}]`);

  const isSignificant = (ch: string): boolean =>
    significant === null ? true : significant.test(ch) && ch.trim() !== '';

  function onInput(): void {
    const before = el.value.slice(0, el.selectionStart ?? el.value.length);
    let count = 0;
    for (const ch of before) if (isSignificant(ch)) count++;
    const formatted = o.formatPartial(el.value);
    if (formatted === el.value) return;
    el.value = formatted;
    let pos = 0;
    let seen = 0;
    while (pos < formatted.length && seen < count) {
      if (isSignificant(formatted[pos])) seen++;
      pos++;
    }
    el.setSelectionRange(pos, pos);
  }

  function onBlur(): void {
    if (o.onState === undefined) return;
    if (el.value.trim() === '') {
      o.onState({ state: 'empty', normalized: null, issue: null });
      return;
    }
    const r = o.validate(el.value);
    o.onState(r.ok
      ? { state: 'valid', normalized: r.normalized, issue: null }
      : { state: 'invalid', normalized: null, issue: r.issues[0].code });
  }

  el.addEventListener('input', onInput);
  el.addEventListener('blur', onBlur);
  return () => {
    el.removeEventListener('input', onInput);
    el.removeEventListener('blur', onBlur);
  };
}
```

`'incomplete'` is part of the `FieldState` union but never emitted by
`bindInput`: distinguishing "too short" from "wrong" needs per-type knowledge
this function does not have. Consumers that want it compare the value's
significant length against `descriptor.maxLength` themselves. Say so in the doc
comment — an unused union member with no explanation reads as a bug.

- [ ] **Step 6: Run the whole dom suite — expect PASS**

- [ ] **Step 7: Wire the export points**

`js/src/index.ts` does **not** re-export `dom` — the main entry stays
platform-neutral. Add `'src/dom/index.ts'` to `tsup.config.ts` and a `"./dom"`
entry to `js/package.json`'s `exports`.

- [ ] **Step 8: Run the build and full suite, commit**

```bash
cd js && npm run build && npm test && cd ..
git add js/src/dom js/test/dom.spec.ts js/tsup.config.ts js/package.json
git commit -m "Add the dom subpath: fieldAttrs, filterValue, bindInput"
```

---

## Task 12: Field descriptors, partial formatting and the invariants

**Files:** Modify `test/vectors/field_descriptor.json`,
`test/vectors/format_partial.json`, `test/vectors_test.dart`,
`test/field_invariants_test.dart`, `js/test/field.conformance.spec.ts`,
`js/test/field-invariants.spec.ts`

- [ ] **Step 1: Add descriptor vectors for all six types**

One entry per type, plus the country-parameterised variants — `vat_id` with no
country and with `AT`, `social_security` / `company_register` / `tax_number`
with `AT`. Follow the existing object shape exactly (`type`, `options`,
`keyboard`, `autofill`, `capitalization`, `maxLength`, `example`,
`allowedChars`).

- [ ] **Step 2: Add partial-format vectors**

At minimum per type: empty input, input with separators the formatter must
re-derive, over-long input that must truncate, and input with rejected
characters. For `company_register` include an upper-case letter that must come
out lower-case — that is the type's one asymmetry and nothing else covers it.

- [ ] **Step 3: Register the six types in all four harnesses**

`test/vectors_test.dart` `_descriptorFor` and `_partialFor`,
`js/test/field.conformance.spec.ts` `descriptorFor` and its partial
counterpart, and the `_types` / `types` lists in both invariants suites.

- [ ] **Step 4: Run both invariants suites and fix what they catch**

Run: `dart test test/field_invariants_test.dart && cd js && npx vitest run test/field-invariants.spec.ts`

These enforce that every non-null `example` validates, fits `maxLength`, and
that `formatPartial` of a valid value equals `format`. Expect real failures
here — `maxLength` counts the **formatted** length, and it is easy to have set
`9` for the tax number instead of `11`. Fix the descriptors, not the tests.

- [ ] **Step 5: Commit**

```bash
git commit -m "Pin field descriptors and partial formatting for the new types"
```

---

## Task 13: Documentation

**Files:** Modify `README.md`, `js/README.md`, `llms.txt`, `doc/algorithms.md`,
`CHANGELOG.md`, `js/CHANGELOG.md`, `pubspec.yaml`, `js/package.json`

- [ ] **Step 1: README — features, input fields, per-type sections, matrix**

Twelve types become eighteen: update the `## ✨ Features` list, add a
`### 🧾 VAT ID`, `### 🏦 BIC`, `### 🏷️ GTIN`, `### 🪪 Social-security number`,
`### 🏛️ Company register` and `### 🧮 Tax number` block in the Quick-start
section (each with a short runnable snippet, matching the existing style), and
extend the `## 🧩 Feature matrix` rows.

In `## 🎹 Input fields`, keep the HTML mapping table but add a sentence saying
the TypeScript port ships this mapping as `fieldAttrs` in
`@kreiseck/validator/dom`, so nobody transcribes the table by hand, and that
the Dart side has no counterpart on purpose.

Document explicitly, because each will otherwise be read as a bug:
- `CompanyRegister.normalize` does not upper-case.
- `Gtin` exposes no GS1 prefix or country.
- `SocialSecurityNumber.parse` returns no four-digit year.
- `TaxNumber` never rejects an unknown Finanzamt number.
- `VatId` performs no online check; `viesRequest` is the seam.
- Any country or sub-form that ended up structure-only after Tasks 6, 8 and 9.

- [ ] **Step 2: `llms.txt`**

Same content, condensed to the file's existing register: the API section grows
by six entries, the "Key behaviors / gotchas" list grows by the bullets above,
and the Dart/TS asymmetry of `dom` is stated so it does not read as an
oversight.

- [ ] **Step 3: `doc/algorithms.md`**

One section per new type naming the standard or the verification data. The
Firmenbuch section must record that `number mod 26` is wrong and which real
numbers disprove it.

- [ ] **Step 4: Changelogs and manifests**

`CHANGELOG.md` and `js/CHANGELOG.md` get a `## 0.11.0` entry listing the six
types, the `dom` subpath, and — as a breaking-ish note — that `IssueCode` gained
members, which makes exhaustive Dart switches over it fail to compile.

Add keywords `vat`, `ust-id`, `bic`, `swift`, `gtin`, `ean`, `barcode` to both
manifests and widen the one-line description in `pubspec.yaml` and
`js/package.json` to mention the new types.

- [ ] **Step 5: Commit**

```bash
git commit -m "Document the 0.11.0 types and the dom subpath"
```

---

## Task 14: Release 0.11.0

**Files:** Modify `pubspec.yaml`, `js/package.json`

- [ ] **Step 1: Full green run from a clean state**

```bash
dart pub get && dart analyze && dart test
cd js && rm -rf dist node_modules && npm ci && npm run build && npm run lint && npm test && cd ..
```

All four must pass. Do not proceed on a single failure.

- [ ] **Step 2: Confirm tree-shaking and the exports map**

Run: `cd js && npx vitest run test/treeshaking.spec.ts`

Extend that spec first so each of the seven new subpaths (`bic`, `gtin`,
`vat-id`, `social-security`, `company-register`, `tax-number`, `dom`) is
imported individually, then confirm `dist/` contains a matching `.js`, `.cjs`
and `.d.ts` for each.

- [ ] **Step 3: Bump both versions in one commit**

```bash
git commit -am "Release 0.11.0"
git tag v0.11.0
```

- [ ] **Step 4: Dry-run both publishes and read the output**

```bash
dart pub publish --dry-run
cd js && npm publish --dry-run --access public && cd ..
```

Check the npm file list contains `dist/` and nothing else, and that pub's
warnings are limited to ones already present on 0.10.0.

- [ ] **Step 5: Publish**

**pub.dev cannot be undone** — a published version can be retracted but never
removed, and 0.11.0 can never be reused. Confirm with the repository owner
before this step, then:

```bash
dart pub publish
cd js && npm publish --access public && cd ..
git push origin feat/business-identifier-types --tags
```

- [ ] **Step 6: Verify both registries serve 0.11.0**

```bash
curl -s https://pub.dev/api/packages/kreiseck_validator | head -c 200
curl -s https://registry.npmjs.org/@kreiseck/validator | head -c 200
```

Both must report `0.11.0` as latest.

---

## Self-Review

**Spec coverage.** Every design section maps to a task: the six types → Tasks
2–9, the source-of-truth rule → the Global Constraints plus the verification
steps in Tasks 6, 8 and 9, the VIES seam → Task 10, `dom` → Task 11,
cross-language parity → each type task's vector file plus Task 12,
public-surface changes → each type task's wiring step, docs → Task 13, release
→ Task 14. The design's "candidates for later" list is deliberately unimplemented.

**Known open items, deliberately left to their tasks rather than guessed here.**
Three algorithms were not reached during design research and each has an
explicit obtain-or-degrade step: the Czech 10-digit individual form and the
Spanish DNI/NIE/CIF trio (Task 9, Step 3) and the short-number weighting for
the Austrian Firmenbuchnummer (Task 6, Step 1). Published example numbers are
missing for DE, PL, PT, SI, SK, HU, CH (Task 8, Step 1) and BE, CY, CZ, ES, FR,
IE, SE, GB (Task 9, Step 1); the assertion added in Task 9, Step 7 fails the
build until every country in the metadata table has one, so none of these can
be skipped silently.

**Type consistency.** `checkVat(iso2, body)` is introduced in Task 7 and
extended in Tasks 8 and 9 under the same name. `VatSubtype` members are fixed
in Task 7's interface block and used unchanged in Task 9.
`Bic.matchesIban`, `Gtin.checkDigit` and `CompanyRegister.checkChar` are the
only extra public members and each appears in exactly one task.
`fieldAttrs`/`filterValue`/`bindInput` are named identically in Task 11's
interface block, tests and implementation. `mod11_10Ok`/`mod97_10Ok` (Dart) and
`mod1110Ok`/`mod9710Ok` (TS) differ by language on purpose, and both spellings
appear in Task 1 so no later task has to guess.
