# Algorithms

This page walks through the non-obvious pieces of logic behind
`kreiseck_validator`'s checksums and heuristics, each with a worked
example. The implementations referenced here live in `lib/src/`.

## Luhn checksum (credit card)

Used by `CreditCard.validate` (`lib/src/credit_card/credit_card.dart`)
to catch typos and transposed digits in card numbers.

Starting from the **rightmost** digit and moving left, the rightmost
digit is left as-is, the next one is doubled, the one after that is
left as-is, and so on (alternating). If doubling pushes a digit above
9, subtract 9 (the same as summing its two digits). All digits —
doubled and untouched — are then summed. The number is valid when
that sum is a multiple of 10.

Worked example, `4111111111111111`:

```
digit:      4   1  1  1  1  1  1  1  1  1  1  1  1  1  1  1
position:  16  15 14 13 12 11 10  9  8  7  6  5  4  3  2  1   (from the right)
doubled?    y   n  y  n  y  n  y  n  y  n  y  n  y  n  y  n
value:      8   1  2  1  2  1  2  1  2  1  2  1  2  1  2  1
```

Sum = 8 + 1+2+1+2+1+2+1+2+1+2+1+2+1+2+1 = 30, a multiple of 10, so the
number passes.

**Computing a check digit** works the same way in reverse: given a
number *without* its last digit (the "prefix"), run the same
alternating-doubling sum over the prefix — but shifted by one, since
the prefix's last digit will end up one position to the left of the
final check digit and so is the one that gets doubled first. The check
digit is then whatever brings the total up to the next multiple of 10:
`(10 - sum % 10) % 10`. For prefix `411111111111111` (15 digits) that
check digit is `1`, giving the well-known test number
`4111111111111111` above. `tool/gen_vectors.py`'s `luhn_check_digit`
implements exactly this and is how the vectors in
`test/vectors/credit_card.json` were produced.

The checksum itself lives in a small shared helper, `luhnOk` (Dart:
`lib/src/common/luhn.dart`; TS: `js/src/common/luhn.ts`), extracted so
`Imei.validate` and `Iccid.validate` can reuse the exact same digit-summing
logic instead of duplicating it — `CreditCard`'s own validation behavior is
unchanged by the extraction. `Imei` runs it over all 15 digits (the 15th is
the check digit); `Iccid` runs it only when the ICCID is 20 digits long
(19-digit ICCIDs carry no check digit at all).

**IMEISV** (`Imei`, opt-in via `allowSv: true`): a 16-digit variant that
replaces the 15th Luhn check digit with a 2-digit software version number
(SVN), so the last two digits of a 16-digit input are never Luhn-checked —
by definition IMEISV carries no check digit at all. With `allowSv: true`,
a 15-digit input still runs the ordinary Luhn check above; a 16-digit input
skips it entirely and is accepted purely on length and digit shape. `parse`
splits a 16-digit value into `tac` (first 8), `serialNumber` (next 6) and
`softwareVersion` (last 2), leaving `checkDigit` `null`; a 15-digit value
keeps `checkDigit` populated and leaves `softwareVersion` `null`. With the
default `allowSv: false`, a 16-digit input is rejected as `imeiBadLength`,
exactly as before this option existed.

## Mod-97 checksum (IBAN)

Used by `Iban.validate` (`lib/src/iban/iban.dart`) to verify the two
check digits mandated by ISO 13616.

Algorithm, given a full IBAN string (country code + check digits +
BBAN):

1. Move the first four characters (country code + check digits) to the
   **end** of the string.
2. Replace every letter with its numeric value: `A` = 10, `B` = 11, …
   `Z` = 35 (so each letter becomes two digits).
3. Interpret the resulting digit string as one big integer and compute
   it **mod 97**. Because that integer can be far larger than fits a
   64-bit int, it is reduced incrementally: process it in chunks of at
   most 7 digits at a time, carrying the running remainder into the
   next chunk (`remainder = int('$remainder$chunk') % 97`) — this
   never lets the intermediate value overflow while still producing
   the exact same result as computing the mod of the whole number at
   once.
4. The IBAN is valid exactly when the final remainder is `1`.

Worked example, `AT611904300234573201`:

- Rearranged (BBAN + country + check): `1904300234573201` + `AT61`
  = `1904300234573201AT61`
- Letters to digits (`A` = 10, `T` = 29): `AT61` → `10` `29` `61`,
  giving the full numeric string `1904300234573201102961` (22 digits).
- Reduce mod 97 in 7-digit chunks, carrying the remainder forward:

  ```
  chunk 1: 1904300            -> 1904300 % 97 = 93
  chunk 2: "93" + 2345732      -> 932345732 % 97 = 65
  chunk 3: "65" + 0110296      -> 650110296 % 97 = 0
  chunk 4: "0"  + 1            -> 1 % 97 = 1
  ```

