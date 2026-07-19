# Phone classification & type-aware formatting (AT) — Implementation Plan

**Goal:** Add Austrian phone-number type classification (`Phone.type`), a bundled `Phone.parse` → `PhoneInfo`, and type-aware national/international formatting, using authoritative RTR numbering data. Ship as 0.2.0.

**Architecture:** A new internal `AtNumbering` holds the AT prefix tables (mobile allow-list, service prefixes, curated area codes) plus a classifier and a type-aware formatter. `Phone` gains `type`/`parse` and delegates AT formatting to `AtNumbering`; DE/CH keep their current simple behavior. New public types: `enum PhoneNumberType`, `class PhoneInfo`.

**Tech Stack:** Dart 3, `package:test`. No runtime dependencies.

## Global Constraints

- **Zero runtime dependencies.** No network calls anywhere (classification is offline, allocation-based).
- **Backward compatible.** `isValid`/`validate`/`normalize`/`format`/`tryFormat` keep their signatures; `Phone.format` output for **mobile** numbers is unchanged so existing tests/vectors stay green.
- **AT-only classification.** `Phone.type` returns `PhoneNumberType.unknown` for invalid input or non-AT numbers; DE/CH keep current formatting.
- **No operator/carrier detection** (number portability makes it misleading).
- **Data is authoritative (RTR numbering plan).** Mobile is an explicit allow-list, NOT a numeric range — `0662` (Salzburg) is landline and must never classify as mobile.
- Every public API element has a `///` dartdoc comment.
- **No AI/tooling markers** in code, comments, docs, or commit messages.

## File Structure

```
lib/src/phone/
  phone_number_type.dart     # NEW: enum PhoneNumberType (public)
  phone_info.dart            # NEW: class PhoneInfo (public)
  at_numbering.dart          # NEW: internal AT tables + classifier + formatter
  phone.dart                 # MODIFIED: type/parse + AT-aware format()
lib/kreiseck_validator.dart  # MODIFIED: export the two new public files
test/phone_type_test.dart    # NEW: classification tests
test/phone_format_test.dart  # NEW: type-aware formatting tests
test/phone_test.dart         # unchanged (regression guard)
test/vectors/phone.json      # MODIFIED: add `type` to some cases
test/vectors_test.dart       # MODIFIED: assert `type` when present
```

---

### Task 1: PhoneNumberType + AT classifier

**Files:**
- Create: `lib/src/phone/phone_number_type.dart`, `lib/src/phone/at_numbering.dart`
- Test: `test/phone_type_test.dart`

**Interfaces:**
- Produces: `enum PhoneNumberType { mobile, landline, voip, freephone, sharedCost, premium, corporate, unknown }`; internal `abstract final class AtNumbering` with `static AtClass classify(String national)` (national = significant number, no trunk 0) and `static const Map<String,String> areaCodes`; `class AtClass { final PhoneNumberType type; final String prefix; }` where `prefix` is the leading group used for spacing (area code, mobile/service prefix), or `''` when unknown.

- [ ] **Step 1: Write the failing test**

