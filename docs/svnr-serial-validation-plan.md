# SVNR Serial-Number Validation Implementation Plan

**Goal:** Reject Austrian social-security numbers whose three-digit serial lies outside 100–999, and correct the documentation that implies `birthDate` is a verified date of birth.

**Architecture:** The Austrian serial (Laufnummer) is only ever issued in 100–999, so its first digit is never zero. A single guard on `compact[0]` goes in after the length check and before the checksum, reporting a new `ssnBadSerial` issue code. Dart and TypeScript carry identical logic and are held together by the shared JSON vectors in `test/vectors/social_security.json`, which both test suites read.

**Tech Stack:** Dart (package root, `dart test`), TypeScript (`js/`, vitest), zero runtime dependencies, shared JSON test vectors.

## Global Constraints

- Zero runtime dependencies in both packages. Do not add any.
- Dart and TypeScript must behave identically. Every behavioural change lands in both, in the same commit.
- The English issue message is byte-identical across both languages.
- The date part of the number is never validated. Do not add any date check.
- No public type changes: `SocialSecurityInfo`, `SsnBirthDate` and every method signature stay exactly as they are.
- Comments and docs are technical only. No tooling, generator or authorship markers anywhere.
- Target release: 0.12.0 in both `pubspec.yaml` and `js/package.json`.

---

### Task 1: Serial validation in Dart and TypeScript

The two languages land together because they share one test-vector file: adding the vectors reds both suites at once, and only a change in both makes them green again. A reviewer cannot sensibly accept one half.

**Files:**
- Modify: `test/vectors/social_security.json:11` (insert after the `1300010190` line)
- Modify: `lib/src/common/issue_code.dart:83` (insert after `ssnBadLength,`)
- Modify: `lib/src/social_security/social_security.dart:69` (insert after the length-check block)
- Modify: `js/src/common/types.ts:18`
- Modify: `js/src/social-security/index.ts` (after the `compact.length !== 10` block)
- Test: `test/vectors_test.dart` (no edit needed — it iterates the vectors)
- Test: `js/test/social-security.conformance.spec.ts` (no edit needed — same)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `IssueCode.ssnBadSerial` (Dart enum value) and `'ssnBadSerial'` (member of the TS `IssueCode` string union). Task 2 and Task 3 refer to this name.

- [ ] **Step 1: Write the failing vectors**

Insert these five lines into `test/vectors/social_security.json` directly after the `{"input": "1300010190", ...}` line. Every one carries a correct check digit, so a failure proves the serial rule fired rather than the checksum:

```json
  {"input": "0000000000", "country": "AT", "isValid": false, "code": "ssnBadSerial"},
  {"input": "0454 010190", "country": "AT", "isValid": false, "code": "ssnBadSerial"},
  {"input": "0999 010190", "country": "AT", "isValid": false, "code": "ssnBadSerial"},
  {"input": "1000 010190", "country": "AT", "isValid": true, "normalized": "1000010190", "format": "1000 010190"},
  {"input": "9993 010190", "country": "AT", "isValid": true, "normalized": "9993010190", "format": "9993 010190"},
```

`1000 010190` (serial 100) and `9993 010190` (serial 999) are the inclusive bounds; `0999 010190` (serial 099) sits one below the lower bound.

- [ ] **Step 2: Run both suites to verify they fail**

```bash
dart test test/vectors_test.dart --name social_security
cd js && npm test -- social-security
```

Expected: both FAIL. The three `ssnBadSerial` vectors currently validate as `true`, so the `isValid` expectation fails first.

- [ ] **Step 3: Add the Dart issue code**

In `lib/src/common/issue_code.dart`, the social-security block becomes:

```dart
  // social security number
  ssnEmpty,
  ssnBadChars,
  ssnBadLength,
  ssnBadSerial,
  ssnBadChecksum,
  ssnUnknownCountry,
```

Enum order mirrors check order, as everywhere else in this file.

- [ ] **Step 4: Add the Dart guard**

In `lib/src/social_security/social_security.dart`, immediately after the `compact.length != 10` block and before the `var sum = 0;` line:

```dart
    if (compact.codeUnitAt(0) == 0x30) {
      return const Invalid([
        ValidationIssue(IssueCode.ssnBadSerial,
            'Social-security number serial must be 100-999.')
      ]);
    }
```

