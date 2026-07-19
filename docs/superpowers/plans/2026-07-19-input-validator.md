# input_validator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A zero-dependency Dart package that validates, normalizes and pretty-formats email, phone, URL/domain, IBAN and credit-card input, driven by shared language-agnostic JSON test vectors.

**Architecture:** Each input type is a class with static methods (`isValid`, `validate`, `normalize`, `format`) sharing a common sealed `ValidationResult` model in `lib/src/common/`. Behavior is pinned by JSON vectors in `test/vectors/`, written before the implementation (TDD), and checked by a native Dart runner plus per-type unit tests.

**Tech Stack:** Dart 3.12+, `package:test`, `package:lints`/strict analysis. No runtime dependencies.

## Global Constraints

- **Zero runtime dependencies.** `pubspec.yaml` `dependencies:` stays empty; only `dev_dependencies` (test, lints) allowed. No network/DNS calls anywhere.
- **Dart SDK floor:** `>=3.0.0 <4.0.0` (sealed classes required).
- **License:** Apache-2.0. `LICENSE` file present; source headers not required but no other license text.
- **No foreign-tooling in the shipped package.** Any Python helper lives under `tool/` and is never imported by `lib/`.
- **Country scope for country-specific logic:** DE, AT, CH only. Checksums (Luhn, Mod-97) are generic.
- **Public API naming:** type classes `Email`, `Phone`, `Url`, `Iban`, `CreditCard`; operations `isValid`/`validate`/`normalize`/`format`(+`tryFormat`).
- **Every public API element has a dartdoc `///` comment.**
- **No AI/tooling markers** in code, comments, docs, commit messages, or file names.

---

## File Structure

```
input_validator/
  pubspec.yaml
  analysis_options.yaml
  LICENSE                         # Apache-2.0
  README.md
  CHANGELOG.md
  lib/
    input_validator.dart          # barrel export
    src/
      common/
        country.dart              # enum Country
        issue_code.dart           # enum IssueCode
        validation_result.dart    # ValidationResult, Valid, Invalid, ValidationIssue, Suggestion
      email/email.dart
      phone/phone.dart
      url/url.dart
      iban/iban.dart
      credit_card/credit_card.dart
  test/
    common_test.dart
    email_test.dart
    phone_test.dart
    url_test.dart
    iban_test.dart
    credit_card_test.dart
    vectors_test.dart             # loads & checks every test/vectors/*.json
    vectors/
      email.json phone.json url.json iban.json credit_card.json
  doc/
    algorithms.md                 # Luhn, Mod-97, E.164, typo distance
  tool/
    gen_vectors.py                # optional vector generator (not shipped)
```

Each `src/<type>/` file owns one input type and depends only on `common/`. `vectors_test.dart` is the shared conformance runner; a future npm port reuses `test/vectors/*.json` verbatim.

---

### Task 0: Project scaffold

**Files:**
- Create: `pubspec.yaml`, `analysis_options.yaml`, `LICENSE`, `CHANGELOG.md`, `lib/input_validator.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: an analyzable, testable empty package. Barrel file `lib/input_validator.dart` will re-export type classes as tasks add them.

- [ ] **Step 1: Create `pubspec.yaml`**

```yaml
name: input_validator
description: >-
  Zero-dependency validation, normalization and pretty-formatting for common
  inputs: email, phone, URL, IBAN and credit-card numbers.
version: 0.1.0
repository: https://github.com/mhmmdlkts/input_validator
environment:
  sdk: ">=3.0.0 <4.0.0"
dev_dependencies:
  lints: ^4.0.0
  test: ^1.24.0
```

- [ ] **Step 2: Create `analysis_options.yaml`**

```yaml
include: package:lints/recommended.yaml
analyzer:
  language:
    strict-casts: true
    strict-raw-types: true
```

- [ ] **Step 3: Create `LICENSE` (Apache-2.0)**

Write the full, unmodified Apache License 2.0 text (https://www.apache.org/licenses/LICENSE-2.0.txt), with the copyright line: `Copyright 2026 mhmmdlkts`.

- [ ] **Step 4: Create `CHANGELOG.md`**

```markdown
# Changelog

## 0.1.0 (unreleased)

- Initial release: email, phone, URL, IBAN and credit-card validation,
  normalization and formatting (DACH country coverage).
```

- [ ] **Step 5: Create empty barrel `lib/input_validator.dart`**

```dart
/// Zero-dependency validation, normalization and formatting for common inputs.
library;

// Type exports are added as each type is implemented.
```

- [ ] **Step 6: Fetch dependencies and analyze**

Run: `dart pub get && dart analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml analysis_options.yaml LICENSE CHANGELOG.md lib/input_validator.dart
git commit -m "Scaffold package: pubspec, lints, license, barrel"
```

---

### Task 1: Common result model

**Files:**
- Create: `lib/src/common/country.dart`, `lib/src/common/issue_code.dart`, `lib/src/common/validation_result.dart`
- Test: `test/common_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum Country { de, at, ch }` with `String get callingCode` (`'49'`/`'43'`/`'41'`) and `String get iso2` (`'DE'`/`'AT'`/`'CH'`).
  - `enum IssueCode { ... }` (full list below).
  - `sealed class ValidationResult`; `class Valid(String normalized, {List<Suggestion> suggestions})`; `class Invalid(List<ValidationIssue> issues)`; `class ValidationIssue(IssueCode code, String message)`; `class Suggestion(String value, String reason)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/common_test.dart
import 'package:input_validator/src/common/country.dart';
import 'package:input_validator/src/common/issue_code.dart';
import 'package:input_validator/src/common/validation_result.dart';
import 'package:test/test.dart';

