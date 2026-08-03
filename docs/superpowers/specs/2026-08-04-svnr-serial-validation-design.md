# Austrian SVNR: serial-number validation and birth-date documentation

Status: approved, ready for implementation
Target release: 0.12.0

## Problem

`SocialSecurityNumber` validates the Austrian Versicherungsnummer with the
correct mod-11 checksum but never constrains the three-digit serial
(Laufnummer). The serial is only ever issued in the range **100–999**; the
first digit is never zero.

Consequences today:

- `0000000000` validates as a correct social-security number.
- `0454 010190` validates — it carries a correct check digit but an
  unissuable serial.
- 90,909,091 numbers are wrongly accepted, exactly 10% of the accepted space.

The `0000ttmmjj` form is the documented placeholder used on Austrian forms to
say "insurance number unknown, birth date follows". That marker is currently
accepted as a valid number, which makes this the most likely real-world
false positive rather than a theoretical one.

A second, separate problem is documentation rather than behaviour: the doc
comment on `SocialSecurityInfo.birthDate` states that the field is null
whenever the digits do not form a real calendar date. That is accurate, but
the converse reads as a guarantee it cannot give. A non-null `birthDate` is
the date **as written in the number**, which is not necessarily the person's
birth date.

## Sources

- ÖGK, *Versicherungsnummer* — the serial is three digits, the birth date is
  present "in most cases", and numbers with months 13, 14 or 15 are issued
  once every serial for a birth date is used up. "Solche Abweichungen sind
  keine Fehler!"
  <https://www.oegk.at/cdscontent/?contentid=10007.870557>
- Wikipedia, *Sozialversicherungsnummer* — the serial runs from 100 to 999;
  when the remainder is 10 the serial is incremented and the check digit
  recomputed.
  <https://de.wikipedia.org/wiki/Sozialversicherungsnummer>
- agsolutions, *Die technischen Details der österreichischen SVNR* —
  positions 1–3 are the serial, "first digit must be non-zero"; weights
  `[3,7,9,0,5,8,4,2,1,6]` mod 11.
  <https://www.agsolutions.at/stories/die-technischen-details-der-oesterreichischen-sozialversicherungsnummer-svnr>
- Parliamentary answer 7147/AB of 6 September 2021 (Federal Ministry of Social
  Affairs, based on a statement by the Dachverband der
  Sozialversicherungsträger): "Das Geburtsdatum muss bzw. darf nicht zwingend
  Teil der Versicherungsnummer sein (vgl. § 358 ASVG). Auch aus technischen
  Gründen kann die Versicherungsnummer vom Geburtsdatum abweichen."
  <https://www.parlament.gv.at/dokument/XXVII/AB/7147/imfname_995754.pdf>
- § 358 ASVG and the case law on it: social-insurance records do not have the
  quality of civil-status records, and the birth date carried in the insurance
  number plays no role in establishing a person's birth date.
  <https://www.jusline.at/gesetz/asvg/paragraf/358>

## Decisions taken

**The date part stays unvalidated and `parse` keeps its current shape.**
Months 13–15 and the 1 January / 1 July placeholders are genuinely issued, so
rejecting them would reject real people. This was reconsidered and confirmed:
no new types, no new fields, no enum. Modelling partial certainty was
considered and rejected as more API surface than the information justifies —
the months 13–15 do not map back to a real month, so nothing beyond the year
could be recovered, and the year alone is not worth a breaking change.

**The serial check is a distinct issue code, not a checksum failure.** A
leading zero is a different mistake from a wrong check digit and deserves its
own message.

**The serial check runs before the checksum.** Ordering only changes the
outcome for a number wrong on both counts — `0451 010190`, say — which now
reports the serial rather than a check-digit failure that would send the
caller looking in the wrong place. A number with a bad serial but a correct
check digit, such as `0454 010190`, is rejected either way, so the ordering is
about the quality of the message rather than about catching anything extra.

## Changes

### 1. New issue code

Dart, `lib/src/common/issue_code.dart`, in the social-security block directly
after `ssnBadLength`:

```dart
ssnBadSerial,
```

TypeScript, `js/src/common/types.ts`, same position in the union:

```ts
| 'ssnEmpty' | 'ssnBadChars' | 'ssnBadLength' | 'ssnBadSerial' | 'ssnBadChecksum' | 'ssnUnknownCountry'
```

Enum order mirrors check order, as elsewhere in the package.

### 2. Validation

In both `lib/src/social_security/social_security.dart` and
`js/src/social-security/index.ts`, after the length check and before the
checksum:

```dart
if (compact.codeUnitAt(0) == 0x30) {
  return const Invalid([
    ValidationIssue(IssueCode.ssnBadSerial,
        'Social-security number serial must be 100-999.')
  ]);
}
```

The condition tests the first digit rather than parsing the serial and
comparing against 100. The two are equivalent — serial 000–099 is exactly the
set whose first digit is zero — and the digit test is the documented rule
stated literally.

The English message is identical in both languages, matching how every other
issue code in the package is worded.

Nothing else changes: `fieldDescriptor`, `formatPartial`, `normalize`,
`format`, `tryFormat` and `parse` keep their behaviour. `parse` returns null
for a rejected serial because it already returns null for any invalid input.

### 3. Test vectors

Added to `test/vectors/social_security.json`. Every entry carries a correct
check digit so that a failure proves the serial rule fired, not the checksum:

| Input | Serial | Expected |
|---|---|---|
| `0000000000` | 000 | invalid, `ssnBadSerial` |
| `0454 010190` | 045 | invalid, `ssnBadSerial` |
| `0999 010190` | 099 | invalid, `ssnBadSerial` |
| `1000 010190` | 100 | valid — lower bound is inclusive |
| `9993 010190` | 999 | valid — upper bound |

Dart (`test/vectors_test.dart`) and TypeScript
(`js/test/social-security.conformance.spec.ts`) read the same file, so
cross-language parity follows from the vectors rather than from duplicated
assertions.

### 4. Documentation

- `lib/src/social_security/social_security.dart` and
  `js/src/social-security/index.ts` — class doc gains the serial rule.
- `lib/src/social_security/social_security_info.dart` and
  `js/src/social-security/types.ts` — the `birthDate` doc gains the warning
  that a non-null value is the date as written, not a verified birth date,
  with the § 358 ASVG reasoning.
- `doc/algorithms.md` — serial range in the algorithm description, plus the
  ASVG note and the sources above.
- `README.md` — the social-security section and a gotchas-table row for the
  serial range.
- `llms.txt` — the API line and the gotchas section.
- `CHANGELOG.md` and `js/CHANGELOG.md` — 0.12.0 entry describing the
  behaviour change.

The files under `docs/business-identifiers-*.md` are superseded planning
documents (they still list an `ssnBadDate` code that was never built) and are
left untouched.

### 5. Version

`pubspec.yaml` and `js/package.json` go to 0.12.0. Input that validated in
0.11.x now fails, so this is not a patch release.

## Testing

- `dart test` and the JS suite must pass with the extended vectors.
- The five new vectors cover both sides of the 100 boundary and the
  correct-checksum-but-bad-serial case.
- Existing vectors are unchanged and must keep passing; none of them uses a
  serial below 100.
