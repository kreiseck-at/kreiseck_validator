# IbanCountry Descriptor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose a public `IbanCountry` descriptor per country — total length, bank / branch / account field lengths, whether a branch code exists, and a valid example IBAN.

**Architecture:** Add a compact example IBAN to each `kIbanBban` entry (DACH real, others synthesised in the generator). A new public `IbanCountry` type derives lengths from the existing offsets and formats the example. No change to `Iban.parse` / `IbanInfo`.

**Tech Stack:** Dart (null-safe, zero runtime deps); Python 3 dev-only generator (`schwifty` + `pycountry`).

## Global Constraints

- **Zero runtime dependencies** in `lib/`. No third-party imports. Generators under `tool/` may use dev deps.
- **No AI/tool attribution** in any commit message, comment, file name, or doc. Output reads as hand-written. The generated-file header is the intended, allowed exception.
- **No change** to `Iban.parse` / `IbanInfo` / the four-operation `Iban` API. This stage is purely additive.
- **`kIbanBban` stays the single source of truth**; `IbanCountry` is a derived public view. Raw BBAN offsets are not exposed publicly — only lengths.
- **License/attribution:** unchanged. Examples are either public canonical (DACH) or synthesised; no new NOTICE entry.

---

### Task 1: Add example IBANs to the structure table

**Files:**
- Modify: `lib/src/iban/iban_metadata.dart` (add `example` field to `IbanBban`)
- Modify: `tool/gen_iban_metadata.py` (synthesis helpers + DACH overrides + emit `example`)
- Regenerate: `lib/src/iban/iban_metadata.g.dart`
- Modify: `test/iban_metadata_test.dart` (assert on the AT example)

**Interfaces:**
- Produces: `IbanBban` gains `final String example;` (compact IBAN, e.g. `'AT611904300234573201'`), required in the const constructor. Every `kIbanBban` entry carries a valid compact example.

- [ ] **Step 1: Write the failing test**

In `test/iban_metadata_test.dart`, add inside the `group('kIbanBban', ...)` block:

```dart
    test('carries a canonical AT example IBAN', () {
      expect(kIbanBban['AT']!.example, 'AT611904300234573201');
    });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `dart test test/iban_metadata_test.dart`
Expected: FAIL — compile error, `IbanBban` has no `example` getter.

- [ ] **Step 3: Add the `example` field to `IbanBban`**

In `lib/src/iban/iban_metadata.dart`, add the parameter to the constructor (after `this.branchEnd,`):

```dart
    required this.example,
```

and add the field (after the `branchEnd` field):

```dart
  /// A valid example IBAN for this country, in compact form.
  final String example;
```

- [ ] **Step 4: Add synthesis helpers + DACH overrides to the generator**

In `tool/gen_iban_metadata.py`, add these two module-level helpers (place them above `bban_structures`) and a DACH example map:

```python
DACH_EXAMPLES = {
    "AT": "AT611904300234573201",
    "DE": "DE89370400440532013000",
    "CH": "CH9300762011623852957",
}


def _iban_check_digits(country: str, bban: str) -> str:
    """The two ISO 13616 check digits for `country` + `bban` (Mod-97)."""
    rearranged = bban + country + "00"
    numeric = "".join(
        str(ord(ch) - 55) if ch.isalpha() else ch for ch in rearranged)
    rem = 0
    for i in range(0, len(numeric), 7):
        rem = int(f"{rem}{numeric[i:i + 7]}") % 97
    return f"{98 - rem:02d}"


def _synth_bban(bban_spec: str) -> str:
    """A deterministic BBAN honouring `bban_spec` tokens (`n` digit, `a`
    letter, `c` alphanumeric), filled with a fixed repeating pattern."""
    out = []
    for length, typ in re.findall(r"(\d+)!?([nac])", bban_spec):
        n = int(length)
        if typ == "n":
            fill = "".join("1234567890"[i % 10] for i in range(n))
        elif typ == "a":
            fill = "".join("ABCDEFGHIJKLMNOPQRSTUVWXYZ"[i % 26] for i in range(n))
        else:
            fill = "".join("ABCDEFGHIJ0123456789"[i % 20] for i in range(n))
        out.append(fill)
    return "".join(out)
