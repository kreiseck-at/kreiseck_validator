# input_validator

A small, zero-dependency Dart package for validating, normalizing and
pretty-formatting the kind of user input almost every app collects:
email addresses, phone numbers, URLs, IBANs and credit-card numbers.
Every type follows the same four-operation pattern (`isValid` /
`validate` / `normalize` / `format`), and country-specific behavior
(phone national formats, IBAN length) covers the DACH region
(Germany, Austria, Switzerland).

## Install

```bash
dart pub add input_validator
```

```dart
import 'package:input_validator/input_validator.dart';
```

## Quick examples

### Email

```dart
Email.isValid('a@b.com');           // true
Email.normalize(' A@B.com ');       // 'a@b.com'

final result = Email.validate('a@gmial.com');
switch (result) {
  case Valid(:final normalized, :final suggestions):
    print(normalized);              // 'a@gmial.com'
    print(suggestions.first.value); // 'a@gmail.com' (offline typo hint)
  case Invalid(:final issues):
    print(issues.first.code);
}
```

### Phone

```dart
Phone.isValid('+43 660 1234567');                    // true
Phone.normalize('0660 1234567', country: Country.at); // '+436601234567'
Phone.format('06601234567', country: Country.at);     // '+43 660 1234567'
Phone.format('+436601234567', international: false);  // '0660 1234567'
```

National input (no `+`, no country code) requires the `country:`
argument; without it, `validate` returns
`Invalid` with `IssueCode.phoneAmbiguousCountry`.

### Url

```dart
Url.isValid('example.com');                   // true
Url.normalize('Example.com/path/');           // 'https://example.com/path'
Url.format('https://www.example.com/');       // 'example.com'
```

### Iban

```dart
Iban.isValid('AT61 1904 3002 3457 3201');     // true
Iban.normalize('at611904300234573201');       // 'AT611904300234573201'
Iban.format('AT611904300234573201');          // 'AT61 1904 3002 3457 3201'
```

### CreditCard

```dart
CreditCard.isValid('4111 1111 1111 1111');    // true
CreditCard.normalize('4111-1111-1111-1111');  // '4111111111111111'
CreditCard.format('378282246310005');         // '3782 822463 10005' (Amex 4-6-5)
CreditCard.network('4111111111111111');       // CardNetwork.visa
```

All `format`/`normalize` calls throw `FormatException` on invalid
input; use `tryFormat` for a null-returning variant instead of a
try/catch.

## Feature matrix

| Type         | isValid | validate | normalize | format | tryFormat | Country scope |
|--------------|:-------:|:--------:|:---------:|:------:|:---------:|----------------|
| `Email`        | yes | yes | yes | – (display = normalized form) | – | none; offline typo suggestions only |
| `Phone`        | yes | yes | yes | yes | yes | DACH (DE/AT/CH) only: recognizes the `+49`/`+43`/`+41` calling codes and DACH national formats; any other calling code is `Invalid(phoneUnknownCountry)` |
| `Url`          | yes | yes | yes | yes | yes | none (scheme/host/TLD plausibility is global) |
| `Iban`         | yes | yes | yes | yes | yes | DACH (DE/AT/CH): checksum + exact length; other countries: checksum only, no length guarantee |
| `CreditCard`   | yes | yes | yes | yes | yes | none (Luhn + network detection is global) |

`Email` has no `format`/`tryFormat`: its normalized form (trimmed,
lower-cased) already is the display form.

## Zero dependencies, Apache-2.0

`input_validator` has **zero runtime dependencies** — every algorithm
(Luhn, Mod-97, E.164 parsing, the typo-distance heuristic) is
hand-written in `lib/`. It is licensed under **Apache-2.0** (see
`LICENSE`).

## How behavior is pinned (cross-language)

The exact expected result of every `isValid`/`validate`/`normalize`/
`format` call for representative inputs is captured once, as data, in
the language-independent JSON files under `test/vectors/` (one file
per type). `test/vectors_test.dart` is the thin Dart runner that loads
those vectors and checks this package against them. A planned npm
port is meant to load the very same JSON files with its own thin
runner, so the two implementations can't quietly drift apart — the
vectors, not either runner, are the source of truth for behavior.
See `doc/algorithms.md` for how the checksums and heuristics behind
those vectors work, and `tool/gen_vectors.py` (a dev-only helper, not
shipped with the package) for how sample check digits were computed
while authoring them.