void main() {
  test('Country exposes calling code and iso2', () {
    expect(Country.at.callingCode, '43');
    expect(Country.de.iso2, 'DE');
  });

  test('Valid carries normalized value and defaults to no suggestions', () {
    const r = Valid('a@b.com');
    expect(r.normalized, 'a@b.com');
    expect(r.suggestions, isEmpty);
  });

  test('Invalid carries at least one issue', () {
    const r = Invalid([ValidationIssue(IssueCode.emailMissingAt, 'no @')]);
    expect(r.issues.single.code, IssueCode.emailMissingAt);
  });

  test('ValidationResult is sealed and switchable', () {
    ValidationResult r = const Valid('x');
    final label = switch (r) { Valid() => 'ok', Invalid() => 'bad' };
    expect(label, 'ok');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/common_test.dart`
Expected: FAIL — target files do not exist.

- [ ] **Step 3: Create `lib/src/common/country.dart`**

```dart
/// Countries with dedicated formatting rules (DACH scope).
enum Country {
  /// Germany.
  de,

  /// Austria.
  at,

  /// Switzerland.
  ch;

  /// The E.164 country calling code without the leading `+`.
  String get callingCode => switch (this) {
        Country.de => '49',
        Country.at => '43',
        Country.ch => '41',
      };

  /// The ISO 3166-1 alpha-2 code.
  String get iso2 => switch (this) {
        Country.de => 'DE',
        Country.at => 'AT',
        Country.ch => 'CH',
      };
}
```

- [ ] **Step 4: Create `lib/src/common/issue_code.dart`**

```dart
/// Stable, translation-friendly identifiers for validation failures.
enum IssueCode {
  // email
  emailEmpty, emailMissingAt, emailMultipleAt, emailEmptyLocal, emailBadDomain,
  // phone
  phoneEmpty, phoneBadChars, phoneTooShort, phoneTooLong,
  phoneAmbiguousCountry, phoneUnknownCountry,
  // url
  urlEmpty, urlBadScheme, urlBadHost, urlBadTld,
  // iban
  ibanEmpty, ibanBadChars, ibanBadChecksum, ibanBadLength,
  // credit card
  cardEmpty, cardBadChars, cardBadLength, cardBadLuhn,
}
```

- [ ] **Step 5: Create `lib/src/common/validation_result.dart`**

```dart
import 'issue_code.dart';

/// Outcome of a `validate` call: either [Valid] or [Invalid].
sealed class ValidationResult {
  const ValidationResult();
}

/// A successful validation carrying the canonical [normalized] form.
class Valid extends ValidationResult {
  /// Creates a valid result.
  const Valid(this.normalized, {this.suggestions = const []});

  /// The canonical form of the accepted input.
  final String normalized;

  /// Optional, non-blocking hints (e.g. a likely typo correction).
  final List<Suggestion> suggestions;
}

/// A failed validation carrying one or more [issues].
class Invalid extends ValidationResult {
  /// Creates an invalid result; [issues] must be non-empty.
  const Invalid(this.issues);

  /// The reasons the input was rejected.
  final List<ValidationIssue> issues;
}

/// A single validation failure reason.
class ValidationIssue {
  /// Creates an issue from a stable [code] and a human-readable [message].
  const ValidationIssue(this.code, this.message);

  /// Stable, translatable identifier.
  final IssueCode code;

  /// English default message; translate via [code].
  final String message;
}

/// A non-blocking correction hint attached to a [Valid] result.
class Suggestion {
  /// Creates a suggestion for a corrected [value] with a machine [reason].
  const Suggestion(this.value, this.reason);

  /// The suggested corrected input.
  final String value;

  /// Machine-readable reason, e.g. `'typo-domain'`.
  final String reason;
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `dart test test/common_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 7: Commit**

```bash
git add lib/src/common test/common_test.dart
git commit -m "Add common result model: Country, IssueCode, ValidationResult"
```

---

### Task 2: Credit-card type (Luhn + network detection + formatting)

Start with credit cards: purely algorithmic, no country rules, exercises the result model end-to-end.

**Files:**
- Create: `lib/src/credit_card/credit_card.dart`
- Modify: `lib/input_validator.dart` (add export)
- Test: `test/credit_card_test.dart`

**Interfaces:**
- Consumes: `ValidationResult`, `Valid`, `Invalid`, `ValidationIssue`, `IssueCode`.
- Produces: `class CreditCard` with `static bool isValid(String)`, `static ValidationResult validate(String)`, `static String normalize(String)` (digits only; throws `FormatException` if invalid), `static String format(String)` / `static String? tryFormat(String)`, and `static CardNetwork? network(String)`; `enum CardNetwork { visa, mastercard, amex, discover, unknown }`.

- [ ] **Step 1: Write the failing test**

```dart
// test/credit_card_test.dart
import 'package:input_validator/src/common/issue_code.dart';
import 'package:input_validator/src/common/validation_result.dart';
import 'package:input_validator/src/credit_card/credit_card.dart';
import 'package:test/test.dart';

void main() {
  test('accepts a valid Visa number with separators', () {
    expect(CreditCard.isValid('4111 1111 1111 1111'), isTrue);
  });

  test('rejects a number failing the Luhn check', () {
    final r = CreditCard.validate('4111111111111112');
    expect(r, isA<Invalid>());
    expect((r as Invalid).issues.first.code, IssueCode.cardBadLuhn);
  });

  test('normalize strips separators to digits', () {
    expect(CreditCard.normalize('4111-1111 1111 1111'), '4111111111111111');
  });

  test('format groups Visa in 4-4-4-4', () {
    expect(CreditCard.format('4111111111111111'), '4111 1111 1111 1111');
  });

  test('format groups Amex in 4-6-5', () {
    expect(CreditCard.format('378282246310005'), '3782 822463 10005');
  });

  test('detects the card network', () {
    expect(CreditCard.network('4111111111111111'), CardNetwork.visa);
    expect(CreditCard.network('378282246310005'), CardNetwork.amex);
  });

  test('detects Discover across its BIN ranges', () {
    expect(CreditCard.network('6011000000000004'), CardNetwork.discover);
    expect(CreditCard.network('6440000000000000'), CardNetwork.discover);
    expect(CreditCard.network('6500000000000000'), CardNetwork.discover);
  });

  test('rejects an implausibly short number even if Luhn-clean', () {
    expect(CreditCard.isValid('00'), isFalse);
    final r = CreditCard.validate('00');
    expect((r as Invalid).issues.first.code, IssueCode.cardBadLength);
  });

  test('tryFormat returns null on invalid input', () {
    expect(CreditCard.tryFormat('abcd'), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/credit_card_test.dart`
Expected: FAIL — `credit_card.dart` missing.

- [ ] **Step 3: Create `lib/src/credit_card/credit_card.dart`**

```dart
import '../common/issue_code.dart';
import '../common/validation_result.dart';

/// Recognized card networks.
enum CardNetwork {
  /// Visa (starts with 4).
  visa,

  /// Mastercard (51-55 or 2221-2720).
  mastercard,

  /// American Express (34/37).
  amex,

  /// Discover (6011/65/644-649).
  discover,

  /// Not recognized.
  unknown,
}

/// Validation, normalization and formatting of payment-card numbers.
///
/// Validation combines a network-specific length check with the Luhn
/// checksum. See `doc/algorithms.md` for the Luhn algorithm.
class CreditCard {
  CreditCard._();

  static final RegExp _digits = RegExp(r'^[0-9]+$');

  /// Returns the digits-only form, discarding spaces and dashes.
  static String _strip(String input) =>
      input.replaceAll(RegExp(r'[\s-]'), '');

  /// Detects the [CardNetwork] from the leading digits, or null if empty.
  static CardNetwork? network(String input) {
    final s = _strip(input);
    if (s.isEmpty || !_digits.hasMatch(s)) return null;
    final n2 = int.parse(s.substring(0, s.length >= 2 ? 2 : 1).padRight(2, '0'));
    final n3 =
        int.parse(s.substring(0, s.length >= 3 ? 3 : s.length).padRight(3, '0'));
    final n4 = s.length >= 4 ? int.parse(s.substring(0, 4)) : n2 * 100;
    if (s[0] == '4') return CardNetwork.visa;
    if (n2 == 34 || n2 == 37) return CardNetwork.amex;
    if ((n2 >= 51 && n2 <= 55) || (n4 >= 2221 && n4 <= 2720)) {
      return CardNetwork.mastercard;
    }
    if (n4 == 6011 || n2 == 65 || (n3 >= 644 && n3 <= 649)) {
      return CardNetwork.discover;
    }
    return CardNetwork.unknown;
  }

  /// True when [input] passes the Luhn checksum (digits weighted right-to-left).
  static bool _luhnOk(String digits) {
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

  static const Map<CardNetwork, Set<int>> _lengths = {
    CardNetwork.visa: {13, 16, 19},
    CardNetwork.mastercard: {16},
    CardNetwork.amex: {15},
    CardNetwork.discover: {16, 19},
  };

  /// Validates [input], returning a [Valid] with the digits-only normalized
  /// form or an [Invalid] describing why it was rejected.
  static ValidationResult validate(String input) {
    final s = _strip(input);
    if (s.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.cardEmpty, 'Card number is empty.')]);
    }
    if (!_digits.hasMatch(s)) {
      return const Invalid([
        ValidationIssue(IssueCode.cardBadChars, 'Card number has non-digits.')
      ]);
    }
    final net = network(s);
    final allowed = _lengths[net];
    if (allowed != null) {
      if (!allowed.contains(s.length)) {
        return const Invalid([
          ValidationIssue(IssueCode.cardBadLength, 'Wrong length for network.')
        ]);
      }
    } else if (s.length < 12 || s.length > 19) {
      // Unknown network: enforce the ISO/IEC 7812 PAN range so short,
      // Luhn-clean junk (e.g. "00") is not accepted as a card.
      return const Invalid([
        ValidationIssue(IssueCode.cardBadLength, 'Implausible card length.')
      ]);
    }
    if (!_luhnOk(s)) {
      return const Invalid([
        ValidationIssue(IssueCode.cardBadLuhn, 'Fails the Luhn checksum.')
      ]);
    }
    return Valid(s);
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input) => validate(input) is Valid;

  /// Returns the digits-only canonical form. Throws [FormatException] if
  /// [input] is not a valid card number.
  static String normalize(String input) => switch (validate(input)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };

  /// Returns [input] grouped for display (Amex 4-6-5, otherwise 4-4-4-4).
  /// Throws [FormatException] if invalid.
  static String format(String input) {
    final s = normalize(input);
    final groups = network(s) == CardNetwork.amex ? [4, 6, 5] : null;
    if (groups == null) {
      return RegExp(r'.{1,4}')
          .allMatches(s)
          .map((m) => m.group(0))
          .join(' ');
    }
    final out = <String>[];
    var i = 0;
    for (final g in groups) {
      out.add(s.substring(i, i + g));
      i += g;
    }
    return out.join(' ');
  }

  /// Like [format] but returns null instead of throwing on invalid input.
  static String? tryFormat(String input) {
    try {
      return format(input);
    } on FormatException {
      return null;
    }
  }
}
```

- [ ] **Step 4: Add export to barrel**

In `lib/input_validator.dart` add:

```dart
export 'src/common/country.dart';
export 'src/common/issue_code.dart';
export 'src/common/validation_result.dart';
export 'src/credit_card/credit_card.dart';
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `dart test test/credit_card_test.dart && dart analyze`
Expected: PASS (7 tests), `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/credit_card lib/input_validator.dart test/credit_card_test.dart
git commit -m "Add credit-card validation, network detection and formatting"
```

---

### Task 3: IBAN type (Mod-97 + DACH length + formatting)

**Files:**
- Create: `lib/src/iban/iban.dart`
- Modify: `lib/input_validator.dart`
- Test: `test/iban_test.dart`

**Interfaces:**
- Consumes: common result model.
- Produces: `class Iban` with `static bool isValid(String)`, `static ValidationResult validate(String)`, `static String normalize(String)`, `static String format(String)` / `static String? tryFormat(String)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/iban_test.dart
import 'package:input_validator/src/common/issue_code.dart';
import 'package:input_validator/src/common/validation_result.dart';
import 'package:input_validator/src/iban/iban.dart';
import 'package:test/test.dart';

void main() {
  test('accepts a valid Austrian IBAN with spaces', () {
    expect(Iban.isValid('AT61 1904 3002 3457 3201'), isTrue);
  });

  test('rejects a bad checksum', () {
    final r = Iban.validate('AT611904300234573200');
    expect((r as Invalid).issues.first.code, IssueCode.ibanBadChecksum);
  });

  test('rejects wrong length for a DACH country', () {
    final r = Iban.validate('DE89370400440532013');
    expect((r as Invalid).issues.first.code, IssueCode.ibanBadLength);
  });

  test('normalize uppercases and removes spaces', () {
    expect(Iban.normalize('at61 1904 3002 3457 3201'), 'AT611904300234573201');
  });

  test('format groups in 4s', () {
    expect(Iban.format('DE89370400440532013000'),
        'DE89 3704 0044 0532 0130 00');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/iban_test.dart`
Expected: FAIL — `iban.dart` missing.

- [ ] **Step 3: Create `lib/src/iban/iban.dart`**

```dart
import '../common/issue_code.dart';
import '../common/validation_result.dart';

/// Validation, normalization and formatting of IBANs.
///
/// The ISO 13616 check digits are verified with the Mod-97 algorithm
/// (see `doc/algorithms.md`). Length is enforced for DACH countries; other
/// countries are accepted on checksum alone.
class Iban {
  Iban._();

  /// Known IBAN lengths for the DACH scope.
  static const Map<String, int> _dachLengths = {'DE': 22, 'AT': 20, 'CH': 21};

  static final RegExp _alnum = RegExp(r'^[0-9A-Z]+$');

  static String _strip(String input) =>
      input.replaceAll(RegExp(r'\s'), '').toUpperCase();

  /// Mod-97 checksum: move first 4 chars to the end, map letters A-Z to
  /// 10-35, take the big integer mod 97 in 7-digit chunks; valid when == 1.
  static bool _checksumOk(String iban) {
    final rearranged = iban.substring(4) + iban.substring(0, 4);
    final buf = StringBuffer();
    for (final cu in rearranged.codeUnits) {
      if (cu >= 0x30 && cu <= 0x39) {
        buf.write(cu - 0x30);
      } else if (cu >= 0x41 && cu <= 0x5A) {
        buf.write(cu - 0x37);
      } else {
        return false;
      }
    }
    final s = buf.toString();
    var remainder = 0;
    for (var i = 0; i < s.length; i += 7) {
      final end = i + 7 > s.length ? s.length : i + 7;
      remainder = int.parse('$remainder${s.substring(i, end)}') % 97;
    }
    return remainder == 1;
  }

  /// Validates [input], returning [Valid] with the compact upper-case form.
  static ValidationResult validate(String input) {
    final s = _strip(input);
    if (s.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.ibanEmpty, 'IBAN is empty.')]);
    }
    if (!_alnum.hasMatch(s) || s.length < 5) {
      return const Invalid([
        ValidationIssue(IssueCode.ibanBadChars, 'IBAN has invalid characters.')
      ]);
    }
    final country = s.substring(0, 2);
    final expected = _dachLengths[country];
    if (expected != null && s.length != expected) {
      return const Invalid(
          [ValidationIssue(IssueCode.ibanBadLength, 'Wrong length.')]);
    }
    if (!_checksumOk(s)) {
      return const Invalid([
        ValidationIssue(IssueCode.ibanBadChecksum, 'Checksum failed.')
      ]);
    }
    return Valid(s);
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input) => validate(input) is Valid;

  /// Returns the compact upper-case canonical form. Throws [FormatException].
  static String normalize(String input) => switch (validate(input)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };

  /// Returns the IBAN grouped in blocks of four. Throws [FormatException].
  static String format(String input) => RegExp(r'.{1,4}')
      .allMatches(normalize(input))
      .map((m) => m.group(0))
      .join(' ');

  /// Like [format] but returns null on invalid input.
  static String? tryFormat(String input) {
    try {
      return format(input);
    } on FormatException {
      return null;
    }
  }
}
```

- [ ] **Step 4: Add export to barrel**

In `lib/input_validator.dart` add: `export 'src/iban/iban.dart';`

- [ ] **Step 5: Run tests to verify they pass**

Run: `dart test test/iban_test.dart && dart analyze`
Expected: PASS (5 tests), `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/iban lib/input_validator.dart test/iban_test.dart
git commit -m "Add IBAN validation (Mod-97 + DACH length) and formatting"
```

---

### Task 4: URL/domain type (validate + normalize + display format)

**Files:**
- Create: `lib/src/url/url.dart`
- Modify: `lib/input_validator.dart`
- Test: `test/url_test.dart`

**Interfaces:**
- Consumes: common result model.
- Produces: `class Url` with `static bool isValid(String)`, `static ValidationResult validate(String)`, `static String normalize(String, {String defaultScheme = 'https'})`, `static String format(String)` / `static String? tryFormat(String)` (display form: no scheme, no leading `www.`, no trailing slash).

- [ ] **Step 1: Write the failing test**

```dart
// test/url_test.dart
import 'package:input_validator/src/common/issue_code.dart';
import 'package:input_validator/src/common/validation_result.dart';
import 'package:input_validator/src/url/url.dart';
import 'package:test/test.dart';

void main() {
  test('accepts a bare domain', () {
    expect(Url.isValid('example.com'), isTrue);
  });

  test('rejects a host without a dot', () {
    final r = Url.validate('localhost');
    expect((r as Invalid).issues.first.code, IssueCode.urlBadHost);
  });

  test('rejects an unsupported scheme', () {
    final r = Url.validate('ftp://example.com');
    expect((r as Invalid).issues.first.code, IssueCode.urlBadScheme);
  });

  test('normalize adds https, lowercases host, strips trailing slash', () {
    expect(Url.normalize('Example.COM/Path/'), 'https://example.com/Path');
  });

  test('format strips scheme, www and trailing slash for display', () {
    expect(Url.format('https://www.example.com/'), 'example.com');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/url_test.dart`
Expected: FAIL — `url.dart` missing.

- [ ] **Step 3: Create `lib/src/url/url.dart`**

```dart
import '../common/issue_code.dart';
import '../common/validation_result.dart';

/// Validation, normalization and display formatting of web URLs / domains.
///
/// This is a pragmatic plausibility check (scheme, host, TLD), not a full
/// URL grammar. Only `http` and `https` schemes are accepted.
class Url {
  Url._();

  static final RegExp _host =
      RegExp(r'^([a-z0-9](-?[a-z0-9])*\.)+[a-z]{2,}$');

  /// Splits [input] into (scheme, rest), defaulting scheme to null.
  static (String?, String) _split(String input) {
    final m = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.-]*)://(.*)$').firstMatch(input);
    if (m == null) return (null, input);
    return (m.group(1)!.toLowerCase(), m.group(2)!);
  }

  /// Validates [input], returning [Valid] with the [normalize] form.
  static ValidationResult validate(String input,
      {String defaultScheme = 'https'}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.urlEmpty, 'URL is empty.')]);
    }
    final (scheme, rest) = _split(trimmed);
    if (scheme != null && scheme != 'http' && scheme != 'https') {
      return const Invalid([
        ValidationIssue(IssueCode.urlBadScheme, 'Only http/https allowed.')
      ]);
    }
    final slash = rest.indexOf('/');
    final hostPart = (slash == -1 ? rest : rest.substring(0, slash));
    final host = hostPart.toLowerCase();
    if (!_host.hasMatch(host)) {
      return const Invalid(
          [ValidationIssue(IssueCode.urlBadHost, 'Invalid host.')]);
    }
    return Valid(normalize(trimmed, defaultScheme: defaultScheme));
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input) => validate(input) is Valid;

  /// Returns the canonical URL: lower-cased host, explicit scheme
  /// (default [defaultScheme]), no trailing slash on the path.
  static String normalize(String input, {String defaultScheme = 'https'}) {
    final trimmed = input.trim();
    final (scheme, rest) = _split(trimmed);
    final slash = rest.indexOf('/');
    final host = (slash == -1 ? rest : rest.substring(0, slash)).toLowerCase();
    var path = slash == -1 ? '' : rest.substring(slash);
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return '${scheme ?? defaultScheme}://$host$path';
  }

  /// Returns a compact display form: no scheme, no leading `www.`, no
  /// trailing slash. Throws [FormatException] if [input] is invalid.
  static String format(String input) {
    switch (validate(input)) {
      case Invalid(:final issues):
        throw FormatException(issues.first.message);
      case Valid(:final normalized):
        var s = normalized.replaceFirst(RegExp(r'^https?://'), '');
        s = s.replaceFirst(RegExp(r'^www\.'), '');
        if (s.endsWith('/')) s = s.substring(0, s.length - 1);
        return s;
    }
  }

  /// Like [format] but returns null on invalid input.
  static String? tryFormat(String input) {
    try {
      return format(input);
    } on FormatException {
      return null;
    }
  }
}
```

- [ ] **Step 4: Add export to barrel**

In `lib/input_validator.dart` add: `export 'src/url/url.dart';`

- [ ] **Step 5: Run tests to verify they pass**

Run: `dart test test/url_test.dart && dart analyze`
Expected: PASS (5 tests), `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/url lib/input_validator.dart test/url_test.dart
git commit -m "Add URL/domain validation, normalization and display format"
```

---

### Task 5: Email type (pragmatic validation + normalization + typo heuristic)

**Files:**
- Create: `lib/src/email/email.dart`
- Modify: `lib/input_validator.dart`
- Test: `test/email_test.dart`

**Interfaces:**
- Consumes: common result model.
- Produces: `class Email` with `static bool isValid(String)`, `static ValidationResult validate(String)` (attaches a `Suggestion(reason: 'typo-domain')` to `Valid` when a close known-domain match exists), `static String normalize(String)` (trim + lowercase).

- [ ] **Step 1: Write the failing test**

```dart
// test/email_test.dart
import 'package:input_validator/src/common/issue_code.dart';
import 'package:input_validator/src/common/validation_result.dart';
import 'package:input_validator/src/email/email.dart';
import 'package:test/test.dart';

void main() {
  test('accepts a normal address', () {
    expect(Email.isValid('a.b+tag@example.com'), isTrue);
  });

  test('rejects a missing @', () {
    final r = Email.validate('ab.com');
    expect((r as Invalid).issues.first.code, IssueCode.emailMissingAt);
  });

  test('rejects an empty local part', () {
    final r = Email.validate('@example.com');
    expect((r as Invalid).issues.first.code, IssueCode.emailEmptyLocal);
  });

  test('normalize trims and lowercases', () {
    expect(Email.normalize('  A@B.COM '), 'a@b.com');
  });

  test('suggests a corrected domain on a likely typo', () {
    final r = Email.validate('user@gmial.com');
    expect(r, isA<Valid>());
    final s = (r as Valid).suggestions.single;
    expect(s.value, 'user@gmail.com');
    expect(s.reason, 'typo-domain');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/email_test.dart`
Expected: FAIL — `email.dart` missing.

- [ ] **Step 3: Create `lib/src/email/email.dart`**

```dart
import '../common/issue_code.dart';
import '../common/validation_result.dart';

/// Validation, normalization and typo-hinting for email addresses.
///
/// Validation is pragmatic (one `@`, non-empty local part, dotted domain with
/// a plausible TLD) rather than full RFC 5322. Typo hinting is offline only.
class Email {
  Email._();

  static final RegExp _local = RegExp(r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+$");
  static final RegExp _domain =
      RegExp(r'^([a-z0-9](-?[a-z0-9])*\.)+[a-z]{2,}$');

  /// Popular domains used as targets for the typo heuristic.
  static const List<String> _knownDomains = [
    'gmail.com', 'googlemail.com', 'yahoo.com', 'hotmail.com',
    'outlook.com', 'icloud.com', 'gmx.net', 'web.de', 'live.com',
  ];

  /// Trims and lower-cases [input].
  static String normalize(String input) => input.trim().toLowerCase();

  /// Optimal string alignment (Damerau) distance between [a] and [b]. Unlike
  /// plain Levenshtein it counts an adjacent transposition (e.g. `gmial` vs
  /// `gmail`) as a single edit, which matches how people mistype domains.
  static int _distance(String a, String b) {
    final n = a.length;
    final m = b.length;
    final d = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = 0; i <= n; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= m; j++) {
      d[0][j] = j;
    }
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        var v = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost]
            .reduce((x, y) => x < y ? x : y);
        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
          final transposed = d[i - 2][j - 2] + 1;
          if (transposed < v) v = transposed;
        }
        d[i][j] = v;
      }
    }
    return d[n][m];
  }

  /// Returns a close known domain within edit distance 1, or null.
  static String? _closeDomain(String domain) {
    if (_knownDomains.contains(domain)) return null;
    for (final known in _knownDomains) {
      if (_distance(domain, known) == 1) return known;
    }
    return null;
  }

  /// Validates [input]. On success returns [Valid] (with a typo [Suggestion]
  /// when the domain is a near-miss of a popular provider).
  static ValidationResult validate(String input) {
    final s = normalize(input);
    if (s.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.emailEmpty, 'Email is empty.')]);
    }
    final at = '@'.allMatches(s).length;
    if (at == 0) {
      return const Invalid(
          [ValidationIssue(IssueCode.emailMissingAt, 'Missing @.')]);
    }
    if (at > 1) {
      return const Invalid(
          [ValidationIssue(IssueCode.emailMultipleAt, 'Multiple @.')]);
    }
    final i = s.indexOf('@');
    final local = s.substring(0, i);
    final domain = s.substring(i + 1);
    if (local.isEmpty || !_local.hasMatch(local)) {
      return const Invalid(
          [ValidationIssue(IssueCode.emailEmptyLocal, 'Bad local part.')]);
    }
    if (!_domain.hasMatch(domain)) {
      return const Invalid(
          [ValidationIssue(IssueCode.emailBadDomain, 'Bad domain.')]);
    }
    final close = _closeDomain(domain);
    return Valid(s,
        suggestions: close == null
            ? const []
            : [Suggestion('$local@$close', 'typo-domain')]);
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input) => validate(input) is Valid;
}
```

- [ ] **Step 4: Add export to barrel**

In `lib/input_validator.dart` add: `export 'src/email/email.dart';`

- [ ] **Step 5: Run tests to verify they pass**

Run: `dart test test/email_test.dart && dart analyze`
Expected: PASS (5 tests), `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/email lib/input_validator.dart test/email_test.dart
git commit -m "Add email validation, normalization and offline typo hints"
```

---

### Task 6: Phone type (E.164 + DACH parsing and formatting)

**Files:**
- Create: `lib/src/phone/phone.dart`
- Modify: `lib/input_validator.dart`
- Test: `test/phone_test.dart`

**Interfaces:**
- Consumes: `Country`, common result model.
- Produces: `class Phone` with `static bool isValid(String, {Country? country})`, `static ValidationResult validate(String, {Country? country})` (Valid.normalized is E.164), `static String normalize(String, {Country? country})`, `static String format(String, {Country? country, bool international = true})` / `static String? tryFormat(...)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/phone_test.dart
import 'package:input_validator/src/common/country.dart';
import 'package:input_validator/src/common/issue_code.dart';
import 'package:input_validator/src/common/validation_result.dart';
import 'package:input_validator/src/phone/phone.dart';
import 'package:test/test.dart';

void main() {
  test('accepts an E.164 number', () {
    expect(Phone.isValid('+436601234567'), isTrue);
  });

  test('parses a national AT number with a country hint', () {
    expect(Phone.normalize('0660 1234567', country: Country.at),
        '+436601234567');
  });

  test('rejects a national number without a country hint', () {
    final r = Phone.validate('0660 1234567');
    expect((r as Invalid).issues.first.code, IssueCode.phoneAmbiguousCountry);
  });

  test('rejects letters', () {
    final r = Phone.validate('+49 ABC');
    expect((r as Invalid).issues.first.code, IssueCode.phoneBadChars);
  });

  test('formats international by default', () {
    expect(Phone.format('+436601234567'), '+43 660 1234567');
  });

  test('formats national when asked', () {
    expect(Phone.format('+436601234567', international: false),
        '0660 1234567');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/phone_test.dart`
Expected: FAIL — `phone.dart` missing.

- [ ] **Step 3: Create `lib/src/phone/phone.dart`**

```dart
import '../common/country.dart';
import '../common/issue_code.dart';
import '../common/validation_result.dart';

/// Validation, normalization (to E.164) and formatting of phone numbers.
///
/// International scope is E.164 syntax only; national parsing and pretty
/// formatting are provided for DACH (DE/AT/CH). See `doc/algorithms.md`.
class Phone {
  Phone._();

  /// Calling code -> country for the DACH set.
  static const Map<String, Country> _byCallingCode = {
    '49': Country.de,
    '43': Country.at,
    '41': Country.ch,
  };

  /// National-number length bounds (subscriber digits, excluding country code).
  static const Map<Country, (int, int)> _natLen = {
    Country.de: (6, 11),
    Country.at: (7, 11),
    Country.ch: (9, 9),
  };

  static String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  /// Validates [input], returning [Valid] with the E.164 normalized form.
  static ValidationResult validate(String input, {Country? country}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.phoneEmpty, 'Phone is empty.')]);
    }
    if (RegExp(r'[A-Za-z]').hasMatch(trimmed)) {
      return const Invalid(
          [ValidationIssue(IssueCode.phoneBadChars, 'Contains letters.')]);
    }
    if (!RegExp(r'^\+?[0-9\s\-/().]+$').hasMatch(trimmed)) {
      return const Invalid(
          [ValidationIssue(IssueCode.phoneBadChars, 'Bad characters.')]);
    }

    String cc;
    String national;
    if (trimmed.startsWith('+')) {
      final d = _digits(trimmed);
      cc = _byCallingCode.keys.firstWhere(d.startsWith, orElse: () => '');
      if (cc.isEmpty) {
        return const Invalid([
          ValidationIssue(IssueCode.phoneUnknownCountry, 'Unknown country.')
        ]);
      }
      national = d.substring(cc.length);
    } else {
      if (country == null) {
        return const Invalid([
          ValidationIssue(
              IssueCode.phoneAmbiguousCountry, 'Country required.')
        ]);
      }
      cc = country.callingCode;
      var d = _digits(trimmed);
      if (d.startsWith('0')) d = d.substring(1); // national trunk prefix
      national = d;
    }

    final resolved = _byCallingCode[cc]!;
    final (min, max) = _natLen[resolved]!;
    if (national.length < min) {
      return const Invalid(
          [ValidationIssue(IssueCode.phoneTooShort, 'Too short.')]);
    }
    if (national.length > max) {
      return const Invalid(
          [ValidationIssue(IssueCode.phoneTooLong, 'Too long.')]);
    }
    return Valid('+$cc$national');
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

  /// Formats [input] internationally (`+43 660 1234567`) or nationally
  /// (`0660 1234567`) when [international] is false. Throws [FormatException].
  static String format(String input,
      {Country? country, bool international = true}) {
    final e164 = normalize(input, country: country);
    final d = e164.substring(1);
    final cc = _byCallingCode.keys.firstWhere(d.startsWith);
    final national = d.substring(cc.length);
    final area = national.substring(0, national.length >= 3 ? 3 : 1);
    final rest = national.substring(area.length);
    return international ? '+$cc $area $rest' : '0$area $rest';
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
}
```

- [ ] **Step 4: Add export to barrel**

In `lib/input_validator.dart` add: `export 'src/phone/phone.dart';`

- [ ] **Step 5: Run tests to verify they pass**

Run: `dart test test/phone_test.dart && dart analyze`
Expected: PASS (6 tests), `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/src/phone lib/input_validator.dart test/phone_test.dart
git commit -m "Add phone validation (E.164 + DACH) and formatting"
```

---

### Task 7: Shared JSON vector runner

Turn the shared behavior data into an executable conformance suite. A future npm port loads the same JSON files.

**Files:**
- Create: `test/vectors/email.json`, `phone.json`, `url.json`, `iban.json`, `credit_card.json`
- Create: `test/vectors_test.dart`

**Interfaces:**
- Consumes: all five type classes.
- Produces: an executable check that every case in `test/vectors/*.json` matches the implementation. Case schema (fields optional except `input`): `{"input": str, "isValid": bool, "normalized": str, "format": str, "code": str, "country": "de"|"at"|"ch", "international": bool}`.

- [ ] **Step 1: Write the vector files (behavior spec)**

`test/vectors/credit_card.json`:

```json
[
  {"input": "4111 1111 1111 1111", "isValid": true, "normalized": "4111111111111111", "format": "4111 1111 1111 1111"},
  {"input": "378282246310005", "isValid": true, "format": "3782 822463 10005"},
  {"input": "4111111111111112", "isValid": false, "code": "cardBadLuhn"},
  {"input": "", "isValid": false, "code": "cardEmpty"}
]
```

`test/vectors/iban.json`:

```json
[
  {"input": "AT61 1904 3002 3457 3201", "isValid": true, "normalized": "AT611904300234573201", "format": "AT61 1904 3002 3457 3201"},
  {"input": "DE89 3704 0044 0532 0130 00", "isValid": true, "normalized": "DE89370400440532013000"},
  {"input": "AT611904300234573200", "isValid": false, "code": "ibanBadChecksum"},
  {"input": "DE8937040044053201", "isValid": false, "code": "ibanBadLength"}
]
```

`test/vectors/url.json`:

```json
[
  {"input": "example.com", "isValid": true, "normalized": "https://example.com", "format": "example.com"},
  {"input": "https://www.example.com/", "isValid": true, "format": "example.com"},
  {"input": "localhost", "isValid": false, "code": "urlBadHost"},
  {"input": "ftp://example.com", "isValid": false, "code": "urlBadScheme"}
]
```

`test/vectors/email.json`:

```json
[
  {"input": "a.b+tag@example.com", "isValid": true, "normalized": "a.b+tag@example.com"},
  {"input": "  A@B.COM ", "isValid": true, "normalized": "a@b.com"},
  {"input": "ab.com", "isValid": false, "code": "emailMissingAt"},
  {"input": "@example.com", "isValid": false, "code": "emailEmptyLocal"}
]
```

`test/vectors/phone.json`:

```json
[
  {"input": "+436601234567", "isValid": true, "normalized": "+436601234567", "format": "+43 660 1234567"},
  {"input": "+436601234567", "international": false, "isValid": true, "format": "0660 1234567"},
  {"input": "0660 1234567", "country": "at", "isValid": true, "normalized": "+436601234567"},
  {"input": "0660 1234567", "isValid": false, "code": "phoneAmbiguousCountry"},
  {"input": "+49 ABC", "isValid": false, "code": "phoneBadChars"}
]
```

- [ ] **Step 2: Write the runner (failing until it loads real files)**

```dart
// test/vectors_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:input_validator/input_validator.dart';
import 'package:test/test.dart';

Country? _country(String? s) => switch (s) {
      'de' => Country.de,
      'at' => Country.at,
      'ch' => Country.ch,
      _ => null,
    };

String? _codeOf(ValidationResult r) =>
    r is Invalid ? r.issues.first.code.name : null;

void _check(
  String name,
  Map<String, Object?> c,
  ValidationResult Function() validate,
  String Function() format,
) {
  final input = c['input'];
  test('$name: $input', () {
    final r = validate();
    if (c.containsKey('isValid')) {
      expect(r is Valid, c['isValid'], reason: 'isValid for $input');
    }
    if (c.containsKey('code')) {
      expect(_codeOf(r), c['code'], reason: 'code for $input');
    }
    if (c.containsKey('normalized')) {
      expect((r as Valid).normalized, c['normalized']);
    }
    if (c.containsKey('format')) {
      expect(format(), c['format']);
    }
  });
}

List<Map<String, Object?>> _load(String file) =>
    (jsonDecode(File('test/vectors/$file').readAsStringSync()) as List)
        .cast<Map<String, Object?>>();

void main() {
  group('credit_card', () {
    for (final c in _load('credit_card.json')) {
      final input = c['input']! as String;
      _check('credit_card', c, () => CreditCard.validate(input),
          () => CreditCard.format(input));
    }
  });

  group('iban', () {
    for (final c in _load('iban.json')) {
      final input = c['input']! as String;
      _check('iban', c, () => Iban.validate(input), () => Iban.format(input));
    }
  });

  group('url', () {
    for (final c in _load('url.json')) {
      final input = c['input']! as String;
      _check('url', c, () => Url.validate(input), () => Url.format(input));
    }
  });

  group('email', () {
    for (final c in _load('email.json')) {
      final input = c['input']! as String;
      _check('email', c, () => Email.validate(input), () => input);
    }
  });

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
    }
  });
}
```

- [ ] **Step 3: Run to verify it passes**

Run: `dart test test/vectors_test.dart`
Expected: PASS (all vector cases across the five groups).

- [ ] **Step 4: Run the full suite**

Run: `dart test && dart analyze`
Expected: PASS (all tests), `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add test/vectors test/vectors_test.dart
git commit -m "Add shared JSON test vectors and conformance runner"
```

---

### Task 8: Documentation and optional vector generator

**Files:**
- Create: `README.md`, `doc/algorithms.md`, `tool/gen_vectors.py`
- Modify: `CHANGELOG.md` (mark released set)

**Interfaces:**
- Consumes: the finished public API.
- Produces: user-facing docs. No code behavior change.

- [ ] **Step 1: Write `README.md`**

Include: one-paragraph intro; install snippet (`dart pub add input_validator`); a copy-paste example per type (reuse the examples from the spec's "Öffentliche API" section); a feature/country matrix (five types × operations; DACH note); "zero dependencies" and Apache-2.0 statements; a "how behavior is pinned" paragraph pointing at `test/vectors/`.

- [ ] **Step 2: Write `doc/algorithms.md`**

Document, with a short worked example each: the Luhn checksum (credit card), the Mod-97 IBAN checksum with the 7-digit chunking, E.164 structure and the national trunk-prefix rule, and the optimal-string-alignment (Damerau) distance-1 typo heuristic for email domains.

- [ ] **Step 3: Write `tool/gen_vectors.py`**

A standalone Python 3 script (no third-party imports) that prints/writes valid sample data used to author vectors: compute a Luhn check digit for a given prefix, compute IBAN check digits (Mod-97) for a given country + BBAN, and emit E.164 examples. Header comment states it is a dev-only helper, not part of the package.

- [ ] **Step 4: Verify docs render and links resolve**

Run: `dart doc --dry-run 2>&1 | tail -5`
Expected: no missing-file or broken-reference errors.

- [ ] **Step 5: Final full check**

Run: `dart test && dart analyze && dart format --output=none --set-exit-if-changed .`
Expected: all tests PASS, `No issues found!`, formatting clean.

- [ ] **Step 6: Commit**

```bash
git add README.md doc/algorithms.md tool/gen_vectors.py CHANGELOG.md
git commit -m "Add README, algorithm docs and vector generator tool"
```

---

## Self-Review Notes

- **Spec coverage:** all five types (Tasks 2–6), common result model (Task 1), shared JSON vectors + native runner + "no external driver" (Task 7), Python only as non-shipped generator (Task 8), DACH scope (Tasks 3/6), Apache-2.0 + zero deps (Tasks 0/8), dartdoc + `doc/` (all tasks + Task 8). No gaps found.
- **Type consistency:** `validate`/`isValid`/`normalize`/`format`/`tryFormat` signatures match across tasks; `IssueCode` names used in tests match Task 1's enum; `Country` accessors (`callingCode`, `iso2`) match Task 6 usage; vector `code` strings equal `IssueCode.name`.
- **Placeholders:** none — every code step ships complete code; doc steps (Task 8) specify exact required content.