- Final remainder is `1`, so the IBAN is valid.

**Computing check digits** for a new IBAN runs the same idea forwards:
place provisional check digits `00`, rearrange as `BBAN + country +
"00"`, convert to digits, take mod 97, and the real check digits are
`98 - remainder` (zero-padded to two digits). `tool/gen_vectors.py`'s
`iban_check_digits('AT', '1904300234573201')` returns `'61'`,
reproducing the example above.

**Structural parsing** (`Iban.parse`, returning an `IbanInfo`) splits the
compact IBAN into bank/branch/account codes using `kIbanBban`
(`lib/src/iban/iban_metadata.g.dart`), a per-country table of BBAN field
offsets sourced from the SWIFT IBAN Registry. Those offsets are absolute
indices into the full IBAN string, so every offset from the registry's
BBAN-relative layout is shifted by 4 to account for the leading country
code and check digits (e.g. Germany's bank code, positions 0-7 within the
BBAN, becomes `bankStart: 4, bankEnd: 12`). For Austrian, German and Swiss
IBANs, `parse` additionally looks up the extracted bank code in `kBanks`, a
country-keyed table to fill in the bank's registered name and BIC: Austrian
lookups use the 5-digit BLZ against a snapshot of the OeNB (Oesterreichische
Nationalbank) SEPA directory; German lookups use the 8-digit BLZ against the
Deutsche Bundesbank Bankleitzahlen directory, restricted to its head-office
rows; Swiss lookups use the 5-digit, zero-padded BC number against the SIX
Bank Master published by SIX Interbank Clearing. Other countries, and
unrecognized bank codes, leave those two fields `null`.

**Per-country format descriptors** (`IbanCountry`, backed by the same
`kIbanBban` table) carry, alongside the field lengths, one valid `example`
IBAN per country. For Austria, Germany and Switzerland this is the
respective country's canonical, publicly documented example IBAN. For every
other country there is no well-known example to fall back on, so one is
built deterministically from the SWIFT registry's `bban_spec`: each `n`
(digit), `a` (letter) or `c` (alphanumeric) run in the spec is filled with a
fixed, repeating pattern (`1234567890`, `A`-`Z`, or `ABCDEFGHIJ0123456789`
respectively), then the two check digits are computed for that BBAN with
the same Mod-97 procedure used everywhere else in this package, so every
generated example passes `Iban.validate`.

## E.164 structure and the national trunk prefix

`Phone.validate`/`normalize` (`lib/src/phone/phone.dart`) accept
either:

- **International (E.164) input**, starting with `+`: `+` followed by
  a country calling code (e.g. `49` = Germany, `43` = Austria, `1` =
  US/Canada) and the national subscriber number, with no leading zero
  — e.g. `+436601234567`.
- **National input**, written the way a local caller would dial it
  domestically, typically with a leading `0` **trunk prefix** — e.g.
  Austrian `0660 1234567` (not every country has one; the trunk prefix
  itself, when present, comes from that country's metadata — see
  "Phone metadata" below). That leading `0` is a dialing convention,
  not part of the number itself, and must be dropped when converting
  to E.164. Because a national number on its own doesn't say which
  country it belongs to, callers must pass `country:` explicitly
  (e.g. `Country.at`); omitting it yields
  `Invalid(IssueCode.phoneAmbiguousCountry)`.

Worked example: Austrian national `0660 1234567` with
`country: Country.at` — strip non-digits (`06601234567`), drop the
leading trunk `0` (`6601234567`), prepend the calling code (`43`) with
a `+`: `+436601234567`. Formatting reverses this: `format(...,
international: false)` re-adds a `0` prefix for the readable national
form (`0660 1234567`).

## Phone metadata: uniform validation and formatting

`Phone.validate`/`normalize`/`format` (`lib/src/phone/phone.dart`) work
the same way for **every** country, not just DACH, driven entirely by
per-country data in `Country` (`lib/src/common/country.dart`,
generated into `lib/src/common/country.g.dart`). That data — calling
code, national trunk prefix, possible national-number lengths, a
national-number pattern, format rules and synthetic example numbers —
is derived from Google's [libphonenumber](https://github.com/google/libphonenumber)
(Apache-2.0) by `tool/gen_phone_metadata.py`; see `NOTICE` for the
attribution and the exact source version.

**Validation** is uniform and strict: a national significant number is
accepted only when its length is one of `Country.possibleLengths`
*and* it matches `Country.pattern` in full. A length outside the
allowed set is rejected as too short/too long; a length that's allowed
but a pattern mismatch is rejected as `IssueCode.phoneInvalid` (e.g. a
US number of the right length that starts with a digit no valid US
number starts with).

