# IMEISV option + Host validator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an opt-in `allowSv` option to `Imei` (accept + parse 16-digit IMEISV), and a new `Host` module (hostname / IPv4 / IPv6 + optional port), in BOTH the Dart package and the TS port, proven by shared JSON vectors.

**Architecture:** Both are pure-algorithm additions (no bundled data). IMEISV extends the existing `Imei` module backward-compatibly; `Host` is a new module mirroring the existing per-module shape.

**Tech Stack:** Dart + TypeScript (mirrored logic). No generator changes.

## Global Constraints

- **Two packages, same behaviour.** Both parts land in Dart AND TS and pass the same vectors in both.
- **Zero runtime dependencies** in both published packages.
- **No AI/tool attribution** anywhere — code, comments, docs, commit messages, package metadata.
- **API parity:** `isValid/validate/normalize/format/tryFormat/parse`; option objects match between languages. `normalize`/`format` throw (FormatException/FormatError) on invalid; `tryFormat` returns null.
- **Backward compatibility:** with `allowSv` defaulting false, all existing IMEI behaviour/vectors are unchanged.
- **New IssueCodes** identical in the Dart enum and TS union: `hostEmpty`, `hostBadFormat`, `hostBadPort`.
- No behaviour change to other existing modules.

---

### Task 1: IMEISV support on `Imei`

**Files:**
- Dart: modify `lib/src/imei/imei.dart`, `lib/src/imei/imei_info.dart`.
- TS: modify `js/src/imei/index.ts`, `js/src/imei/types.ts`.
- Tests: extend `test/vectors/imei.json` + the imei group in `test/vectors_test.dart` (read an `allowSv` option) + `js/test/imei.conformance.spec.ts`.

**Interfaces:**
- Produces: every `Imei` op takes an `allowSv` option (Dart named param `bool allowSv = false`; TS options `{ allowSv?: boolean }`). `ImeiInfo` gains `softwareVersion` (nullable) and `checkDigit` becomes nullable.

- [ ] **Step 1: Extend `ImeiInfo`**

Dart `lib/src/imei/imei_info.dart`: make `checkDigit` nullable and add `softwareVersion`:
```dart
  const ImeiInfo({
    required this.tac,
    required this.serialNumber,
    required this.checkDigit,
    required this.reportingBodyIdentifier,
    this.softwareVersion,
  });
  ...
  /// Luhn check digit (last digit of a 15-digit IMEI); null for a 16-digit IMEISV.
  final String? checkDigit;
  ...
  /// Software version number (last 2 digits of a 16-digit IMEISV); null for a plain IMEI.
  final String? softwareVersion;
```
TS `js/src/imei/types.ts`: `checkDigit: string | null;` and add `softwareVersion: string | null;`.

- [ ] **Step 2: Add the `allowSv` option to `Imei` (Dart)**

In `lib/src/imei/imei.dart`, thread `{bool allowSv = false}` through `validate`, `isValid`, `normalize`, `format`, `tryFormat`, `parse`. New `validate`:
```dart
  static ValidationResult validate(String input, {bool allowSv = false}) {
    final s = _strip(input);
    if (s.isEmpty) {
      return const Invalid([ValidationIssue(IssueCode.imeiEmpty, 'IMEI is empty.')]);
    }
    if (!_digits.hasMatch(s)) {
      return const Invalid([ValidationIssue(IssueCode.imeiBadChars, 'IMEI has invalid characters.')]);
    }
    final ok = s.length == 15 || (allowSv && s.length == 16);
    if (!ok) {
      return Invalid([ValidationIssue(IssueCode.imeiBadLength,
          allowSv ? 'IMEI must be 15 or 16 digits.' : 'IMEI must be 15 digits.')]);
    }
    if (s.length == 15 && !luhnOk(s)) {
      return const Invalid([ValidationIssue(IssueCode.imeiBadChecksum, 'Fails the Luhn checksum.')]);
    }
    return Valid(s);
  }
```
Update `isValid`/`normalize`/`format`/`tryFormat` to accept and forward `{bool allowSv = false}`. `parse`:
```dart
  static ImeiInfo? parse(String input, {bool allowSv = false}) {
    final r = validate(input, allowSv: allowSv);
    if (r is! Valid) return null;
    final s = r.normalized;
    final isSv = s.length == 16;
    return ImeiInfo(
      tac: s.substring(0, 8),
      serialNumber: s.substring(8, 14),
      checkDigit: isSv ? null : s.substring(14),
      reportingBodyIdentifier: s.substring(0, 2),
      softwareVersion: isSv ? s.substring(14, 16) : null,
    );
  }
```
Update the class doc comment (remove "IMEISV is out of scope"; describe the option).

- [ ] **Step 3: Mirror in TS**

In `js/src/imei/index.ts`, add `options: { allowSv?: boolean } = {}` to each op, same logic (15 always; 16 when `allowSv`; Luhn only for 15; `parse` sets `softwareVersion`/nullable `checkDigit`). Keep Dart and TS identical.

- [ ] **Step 4: Extend the vectors**