```dart
// test/phone_type_test.dart
import 'package:kreiseck_validator/src/phone/at_numbering.dart';
import 'package:kreiseck_validator/src/phone/phone_number_type.dart';
import 'package:test/test.dart';

void main() {
  PhoneNumberType t(String national) => AtNumbering.classify(national).type;

  test('mobile prefixes classify as mobile', () {
    expect(t('6641234567'), PhoneNumberType.mobile); // 0664
    expect(t('6991234567'), PhoneNumberType.mobile); // 0699
    expect(t('6501234567'), PhoneNumberType.mobile); // 0650
  });

  test('Salzburg 0662 is landline, NOT mobile (the range trap)', () {
    expect(t('662123456'), PhoneNumberType.landline);
  });

  test('geographic area codes classify as landline', () {
    expect(t('15321234'), PhoneNumberType.landline); // 01 Wien
    expect(t('316123456'), PhoneNumberType.landline); // 0316 Graz
    expect(t('5572123456'), PhoneNumberType.landline); // 05572 Dornbirn
  });

  test('service ranges classify correctly', () {
    expect(t('800123456'), PhoneNumberType.freephone); // 0800
    expect(t('810123456'), PhoneNumberType.sharedCost); // 0810
    expect(t('900123456'), PhoneNumberType.premium); // 0900
    expect(t('720123456'), PhoneNumberType.voip); // 0720
  });

  test('corporate 05x/059x classify as corporate', () {
    expect(t('590133999'), PhoneNumberType.corporate); // 0590
    expect(t('500123456'), PhoneNumberType.corporate); // 0500
  });

  test('classify exposes the grouping prefix', () {
    expect(AtNumbering.classify('316123456').prefix, '316');
    expect(AtNumbering.classify('15321234').prefix, '1');
    expect(AtNumbering.classify('6641234567').prefix, '664');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/phone_type_test.dart`
Expected: FAIL — files don't exist.

- [ ] **Step 3: Create `lib/src/phone/phone_number_type.dart`**

```dart
/// The kind of Austrian phone number, derived from the public RTR numbering
/// plan. This describes the number *type*, not the current operator — number
/// portability means a prefix no longer identifies the carrier.
enum PhoneNumberType {
  /// Mobile number (RTR mobile prefix, e.g. 0664, 0699).
  mobile,

  /// Geographic landline (an area code such as 01 Vienna, 0316 Graz).
  landline,

  /// Location-independent / VoIP number (0720).
  voip,

  /// Toll-free number (0800).
  freephone,

  /// Shared-cost number (0810/0820/0821).
  sharedCost,

  /// Premium-rate number (0900/0901/0930/0931/0939).
  premium,

  /// Corporate / private-network number (050x/059x).
  corporate,

  /// Could not be classified (invalid, or a non-AT number).
  unknown,
}
```

- [ ] **Step 4: Create `lib/src/phone/at_numbering.dart`**