**Formatting** (`lib/src/phone/phone_format.dart`) applies each
country's ordered list of `PhoneFormat` rules — a regex `pattern` to
match against the national number, an optional `leadingDigits` filter
to pick the right rule when several patterns could match, and a
`format` template (`$1`, `$2`, …) built from the regex's capture
groups. For national (non-international) display, a
`nationalPrefixFormattingRule` (e.g. `0$1`) additionally prepends the
national prefix. This reproduces libphonenumber's national and
international grouping for the large majority of countries.

*Known limitation:* the `nationalPrefixFormattingRule` handling here
is a pragmatic subset — it treats the whole already-grouped number as
`$1`/`$FG`, which reproduces the common case (`0$1`, used by DACH and
most of Europe) but not rules that parenthesize only the *first*
captured group, e.g. Brazil's `($1)` or Russia's `8 ($1)`. For those,
this package's national-form output does not exactly match
libphonenumber's; the generator (`tool/gen_phone_metadata.py`)
deliberately excludes such regions from the cross-language test
vectors rather than asserting a result it can't actually produce.
Carrier codes (`$CC`) are likewise not supported.

*Known limitation:* countries that share a calling code without any
area-code routing data (e.g. NANP `+1`, shared by the US and Canada
among others) all resolve to that calling code's **main region** —
`Country.fromCallingCode('1')` is US — so a structurally valid
Canadian number is validated and formatted, but attributed to the US
`Country`.

*Known limitation:* three libphonenumber regions — `AC`, `TA`, `XK` —
have no corresponding ISO 3166-1 country name and fall back to their
ISO2 code as `displayName` (e.g. `Country.fromIso2('XK')!.displayName
== 'XK'`).

Number-**type** classification (`Phone.type`/`Phone.parse`) is a
separate layer on top of this and, as before, Austria-only — see
below; every other country reports `PhoneNumberType.unknown`.

## Austrian number classification (AT)

`Phone.type`/`Phone.parse` (`lib/src/phone/phone.dart`, delegating to
`lib/src/phone/at_numbering.dart`) classify an Austrian **national
significant number** — the number with the international `+43` or the
national trunk `0` already stripped — into a `PhoneNumberType`. This
is sourced from the public RTR (Rundfunk und Telekom Regulierungs-GmbH)
numbering plan and describes the number's **type**, not its current
operator: number portability means a prefix no longer reliably
identifies the carrier. This classification is **Austria-only**; for
every other country `type` is always `PhoneNumberType.unknown`.
Display **formatting** (national/international grouping), by contrast,
is the generic pattern-driven formatter described in "Phone metadata"
above and applies to AT the same way it applies to every other
country.

`AtNumbering.classify` checks the leading digits of the national
number in five steps, in this order:

1. **Mobile — an explicit 3-digit allow-list, not a range.** The RTR
   mobile block is `650`–`653`, `655`, `657`, `659`–`661`, `663`–`699`,
   with deliberate gaps at `654`, `656`, `658` and `662`. The `662` gap
   matters: `662` is the Salzburg geographic area code, so a number
   like `0662 123456` is a **landline**, even though `662` sits
   numerically inside the `65x`–`69x` mobile span. Checking mobile
   before geographic (and as an allow-list, not a range test) is what
   keeps Salzburg out of the mobile bucket.
2. **Service ranges** — fixed 3-digit prefixes mapped directly to a
   type: `800` → freephone (toll-free), `810`/`820`/`821` →
   shared-cost, `900`/`901`/`930`/`931`/`939` → premium-rate, `720` →
   voip (location-independent).
3. **Geographic — longest-prefix match.** A curated table of area
   codes (Vienna `1`, Graz `316`, Linz `732`, Salzburg `662`,
   Innsbruck `512`, Klagenfurt `463`, and a dozen more regional
   codes, 1–4 digits long) is matched by trying the longest candidate
   prefix first (4, then 3, then 2, then 1 digit) so that, e.g., a
   4-digit code isn't shadowed by an unrelated 1-digit one. A match
   yields `PhoneNumberType.landline` with the matched prefix as the
   display grouping.
4. **Corporate / private networks** — numbers starting `50` or `59`
   that didn't match a known geographic code fall back to
   `PhoneNumberType.corporate` (e.g. `050x`/`059x` corporate ranges).
5. **Approximate geographic fallback.** If nothing above matched but
   the number plausibly starts with a geographic first digit (`2`,
   `3`, `4`, `5`, `6`, `7` or `8`), it's still classified as
   `landline` with an empty (unknown) prefix, rather than giving up.
   This is what catches the many `06xx` regional landlines outside the
   curated table (e.g. Bad Ischl `06132`, Zell am See `06542`); mobile
   `06xx` numbers were already matched by the allow-list in step 1, so
   anything reaching here is geographic. Anything else is
   `PhoneNumberType.unknown`.