Add to `test/vectors/imei.json` (the imei group runner must read an `allowSv` option and pass it to validate/parse):
```json
  {"input": "3538800800787456", "allowSv": true, "isValid": true, "normalized": "3538800800787456",
   "parse": {"tac": "35388008", "serialNumber": "007874", "checkDigit": null, "softwareVersion": "56", "reportingBodyIdentifier": "35"}},
  {"input": "3538800800787456", "isValid": false, "code": "imeiBadLength"}
```
(The 16-digit IMEISV `3538800800787456` = TAC `35388008` + serial `007874` + SVN `56`; with `allowSv` omitted it must be `imeiBadLength`. Confirm the split matches your parse; a 16-digit value is NOT Luhn-checked.) Wire the `allowSv` option into `test/vectors_test.dart`'s imei group and `js/test/imei.conformance.spec.ts` (default false when absent). Ensure ALL existing 15-digit imei vectors still pass with `allowSv` absent.

- [ ] **Step 5: Verify + commit**

`dart test`, `dart analyze`, `cd js && npm run build && npm test` — all green (existing IMEI unchanged; new IMEISV cases pass). Commit "Add IMEISV support to Imei via allowSv option".

---

### Task 2: `Host` module

**Files:**
- Dart: create `lib/src/host/host.dart`, `lib/src/host/host_info.dart`; modify `lib/src/common/issue_code.dart`, `lib/kreiseck_validator.dart`.
- TS: create `js/src/host/index.ts`, `js/src/host/types.ts`; modify `js/src/common/types.ts`, `js/src/index.ts`, `js/package.json`, `js/tsup.config.ts`.
- Tests: `test/vectors/host.json` + `test/vectors_test.dart` host group + `js/test/host.conformance.spec.ts`.

**Interfaces:**
- Produces: `Host` namespace (`isValid/validate/normalize/format/tryFormat/parse`); `HostInfo { host; type; port; hasPort }` where `type ∈ 'hostname' | 'ipv4' | 'ipv6'`, `port: int|null`, `hasPort: bool`. IssueCodes `hostEmpty/hostBadFormat/hostBadPort`.

- [ ] **Step 1: Add IssueCodes + write the failing vectors**

Dart enum + TS union: `hostEmpty, hostBadFormat, hostBadPort`. `test/vectors/host.json` — cover the classification + port cases:
```json
[
  {"input": "example.com", "isValid": true, "normalized": "example.com",
   "parse": {"host": "example.com", "type": "hostname", "port": null, "hasPort": false}},
  {"input": "localhost", "isValid": true, "parse": {"type": "hostname", "port": null}},
  {"input": "Sub.Example.CO.UK", "isValid": true, "normalized": "sub.example.co.uk"},
  {"input": "example.com:8080", "isValid": true,
   "parse": {"host": "example.com", "type": "hostname", "port": 8080, "hasPort": true}},
  {"input": "192.168.1.1", "isValid": true, "parse": {"host": "192.168.1.1", "type": "ipv4", "port": null}},
  {"input": "192.168.1.1:443", "isValid": true, "parse": {"type": "ipv4", "port": 443}},
  {"input": "::1", "isValid": true, "parse": {"host": "::1", "type": "ipv6", "port": null}},
  {"input": "2001:db8::1", "isValid": true, "parse": {"type": "ipv6", "port": null}},
  {"input": "[::1]:8080", "isValid": true, "parse": {"host": "::1", "type": "ipv6", "port": 8080, "hasPort": true}},
  {"input": "[2001:db8::1]:443", "isValid": true, "parse": {"host": "2001:db8::1", "type": "ipv6", "port": 443}},
  {"input": "::ffff:192.0.2.1", "isValid": true, "parse": {"type": "ipv6"}},
  {"input": "", "isValid": false, "code": "hostEmpty"},
  {"input": "-bad.example.com", "isValid": false, "code": "hostBadFormat"},
  {"input": "example..com", "isValid": false, "code": "hostBadFormat"},
  {"input": "example.com:99999", "isValid": false, "code": "hostBadPort"},
  {"input": "2001:db8::1::2", "isValid": false, "code": "hostBadFormat"},
  {"input": "192.168.1.256", "isValid": true, "parse": {"type": "hostname"}}
]
```
(Note the last case: `192.168.1.256` is NOT valid IPv4 (256>255); it still matches the lenient RFC-1123 hostname rule → classifies as `hostname`. Keep it or drop it, but be explicit and consistent between both languages.)

- [ ] **Step 2: Run to verify they fail**

`dart test test/vectors_test.dart` / `npx vitest run test/host.conformance.spec.ts` → fail (module missing).

- [ ] **Step 3: Implement `Host` (Dart + TS, identical logic)**

Split off an optional port first, then classify + validate the host:
1. **Port split.**
   - If input starts with `[`: it is a bracketed IPv6. Require a matching `]`. `hostPart` = between the brackets. If a `:PORT` follows the `]`, parse the port; anything else after `]` (other than `:digits`) → `hostBadFormat`.
   - Else if input contains a `.` or exactly ONE `:` and the part after the last `:` is all digits AND there is at most one `:` total: treat the trailing `:digits` as the port, `hostPart` = the rest. (This handles `example.com:8080`, `192.168.1.1:443`, but NOT bare IPv6 which has multiple `:`.)
   - Else: no port; `hostPart` = input.
   - Port, when present, must be all digits and `0 <= port <= 65535`, else `hostBadPort`.