```dart
import 'phone_number_type.dart';

/// Result of classifying an Austrian national number.
class AtClass {
  /// Creates a classification with the [type] and the grouping [prefix].
  const AtClass(this.type, this.prefix);

  /// The classified number type.
  final PhoneNumberType type;

  /// The leading digit group used for display spacing (area code, mobile or
  /// service prefix); empty when it could not be determined.
  final String prefix;
}

/// Austrian (AT) numbering-plan data and classifier, sourced from the public
/// RTR numbering plan. All inputs are the *national significant number*: the
/// number without the international `+43` or the national trunk `0`.
abstract final class AtNumbering {
  AtNumbering._();

  /// RTR mobile prefixes (3 digits): 650-653, 655, 657, 659-661, 663-699.
  /// Note the deliberate gaps — 654, 656, 658 and 662 are NOT mobile
  /// (662 is the Salzburg geographic area code).
  static final Set<String> _mobile = {
    '650', '651', '652', '653', '655', '657', '659', '660', '661',
    for (var n = 663; n <= 699; n++) '$n',
  };

  /// Service prefixes mapped to their type.
  static const Map<String, PhoneNumberType> _service = {
    '800': PhoneNumberType.freephone,
    '810': PhoneNumberType.sharedCost,
    '820': PhoneNumberType.sharedCost,
    '821': PhoneNumberType.sharedCost,
    '900': PhoneNumberType.premium,
    '901': PhoneNumberType.premium,
    '930': PhoneNumberType.premium,
    '931': PhoneNumberType.premium,
    '939': PhoneNumberType.premium,
    '720': PhoneNumberType.voip,
  };

  /// Curated geographic area codes (without the trunk 0) for major cities.
  /// Longest-prefix match wins. Not exhaustive; unknown geographic numbers
  /// fall back to an approximate 4-digit area-code split.
  static const Map<String, String> areaCodes = {
    '1': 'Wien',
    '316': 'Graz',
    '732': 'Linz',
    '662': 'Salzburg',
    '512': 'Innsbruck',
    '463': 'Klagenfurt',
    '4242': 'Villach',
    '7242': 'Wels',
    '2742': 'St. Pölten',
    '5572': 'Dornbirn',
    '5574': 'Bregenz',
    '2622': 'Wiener Neustadt',
    '7252': 'Steyr',
    '5522': 'Feldkirch',
    '2682': 'Eisenstadt',
    '3842': 'Leoben',
    '2732': 'Krems',
    '7472': 'Amstetten',
    '5372': 'Kufstein',
  };

  /// Classifies an Austrian national significant [national] number.
  static AtClass classify(String national) {
    final p3 = national.length >= 3 ? national.substring(0, 3) : national;

    // 1. Mobile — explicit allow-list (checked before geographic so that a
    //    geographic code numerically inside the mobile span, like 662, is not
    //    swept up here).
    if (_mobile.contains(p3)) return AtClass(PhoneNumberType.mobile, p3);

    // 2. Service ranges.
    final service = _service[p3];
    if (service != null) return AtClass(service, p3);

    // 3. Geographic — longest known area-code prefix wins (4 → 3 → 1 digits).
    for (final len in const [4, 3, 2, 1]) {
      if (national.length > len) {
        final code = national.substring(0, len);
        if (areaCodes.containsKey(code)) {
          return AtClass(PhoneNumberType.landline, code);
        }
      }
    }

    // 4. Corporate / private networks: 050x / 059x (not a known geographic code).
    if (national.startsWith('50') || national.startsWith('59')) {
      return AtClass(PhoneNumberType.corporate, p3);
    }

    // 5. Plausible geographic first digit → landline with an unknown area code.
    if (national.isNotEmpty && '234578'.contains(national[0])) {
      return const AtClass(PhoneNumberType.landline, '');
    }

    return const AtClass(PhoneNumberType.unknown, '');
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `dart test test/phone_type_test.dart && dart analyze`
Expected: PASS (6 tests), `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/phone/phone_number_type.dart lib/src/phone/at_numbering.dart test/phone_type_test.dart
git commit -m "Add Austrian phone-number type classifier (RTR numbering plan)"
```

---

### Task 2: Type-aware AT formatter, wired into Phone.format

**Files:**
- Modify: `lib/src/phone/at_numbering.dart` (add formatter), `lib/src/phone/phone.dart`
- Test: `test/phone_format_test.dart`

**Interfaces:**
- Consumes: `AtNumbering.classify`, `AtClass`.
- Produces: `static String AtNumbering.format(String national, {required bool international})`. `Phone.format` uses it when the resolved country is AT; DE/CH unchanged.

- [ ] **Step 1: Write the failing test**

```dart
// test/phone_format_test.dart
import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:test/test.dart';

