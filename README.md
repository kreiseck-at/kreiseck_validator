<p align="center">
  <img src="doc/kreiseck_logo.png" alt="Kreiseck — Software Solutions" width="300">
</p>

<h1 align="center">kreiseck_validator</h1>

<p align="center">
  <b>Validate, normalize and pretty-format the input every app collects —<br>
  email, phone, URL, host, IBAN, credit-card, license plate, IMEI, ICCID, MAC address,
  VIN and postal code — in a few lines of Dart.</b><br>
  Zero dependencies. Hand-written algorithms. DACH-aware.
</p>

<p align="center">
  <a href="https://pub.dev/packages/kreiseck_validator"><img src="https://img.shields.io/pub/v/kreiseck_validator?color=930C0C&label=pub" alt="pub version"></a>
  <a href="https://pub.dev/packages/kreiseck_validator/score"><img src="https://img.shields.io/pub/points/kreiseck_validator?color=930C0C" alt="pub points"></a>
  <a href="https://pub.dev/packages/kreiseck_validator/score"><img src="https://img.shields.io/pub/likes/kreiseck_validator?color=930C0C" alt="pub likes"></a>
  <img src="https://img.shields.io/badge/dependencies-0-930C0C" alt="zero dependencies">
  <img src="https://img.shields.io/badge/license-Apache--2.0-930C0C" alt="Apache-2.0 license">
  <a href="https://kreiseck.com"><img src="https://img.shields.io/badge/by-Kreiseck-111111" alt="by Kreiseck"></a>
</p>

---

`kreiseck_validator` is a small, **zero-dependency Dart package** for **validating**,
**normalizing** and **formatting** the kinds of user input almost every app collects:
**email addresses, phone numbers, URLs/domains, hosts, IBANs, credit-card numbers, license
plates, IMEIs, ICCIDs, MAC addresses, VINs and postal codes**. Every type follows the
same four-operation API — `isValid`, `validate`, `normalize`, `format` — so once you
learn one, you know them all.