Test the first digit rather than parsing the serial and comparing against 100. The two are equivalent — serials 000–099 are exactly those starting with zero — and the digit test states the documented rule literally without an `int.parse`.

- [ ] **Step 5: Run the Dart suite to verify it passes**

```bash
dart test test/vectors_test.dart --name social_security
```

Expected: PASS, all vectors including the five new ones.

- [ ] **Step 6: Add the TypeScript issue code**

In `js/src/common/types.ts`, line 18 becomes:

```ts
  | 'ssnEmpty' | 'ssnBadChars' | 'ssnBadLength' | 'ssnBadSerial' | 'ssnBadChecksum' | 'ssnUnknownCountry'
```

- [ ] **Step 7: Add the TypeScript guard**

In `js/src/social-security/index.ts`, immediately after the `compact.length !== 10` block and before `let sum = 0;`:

```ts
  if (compact.charCodeAt(0) === 48) {
    return invalid('ssnBadSerial', 'Social-security number serial must be 100-999.');
  }
```

The message string must match the Dart one byte for byte.

- [ ] **Step 8: Run the JS suite to verify it passes**

```bash
cd js && npm test -- social-security
```

Expected: PASS.

- [ ] **Step 9: Run everything**

```bash
dart analyze
dart test
cd js && npm test
```

Expected: no analyzer issues, both full suites green. The existing vectors are unaffected — every serial already present starts with `1`, including `1300010190`, which still reports `ssnBadChecksum`.

- [ ] **Step 10: Commit**

```bash
git add test/vectors/social_security.json lib/src/common/issue_code.dart \
        lib/src/social_security/social_security.dart \
        js/src/common/types.ts js/src/social-security/index.ts
git commit -m "Reject social-security serials below 100

The Austrian Laufnummer is only issued in the range 100-999, so its first
digit is never zero. Validation checked the mod-11 check digit alone, which
accepted 0000000000 -- the placeholder written on forms to mean the number is
unknown -- along with 90.909.091 other numbers that cannot have been issued.

The new ssnBadSerial code is reported before the checksum, so a number wrong
on both counts reports the serial it cannot have rather than a check-digit
failure that would send the caller looking in the wrong place."
```

---

### Task 2: Documentation

No behaviour changes here. This task records the serial rule and fixes the `birthDate` doc, which currently states only that the field is null for a non-calendar date — true, but it reads as a promise that a non-null value is the person's real date of birth.

**Files:**
- Modify: `lib/src/social_security/social_security.dart:13-18` (class doc)
- Modify: `lib/src/social_security/social_security_info.dart:41-49` (`birthDate` doc)
- Modify: `js/src/social-security/index.ts:13-20` (class doc comment)
- Modify: `js/src/social-security/types.ts` (`birthDate` comment in `SocialSecurityInfo`)
- Modify: `doc/algorithms.md:498-526`
- Modify: `README.md:486-499` and the gotchas table around `README.md:534-535`
- Modify: `llms.txt:84-87` and `llms.txt:146-148`

**Interfaces:**
- Consumes: `IssueCode.ssnBadSerial` / `'ssnBadSerial'` from Task 1.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Update the Dart class doc**

In `lib/src/social_security/social_security.dart`, replace the paragraph beginning "The Austrian Versicherungsnummer is ten digits" with:

```dart
/// The Austrian Versicherungsnummer is ten digits, written `NNNP TTMMJJ`: a
/// three-digit serial, a check digit, then the date of birth. The serial runs
/// from 100 to 999 — it never starts with a zero, and `0000TTMMJJ` is the
/// placeholder written on forms to mean the number is unknown, so a leading
/// zero is rejected. The nine non-check digits are weighted 3, 7, 9, 5, 8, 4,
/// 2, 1, 6 from the left and the sum taken modulo 11. A remainder of 10 is
/// never issued — the serial is skipped instead — so such a number is
/// rejected rather than treated as an edge case.
```

- [ ] **Step 2: Update the Dart `birthDate` doc**

In `lib/src/social_security/social_security_info.dart`, replace the doc comment on `birthDate` with:

```dart
  /// The date of birth **as written in the number**, or null when the digits
  /// do not form a real calendar date.
  ///
  /// A non-null value is not a verified date of birth. Austria issues numbers
  /// whose date part is deliberately fictitious: when every serial for a real
  /// date is used up, months 13, 14 and 15 are issued, and a person whose
  /// birthday is unknown is registered as 1 January or 1 July of their birth
  /// year. The last case produces a perfectly ordinary calendar date that no
  /// amount of inspection can tell apart from a real one.
  ///
  /// § 358 ASVG settles what that means: social-insurance records do not have
  /// the quality of civil-status records, and the date carried in the number
  /// plays no part in establishing when someone was born. Treat this as the
  /// digits the number happens to contain, and collect a date of birth
  /// separately if you need one.
```

- [ ] **Step 3: Mirror both into TypeScript**

Apply the same two edits to `js/src/social-security/index.ts` (class comment) and `js/src/social-security/types.ts` (the `birthDate` comment inside `SocialSecurityInfo`), converted to `//` comment style and without the `///` or `**bold**` markup, matching the surrounding file.

- [ ] **Step 4: Update `doc/algorithms.md`**

In the section `## Austrian Versicherungsnummer check digit (social-security number)`, insert after the paragraph ending "so it is rejected rather than accommodated.":

```markdown
**The serial is 100 to 999.** Its first digit is never zero, so a leading zero
is rejected with `ssnBadSerial` before the check digit is computed — a number
wrong on both counts, such as `0451 010190`, then reports the serial rather
than a check-digit failure that would send you looking in the wrong place.
This matters in practice because `0000TTMMJJ` is the form written on Austrian
paperwork to say "insurance number unknown, birth date follows"; without the
rule it validates as a real number.
```

Then append to the end of that section:

```markdown
Sources: [ÖGK, Versicherungsnummer](https://www.oegk.at/cdscontent/?contentid=10007.870557);
[agsolutions, Die technischen Details der österreichischen SVNR](https://www.agsolutions.at/stories/die-technischen-details-der-oesterreichischen-sozialversicherungsnummer-svnr);
[parliamentary answer 7147/AB of 6 September 2021](https://www.parlament.gv.at/dokument/XXVII/AB/7147/imfname_995754.pdf),
which states that the birth date need not be part of the number at all
(§ 358 ASVG) and that it may diverge for technical reasons.
```

- [ ] **Step 5: Update `README.md`**

Replace the prose under `### 🪪 Social-security number` with:

```markdown
Validation never looks at the date. Austria issues months 13, 14 and 15 when the
serials for a real birth date run out, and registers an unknown birthday as
1 January or 1 July — rejecting those would reject real people. The century is
never inferred either: `SsnBirthDate` carries `day`, `month` and `twoDigitYear`,
and any age heuristic belongs to your application.

The serial *is* checked: it runs from 100 to 999, so a leading zero is rejected
with `ssnBadSerial`. `0000TTMMJJ` is what Austrian forms carry to mean "number
unknown, birth date follows", and it is not a valid number.

Note that a non-null `birthDate` is the date **as written**, not a verified one —
the 1 January and 1 July placeholders are ordinary calendar dates and cannot be
told apart from real ones. Per § 358 ASVG the date in the number has no
civil-status quality at all, so collect a date of birth separately if you need it.
```

In the gotchas table, replace the row `| `SocialSecurityNumber` never rejects a date | months 13-15 and 1 January placeholders are really issued |` with these two:

```markdown
| `SocialSecurityNumber` never rejects a date | months 13-15 and 1 January placeholders are really issued |
| `SocialSecurityNumber.parse` gives a date that may be fictitious | the 1 January / 1 July placeholders are valid calendar dates; § 358 ASVG gives the number's date no civil-status quality |
```

- [ ] **Step 6: Update `llms.txt`**

Replace the `SocialSecurityNumber` API entry with:

```
- `SocialSecurityNumber({required String country})` — AT only; serial 100-999
  (leading zero rejected as `ssnBadSerial`), mod-11 over weights
  3,7,9,5,8,4,2,1,6, remainder 10 rejected.
  `parse -> SocialSecurityInfo` with `birthDate` as `SsnBirthDate {day, month,
  twoDigitYear}` or null.
```