`AtClass` also carries a `prefix` (the matched mobile/service/area-code
digits) alongside `type`, but it is used internally only — it is not
currently exposed through `Phone.type`/`Phone.parse`/`PhoneInfo`.
Display grouping for AT numbers comes entirely from the generic
pattern-driven formatter described in "Phone metadata" above, the same
formatter used for every other country.

Source: the RTR public numbering plan
(<https://www.rtr.at/TKP/was_wir_tun/telekommunikation/nummerierung/nummernplaene/nummernplaene.de.html>).
The mobile allow-list, service ranges and curated area-code table
above are a snapshot of that plan and are not exhaustive of every
Austrian area code; unmatched numbers degrade gracefully to the
approximate fallback rather than throwing.

## Optimal string alignment (Damerau) distance-1 email typo heuristic

`Email.validate` (`lib/src/email/email.dart`) never rejects a
syntactically valid address for being "close" to a popular domain —
instead it attaches a non-blocking `Suggestion` when the domain is
exactly **edit distance 1** from a known provider (`gmail.com`,
`outlook.com`, `web.de`, …), using the *optimal string alignment*
(a restricted Damerau-Levenshtein) distance.

Plain Levenshtein distance counts an insertion, deletion or
substitution as one edit each. OSA distance additionally counts an
**adjacent transposition** (swapping two neighboring characters) as a
single edit, rather than two substitutions — which matches how people
actually mistype domains (`gmial.com` for `gmail.com` is one swapped
pair of letters, not two unrelated changes).

Worked example, `gmial` vs. `gmail` (the `.com` suffix is identical in
both and doesn't affect the distance):

- Plain Levenshtein distance is 2, because it has no transposition
  move: turning `gmial` into `gmail` needs one substitution to fix the
  `i`/`a` swap plus one more to fix the position that swap left wrong
  (e.g. substitute `i`→`a` at index 3, then `a`→`i` at index 4).
- OSA distance is 1: the algorithm recognizes `ia` → `ai` as a single
  adjacent-transposition edit instead of two substitutions.

Because the OSA distance is 1, `Email.validate('user@gmial.com')`
returns `Valid('user@gmial.com', suggestions:
[Suggestion('user@gmail.com', 'typo-domain')])` — the input is
accepted as-is (it *is* syntactically a valid email), with a hint
attached rather than an error.

## License-plate grammar and region lookup (no checksum)

Used by `LicensePlate` (`lib/src/license_plate/license_plate.dart`) for
Austrian, German, Swiss, Croatian and Turkish vehicle registration plates.
Unlike the other types on this page, plates carry **no checksum** — there is
no arithmetic to verify. Validation is instead a per-country **grammar**
(a regular expression describing how the district/canton/province code and
the serial part are shaped) plus a lookup against a curated **code → region
table** (`kPlateRegions`, generated by `tool/gen_plate_metadata.py` from the
sources noted in [NOTICE](../NOTICE)).

The two checks are independent: a plate can be structurally well-formed with
a code that isn't in the table (AT and DE tolerate this — `parse` returns a
`null` region, but the plate is still `Valid`), while CH, HR and TR treat
their code sets as closed and small enough (26/34/81 entries) that an
unrecognized code is rejected outright as `plateBadFormat` rather than
accepted with an unresolved region.

`parse`'s `type` (`PlateType`) classification is separate again: a set of
per-country rules over the code and any suffix (e.g. Germany's trailing `H`/
`E` for historic/electric plates, or a nationwide authority code) that map to
`diplomatic`/`authority`/`military`/`temporary`/`seasonal`/`historic`/
`electric`. Classification is **best-effort** and never blocks validation —
a country whose special-plate conventions aren't (yet) reliably
distinguishable from plate text alone (Switzerland, Croatia, Turkey today)
always classifies as `standard` rather than guessing.

## VIN check digit and model-year decode (ISO 3779)

Used by `Vin.parse` (`lib/src/vin/vin.dart`) to compute the ISO 3779
weighted-sum check digit and to decode the model year — neither of which
`Vin.validate` enforces, since **structure** (17 characters from the
`A-HJ-NPR-Z0-9` charset — `I`, `O` and `Q` are forbidden to avoid confusion
with `1`/`0`) is the only thing every VIN scheme agrees on; the check digit
is mandatory only in North America and frequently absent or non-standard on
European VINs.

**Check digit** (position 9, 0-indexed 8): each of the 17 characters is
transliterated to a numeric value (digits keep their value; letters map
cyclically — `A/J`→1, `B/K/S`→2, `C/L/T`→3, … skipping `I`, `O`, `Q`), then
each value is multiplied by a fixed per-position weight
(`[8,7,6,5,4,3,2,10,0,9,8,7,6,5,4,3,2]` — note position 9 itself weighs `0`,
since it's the digit being checked) and the products summed. The sum mod 11
gives the expected check character: `0`-`9` as-is, `10` written as `X`.
`checkDigitValid` just compares this to the VIN's actual character 9.

**Model year** (position 10, 0-indexed 9): each character maps to a
calendar year via a fixed table (`A`=1980, `B`=1981, … `Y`=2000, then
`1`=2001, `2`=2002, … `9`=2009). Because manufacturers reuse the same 17
letter/digit codes on a **30-year cycle**, that single character is
ambiguous between two years thirty years apart (e.g. `3` alone could mean
2003 or 2033) — position 10 alone cannot disambiguate. The convention
disambiguates using **position 7** (0-indexed 6) instead: if it's a
**letter**, the VIN belongs to the 2010-2039 cycle and 30 years are added to
the base-table year; if it's a **digit**, the VIN belongs to the base
1980-2009 cycle and the table year is used unchanged.

Worked example, `1HGCM82633A004352`: transliterating and weighting all 17
characters and summing the products gives `311`; `311 mod 11 = 3`, matching
the VIN's own character 9 (`3`), so `checkDigitValid` is `true`. Character
10 is `3` → base year 2003 from the year table; character 7 is `6`, a
digit, so no 30-year offset is added — `modelYear` is `2003`.

## MAC address notations and flag bits (EUI-48 / EUI-64)

Used by `MacAddress` (`lib/src/mac_address/mac_address.dart`) to accept and
convert between the four notations vendors commonly use for the same
12-hex-digit (EUI-48) or 16-hex-digit (EUI-64) hardware address: colon
(`aa:bb:cc:dd:ee:ff`), hyphen (`aa-bb-cc-dd-ee-ff`), Cisco dot
(`aabb.ccdd.eeff`) and bare (`aabbccddeeff`). There is no checksum here
either — validation is purely "does the input match one of these four
shapes with the right hex-digit count", and the canonical `normalize` form
is always lower-case colon-separated.

`parse`'s unicast/multicast and universal/local flags read two individual
bits out of the **first octet** — the same bit positions IEEE 802
hardware uses to interpret an address on the wire: the least-significant
bit (`0x01`) is the I/G (individual/group) bit — `0` means the address
identifies one station (unicast), `1` means it's a group/multicast
address; the second-least-significant bit (`0x02`) is the U/L
(universal/local) bit — `0` means the address comes from an
IEEE-assigned OUI block (universal), `1` means it was locally assigned
(e.g. a hand-configured or virtualized interface). `MacAddress` needs no
bundled data for any of this — the notation regexes, the bit masks and
the octet split are all fixed, in-code constants.

## Host classification order and the bracketed-IPv6-port rule

Used by `Host` (`lib/src/host/host.dart`) to classify a bare host — no
scheme, unlike `Url` — as a hostname, an IPv4 address or an IPv6 address,
with an optional port.

**Classification order.** A host part is tried against IPv4 first, then
IPv6, then hostname, and the first match wins: `192.168.1.1` is IPv4 before
it's ever considered as a (rejected) hostname; a hex-only IPv6 group like
`::1` fails the IPv4 regex and is then matched as IPv6; anything left over
falls through to the RFC 1123 hostname grammar (dot-separated labels, each
1-63 characters of `[A-Za-z0-9-]`, not starting or ending with a hyphen,
total length ≤ 253 — single-label hosts like `localhost` are allowed).

**IPv6** is validated algorithmically rather than by one giant regex: split
the address on `::` (at most one such split is allowed — two would make the
expansion ambiguous), split each side on `:` into groups, and require every
group to be 1-4 hex digits **except** the last group, which may instead be
an embedded IPv4 address (`::ffff:192.0.2.1`) counted as two groups. An
address without `::` must expand to exactly 8 groups; one with `::` must
expand to 7 or fewer (the `::` stands in for at least one all-zero group).

**Port recognition** differs by host type because IPv6 addresses already
contain colons: for a hostname or IPv4 host, a single trailing `:port` is
split off directly (`example.com:8080`, `192.168.1.1:443`). For IPv6, a bare
address is never split on `:` for a port — `::1` alone parses as the IPv6
address with no port — a port is only recognised in the **bracketed** form
`[::1]:8080`, where the brackets unambiguously mark where the address ends
and the port begins. `Host.normalize` re-applies this rule on the way out:
an IPv6 host is only wrapped in brackets when a port is present to attach.

A port, when present, must be a decimal integer `0-65535`; anything outside
that range (or non-numeric) is rejected as `IssueCode.hostBadPort` rather
than `hostBadFormat`, since the host part itself was otherwise valid.

## PostalCode per-country patterns (Europe + Turkey)

Unlike the checksum-based types above, `PostalCode`
(`lib/src/postal_code/postal_code.dart`) validates against a **curated
data table** rather than an algorithm, because postal-code formats are a
per-country administrative convention with no common structure to derive
them from. `kPostalPatterns` (`lib/src/postal_code/postal_metadata.g.dart`,
generated by `tool/gen_postal_metadata.py` from the public i18n
postal-format data — see [NOTICE](../NOTICE)) maps each of 51 European
countries (plus Turkey) to an anchored validation regex and a canonical
spacing rule (e.g. insert a literal separator after N characters, or —
for the UK-style postcodes used by GB/GG/GI/IM/JE — a space before the
last three characters regardless of total length). `country` is required
on every `PostalCode` operation, since the same bare digit string (a plain
4-digit code, for instance) is a valid postal code in a dozen different
countries at once; a country missing from the table yields
`IssueCode.postalUnknownCountry` rather than a guess.

## GS1 mod-10 check digit (GTIN-8/12/13/14)

`Gtin` (`lib/src/gtin/gtin.dart`) implements the GS1 check digit shared by
EAN-8, UPC-A, EAN-13 and ITF-14: digits are weighted 3 and 1 alternately
**from the right**, starting with 3 on the digit immediately left of the check
digit, and the check digit is whatever completes the sum to a multiple of ten.
Only lengths 8, 12, 13 and 14 exist; anything else is `gtinBadLength` before
the checksum is even attempted.

`Gtin.parse` deliberately exposes no GS1 prefix and no country. A GS1 prefix
identifies the member organisation that issued the number, not where the goods
came from, and an API that surfaces it is reliably misread as
country-of-origin. What it does expose is `gtin14`, the zero-padded 14-digit
form GS1 recommends for storage, so an EAN-13 scanned at the till can be
matched against an ITF-14 printed on the outer case.

## Austrian Abgabenkontonummer check digit (tax number)

`TaxNumber` (`lib/src/tax_number/tax_number.dart`) validates the nine-digit
Austrian tax number — a two-digit Finanzamt number, six free digits and a check
digit, written `12-345/6789`.

The official description states the check as
`S = F + Q(A) + N1 + Q(N2) + N3 + Q(N4) + N5 + Q(N6)`, where `Q(z)` is the
digit sum of `2z`, and `P = (80 - S) mod 10`. Written out, that is exactly the
Luhn algorithm over all nine digits, so the implementation reuses `luhnOk`
rather than restating the formula. Verified against the documented worked
example `98-123/4560`: S = 40, P = 0, and Luhn over `981234560` gives 40 ≡ 0
(mod 10).

**The Finanzamt number never rejects.** Austria reorganised its tax
administration on 2021-01-01 into Finanzamt Österreich and Finanzamt für
Großbetriebe, and froze existing account numbers at that point — so historical
office prefixes stay valid forever and appear on documents indefinitely. Any
bundled list of office numbers would be a snapshot that quietly refuses valid
numbers as it ages, and most of the offices those digits refer to no longer
exist, so no office-name table is shipped either. `parse` reports the two
digits and nothing more.

## Austrian Versicherungsnummer (social-security number)

`SocialSecurityNumber` (`lib/src/social_security/social_security.dart`)
validates the ten-digit Austrian number `NNNP TTMMJJ`. The nine non-check
digits are weighted 3, 7, 9, 5, 8, 4, 2, 1, 6 from the left (equivalently: the
full ten positions weighted 3, 7, 9, **0**, 5, 8, 4, 2, 1, 6, since position 4
is the check digit itself) and the sum taken modulo 11. A remainder of 10 is
never issued — the assigning system skips to the next serial — so it is
rejected rather than accommodated.

**The serial is 100 to 999.** Its first digit is never zero, so a leading zero
is rejected with `ssnBadSerial` before the check digit is computed — a number
wrong on both counts, such as `0451 010190`, then reports the serial rather
than a check-digit failure that would send you looking in the wrong place.
This matters in practice because `0000TTMMJJ` is the form written on Austrian
paperwork to say "insurance number unknown, birth date follows"; without the
rule it validates as a real number.

**Validation never inspects the date**, and this is the important part. The
date portion is routinely fictitious by design:

- Only a limited number of serials exist per birth date, so when they run out
  the number is issued with **month 13, 14 or 15**.
- Someone whose exact birthday is unknown is registered as 1 January or 1 July
  of their birth year.

Those are correct, issued numbers. Rejecting an out-of-range month would reject
real people, so the date plays no part in validity and
`SocialSecurityInfo.birthDate` is simply null whenever the digits do not form a
real calendar date.

The century is not inferred either. A two-digit year is genuinely ambiguous,
and every rule for resolving it is an age heuristic that belongs to the calling
application — so `SsnBirthDate` carries `day`, `month` and `twoDigitYear` and
stops there. February is treated as having 29 days for the same reason: without
a century, leap years are unknowable.

Sources: [ÖGK, Versicherungsnummer](https://www.oegk.at/cdscontent/?contentid=10007.870557);
[agsolutions, Die technischen Details der österreichischen SVNR](https://www.agsolutions.at/stories/die-technischen-details-der-oesterreichischen-sozialversicherungsnummer-svnr);
[parliamentary answer 7147/AB of 6 September 2021](https://www.parlament.gv.at/dokument/XXVII/AB/7147/imfname_995754.pdf),
which states that the birth date need not be part of the number at all
(§ 358 ASVG) and that it may diverge for technical reasons.

## Austrian Firmenbuchnummer check letter (company register)

`CompanyRegister` (`lib/src/company_register/company_register.dart`) computes
the check letter as follows:

1. Zero-pad the digits to six.
2. Weight them 6, 4, 14, 15, 10, 1 from the left.
3. Sum, take modulo 17.
4. Index into `A B D F G H I K M P S T V W X Y Z` — 17 letters, with the
   confusable `C`, `E`, `J`, `L`, `N`, `O`, `Q`, `R` and `U` omitted.

No official specification of this algorithm could be obtained, so it was
established empirically and must not be changed without new evidence. **Twelve
real, independently published Firmenbuchnummern all satisfy it:**

| Number | Letter | Source |
|---|---|---|
| 415772 | f | gps365 GmbH, imprint |
| 187010 | s | Umweltbundesamt GmbH, imprint |
| 536480 | t | VLR Austria GmbH, imprint |
| 512160 | b | FS19 GmbH, imprint |
| 271797 | b | ÖBB-Operative Services GmbH & Co KG, imprint |
| 270943 | x | ÖBB-Operative Services GmbH, imprint |
| 247642 | f | ÖBB-Holding AG, register service |
| 254941 | p | Wienerberger West European Holding GmbH, register service |
| 71396 | w | ÖBB-Infrastruktur AG, register service |
| 93363 | z | OMV AG, imprint |
| 77676 | f | Wienerberger AG, imprint |
| 94684 | t | Wienerberger Österreich GmbH, imprint |

Two widely repeated claims about this letter are **wrong**, and both are
refuted by the table above:

- **"It is the number modulo 26, with a = 0."** This reproduces exactly one of
  the twelve (187010 s), by coincidence. It gives `g` for 415772, `w` for
  536480 and `m` for 512160, all of which are wrong.
- **"The letter encodes the legal form."** Seven of the twelve are GmbHs and
  they carry seven different letters.

The zero-padding matters and is what the short numbers pin down: applying the
weights **left-aligned** to an unpadded five-digit number instead reproduces
none of `71396 w`, `93363 z`, `77676 f` or `94684 t`. One circulating
five-digit example that *does* match left-alignment, `92754 f`, appears in the
README of a third-party checker that uses left-alignment — i.e. it is almost
certainly output of that implementation rather than a real number, and it is
kept in the vectors as a **rejected** case.

## VAT check digits (27 EU member states plus CH, GB and XI)

`VatId` (`lib/src/vat_id/vat_id.dart`) splits into two parts: the **structure**
of each country's number is data (`tool/data/vat-formats.json`, generated into
`vat_metadata.g.dart` and `js/src/data/vat-metadata.json`), and the **check
digit** is code (`vat_checks.dart`), because the algorithms have nothing in
common and no table could express them.

Every supported country has a real arithmetic check — there is no
structure-only tier, and `checkVat` throws rather than falling back to one, so
a country cannot be added to the metadata and quietly validate on shape alone.

| Country | Rule |
|---|---|
| AT | Luhn over the eight digits; check digit `(6 − luhn(first seven)) mod 10` |
| BE | `int(first 8) + int(last 2)` is a multiple of 97 (an addition, not one long number) |
| BG | 9 digits: `Σ(i+1)·dᵢ mod 11`, retried with `Σ(i+3)·dᵢ` when that is 10 — 10 digits: weights 4,3,2,7,6,5,4,3,2 |
| CH | weights 5,4,3,2,7,6,5,4; check `(11 − Σ) mod 11`, a computed 10 is not issued |
| CY | even positions through a substitution table, odd positions as they are, mod 26 → letter |
| CZ | three forms; see below |
| DE, HR | ISO 7064 MOD 11,10 |
| DK | weights 2,7,6,5,4,3,2,1, multiple of 11 |
| EE | weights 3,7,1 repeated, multiple of 10 |
| ES | four forms; see below |
| FI | weights 7,9,10,5,8,4,2,1, multiple of 11 |
| FR | numeric prefix: `int(SIREN + "12") mod 97` — letter prefix: alphabet-index formula; SIREN itself Luhn unless `000` |
| GB, XI | weights 8,7,6,5,4,3,2,10,1 mod 97 ∈ {0, 42, 55} for blocks from 100, otherwise 0 |
| GR | `c ← 2c + dᵢ` over the first eight; check `2c mod 11 mod 10` |
| HU | weights 9,7,3,1 repeated, multiple of 10 |
| IE | 23-letter alphabet `WABCDEFGHIJKLMNOPQRSTUV` indexed by a weighted sum mod 23 |
| IT | Luhn, plus office code `001`–`100`/`120`/`121`/`888`/`999` and a non-zero company part |
| LT | `Σ(1 + i mod 9)·dᵢ mod 11`, retried with the sequence shifted by two when that is 10 |
| LU | `int(first 6) mod 89` equals the last two |
| LV | first digit > 3: weights 9,1,4,8,3,10,2,5,7,6,1 with remainder **3** — otherwise the personal-code rule |
| MT | weights 3,4,6,7,8,9,10,1, multiple of 37 |
| NL | eleven-proof on the first nine **or** ISO 7064 MOD 97,10 over `NL` + number |
| PL | weights 6,5,7,2,3,4,5,6,7,−1, multiple of 11 |
| PT | weights 9…2; check `(11 − Σ) mod 11 mod 10` |
| RO | left-padded to nine, weights 7,5,3,2,1,7,5,3,2; check `10Σ mod 11 mod 10` |
| SE | last two digits are `01`; first ten satisfy Luhn |
| SI | weights 8…2; check `11 − (Σ mod 11)`, 10 becomes 0 |
| SK | the whole ten-digit number is a multiple of 11 |

### The countries that pack several identifiers into one field

- **CZ** — eight digits is a legal entity (and may not start with `9`); nine
  digits starting with `6` is a historical special form; nine or ten digits
  otherwise is a rodné číslo. Only the ten-digit birth number carries a check
  digit; the nine-digit one carries none at all, so nothing beyond the
  structure can be verified for it. The birth date embedded in a rodné číslo is
  a plausibility rule about a person rather than a checksum and is deliberately
  not enforced.
- **ES** — the first character decides: a digit or `K`/`L`/`M` is a DNI, `X`,
  `Y` or `Z` is an NIE, and one of `ABCDEFGHJNPQRSUVW` is a CIF. DNI and NIE
  index the letter table `TRWAGMYFPDXBNJZSQVHLCKE` by the number modulo 23; a
  CIF takes the Luhn check digit over its seven digits and accepts it either as
  that digit or as the letter it maps to through `JABCDEFGHI`, because sources
  disagree on which organisation types must use which form.
- **BG, LV, LT, NL, GB** — see the table; `VatInfo.subtype` reports which
  branch validated, so a consumer never has to re-derive it.

### Two spellings that are not ISO

Greece writes **EL** where ISO 3166 says `GR`, and Northern Ireland writes
**XI** where ISO says `GB`. The metadata is keyed by the ISO code and carries
the tax prefix as data, so `VatInfo.country` is always ISO and
`VatInfo.prefix` is always what goes on the invoice. Both spellings are
accepted as the `country` option.

### How the vectors were sourced

`test/vectors/vat_id.json` pins one published number per country plus a
deliberately broken twin. Twelve of them — BE, CZ, DE, ES, IE, IT, LV, PL, PT,
SE, SI and SK — were confirmed as live registrations through the Commission's
VIES service during implementation. AT's are published in company imprints and
were checked by hand. The rest come from documented third-party test data.
**No valid vector was produced by this implementation.** Three cases are stated
rather than hidden:

- **FR** — the SIREN `919434894` is published (L'Oréal France, in the French
  government's company register); the two-digit key was computed from it with
  the documented rule rather than copied from a published TVA number. VIES
  returned `MS_MAX_CONCURRENT_REQ` on every attempt, so it could not be
  confirmed as a live registration.
- **HU** — `10625790` is the published trunk of MOL Nyrt.'s adószám and
  satisfies the checksum, but VIES reports it as not registered. The vector
  therefore pins the arithmetic, which is all this type promises: whether a
  number is *registered* is a fact about a company, not about the string.
- **XI** — no published Northern Ireland registration was obtainable. An XI
  number is the holder's GB number re-prefixed and uses GB's algorithm
  unchanged, so GB's vectors cover it and the metadata ships no XI example.