It is built and maintained by **[Kreiseck Software Solutions](https://kreiseck.com)**, an
Austrian software company. Every algorithm (Luhn, IBAN Mod-97, E.164 phone parsing, an
offline typo-distance heuristic) is hand-written in pure Dart — **no third-party
dependencies, no network calls, no telemetry.**

## ✨ Features

- 📧 **Email** — pragmatic syntax validation, `trim` + lower-case normalization, and an
  **offline typo-domain suggestion** (`user@gmial.com` → suggests `user@gmail.com`, no DNS lookup)
- ☎️ **Phone** — **E.164** validation, normalization and national ↔ international formatting
  for **every country** (libphonenumber-derived metadata), tolerant of `+43 (0)…` business-card
  notation, plus Austrian number-**type** classification (mobile, landline, VoIP, …)
- 🔗 **URL / Domain** — scheme/host/TLD plausibility check (accepts `:port`, `?query`,
  `#fragment`), canonical normalization, and a compact display form (`https://www.example.com/` → `example.com`)
- 🖧 **Host** — a bare hostname (RFC 1123), IPv4 or IPv6 address with an optional port,
  classified and parsed into a `HostInfo`; more lenient than `Url` (no scheme required,
  accepts `localhost` and IP literals)
- 🏦 **IBAN** — **ISO 13616 Mod-97** checksum, per-country length checks, pretty
  4-group formatting, and **`parse`** into an `IbanInfo` (country, bank/branch/
  account codes; **Austrian, German and Swiss bank name + BIC** from bundled
  OeNB / Bundesbank / SIX snapshots); per-country **format descriptors + example
  IBANs** via `IbanCountry`
- 💳 **Credit card** — **Luhn** checksum, network detection (Visa / Mastercard / Amex / Discover),
  network-aware grouping (Amex `4-6-5`, else `4-4-4-4`)
- 🚘 **License plate** — grammar + region-table validation for **Austria, Germany,
  Switzerland, Croatia and Turkey**, plus **`parse`** into a `PlateInfo` (district/canton/
  province code, official region name, serial) with best-effort special-plate
  **classification** (diplomatic, authority, military, historic, electric, …)
- 📱 **IMEI** — **Luhn** checksum over the 15-digit device identifier, plus **`parse`**
  into an `ImeiInfo` (TAC, serial number, check digit, reporting-body identifier); the
  opt-in `allowSv` option additionally accepts a 16-digit **IMEISV** (no Luhn), exposing
  its 2-digit software version via `softwareVersion`
- 💳 **ICCID** — SIM card identifier (ITU-T E.118): MII + Luhn check on 20-digit cards
  (19-digit cards carry no check digit), plus **`parse`** resolving the issuing
  **country** from the embedded E.164 calling code
- 🔌 **MAC address** — EUI-48/64 hardware addresses in **colon, hyphen, Cisco-dot and
  bare** notation, format conversion between them, and **`parse`** exposing
  unicast/multicast and universal/local bits plus the OUI/NIC split
- 🚗 **VIN** — ISO 3779 structure validation (17-char charset, `I`/`O`/`Q` forbidden),
  plus **`parse`** into a `VinInfo` with the ISO check-digit result and the decoded
  **model year** (e.g. `Vin.parse('1HGCM82633A004352')!.modelYear` → `2003`)
- 📮 **Postal code** — curated per-country pattern table for **Europe + Turkey**
  (51 countries), canonical spacing (`1234AB` → `1234 AB`, `00950` → `00-950`, …) and
  **`parse`** into a `PostalInfo`
- 🧱 **One consistent API** — `isValid` / `validate` / `normalize` / `format` (+ `tryFormat`) on every type
- 🪶 **Zero dependencies** · **Apache-2.0** · **null-safe** · works on **all Dart & Flutter platforms**

## 📦 Install

```bash
dart pub add kreiseck_validator
```

```dart
import 'package:kreiseck_validator/kreiseck_validator.dart';
```

## 🚀 Quick start

### 📧 Email

```dart
Email.isValid('a@b.com');           // true
Email.normalize(' A@B.com ');       // 'a@b.com'

final result = Email.validate('user@gmial.com');
switch (result) {
  case Valid(:final normalized, :final suggestions):
    print(normalized);              // 'user@gmial.com'
    print(suggestions.first.value); // 'user@gmail.com'  (offline typo hint)
  case Invalid(:final issues):
    print(issues.first.code);       // e.g. IssueCode.emailMissingAt
}
```

### ☎️ Phone

```dart
Phone.isValid('+43 660 1234567');                     // true
Phone.normalize('0660 1234567', country: Country.at); // '+436601234567'
Phone.normalize('+43 (0) 660 1234567');               // '+436601234567'
Phone.format('06601234567', country: Country.at);     // '+43 660 1234567'
Phone.format('+436601234567', international: false);   // '0660 1234567'

Phone.type('+43 664 1234567');                    // PhoneNumberType.mobile
Phone.type('0662 123456', country: Country.at);   // PhoneNumberType.landline (not mobile!)

final info = Phone.parse('0316 123456', country: Country.at);
info?.type;           // PhoneNumberType.landline
info?.national;       // '0316 123456'    (area-code-aware spacing)
info?.international;  // '+43 316 123456'
```

National input (no `+`, no country code) requires the `country:` argument; without it,
`validate` returns `Invalid` with `IssueCode.phoneAmbiguousCountry`. Validation and
national/international formatting cover **every country**, driven by
libphonenumber-derived metadata (see [`doc/algorithms.md`](doc/algorithms.md) for the
formatter's grouping rules and its documented limitations). For **Austria** specifically,
`Phone.format` also spaces the geographic area code correctly (e.g. `01 …` Vienna,
`0316 …` Graz), derived from the public RTR numbering plan.

`Phone.type`/`Phone.parse` classify Austrian numbers into `PhoneNumberType` (mobile,
landline, voip, freephone, sharedCost, premium, corporate) from the same RTR numbering
plan; this **type classification is Austria-only** — for every other country `type` is
always `PhoneNumberType.unknown`. It classifies the number's **type**, not its current
operator: number portability means a prefix no longer reliably identifies the carrier.

### 🌍 Global phone support

`Phone` and `Country` cover **every country**, not just DACH — `Country` exposes a
flag emoji and synthetic example numbers for every one of them, derived from
libphonenumber metadata (see [NOTICE](NOTICE)):

```dart
final fr = Country.fromIso2('FR')!;
print('${fr.displayName} ${fr.flag}: ${fr.exampleInternational}');
// France 🇫🇷: +33 6 12 34 56 78

print(Phone.format('+33612345678'));
// +33 6 12 34 56 78
print(Phone.format('+33612345678', international: false));
// 06 12 34 56 78
```

`Country.values` enumerates all supported countries; `Country.fromCallingCode('1')`
resolves a shared calling code (e.g. NANP `+1`) to its **main region** (US), so a
structurally valid Canadian number is still validated and formatted correctly but
attributed to the US `Country`. Three regions without a distinct ISO country name
(`AC`, `TA`, `XK`) fall back to their ISO2 code as `displayName`.

### 🔗 URL

```dart
Url.isValid('example.com');                   // true
Url.isValid('example.com:8080');              // true
Url.normalize('Example.com/path/');           // 'https://example.com/path'
Url.format('https://www.example.com/');       // 'example.com'
```

### 🖧 Host

```dart
Host.isValid('example.com:8080');             // true
Host.isValid('[2001:db8::1]:443');            // true

final h = Host.parse('[::1]:8080')!;
h.type; // HostType.ipv6
h.port; // 8080
```

`Host` classifies a bare host (no scheme) as a hostname, IPv4 or IPv6 address, trying
IPv4 then IPv6 then hostname in that order. A port is only recognised for IPv6 in the
bracketed form (`[::1]:8080`) — a bare `::1` parses as IPv6 with no port, since a plain
trailing `:port` would be ambiguous with the address's own colons.

### 🏦 IBAN

```dart
Iban.isValid('AT61 1904 3002 3457 3201');     // true
Iban.normalize('at611904300234573201');       // 'AT611904300234573201'
Iban.format('AT611904300234573201');          // 'AT61 1904 3002 3457 3201'

final info = Iban.parse('AT72 1200 0002 3457 3201')!;
info.bankCode; // '12000'
info.bankName; // 'UniCredit Bank Austria AG'
info.bic;      // 'BKAUATWW'

final at = IbanCountry.of('AT')!;
at.length;        // 20
at.bankCodeLength; // 5
at.hasBranchCode;  // false
at.example;        // 'AT61 1904 3002 3457 3201'
```

### 💳 Credit card

```dart
CreditCard.isValid('4111 1111 1111 1111');    // true
CreditCard.normalize('4111-1111-1111-1111');  // '4111111111111111'
CreditCard.format('378282246310005');         // '3782 822463 10005'  (Amex 4-6-5)
CreditCard.network('4111111111111111');       // CardNetwork.visa
```

### 🚘 License plate

```dart
LicensePlate.isValid('W-12345A', country: 'AT');   // true
LicensePlate.format('m ab1234', country: 'DE');    // 'M-AB 1234'

final info = LicensePlate.parse('W-12345A', country: 'AT')!;
info.districtCode; // 'W'
info.region;       // 'Wien'
info.type;         // PlateType.standard
```

Covers **Austria, Germany, Switzerland, Croatia and Turkey** (`country: 'AT' | 'DE' |
'CH' | 'HR' | 'TR'`). Plates have no checksum, so `validate` checks a per-country grammar
plus a curated code → region table; `parse`'s `region` is `null` when the code is
structurally valid but not in the table (AT/DE only — CH/HR/TR require a known code).
`type` classifies special-purpose plates (diplomatic, authority, military, historic,
seasonal, electric, …) on a **best-effort** basis and defaults to `PlateType.standard`
when a country's special forms aren't (yet) identifiable from the plate text alone — see
[`doc/algorithms.md`](doc/algorithms.md).

### 📱 IMEI

```dart
Imei.isValid('353880080078742');   // true (passes the Luhn checksum)

final info = Imei.parse('353880080078742')!;
info.tac;          // '35388008'
info.serialNumber; // '007874'
info.checkDigit;   // '2'
```

Passing `allowSv: true` additionally accepts a 16-digit **IMEISV** (the IMEI plus a
2-digit software version, no Luhn check) on every operation:

```dart
Imei.parse('3538800800787456', allowSv: true)!.softwareVersion; // '56'
```

For a 16-digit IMEISV, `checkDigit` is `null` (IMEISV has no check digit); for a
15-digit IMEI, `softwareVersion` is `null`.

### 💳 ICCID

```dart
Iccid.isValid('8949012345678901234'); // true

final info = Iccid.parse('8949012345678901234')!;
info.mii;     // '89'
info.country; // Country for 'DE' (resolved from the embedded E.164 code)
```

### 🔌 MAC address

```dart
MacAddress.isValid('00:1A:2B:3C:4D:5E');                     // true
MacAddress.normalize('00-1A-2B-3C-4D-5E');                   // '00:1a:2b:3c:4d:5e'
MacAddress.format('00:1A:2B:3C:4D:5E', notation: MacNotation.hyphen); // '00-1a-2b-3c-4d-5e'

final info = MacAddress.parse('00:1A:2B:3C:4D:5E')!;
info.oui;        // '00:1a:2b'
info.isUnicast;  // true
```

### 🚗 VIN

```dart
Vin.isValid('1HGCM82633A004352');            // true (structurally valid)
Vin.parse('1HGCM82633A004352')!.modelYear;   // 2003

final info = Vin.parse('1HGCM82633A004352')!;
info.wmi;               // '1HG'
info.checkDigitValid;   // true
```

`Vin.validate` checks **structure only** (17 chars from the ISO 3779 charset); the
check digit is mandatory only for North American VINs, so its result is exposed via
`parse`'s `checkDigitValid` instead of blocking validation — see
[`doc/algorithms.md`](doc/algorithms.md) for the model-year decode.

### 📮 Postal code

```dart
PostalCode.isValid('1234 AB', country: 'NL');   // true
PostalCode.format('1234ab', country: 'NL');     // '1234 AB'
PostalCode.format('00950', country: 'PL');      // '00-950'
PostalCode.format('sw1a1aa', country: 'GB');    // 'SW1A 1AA'
```

`country` is required (ISO2) — a bare postal code is ambiguous across countries.
Covers **Europe + Turkey** (51 countries) from a curated per-country pattern table;
an unlisted country yields `IssueCode.postalUnknownCountry`.

All `format`/`normalize` calls throw `FormatException` on invalid input, with one
exception: `Email.normalize` doesn't validate at all — it's a pure `trim` + lower-case
transform, so it never throws. Use `tryFormat` for a null-returning variant instead of a
`try`/`catch` on the types that do throw.

## 🧾 The result model

`validate` returns a **sealed** `ValidationResult`, so a `switch` is exhaustive:

```dart
sealed class ValidationResult {}
class Valid   extends ValidationResult { String normalized; List<Suggestion> suggestions; }
class Invalid extends ValidationResult { List<ValidationIssue> issues; }
// ValidationIssue(IssueCode code, String message) — codes are a stable, translatable enum.
```

`isValid(x)` is shorthand for `validate(x) is Valid`. Error **codes** (`IssueCode`) are
stable enums you can switch on and translate; the English `message` is only a default.

## 🧩 Feature matrix

| Type         | isValid | validate | normalize | format | tryFormat | Country scope |
|--------------|:-------:|:--------:|:---------:|:------:|:---------:|----------------|
| `Email`      | ✅ | ✅ | ✅ | – (display = normalized) | – | none; offline typo suggestions only |
| `Phone`      | ✅ | ✅ | ✅ | ✅ | ✅ | every country (libphonenumber-derived); AT-only number-type classification |
| `Url`        | ✅ | ✅ | ✅ | ✅ | ✅ | none (scheme/host/TLD check is global) |
| `Host`       | ✅ | ✅ | ✅ | ✅ | ✅ | none (hostname/IPv4/IPv6 classification is global) |
| `Iban`       | ✅ | ✅ | ✅ | ✅ | ✅ | checksum + per-country length for every registry country; `parse` bank/BIC lookup is AT/DE/CH |
| `CreditCard` | ✅ | ✅ | ✅ | ✅ | ✅ | none (Luhn + network detection is global) |
| `LicensePlate` | ✅ | ✅ | ✅ | ✅ | ✅ | grammar + region-table validation and `parse` for AT/DE/CH/HR/TR |
| `Imei`       | ✅ | ✅ | ✅ | ✅ | ✅ | none (Luhn checksum is global) |
| `Iccid`      | ✅ | ✅ | ✅ | ✅ | ✅ | none for checksum; `parse` country resolution is global (E.164 calling codes) |
| `MacAddress` | ✅ | ✅ | ✅ | ✅ | ✅ | none (EUI-48/64 notation handling is global) |
| `Vin`        | ✅ | ✅ | ✅ | ✅ | ✅ | none (structure + check digit + model year are global, ISO 3779) |
| `PostalCode` | ✅ | ✅ | ✅ | ✅ | ✅ | curated pattern table for Europe + Turkey (51 countries) |

## 🪶 Zero dependencies, Apache-2.0

`kreiseck_validator` has **zero runtime dependencies** — every algorithm (Luhn, Mod-97,
E.164 parsing, the Damerau/OSA typo-distance heuristic) is hand-written in `lib/` and
documented in [`doc/algorithms.md`](doc/algorithms.md). It is licensed under
**Apache-2.0** (see [LICENSE](LICENSE)) — free for commercial and closed-source use, with
patent protection and attribution.

## 🌍 How behavior is pinned (cross-language)

The exact expected result of every operation, for representative inputs, is captured once
**as data** in the language-independent JSON files under `test/vectors/` (one per type).
`test/vectors_test.dart` is a thin Dart runner that checks this package against them. A
planned **npm port** will load the very same JSON files with its own runner, so the two
implementations cannot quietly drift apart — the vectors, not either runner, are the source
of truth for behavior.

## 🧭 About Kreiseck

<p>
  <a href="https://kreiseck.com"><img src="doc/kreiseck_logo.png" alt="Kreiseck Software Solutions" width="180"></a>
</p>

**[Kreiseck Software Solutions](https://kreiseck.com)** is an Austrian software company
building practical tools for developers and businesses — from point-of-sale and payment
systems to open-source developer libraries like this one. We favour **lightweight,
dependency-free, well-documented** code that is easy to audit and easy to trust.

- 🌐 Website — **[kreiseck.com](https://kreiseck.com)**
- ✉️ Contact — **[office@kreiseck.com](mailto:office@kreiseck.com)**
- 💙 If this package saves you time, a **like on [pub.dev](https://pub.dev/packages/kreiseck_validator)** or a ⭐ on GitHub helps others find it.

## 🗂️ Versioning

Semantic versioning — see the [CHANGELOG](CHANGELOG.md).

## 📄 License

Apache-2.0 — see [LICENSE](LICENSE). © 2026 Kreiseck Software Solutions.

---

<p align="center">
  <sub>Made with care by <a href="https://kreiseck.com"><b>Kreiseck Software Solutions</b></a> · Austria 🇦🇹</sub>
</p>
