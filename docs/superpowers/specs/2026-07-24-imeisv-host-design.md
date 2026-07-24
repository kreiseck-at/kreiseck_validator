# IMEISV option + `Host` validator — Design

**Status:** approved for implementation planning
**Applies to both packages:** Dart `kreiseck_validator` and TS `@kreiseck/validator`,
built together, verified against shared JSON vectors.

## Goal

Two additions:
1. **IMEISV support** on the existing `Imei` module via an opt-in `allowSv`
   option (backward-compatible), so 16-digit IMEISV (IMEI + 2-digit software
   version, no Luhn) is accepted and parsed.
2. A new **`Host`** module that validates and parses a host — hostname
   (RFC 1123), IPv4, or IPv6 — with an optional port.

## Part 1 — IMEISV on `Imei`

The Imei module today is 15-digit, Luhn-only. Add an option (Dart named param,
TS options object) to every operation: `allowSv` (default **false**).

- `Imei.validate(input, { allowSv })`:
  - `allowSv == false` (default): unchanged — exactly 15 digits + Luhn.
  - `allowSv == true`: accept EITHER a 15-digit Luhn IMEI OR a **16-digit
    IMEISV** (TAC 8 + serial 6 + SVN 2, **no Luhn** — the last two digits are the
    software-version number). A 16-digit value is never Luhn-checked.
  - Errors unchanged: `imeiEmpty` / `imeiBadChars` / `imeiBadLength` (length not
    in the allowed set) / `imeiBadChecksum` (15-digit only).
- `ImeiInfo` gains `softwareVersion: String?` and `checkDigit` becomes
  **nullable**:
  - 15-digit IMEI → `checkDigit` = last digit, `softwareVersion` = null.
  - 16-digit IMEISV → `checkDigit` = null, `softwareVersion` = last 2 digits;
    `tac` = first 8, `serialNumber` = digits 9–14 (6), `reportingBodyIdentifier`
    = first 2.
- `isValid`/`normalize`/`format`/`tryFormat`/`parse` all take `allowSv` and
  thread it through. `normalize`/`format` = compact digits (15 or 16).

Backward compatibility: with the default `allowSv == false`, every existing IMEI
vector and behaviour is unchanged. `checkDigit` going nullable is additive in
Dart (the field is still populated for 15-digit) and TS (`string | null`);
existing 15-digit callers are unaffected.

## Part 2 — `Host` module

New module `Host` (Dart `lib/src/host/`; TS `js/src/host/`; subpath
`@kreiseck/validator/host`), same four-operation API + `parse`.

### Accepted input

A host, optionally with a port:
- hostname: `example.com`, `localhost`, `sub.example.co.uk`
- IPv4: `192.168.1.1`
- IPv6 (bare): `::1`, `2001:db8::1`, `fe80::1`, `::ffff:192.0.2.1`
- with a port: `example.com:8080`, `192.168.1.1:443`, and for IPv6 the
  bracketed form `[::1]:8080`, `[2001:db8::1]:443`.

Bare IPv6 has colons, so a port is ONLY recognised for IPv6 in the bracketed
form; a bare `::1` parses as IPv6 with no port. For hostname/IPv4 a single
trailing `:port` is split off.

### Rules

- **hostname** (RFC 1123): total length ≤ 253; dot-separated labels, each 1–63
  chars of `[A-Za-z0-9-]`, not starting or ending with a hyphen; single-label
  hostnames (`localhost`) allowed. Classification tries IPv4 first, then IPv6,
  then hostname.
- **IPv4**: four dotted octets `0–255`.
- **IPv6**: full and `::`-compressed forms (at most one `::`), 1–4 hex digits per
  group, up to 8 groups, including IPv4-mapped tails (`::ffff:192.0.2.1`).
  Implemented with a proper IPv6 validator (algorithmic split on `::` +
  group/embedded-IPv4 checks), not a naive regex.
- **port**: `0–65535` when present.

### API

- `Host.validate(input)`: empty → `hostEmpty`; unparseable/invalid host →
  `hostBadFormat`; port present but out of range → `hostBadPort`.
- `Host.normalize(input)`: lower-case the host (hostname and IPv6 hex);
  IPv6 kept in its bracketed form when a port is present; port preserved.
- `Host.format` / `tryFormat`: canonical display form.
- `Host.parse(input) → HostInfo { host, type, port, hasPort }` where
  `host` is the host without brackets/port, `type ∈ 'hostname' | 'ipv4' | 'ipv6'`,
  `port: int | null`, `hasPort: bool`.

New IssueCodes (identical Dart enum + TS union): `hostEmpty`, `hostBadFormat`,
`hostBadPort`.

Relationship to `Url`: `Url` validates a full URL (scheme + dotted host + TLD);
`Host` validates a bare host/IP with an optional port and is more lenient
(accepts `localhost` and IP literals). They stay independent.

## Data & generation

No bundled data — both parts are pure algorithms. No generator changes.

## Conformance

- Extend `test/vectors/imei.json`: add IMEISV cases with `"allowSv": true`
  (a valid 16-digit IMEISV → `softwareVersion` set, `checkDigit` null; a 16-digit
  value with `allowSv` omitted/false → `imeiBadLength`). The vector runner reads
  an `allowSv` option for the imei group.
- New `test/vectors/host.json` + `test/vectors_test.dart` host group + TS
  `js/test/host.conformance.spec.ts`: hostnames, IPv4, IPv6 (bare + bracketed),
  each with/without a port; invalid hosts, out-of-range ports, malformed IPv6.

## Staged delivery

1. **IMEISV** — the `allowSv` option + `softwareVersion` on `Imei`, both
   languages, extended vectors.
2. **`Host`** — hostname + IPv4 + IPv6 + optional port, both languages, vectors.
3. **Docs** (both READMEs, CHANGELOG, `doc/algorithms.md`) + version bump to
   `0.9.0` in both packages.

## No-footprint

No AI/assistant/tooling references anywhere. (No generated files in this feature.)

## Version

Both packages bump to `0.9.0`.

## Out of scope

- Punycode/IDN hostname handling (accept ASCII/RFC-1123 labels only).
- IPv6 zone IDs (`%eth0`), IPv6 address compression/canonicalisation beyond
  lower-casing.
- A separate `Port` or `IpAddress` module (folded into `Host`).
- IMEISV Luhn (IMEISV has no check digit by definition).