Replace the gotchas entry with:

```
- `SocialSecurityNumber` never validates the date: Austria issues months 13-15
  and 1 January/1 July placeholders on purpose. `birthDate` is null for those.
  The century is never inferred. A non-null `birthDate` is the date as written,
  not a verified one — § 358 ASVG gives it no civil-status quality. The serial
  is validated: 100-999, leading zero rejected.
```

- [ ] **Step 7: Verify docs build and nothing regressed**

```bash
dart analyze
dart test
cd js && npm test
```

Expected: all green. Doc comments are compiled by `dart analyze`, so a malformed reference is caught here.

- [ ] **Step 8: Commit**

```bash
git add lib/src/social_security/ js/src/social-security/ doc/algorithms.md README.md llms.txt
git commit -m "Document the serial range and what birthDate really is

birthDate was documented as null whenever the digits are not a real calendar
date. That is true and reads as a guarantee it cannot give: someone registered
with an unknown birthday gets 1 January or 1 July of their birth year, which is
an ordinary date and indistinguishable from a real one. § 358 ASVG is explicit
that the date in the number has no civil-status quality."
```

---

### Task 3: Release 0.12.0

Input that validated in 0.11.x now fails, so this is a minor bump rather than a patch.

**Files:**
- Modify: `pubspec.yaml:7`
- Modify: `js/package.json:3`
- Modify: `CHANGELOG.md` (new section at the top, under `# Changelog`)
- Modify: `js/CHANGELOG.md` (same)

**Interfaces:**
- Consumes: the behaviour from Task 1 and the wording from Task 2.
- Produces: nothing.

- [ ] **Step 1: Bump both versions**

`pubspec.yaml` line 7: `version: 0.12.0`
`js/package.json` line 3: `  "version": "0.12.0",`

- [ ] **Step 2: Write the changelog entry**

Insert into `CHANGELOG.md` directly after the `# Changelog` heading, and the same text into `js/CHANGELOG.md`:

```markdown
## 0.12.0

**Breaking — social-security numbers with a serial below 100 are now rejected.**
The Austrian Laufnummer is only ever issued in the range 100-999, so its first
digit is never zero. Validation checked the mod-11 check digit alone, which let
through `0000000000` and 90.909.091 further numbers that cannot have been
issued — a tenth of everything it accepted. `0000TTMMJJ` in particular is the
form written on Austrian paperwork to mean "insurance number unknown, birth
date follows", so this was the likeliest wrong answer in practice, not a
theoretical one. The new `ssnBadSerial` code is reported before the checksum,
so a number wrong on both counts reports the serial it cannot have rather than
a check-digit failure that would send you looking in the wrong place.

**`SocialSecurityInfo.birthDate` is documented for what it is.** No behaviour
changed. The field was described as null whenever the digits do not form a real
calendar date, which is accurate but reads as a promise that a non-null value is
the person's date of birth. It is not: someone whose birthday is unknown is
registered as 1 January or 1 July of their birth year, and that is an ordinary
calendar date no inspection can tell from a real one. § 358 ASVG is explicit
that the date carried in the number has no civil-status quality. Collect a date
of birth separately if you need one.
```

- [ ] **Step 3: Verify**

```bash
dart analyze
dart test
cd js && npm test
```

Expected: all green.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml js/package.json CHANGELOG.md js/CHANGELOG.md
git commit -m "Release 0.12.0"
```

---

## Self-review

**Spec coverage.** Serial validation and the new issue code: Task 1. Vectors including both boundaries: Task 1, Step 1. Documentation across the six listed files: Task 2. Version bump and changelogs: Task 3. The spec's decision not to touch `parse`, `SsnBirthDate` or `SocialSecurityInfo` is carried as a global constraint. The spec's instruction to leave `docs/business-identifiers-*.md` alone is honoured — no task lists them.

**Type consistency.** `ssnBadSerial` is spelled identically in the Dart enum, the TS union, the five vectors, both changelogs, `README.md`, `llms.txt` and `doc/algorithms.md`. The message `Social-security number serial must be 100-999.` is byte-identical in Steps 4 and 7 of Task 1.

**Placeholders.** None. Every code and prose block is the literal text to insert.