```

- [ ] **Step 5: Compute the example inside `bban_structures`**

In `tool/gen_iban_metadata.py`, in `bban_structures()`, inside the loop, after the `if branch.end > branch.start:` block that sets branch offsets, add the example computation before `out[cc] = entry`:

```python
        if cc in DACH_EXAMPLES:
            entry["example"] = DACH_EXAMPLES[cc]
        else:
            bban = _synth_bban(spec.bban_spec)
            entry["example"] = f"{cc}{_iban_check_digits(cc, bban)}{bban}"
```

(The existing lines that assign `out[cc] = entry` and `return out` stay unchanged.)

- [ ] **Step 6: Emit the example in the generated map**

In `tool/gen_iban_metadata.py`, in the `kIbanBban` emission loop, extend the `IbanBban(...)` literal to include the example. Change:

```python
        buf.write(
            f"  '{cc}': IbanBban(length: {e['length']}, "
            f"bankStart: {e['bank_start']}, bankEnd: {e['bank_end']}, "
            f"branchStart: {bs}, branchEnd: {be}),\n"
        )
```

to:

```python
        buf.write(
            f"  '{cc}': IbanBban(length: {e['length']}, "
            f"bankStart: {e['bank_start']}, bankEnd: {e['bank_end']}, "
            f"branchStart: {bs}, branchEnd: {be}, "
            f"example: '{e['example']}'),\n"
        )
```

- [ ] **Step 7: Regenerate the data file**

Run the generator (needs schwifty + all three bank sources; see dispatch notes for the exact interpreter and local `--csv`/`--de-csv`/`--de-date`/`--ch-csv` paths in this environment).

Expected: prints `Wrote .../iban_metadata.g.dart: 126 countries; banks AT=863, CH=1125, DE=3504`, and every `kIbanBban` entry now ends with `example: '<COMPACT_IBAN>'` (e.g. `'AT': IbanBban(length: 20, ..., example: 'AT611904300234573201')`).

- [ ] **Step 8: Run the tests + analyzer**

Run: `dart test && dart analyze`
Expected: all tests pass (the new AT-example assertion + everything else); analyzer clean.

- [ ] **Step 9: Commit**

```bash
git add lib/src/iban/iban_metadata.dart lib/src/iban/iban_metadata.g.dart \
        tool/gen_iban_metadata.py test/iban_metadata_test.dart
git commit -m "Add example IBANs to the country structure table"
```

---

### Task 2: Public `IbanCountry` descriptor

**Files:**
- Create: `lib/src/iban/iban_country.dart`
- Modify: `lib/kreiseck_validator.dart` (export)
- Test: `test/iban_country_test.dart`

**Interfaces:**
- Consumes: `kIbanBban` + `IbanBban` (with `example`, from Task 1); `Iban.isValid` (existing).
- Produces: `class IbanCountry` with `iso2`, `length`, `bankCodeLength`, `branchCodeLength` (int?), `accountLength`, `example`, `hasBranchCode` getter, `static IbanCountry? of(String)`, `static List<IbanCountry> get values`.

- [ ] **Step 1: Write the failing tests**

Create `test/iban_country_test.dart`:

```dart
import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:test/test.dart';