void main() {
  test('mobile spacing is unchanged', () {
    expect(Phone.format('+436641234567'), '+43 664 1234567');
    expect(Phone.format('+436641234567', international: false), '0664 1234567');
  });

  test('Vienna landline uses the 1-digit area code', () {
    // national = 15321234 -> area '1', rest '5321234'
    expect(Phone.format('+4315321234'), '+43 1 5321234');
    expect(Phone.format('+4315321234', international: false), '01 5321234');
  });

  test('Graz landline uses the 3-digit area code', () {
    expect(Phone.format('+43316123456'), '+43 316 123456');
    expect(Phone.format('+43316123456', international: false), '0316 123456');
  });

  test('unknown area code falls back without throwing', () {
    // 0288x is not in the curated table -> approximate split, still readable.
    expect(Phone.format('+43288123456', international: false).startsWith('0'),
        isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/phone_format_test.dart`
Expected: FAIL on the Vienna case — the current fixed 3-digit split gives `+43 153 21234`, not `+43 1 5321234`. (Graz already happens to work under the 3-digit split; the AT branch makes it intentional.)

- [ ] **Step 3: Add the formatter to `lib/src/phone/at_numbering.dart`**

Add inside `AtNumbering`:

```dart
  /// Formats an Austrian national significant [national] number with
  /// type-aware spacing. [international] chooses `+43 <area> <rest>` vs
  /// `0<area> <rest>`. Never throws; unknown area codes use an approximate
  /// 4-digit split.
  static String format(String national, {required bool international}) {
    final c = classify(national);
    var area = c.prefix;
    if (area.isEmpty) {
      // Fallback: approximate area code (min 2, max 4 digits) for readability.
      final len = national.length >= 6 ? 4 : 2;
      area = national.substring(0, national.length > len ? len : national.length);
    }
    final rest = national.substring(area.length);
    return international ? '+43 $area $rest' : '0$area $rest';
  }
```

- [ ] **Step 4: Wire it into `lib/src/phone/phone.dart`**

Add the import at the top:

```dart
import 'at_numbering.dart';
```

Replace the body of `format` (the area/rest split and return) with an AT branch:

```dart
  static String format(String input,
      {Country? country, bool international = true}) {
    final e164 = normalize(input, country: country);
    final d = e164.substring(1);
    final cc = _byCallingCode.keys.firstWhere(d.startsWith);
    final national = d.substring(cc.length);
    if (cc == '43') {
      return AtNumbering.format(national, international: international);
    }
    final area = national.substring(0, 3);
    final rest = national.substring(3);
    return international ? '+$cc $area $rest' : '0$area $rest';
  }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `dart test test/phone_format_test.dart test/phone_test.dart && dart analyze`
Expected: PASS (new formatting + unchanged regression tests), `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/phone/at_numbering.dart lib/src/phone/phone.dart test/phone_format_test.dart
git commit -m "Make Austrian phone formatting type-aware (area-code spacing)"
```

---

### Task 3: PhoneInfo, Phone.type and Phone.parse

**Files:**
- Create: `lib/src/phone/phone_info.dart`
- Modify: `lib/src/phone/phone.dart`, `lib/kreiseck_validator.dart`
- Test: append to `test/phone_type_test.dart`

**Interfaces:**
- Consumes: `PhoneNumberType`, `AtNumbering`, `Country`, `Valid`.
- Produces: `class PhoneInfo { String e164; Country country; PhoneNumberType type; String national; String international; }`; `static PhoneNumberType Phone.type(String, {Country?})`; `static PhoneInfo? Phone.parse(String, {Country?})`; barrel exports the two new public files.

- [ ] **Step 1: Write the failing test**

Append to `test/phone_type_test.dart` `main()`:

```dart
  test('Phone.type classifies AT numbers and is unknown off-AT/invalid', () {
    expect(Phone.type('+436641234567'), PhoneNumberType.mobile);
    expect(Phone.type('0316 123456', country: Country.at),
        PhoneNumberType.landline);
    expect(Phone.type('+491701234567'), PhoneNumberType.unknown); // DE
    expect(Phone.type('nonsense'), PhoneNumberType.unknown);
  });

  test('Phone.parse bundles type and both formats, null on invalid', () {
    final info = Phone.parse('0316123456', country: Country.at)!;
    expect(info.type, PhoneNumberType.landline);
    expect(info.e164, '+43316123456');
    expect(info.national, '0316 123456');
    expect(info.international, '+43 316 123456');
    expect(info.country, Country.at);
    expect(Phone.parse('nonsense'), isNull);
  });
```

Add the import `import 'package:kreiseck_validator/kreiseck_validator.dart';` at the top of the test (alongside the existing `src/...` imports) for `Phone`/`Country`.

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/phone_type_test.dart`
Expected: FAIL — `Phone.type`/`Phone.parse`/`PhoneInfo` undefined.

- [ ] **Step 3: Create `lib/src/phone/phone_info.dart`**

```dart
import '../common/country.dart';
import 'phone_number_type.dart';

/// A parsed, classified phone number with its canonical and display forms.
class PhoneInfo {
  /// Creates a [PhoneInfo].
  const PhoneInfo({
    required this.e164,
    required this.country,
    required this.type,
    required this.national,
    required this.international,
  });

  /// Canonical E.164 form, e.g. `+43316123456`.
  final String e164;

  /// The resolved country.
  final Country country;

  /// The classified number type (`unknown` for non-AT numbers).
  final PhoneNumberType type;

  /// National display form, e.g. `0316 123456`.
  final String national;

  /// International display form, e.g. `+43 316 123456`.
  final String international;
}
```

- [ ] **Step 4: Add `type` and `parse` to `lib/src/phone/phone.dart`**

Add imports:

```dart
import 'phone_info.dart';
import 'phone_number_type.dart';
```

Add a private helper and the two public methods (place after `tryFormat`):

```dart
  /// Splits a normalized E.164 string into (callingCode, nationalNumber).
  static (String, String) _ccNational(String e164) {
    final d = e164.substring(1);
    final cc = _byCallingCode.keys.firstWhere(d.startsWith);
    return (cc, d.substring(cc.length));
  }

  /// Classifies [input] by Austrian number type. Returns
  /// [PhoneNumberType.unknown] for invalid input or non-AT numbers.
  static PhoneNumberType type(String input, {Country? country}) {
    final result = validate(input, country: country);
    if (result is! Valid) return PhoneNumberType.unknown;
    final (cc, national) = _ccNational(result.normalized);
    if (cc != '43') return PhoneNumberType.unknown;
    return AtNumbering.classify(national).type;
  }

  /// Parses [input] into a [PhoneInfo] bundle, or null if invalid.
  static PhoneInfo? parse(String input, {Country? country}) {
    final result = validate(input, country: country);
    if (result is! Valid) return null;
    final e164 = result.normalized;
    final (cc, national) = _ccNational(e164);
    final resolved = _byCallingCode[cc]!;
    final numberType = resolved == Country.at
        ? AtNumbering.classify(national).type
        : PhoneNumberType.unknown;
    return PhoneInfo(
      e164: e164,
      country: resolved,
      type: numberType,
      national: format(input, country: country, international: false),
      international: format(input, country: country, international: true),
    );
  }
```

- [ ] **Step 5: Export the new public types from the barrel**

In `lib/kreiseck_validator.dart` add:

```dart
export 'src/phone/phone_info.dart';
export 'src/phone/phone_number_type.dart';
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `dart test test/phone_type_test.dart && dart analyze`
Expected: PASS, `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/src/phone/phone_info.dart lib/src/phone/phone.dart lib/kreiseck_validator.dart test/phone_type_test.dart
git commit -m "Add Phone.type and Phone.parse (PhoneInfo bundle)"
```

---

### Task 4: Vectors, docs, example and 0.2.0 release

**Files:**
- Modify: `test/vectors/phone.json`, `test/vectors_test.dart`, `README.md`, `doc/algorithms.md`, `CHANGELOG.md`, `pubspec.yaml`, `example/kreiseck_validator_example.dart`

**Interfaces:**
- Consumes: the finished `Phone.type`/`parse`/`format`.
- Produces: cross-language `type` vectors, updated docs, bumped version.

- [ ] **Step 1: Add a `type` field to some phone vectors**

In `test/vectors/phone.json`, add these cases to the array (fix commas so JSON stays valid):

```json
  {"input": "+436641234567", "isValid": true, "type": "mobile", "format": "+43 664 1234567"},
  {"input": "0662 123456", "country": "at", "isValid": true, "type": "landline"},
  {"input": "+43316123456", "isValid": true, "type": "landline", "format": "+43 316 123456"},
  {"input": "+43800123456", "isValid": true, "type": "freephone"},
```

- [ ] **Step 2: Assert `type` in the runner**

In `test/vectors_test.dart`, extend the phone group so it checks `type` when present. Replace the phone group with:

```dart
  group('phone', () {
    for (final c in _load('phone.json')) {
      final input = c['input']! as String;
      final country = _country(c['country'] as String?);
      final international = c['international'] as bool? ?? true;
      _check(
          'phone',
          c,
          () => Phone.validate(input, country: country),
          () => Phone.format(input,
              country: country, international: international));
      if (c.containsKey('type')) {
        test('phone type: $input', () {
          expect(Phone.type(input, country: country).name, c['type']);
        });
      }
    }
  });
```

- [ ] **Step 3: Run the full suite**

Run: `dart test && dart analyze`
Expected: PASS (all groups incl. new type assertions), `No issues found!`

- [ ] **Step 4: Update the README phone section**

In the `☎️ Phone` block, add examples and a scope note. Insert after the existing phone examples:

```dart
Phone.type('+43 664 1234567');            // PhoneNumberType.mobile
Phone.type('0662 123456', country: Country.at); // PhoneNumberType.landline (not mobile!)

final info = Phone.parse('0316 123456', country: Country.at);
info?.type;          // PhoneNumberType.landline
info?.national;      // '0316 123456'   (area-code-aware spacing)
info?.international;  // '+43 316 123456'
```

Add prose: type classification and area-code spacing are **Austria-only** (RTR numbering plan); for DE/CH `type` is `unknown` and formatting stays simple. It classifies the number **type**, not the current operator — number portability means a prefix no longer identifies the carrier.

- [ ] **Step 5: Document the numbering plan in `doc/algorithms.md`**

Add a section "Austrian number classification (AT)" explaining: mobile is an explicit RTR allow-list (650-653, 655, 657, 659-661, 663-699) — NOT a range, since 0662 Salzburg is landline; the service ranges (0800/0810/0820/0821/0900/0901/0930/0931/0939/0720); geographic area codes with longest-prefix match + approximate fallback; and the RTR source plus the portability caveat.

- [ ] **Step 6: Update example, CHANGELOG and version**

Append to `example/kreiseck_validator_example.dart`'s `_phone()` a couple of lines showing `Phone.type` and `Phone.parse`.

Prepend to `CHANGELOG.md`:

```markdown
## 0.2.0

- `Phone.type` and `Phone.parse` (`PhoneInfo`): Austrian number-type
  classification (mobile, landline, VoIP, freephone, shared-cost, premium,
  corporate) from the public RTR numbering plan.
- Type-aware Austrian formatting: `Phone.format` now uses the geographic
  area-code length for landlines (e.g. `01 …` Vienna, `0316 …` Graz);
  mobile output is unchanged.
```

Set `version: 0.2.0` in `pubspec.yaml`.

- [ ] **Step 7: Full verification and commit**

Run: `dart test && dart analyze && dart format --output=none --set-exit-if-changed . && dart run example/kreiseck_validator_example.dart`
Expected: all tests pass, no analyzer issues, formatting clean, example runs.

```bash
git add -A
git commit -m "Add classification vectors, docs and example; release 0.2.0"
```

---

## Self-Review Notes

- **Spec coverage:** classifier (Task 1), type-aware formatter (Task 2), `type`/`parse`/`PhoneInfo` (Task 3), vectors/docs/example/release (Task 4). AT-only + DE/CH fallback covered in Tasks 2–3. No operator detection anywhere. Data matches the RTR research (mobile allow-list with the 0662 exclusion; service ranges; curated area codes).
- **Type consistency:** `AtNumbering.classify` returns `AtClass{type,prefix}` used by both the classifier tests and the formatter; `Phone.type`/`parse` reuse `_ccNational`; barrel exports `phone_info.dart` + `phone_number_type.dart`; vector `type` strings equal `PhoneNumberType.name`.
- **Placeholders:** none. The Vienna test expectation carries an explicit note to align input digits with the `1`-area-code output before running.
