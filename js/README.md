# @kreiseck/validator

Validate, normalize and format the input every app collects — **email, phone,
URL, host, IBAN, credit-card, license plate, IMEI, ICCID, MAC address, VIN and
postal code** — in a few lines of TypeScript. Zero dependencies, DACH-aware.

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

### Host

```ts
import { Host } from '@kreiseck/validator/host';

Host.isValid('example.com:8080');            // true
Host.isValid('[2001:db8::1]:443');           // true

const h = Host.parse('[::1]:8080')!;
h.type; // 'ipv6'
h.port; // 8080
```

`Host` classifies a bare host (no scheme) as a hostname, IPv4 or IPv6 address,
trying IPv4 then IPv6 then hostname in that order. A port is only recognised
for IPv6 in the bracketed form (`[::1]:8080`) — a bare `::1` parses as IPv6
with no port, since a plain trailing `:port` would be ambiguous with the
address's own colons.

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

### License plate

```ts
import { LicensePlate } from '@kreiseck/validator/license-plate';

LicensePlate.isValid('W-12345A', { country: 'AT' });  // true
LicensePlate.format('m ab1234', { country: 'DE' });   // 'M-AB 1234'

const info = LicensePlate.parse('W-12345A', { country: 'AT' })!;
info.districtCode; // 'W'
info.region;       // 'Wien'
info.type;         // 'standard'
```

Covers **Austria, Germany, Switzerland, Croatia and Turkey**
(`country: 'AT' | 'DE' | 'CH' | 'HR' | 'TR'`). Plates have no checksum, so
`validate` checks a per-country grammar plus a curated code → region table;
`parse`'s `region` is `null` when the code is structurally valid but not in
the table (AT/DE only — CH/HR/TR require a known code). `type` classifies
special-purpose plates (diplomatic, authority, military, historic, seasonal,
electric, …) on a **best-effort** basis and defaults to `'standard'` when a
country's special forms aren't (yet) identifiable from the plate text alone.

### IMEI

```ts
import { Imei } from '@kreiseck/validator/imei';

Imei.isValid('353880080078742');   // true (passes the Luhn checksum)

const info = Imei.parse('353880080078742')!;
info.tac;          // '35388008'
info.serialNumber; // '007874'
info.checkDigit;   // '2'
```

Passing `{ allowSv: true }` additionally accepts a 16-digit **IMEISV** (the
IMEI plus a 2-digit software version, no Luhn check) on every operation:

```ts
Imei.parse('3538800800787456', { allowSv: true })!.softwareVersion; // '56'
```

For a 16-digit IMEISV, `checkDigit` is `null` (IMEISV has no check digit);
for a 15-digit IMEI, `softwareVersion` is `null`.

### ICCID

```ts
import { Iccid } from '@kreiseck/validator/iccid';

Iccid.isValid('8949012345678901234'); // true

const info = Iccid.parse('8949012345678901234')!;
info.mii;            // '89'
info.country?.iso2;  // 'DE' (resolved from the embedded E.164 code)
```

### MAC address

```ts
import { MacAddress } from '@kreiseck/validator/mac-address';

MacAddress.isValid('00:1A:2B:3C:4D:5E');                       // true
MacAddress.normalize('00-1A-2B-3C-4D-5E');                     // '00:1a:2b:3c:4d:5e'
MacAddress.format('00:1A:2B:3C:4D:5E', { notation: 'hyphen' }); // '00-1a-2b-3c-4d-5e'

const info = MacAddress.parse('00:1A:2B:3C:4D:5E')!;
info.oui;        // '00:1a:2b'
info.isUnicast;  // true
```

### VIN

```ts
import { Vin } from '@kreiseck/validator/vin';

Vin.isValid('1HGCM82633A004352');          // true (structurally valid)
Vin.parse('1HGCM82633A004352')!.modelYear; // 2003

const info = Vin.parse('1HGCM82633A004352')!;
info.wmi;             // '1HG'
info.checkDigitValid; // true
```

`Vin.validate` checks **structure only** (17 chars from the ISO 3779 charset);
the check digit is mandatory only for North American VINs, so its result is
exposed via `parse`'s `checkDigitValid` instead of blocking validation.

### Postal code

```ts
import { PostalCode } from '@kreiseck/validator/postal-code';

PostalCode.isValid('1234 AB', { country: 'NL' }); // true
PostalCode.format('1234ab', { country: 'NL' });   // '1234 AB'
PostalCode.format('00950', { country: 'PL' });    // '00-950'
PostalCode.format('sw1a1aa', { country: 'GB' });  // 'SW1A 1AA'
```

`country` is required (ISO2) — a bare postal code is ambiguous across
countries. Covers **Europe + Turkey** (51 countries) from a curated
per-country pattern table; an unlisted country yields the
`postalUnknownCountry` issue code.

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
import { Host } from '@kreiseck/validator/host';
import { CreditCard } from '@kreiseck/validator/credit-card';
import { LicensePlate } from '@kreiseck/validator/license-plate';
import { Imei } from '@kreiseck/validator/imei';
import { Iccid } from '@kreiseck/validator/iccid';
import { MacAddress } from '@kreiseck/validator/mac-address';
import { Vin } from '@kreiseck/validator/vin';
import { PostalCode } from '@kreiseck/validator/postal-code';
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
