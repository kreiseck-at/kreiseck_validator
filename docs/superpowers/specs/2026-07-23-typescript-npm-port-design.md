# TypeScript / npm port (`@kreiseck/validator`) — Design

**Status:** approved for implementation planning

## Goal

Port the Dart `kreiseck_validator` package to a framework-agnostic TypeScript
npm package, `@kreiseck/validator`, that runs in the browser (React etc.),
Node.js, and edge/serverless runtimes. Behaviour must be byte-identical to the
Dart package, guaranteed by running the TS implementation against the same
`test/vectors/*.json` conformance suite.

Full parity: all five modules — `email`, `phone`, `url`, `iban`,
`credit_card` — plus the `IbanCountry` descriptor and the shared `Country` /
`IssueCode` / `ValidationResult` types.

## Repository layout (monorepo)

The TS package lives beside the Dart package in the same repository:

```
/                     ← Dart package (unchanged)
  lib/ …              ← Dart sources
  test/vectors/*.json ← shared cross-language conformance vectors (source of truth)
  tool/*.py           ← generators (extended to also emit JSON for JS)
  js/                 ← new: the @kreiseck/validator npm package
    package.json
    tsconfig.json
    tsup.config.ts
    vitest.config.ts
    src/
      index.ts        ← re-exports every module
      email/  phone/  url/  iban/  credit-card/  common/
      data/           ← generated JSON consumed at build/runtime
    test/             ← vitest specs, incl. the shared-vector conformance runner
```

The Dart package at the repo root is untouched except for the generators under
`tool/`, which gain JSON emission.

## Public API

Mirrors the Dart four-operation API; method names are identical across languages
so knowledge transfers. Each module is exported as a namespace object AND is
reachable via a subpath for tree-shaking.

```ts
import { Iban, Email, Phone, Url, CreditCard, IbanCountry } from '@kreiseck/validator';
// or, tree-shakeable:
import { Iban } from '@kreiseck/validator/iban';

Iban.isValid(input: string): boolean;
Iban.validate(input: string): ValidationResult;
Iban.normalize(input: string): string;        // throws FormatError on invalid
Iban.format(input: string): string;            // throws FormatError on invalid
Iban.tryFormat(input: string): string | null;
Iban.parse(input: string): IbanInfo | null;

IbanCountry.of(code: string): IbanCountry | null;
IbanCountry.values(): IbanCountry[];
```

Per-module operations match the Dart surface:
- `Email`: `isValid`, `validate`, `normalize` (validate carries typo-domain
  `suggestions`).
- `Phone`: `isValid`, `validate`, `normalize`, `format({ international })`,
  `tryFormat`, `type`, `parse` → `PhoneInfo`.
- `Url`: `isValid`, `validate`, `normalize`, `format`, `tryFormat`.
- `CreditCard`: `isValid`, `validate`, `normalize`, `format`, `tryFormat`.
- `Iban`: as above.

### Shared types

```ts
type ValidationResult =
  | { ok: true;  normalized: string; suggestions: Suggestion[] }
  | { ok: false; issues: ValidationIssue[] };

interface ValidationIssue { code: IssueCode; message: string }
interface Suggestion { value: string; reason: string }

type IssueCode =
  | 'emailEmpty' | 'emailMissingAt' | /* … every code from the Dart enum … */
  | 'ibanBadChecksum' | 'cardBadLuhn' | /* … */ ;
```

`normalize` / `format` throw a `FormatError` (a small `Error` subclass) on
invalid input, mirroring Dart's `FormatException`. `tryFormat` returns `null`
instead. Type shapes (`IbanInfo`, `IbanCountry`, `PhoneInfo`,
`PhoneNumberType`, `Country`) mirror the Dart classes as plain interfaces /
`readonly` objects.

## Data & generation

The Python generators under `tool/` become the single source of truth for both
languages by additionally emitting JSON that the TS build embeds:

- **Phone:** `tool/gen_phone_metadata.py` already emits
  `lib/src/phone/data/metadata.json` (`{ countries: [...], libphonenumberVersion }`).
  The TS build consumes this JSON (copied or imported into `js/src/data/`).
- **IBAN:** `tool/gen_iban_metadata.py` gains a JSON output —
  `iban-metadata.json` holding `kIbanBban` (incl. `example`) and `kBanks`
  (the nested `country → code → { name, bic }` map) — the exact same data it
  emits into `iban_metadata.g.dart`.
- **Email / URL / credit-card:** no bundled data; pure algorithms.

Generated JSON is committed under `js/src/data/`. Because Dart and TS consume
data emitted by one generator run, they cannot drift.

### Bundle strategy (browser)

- `"sideEffects": false` and subpath exports (`/email`, `/phone`, `/url`,
  `/iban`, `/credit-card`) so a bundler includes only imported modules.
- The large datasets are reachable only through their module: phone metadata
  (~307 KB) is imported solely by the phone module; the IBAN bank directory
  (~5 500 entries) solely by the iban module. A React app using only
  `iban` + `email` ships neither the phone metadata nor an unused module.
- Data is imported as JSON modules so bundlers can statically include exactly
  what is referenced.

## Conformance testing

The guarantee of parity is a vitest suite that loads the repository's existing
`test/vectors/*.json` (relative path `../../test/vectors`) and runs the TS
implementation against each vector — the same files the Dart `vectors_test.dart`
consumes. Coverage: `email`, `url`, `credit_card`, `iban` (incl. `parse`
fields), `phone`, `phone_global`.

Additional TS-only tests: type-level smoke tests, `IbanCountry` invariants (every
example valid), and a tree-shaking smoke check (importing `/iban` does not pull
phone metadata).

## Build, tooling, CI

- **Build:** `tsup` → ESM + CJS + `.d.ts`, target ES2020.
- **Test:** `vitest`. **Lint/format:** `eslint` + `prettier`.
- **CI:** a workflow that runs the Dart suite and the JS suite (both against the
  shared vectors) so cross-language drift fails the build. (Add the workflow file;
  wiring it to a CI provider is the maintainer's step.)
- **Publish:** `npm publish --access public` under the `@kreiseck` scope — done
  manually by the maintainer; the implementation never publishes.

## Versioning

`@kreiseck/validator` starts at `0.6.0` to signal parity with the current Dart
feature set. Thereafter the two packages are versioned together when a change
affects both.

## No-footprint constraint

As with the Dart package: no reference to AI, assistants, or code-generation
tools anywhere in code, comments, docs, file names, commit messages, or package
metadata. Output must read as hand-written.

## Out of scope (later)

- React-specific helpers (hooks, `react-hook-form`/`zod` resolvers). The core is
  framework-agnostic; adapters can follow.
- Publishing to npm (maintainer action).
- Any change to the Dart package's runtime behaviour.

## Implementation stages

One plan, executed task-by-task, phone deliberately late and isolated:

1. Scaffold `js/` — package.json, tsconfig, tsup, vitest, `common` types
   (`ValidationResult`, `IssueCode`, `Suggestion`, `FormatError`), empty
   `index.ts`, subpath export map.
2. Extend `tool/gen_iban_metadata.py` to emit `iban-metadata.json`; commit the
   generated JSON under `js/src/data/`.
3. Port `email` + conformance against `email.json`.
4. Port `url` + conformance against `url.json`.
5. Port `credit_card` + conformance against `credit_card.json`.
6. Port `iban` (validate/normalize/format/parse) + conformance against
   `iban.json`.
7. Port `IbanCountry` + its tests.
8. Port `phone` (parse/format/type + global metadata) + conformance against
   `phone.json` and `phone_global.json`.
9. Build verification, tree-shaking smoke test, CI workflow, `js/README.md`.
