# @kreiseck/validator

Validate, normalize and format the input every app collects — **email, phone,
URL, IBAN and credit-card** — in a few lines of TypeScript. Zero dependencies,
DACH-aware.

This is the TypeScript/JavaScript port of the
[`kreiseck_validator`](https://pub.dev/packages/kreiseck_validator) Dart
package. Every type follows the same four-operation API — `isValid`,
`validate`, `normalize`, `format` — so once you learn one, you know them all.
Behavior is kept in lockstep with the Dart package via a shared,
language-independent set of test vectors.

## Install

```bash
npm i @kreiseck/validator
```

Works in Node, browser and edge runtimes — zero runtime dependencies, ships
as ESM + CommonJS with full TypeScript types.

## Quick start

### Email

```ts
import { Email } from '@kreiseck/validator';

Email.isValid('a@b.com');          // true
Email.normalize(' A@B.com ');      // 'a@b.com'

const result = Email.validate('user@gmial.com');
if (result.ok) {
  result.normalized;               // 'user@gmial.com'
  result.suggestions[0]?.value;    // 'user@gmail.com'  (offline typo hint)
} else {
  result.issues[0].code;           // e.g. 'emailMissingAt'
}
```

### Phone

```ts
import { Phone } from '@kreiseck/validator';

Phone.isValid('+43 660 1234567');                        // true
Phone.normalize('0660 1234567', { country: 'AT' });      // '+436601234567'
Phone.format('06601234567', { country: 'AT' });          // '+43 660 1234567'
Phone.format('+436601234567', { international: false }); // '0660 1234567'
```

National input (no `+`, no country code) requires the `country` option;
without it, `validate` returns an issue with code `phoneAmbiguousCountry`.
Validation and national/international formatting cover **every country**,
driven by libphonenumber-derived metadata (see the root
[NOTICE](../NOTICE)). `Phone.type`/`Phone.parse` additionally classify
Austrian numbers into mobile/landline/voip/etc. — that classification is
Austria-only; every other country resolves to `'unknown'`.

### URL

```ts
import { Url } from '@kreiseck/validator';

Url.isValid('example.com');               // true
Url.isValid('example.com:8080');          // true
Url.normalize('Example.com/path/');       // 'https://example.com/path'
Url.format('https://www.example.com/');   // 'example.com'
```

### IBAN

```ts
import { Iban, IbanCountry } from '@kreiseck/validator';

Iban.isValid('AT61 1904 3002 3457 3201');    // true
Iban.normalize('at611904300234573201');      // 'AT611904300234573201'
Iban.format('AT611904300234573201');         // 'AT61 1904 3002 3457 3201'

const info = Iban.parse('AT72 1200 0002 3457 3201')!;
info.bankCode;  // '12000'
info.bankName;  // 'UniCredit Bank Austria AG'
info.bic;       // 'BKAUATWW'

const at = IbanCountry.of('AT')!;
at.length;          // 20
at.bankCodeLength;  // 5
at.hasBranchCode;   // false
at.example;         // 'AT61 1904 3002 3457 3201'
```

`Iban.parse`'s structural fields (`bankCode`, `branchCode`,
`accountNumber`) are filled for every country with a known BBAN layout;
`bankName`/`bic` lookup is bundled for Austria, Germany and Switzerland.

### Credit card

```ts
import { CreditCard } from '@kreiseck/validator';

CreditCard.isValid('4111 1111 1111 1111');   // true
CreditCard.normalize('4111-1111-1111-1111'); // '4111111111111111'
CreditCard.format('378282246310005');        // '3782 822463 10005'  (Amex 4-6-5)
CreditCard.network('4111111111111111');      // 'visa'
```

All `format`/`normalize` calls throw `FormatError` on invalid input, with
one exception: `Email.normalize` doesn't validate at all — it's a pure
`trim` + lower-case transform, so it never throws. Use `tryFormat` for a
null-returning variant instead of a `try`/`catch` on the types that do
throw.

## The result model

`validate` returns a discriminated union:

```ts
type ValidationResult =
  | { ok: true; normalized: string; suggestions: Suggestion[] }
  | { ok: false; issues: ValidationIssue[] };
```

`isValid(x)` is shorthand for `validate(x).ok`. Error `code`s (`IssueCode`)
are a stable, translatable string union; the English `message` is only a
default.

## Tree-shaking: import from a subpath

The root import (`from '@kreiseck/validator'`) pulls in every module. If
you only need one, import its subpath instead so bundlers exclude the
rest — e.g. an IBAN-only build won't inline phone metadata:

```ts
import { Iban } from '@kreiseck/validator/iban';
import { Phone } from '@kreiseck/validator/phone';
import { Email } from '@kreiseck/validator/email';
import { Url } from '@kreiseck/validator/url';
import { CreditCard } from '@kreiseck/validator/credit-card';
```

Each subpath ships its own ESM, CommonJS and `.d.ts` build.

## How behavior is pinned across languages

The exact expected result of every operation, for representative inputs,
is captured once as data in the shared, language-independent JSON files
under `test/vectors/` at the repo root. This package's conformance tests
run against the very same vectors as the Dart package, so the two
implementations cannot quietly drift apart.

## License

Apache-2.0 — see [LICENSE](../LICENSE).