2. **Empty host** → `hostEmpty`.
3. **Classify `hostPart`** in order: IPv4 → IPv6 → hostname; none → `hostBadFormat`.
   - **IPv4:** `^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$`.
   - **IPv6** (algorithmic, lower-cased; implement identically in both languages, iterate until all IPv6 vectors pass):
     - At most one `::`. Charset per group `^[0-9a-f]{1,4}$`.
     - If a group contains `.`, it must be the LAST group and a valid IPv4 (embedded IPv4-mapped), counting as 2 hex groups.
     - Split on `::`: with `::` present the explicit group count (embedded IPv4 = 2) must be ≤ 7; without `::` it must be exactly 8 (or 6 groups + embedded IPv4). Empty groups only allowed via the single `::`.
   - **hostname (RFC 1123):** total length ≤ 253; split on `.`; each label matches `^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$` (1–63 chars, no leading/trailing hyphen); at least one label; single-label allowed. (Reject empty labels → `example..com` fails.)
4. **normalize:** lower-case the host; re-emit with brackets for IPv6-with-port; append `:port` when present. **format/tryFormat** as usual.
5. **parse → `HostInfo`:** `host` = `hostPart` (no brackets, no port, lower-cased), `type`, `port` (int or null), `hasPort`.

Export from both barrels; add `./host` to `js/package.json` exports + `js/tsup.config.ts`.

- [ ] **Step 4: Verify both languages**

`dart test`, `dart analyze`, `cd js && npm run build && npm test` — all host vectors pass in both, no regression. Iterate the IPv6 validator until every IPv6 vector (bare, bracketed+port, embedded-IPv4, the double-`::` reject) passes identically in both languages.

- [ ] **Step 5: Commit**

```bash
git add lib/src/host lib/src/common/issue_code.dart lib/kreiseck_validator.dart \
        js/src/host js/src/common/types.ts js/src/index.ts js/package.json js/tsup.config.ts \
        test/vectors/host.json test/vectors_test.dart js/test/host.conformance.spec.ts
git commit -m "Add Host validator (hostname, IPv4, IPv6, optional port)"
```

---

### Task 3: Docs, exports, and version bump (both packages)

**Files:** `README.md`, `js/README.md`, `CHANGELOG.md`, `pubspec.yaml`, `js/package.json`, `doc/algorithms.md`.

- [ ] **Step 1: Dart docs + version**

README: document the new `Imei` `allowSv` option (with an IMEISV example) and the new `Host` module (hostname/IPv4/IPv6 + port example, e.g. `Host.parse('[::1]:8080')` → type ipv6, port 8080). Verify outputs against the built package. Add a `## 0.9.0` CHANGELOG entry (IMEISV opt-in on Imei; new Host module). Bump `pubspec.yaml` to `0.9.0`; update the `description` if it enumerates modules.

- [ ] **Step 2: TS docs + version**

`js/README.md`: add the `Host` subpath import (`@kreiseck/validator/host`) + the IMEISV option; bump `js/package.json` to `0.9.0` (add `host` to `keywords`); matching CHANGELOG line.

- [ ] **Step 3: algorithms doc**

`doc/algorithms.md`: note IMEISV (16-digit, no Luhn, opt-in) and the Host classification order (IPv4 → IPv6 → hostname) + the bracketed-IPv6-port rule. Match the doc's voice.

- [ ] **Step 4: Final verification**

`dart analyze && dart test`; `cd js && npm run build && npm test`. All green in both.

- [ ] **Step 5: Commit** (`git commit -am "Document IMEISV and Host, release 0.9.0"`).

---

## Self-Review

**Spec coverage:**
- IMEISV via `allowSv` (default false, backward-compatible) + `softwareVersion`/nullable `checkDigit` — Task 1. ✓
- Host module (hostname RFC-1123, IPv4, IPv6 incl. `::`/embedded-IPv4, optional port incl. bracketed IPv6) — Task 2. ✓
- Both Dart + TS per part, shared vectors — Tasks 1-2. ✓
- New IssueCodes host×3 — Task 2. ✓
- Docs + version 0.9.0 both packages — Task 3. ✓

**Type consistency:** `allowSv` option present on every `Imei` op in both languages; `ImeiInfo.checkDigit` nullable + `softwareVersion` nullable in both. `HostInfo { host; type; port; hasPort }` identical; `type` union values `hostname|ipv4|ipv6` match. IssueCodes added identically to the Dart enum and TS union.

**Placeholder scan:** the IMEISV split and the Host classification/IPv6 algorithm are given in full (pseudocode + regexes); the IPv6 validator's exact code is left to the implementer to write identically in both languages, with a comprehensive IPv6 vector set (bare, bracketed+port, embedded IPv4, double-`::` reject) as the concrete acceptance gate. The 16-digit IMEISV vector split is verified against the parse rule during the task.
