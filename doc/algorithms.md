# Algorithms

This page walks through the non-obvious pieces of logic behind
`input_validator`'s checksums and heuristics, each with a worked
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

## E.164 structure and the national trunk prefix

`Phone.validate`/`normalize` (`lib/src/phone/phone.dart`) accept
either:

- **International (E.164) input**, starting with `+`: `+` followed by
  a country calling code (`49` = DE, `43` = AT, `41` = CH in this
  package's DACH scope) and the national subscriber number, with no
  leading zero — e.g. `+436601234567`.
- **National input**, written the way a local caller would dial it
  domestically, typically with a leading `0` **trunk prefix** — e.g.
  Austrian `0660 1234567`. That leading `0` is a dialing convention,
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