void main() {
  group('IbanCountry', () {
    test('describes the Austrian IBAN format', () {
      final at = IbanCountry.of('AT')!;
      expect(at.iso2, 'AT');
      expect(at.length, 20);
      expect(at.bankCodeLength, 5);
      expect(at.branchCodeLength, isNull);
      expect(at.accountLength, 11);
      expect(at.hasBranchCode, isFalse);
      expect(at.example, 'AT61 1904 3002 3457 3201');
    });

    test('exposes a branch code length where the country has one', () {
      final it = IbanCountry.of('IT')!;
      expect(it.length, 27);
      expect(it.bankCodeLength, 5);
      expect(it.branchCodeLength, 5);
      expect(it.accountLength, 12);
      expect(it.hasBranchCode, isTrue);
    });

    test('lookup is case-insensitive', () {
      final lower = IbanCountry.of('at')!;
      final upper = IbanCountry.of('AT')!;
      expect(lower.iso2, upper.iso2);
      expect(lower.length, upper.length);
    });

    test('returns null for countries without an IBAN', () {
      expect(IbanCountry.of('XX'), isNull); // not a country
      expect(IbanCountry.of('US'), isNull); // real country, no IBAN
    });

    test('every example is a valid IBAN and values is sorted', () {
      final values = IbanCountry.values;
      expect(values, isNotEmpty);
      for (final c in values) {
        expect(Iban.isValid(c.example), isTrue,
            reason: 'invalid example for ${c.iso2}: ${c.example}');
      }
      final codes = values.map((c) => c.iso2).toList();
      final sorted = [...codes]..sort();
      expect(codes, sorted);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `dart test test/iban_country_test.dart`
Expected: FAIL — `IbanCountry` is not defined.

- [ ] **Step 3: Create the `IbanCountry` type**

Create `lib/src/iban/iban_country.dart`:

```dart
import 'iban_metadata.dart';

/// A public description of one country's IBAN format: its total length, the
/// lengths of the bank / branch / account fields, and a valid example.
///
/// Obtained via [IbanCountry.of] or [IbanCountry.values]. Derived from the same
/// bundled metadata that drives IBAN validation.
class IbanCountry {
  const IbanCountry._({
    required this.iso2,
    required this.length,
    required this.bankCodeLength,
    required this.branchCodeLength,
    required this.accountLength,
    required this.example,
  });

  /// ISO 3166-1 alpha-2 code, upper-case (e.g. `AT`).
  final String iso2;

  /// Total IBAN length for this country.
  final int length;

  /// Length of the bank identifier (0 if the country has none).
  final int bankCodeLength;

  /// Length of the branch identifier, or null if the country has none.
  final int? branchCodeLength;

  /// Length of the account-number field.
  final int accountLength;

  /// A valid example IBAN, grouped in blocks of four, e.g.
  /// `AT61 1904 3002 3457 3201`.
  final String example;

  /// Whether this country's IBAN carries a branch identifier.
  bool get hasBranchCode => branchCodeLength != null;

  static IbanCountry _from(String iso2, IbanBban b) {
    final branchStart = b.branchStart;
    final branchEnd = b.branchEnd;
    final branchLen =
        branchStart == null ? null : branchEnd! - branchStart;
    final accountStart = branchEnd ?? b.bankEnd;
    return IbanCountry._(
      iso2: iso2,
      length: b.length,
      bankCodeLength: b.bankEnd - b.bankStart,
      branchCodeLength: branchLen,
      accountLength: b.length - accountStart,
      example: _group(b.example),
    );
  }

  static String _group(String compact) => RegExp(r'.{1,4}')
      .allMatches(compact)
      .map((m) => m.group(0))
      .join(' ');

  /// The descriptor for [code] (case-insensitive ISO2), or null if the country
  /// has no known IBAN format.
  static IbanCountry? of(String code) {
    final cc = code.toUpperCase();
    final b = kIbanBban[cc];
    return b == null ? null : _from(cc, b);
  }

  /// All known IBAN countries, sorted by ISO2 code.
  static List<IbanCountry> get values {
    final codes = kIbanBban.keys.toList()..sort();
    return [for (final cc in codes) _from(cc, kIbanBban[cc]!)];
  }
}
```

- [ ] **Step 4: Export from the barrel**

In `lib/kreiseck_validator.dart`, add next to the other IBAN exports:

```dart
export 'src/iban/iban_country.dart';
```

- [ ] **Step 5: Run the tests + analyzer**

Run: `dart test test/iban_country_test.dart && dart analyze`
Expected: PASS (all `IbanCountry` cases, including the all-examples-valid invariant); analyzer clean.

- [ ] **Step 6: Run the full suite**

Run: `dart test`
Expected: everything green, no regressions.

- [ ] **Step 7: Commit**

```bash
git add lib/src/iban/iban_country.dart lib/kreiseck_validator.dart test/iban_country_test.dart
git commit -m "Add IbanCountry format descriptor"
```

---

### Task 3: Documentation and version bump

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `pubspec.yaml`
- Modify: `doc/algorithms.md`

**Interfaces:**
- Consumes: everything above. No code.

- [ ] **Step 1: Add an IbanCountry usage note to the README**

In `README.md`, near the IBAN section, add a short snippet showing the new descriptor. Read the surrounding IBAN examples first and match the style:

```dart
final at = IbanCountry.of('AT')!;
at.length;        // 20
at.bankCodeLength; // 5
at.hasBranchCode;  // false
at.example;        // 'AT61 1904 3002 3457 3201'
```

If the IBAN feature bullet lists what the module offers, extend it to mention
per-country **format descriptors + example IBANs** (`IbanCountry`).

- [ ] **Step 2: Add the changelog entry**

At the top of `CHANGELOG.md` (above `## 0.5.0`), add:

```markdown
## 0.6.0

- `IbanCountry.of(code)` / `IbanCountry.values` expose each country's IBAN
  format — total length, bank / branch / account field lengths, whether a
  branch code exists, and a valid example IBAN (canonical for AT/DE/CH,
  deterministically generated for the rest).

```

- [ ] **Step 3: Bump the version**

In `pubspec.yaml`, change `version: 0.5.0` to `version: 0.6.0`.

- [ ] **Step 4: Note the examples in the algorithms doc**

In `doc/algorithms.md`, add a short paragraph to the IBAN section explaining that
each country carries an example IBAN — the canonical published example for
AT/DE/CH, and for other countries a deterministic string built from the SWIFT
`bban_spec` and completed with correct Mod-97 check digits. Read the file first
and match its voice.

- [ ] **Step 5: Verify the whole suite**

Run: `dart analyze && dart test`
Expected: no analyzer issues; all tests pass.

- [ ] **Step 6: Commit**

```bash
git add README.md CHANGELOG.md pubspec.yaml doc/algorithms.md
git commit -m "Document IbanCountry and release 0.6.0"
```

---

## Self-Review

**Spec coverage:**
- `IbanCountry` type with `iso2`/`length`/`bankCodeLength`/`branchCodeLength`/`accountLength`/`example`/`hasBranchCode` — Task 2. ✓
- `of` (case-insensitive, null for unknown) + `values` (sorted) — Task 2. ✓
- Lengths derived from `kIbanBban` offsets — Task 2 `_from`. ✓
- Example: DACH canonical, others synthesised + Mod-97 — Task 1. ✓
- `example` compact stored in `IbanBban`, formatted (4-group) in `IbanCountry` — Tasks 1-2. ✓
- Invariant test (all examples valid) — Task 2. ✓
- No change to `Iban.parse`/`IbanInfo` — held throughout. ✓
- Docs + 0.6.0 — Task 3. ✓

**Type consistency:** `IbanBban.example` (String) added in Task 1 and consumed by `IbanCountry._from` in Task 2. `IbanCountry.of`/`values` signatures match the spec and the tests. `bankCodeLength = bankEnd - bankStart`, `accountLength = length - (branchEnd ?? bankEnd)` match the offset semantics already used by `Iban.parse`.

**Placeholder scan:** none. The `126 countries` / bank counts in generator output are runtime prints, snapshot-dependent, not asserted as literals (the tests assert `values` is non-empty and every example validates, not a hard count).
