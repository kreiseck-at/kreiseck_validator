# TypeScript npm Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `@kreiseck/validator` — a TypeScript npm package under `js/` that ports every module of the Dart `kreiseck_validator` and is proven byte-identical by running against the shared `test/vectors/*.json`.

**Architecture:** Each Dart module (`lib/src/<m>/<m>.dart`) is translated to a TS module (`js/src/<m>/index.ts`) preserving behaviour exactly. Bundled data (phone, IBAN) is emitted as JSON by the existing Python generators and consumed by the TS modules. Parity is enforced per module by a vitest conformance spec over the corresponding vector file.

**Tech Stack:** TypeScript (ES2020), tsup (ESM+CJS+dts), vitest; Python 3 generators (unchanged logic, add JSON output).

## Global Constraints

- **The Dart sources are the authoritative behaviour spec.** A port is correct when its module passes the same `test/vectors/*.json` its Dart counterpart passes, with identical results. Do not "improve" or change behaviour.
- **Zero runtime dependencies** in the published package. `dependencies: {}` in `js/package.json`; only `devDependencies` (typescript, tsup, vitest, eslint, prettier). No polyfills, no `fs`/DOM/network at runtime — pure functions + embedded JSON.
- **No AI/tool attribution** anywhere — code, comments, docs, file names, commit messages, package.json fields. Output reads as hand-written.
- **API parity:** method names match Dart exactly (`isValid`/`validate`/`normalize`/`format`/`tryFormat`/`parse`/`type`). `normalize`/`format` throw `FormatError` on invalid input; `tryFormat` returns `null`.
- **`ValidationResult`** is the discriminated union `{ ok: true; normalized; suggestions } | { ok: false; issues }`. `IssueCode` is a string-literal union with exactly the Dart enum's names.
- **Package name** `@kreiseck/validator`, version `0.6.0`. **Never run `npm publish`.**
- **Tree-shaking:** `"sideEffects": false`; subpath exports per module; large data reachable only via its module.
- The Dart package at the repo root stays behaviourally unchanged; only `tool/*.py` gain JSON emission.

---

### Task 1: Scaffold the `js/` package and common types

**Files:**
- Create: `js/package.json`, `js/tsconfig.json`, `js/tsup.config.ts`, `js/vitest.config.ts`, `js/.gitignore`
- Create: `js/src/common/types.ts`, `js/src/common/errors.ts`, `js/src/index.ts`
- Test: `js/test/common.spec.ts`

**Interfaces:**
- Produces: `type ValidationResult`, `interface ValidationIssue`, `interface Suggestion`, `type IssueCode`, `class FormatError extends Error`, and helper constructors `valid(normalized, suggestions?)` / `invalid(code, message)` used by every module.

- [ ] **Step 1: Create `js/package.json`**

```json
{
  "name": "@kreiseck/validator",
  "version": "0.6.0",
  "description": "Validate, normalize and format email, phone, URL, IBAN and credit-card input. Zero dependencies, DACH-aware.",
  "license": "Apache-2.0",
  "type": "module",
  "sideEffects": false,
  "files": ["dist"],
  "exports": {
    ".":            { "types": "./dist/index.d.ts",       "import": "./dist/index.js",       "require": "./dist/index.cjs" },
    "./email":      { "types": "./dist/email/index.d.ts", "import": "./dist/email/index.js", "require": "./dist/email/index.cjs" },
    "./phone":      { "types": "./dist/phone/index.d.ts", "import": "./dist/phone/index.js", "require": "./dist/phone/index.cjs" },
    "./url":        { "types": "./dist/url/index.d.ts",   "import": "./dist/url/index.js",   "require": "./dist/url/index.cjs" },
    "./iban":       { "types": "./dist/iban/index.d.ts",  "import": "./dist/iban/index.js",  "require": "./dist/iban/index.cjs" },
    "./credit-card":{ "types": "./dist/credit-card/index.d.ts", "import": "./dist/credit-card/index.js", "require": "./dist/credit-card/index.cjs" }
  },
  "scripts": {
    "build": "tsup",
    "test": "vitest run",
    "lint": "eslint src test"
  },
  "devDependencies": {
    "tsup": "^8.0.0",
    "typescript": "^5.4.0",
    "vitest": "^1.6.0"
  }
}
```

- [ ] **Step 2: Create `js/tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "declaration": true,
    "resolveJsonModule": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "outDir": "dist"
  },
  "include": ["src", "test"]
}
```

- [ ] **Step 3: Create `js/tsup.config.ts`**

```ts
import { defineConfig } from 'tsup';

export default defineConfig({
  entry: [
    'src/index.ts',
    'src/email/index.ts',
    'src/phone/index.ts',
    'src/url/index.ts',
    'src/iban/index.ts',
    'src/credit-card/index.ts',
  ],
  format: ['esm', 'cjs'],
  dts: true,
  clean: true,
  treeshake: true,
});
```

- [ ] **Step 4: Create `js/vitest.config.ts` and `js/.gitignore`**

`js/vitest.config.ts`:

```ts
import { defineConfig } from 'vitest/config';

export default defineConfig({ test: { include: ['test/**/*.spec.ts'] } });
```

`js/.gitignore`:

```
node_modules
dist
```

- [ ] **Step 5: Create the common types**

`js/src/common/types.ts` — mirror `lib/src/common/issue_code.dart` and `lib/src/common/validation_result.dart`. `IssueCode` must list EVERY name from the Dart enum (read `lib/src/common/issue_code.dart` and copy them verbatim):

```ts
export type IssueCode =
  | 'emailEmpty' | 'emailMissingAt' | 'emailMultipleAt' | 'emailEmptyLocal' | 'emailBadDomain'
  | 'phoneEmpty' | 'phoneBadChars' | 'phoneTooShort' | 'phoneTooLong'
  | 'phoneAmbiguousCountry' | 'phoneUnknownCountry' | 'phoneInvalid'
  | 'urlEmpty' | 'urlBadScheme' | 'urlBadHost' | 'urlBadTld'
  | 'ibanEmpty' | 'ibanBadChars' | 'ibanBadChecksum' | 'ibanBadLength'
  | 'cardEmpty' | 'cardBadChars' | 'cardBadLength' | 'cardBadLuhn';

export interface ValidationIssue { readonly code: IssueCode; readonly message: string }
export interface Suggestion { readonly value: string; readonly reason: string }

export type ValidationResult =
  | { readonly ok: true; readonly normalized: string; readonly suggestions: Suggestion[] }
  | { readonly ok: false; readonly issues: ValidationIssue[] };

export function valid(normalized: string, suggestions: Suggestion[] = []): ValidationResult {
  return { ok: true, normalized, suggestions };
}

export function invalid(code: IssueCode, message: string): ValidationResult {
  return { ok: false, issues: [{ code, message }] };
}
```

`js/src/common/errors.ts`:

```ts
/// Thrown by normalize/format on invalid input (mirrors Dart's FormatException).
export class FormatError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'FormatError';
  }
}
```

- [ ] **Step 6: Create the barrel `js/src/index.ts`**

Start with only the common re-exports; module namespaces are added as each module lands:

```ts
export * from './common/types';
export { FormatError } from './common/errors';
```

- [ ] **Step 7: Write a smoke test**

`js/test/common.spec.ts`:

```ts
import { describe, it, expect } from 'vitest';
import { valid, invalid, FormatError } from '../src/index';

describe('common', () => {
  it('builds valid/invalid results', () => {
    const v = valid('X', []);
    expect(v.ok).toBe(true);
    const i = invalid('emailEmpty', 'Email is empty.');
    expect(i.ok).toBe(false);
    if (!i.ok) expect(i.issues[0].code).toBe('emailEmpty');
  });
  it('FormatError carries a name', () => {
    expect(new FormatError('x').name).toBe('FormatError');
  });
});
```

- [ ] **Step 8: Install, test, build**

Run (in `js/`): `npm install && npm test && npm run build`
Expected: install succeeds; the smoke test passes; `tsup` produces `dist/` with ESM+CJS+dts (the empty module entries build as empty for now — that is fine).

- [ ] **Step 9: Commit**

```bash
git add js/package.json js/tsconfig.json js/tsup.config.ts js/vitest.config.ts \
        js/.gitignore js/src/common js/src/index.ts js/test/common.spec.ts
git commit -m "Scaffold @kreiseck/validator TypeScript package"
```

Note: `js/package-lock.json` may be created by `npm install`; commit it too if present.

---

### Task 2: Emit bundled data as JSON for the TS build

**Files:**
- Modify: `tool/gen_iban_metadata.py` (also write `js/src/data/iban-metadata.json`)
- Modify: `tool/gen_phone_metadata.py` (also write `js/src/data/phone-metadata.json`)
- Create (generated, committed): `js/src/data/iban-metadata.json`, `js/src/data/phone-metadata.json`
- Test: `js/test/data.spec.ts`

**Interfaces:**
- Produces: `js/src/data/iban-metadata.json` shaped `{ "bban": { ISO2: { length, bankStart, bankEnd, branchStart, branchEnd, example } }, "banks": { ISO2: { code: { name, bic } } } }`, and `js/src/data/phone-metadata.json` = the existing phone `metadata.json` content (`{ countries: [...], libphonenumberVersion }`).

- [ ] **Step 1: Add IBAN JSON emission to the generator**

In `tool/gen_iban_metadata.py`, add `import json` (near the other imports) and a JSON output path constant next to `OUT`:

```python
JSON_OUT = os.path.join(ROOT, "js", "src", "data", "iban-metadata.json")
```

At the end of `main()` (after the existing `.g.dart` is written and before/after the final `print`), add:

```python
    bban_json = {
        cc: {
            "length": e["length"],
            "bankStart": e["bank_start"],
            "bankEnd": e["bank_end"],
            "branchStart": e["branch_start"],
            "branchEnd": e["branch_end"],
            "example": e["example"],
        }
        for cc, e in structures.items()
    }
    banks_json = {
        cc: {code: {"name": n, "bic": b} for code, (n, b) in directories[cc][1].items()}
        for cc in directories
    }
    os.makedirs(os.path.dirname(JSON_OUT), exist_ok=True)
    with open(JSON_OUT, "w", encoding="utf-8") as f:
        json.dump({"bban": bban_json, "banks": banks_json}, f,
                  ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    print(f"Wrote {JSON_OUT}")
```

- [ ] **Step 2: Add phone JSON emission to the phone generator**

In `tool/gen_phone_metadata.py`, locate where it writes `JSON_OUT` (the `lib/src/phone/data/metadata.json` path). Add a second output path constant near it:

```python
JS_JSON_OUT = os.path.join(ROOT, "js", "src", "data", "phone-metadata.json")
```

and, immediately after it writes the existing `metadata.json`, write the same payload to `JS_JSON_OUT` (create the directory first with `os.makedirs(os.path.dirname(JS_JSON_OUT), exist_ok=True)`). Read the file first to match the exact variable holding the payload and its `json.dump` arguments, and reuse them verbatim.

- [ ] **Step 3: Generate the IBAN JSON**

Run the IBAN generator with the pre-staged sources (see dispatch notes for the interpreter + `--csv`/`--de-csv`/`--de-date`/`--ch-csv` paths). It now prints an extra `Wrote .../js/src/data/iban-metadata.json` line and creates that file.

- [ ] **Step 4: Produce the phone JSON without re-running the heavy phone generator**

The phone metadata is unchanged and already committed at `lib/src/phone/data/metadata.json`. Copy it to the JS data dir (the Step-2 generator change keeps future regenerations in sync, but for now avoid re-running the phonenumbers-based generator):

```bash
mkdir -p js/src/data
cp lib/src/phone/data/metadata.json js/src/data/phone-metadata.json
```

- [ ] **Step 5: Write a data sanity test**

`js/test/data.spec.ts`:

```ts
import { describe, it, expect } from 'vitest';
import iban from '../src/data/iban-metadata.json';
import phone from '../src/data/phone-metadata.json';

describe('bundled data', () => {
  it('IBAN metadata has bban + banks with AT/DE/CH', () => {
    expect(iban.bban.AT.length).toBe(20);
    expect(iban.bban.AT.example).toBe('AT611904300234573201');
    expect(iban.banks.AT['12000']).toEqual({ name: 'UniCredit Bank Austria AG', bic: 'BKAUATWW' });
    expect(iban.banks.DE['37040044']).toEqual({ name: 'Commerzbank', bic: 'COBADEFF' });
    expect(iban.banks.CH['00100'].bic).toBe('SNBZCHZZ');
  });
  it('phone metadata has a countries array', () => {
    expect(Array.isArray(phone.countries)).toBe(true);
    expect(phone.countries.length).toBeGreaterThan(200);
  });
});
```

- [ ] **Step 6: Test**

Run (in `js/`): `npm test`
Expected: the data spec passes.

- [ ] **Step 7: Commit**

```bash
git add tool/gen_iban_metadata.py tool/gen_phone_metadata.py \
        js/src/data/iban-metadata.json js/src/data/phone-metadata.json js/test/data.spec.ts
git commit -m "Emit IBAN and phone metadata as JSON for the TS build"
```

---

### Task 3: Port the `email` module

**Files:**
- Create: `js/src/email/index.ts`
- Modify: `js/src/index.ts` (export `Email`)
- Test: `js/test/email.conformance.spec.ts`

**Interfaces:**
- Consumes: `common/types`.
- Produces: `export const Email = { isValid, validate, normalize }` where `validate(input): ValidationResult`, `normalize(input): string`, `isValid(input): boolean`. Includes the offline typo-domain suggestion.

- [ ] **Step 1: Write the conformance test**

`js/test/email.conformance.spec.ts` — the shared vector runner pattern for this module:

```ts
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Email } from '../src/email/index';

type Vec = { input: string; isValid?: boolean; code?: string; normalized?: string };
const vectors: Vec[] = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../test/vectors/email.json', import.meta.url)), 'utf8'),
);

describe('email conformance', () => {
  for (const v of vectors) {
    it(`email: ${v.input}`, () => {
      const r = Email.validate(v.input);
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
    });
  }
});
```

- [ ] **Step 2: Run to verify it fails**

Run (in `js/`): `npx vitest run test/email.conformance.spec.ts`
Expected: FAIL — `../src/email/index` does not exist.

- [ ] **Step 3: Port `lib/src/email/email.dart` to `js/src/email/index.ts`**

Read `lib/src/email/email.dart` and translate it faithfully to TypeScript: same `_knownDomains` list, same Damerau/OSA `_distance`, same `_closeDomain`, same `validate` logic and issue codes, `normalize = input.trim().toLowerCase()`. Use the `valid`/`invalid` helpers from `common/types`; suggestion reason is `'typo-domain'`. Export `const Email = { isValid, validate, normalize }`. Do not add operations the Dart module lacks (no `format` on email).

- [ ] **Step 4: Export from the barrel**

In `js/src/index.ts`, add `export { Email } from './email/index';`.

- [ ] **Step 5: Run the conformance test + build**

Run (in `js/`): `npx vitest run test/email.conformance.spec.ts && npm run build`
Expected: all email vectors pass; build clean.

- [ ] **Step 6: Commit**

```bash
git add js/src/email js/src/index.ts js/test/email.conformance.spec.ts
git commit -m "Port email module to TypeScript"
```

---

### Task 4: Port the `url` module

**Files:**
- Create: `js/src/url/index.ts`
- Modify: `js/src/index.ts`
- Test: `js/test/url.conformance.spec.ts`

**Interfaces:**
- Produces: `export const Url = { isValid, validate, normalize, format, tryFormat }`. `validate`/`normalize` accept an optional `{ defaultScheme?: string }` (default `'https'`); `format` throws `FormatError`, `tryFormat` returns null.

- [ ] **Step 1: Write the conformance test**

`js/test/url.conformance.spec.ts` — same runner shape as Task 3 but for `url.json`, additionally checking `format` when the vector has a `format` key:

```ts
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Url } from '../src/url/index';

type Vec = { input: string; isValid?: boolean; code?: string; normalized?: string; format?: string };
const vectors: Vec[] = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../test/vectors/url.json', import.meta.url)), 'utf8'),
);

describe('url conformance', () => {
  for (const v of vectors) {
    it(`url: ${v.input}`, () => {
      const r = Url.validate(v.input);
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
      if (v.format !== undefined) expect(Url.format(v.input)).toBe(v.format);
    });
  }
});
```

- [ ] **Step 2: Run to verify it fails**

Run (in `js/`): `npx vitest run test/url.conformance.spec.ts`
Expected: FAIL — module missing.

- [ ] **Step 3: Port `lib/src/url/url.dart` to `js/src/url/index.ts`**

Read `lib/src/url/url.dart` and translate faithfully: `_parts` (scheme/hostToken/tail split on the first of `/ ? #`), `_hostname`, `validate({ defaultScheme })`, `normalize({ defaultScheme })` (lower-case host, strip a single trailing slash from a bare path), `format` (drop scheme, leading `www.`, trailing slash) throwing `FormatError`, `tryFormat`. Same regexes and issue codes. Export `const Url = { isValid, validate, normalize, format, tryFormat }`.

- [ ] **Step 4: Export from the barrel**

Add `export { Url } from './url/index';` to `js/src/index.ts`.

- [ ] **Step 5: Run + build**

Run (in `js/`): `npx vitest run test/url.conformance.spec.ts && npm run build`
Expected: all url vectors pass; build clean.

- [ ] **Step 6: Commit**

```bash
git add js/src/url js/src/index.ts js/test/url.conformance.spec.ts
git commit -m "Port url module to TypeScript"
```

---

### Task 5: Port the `credit-card` module

**Files:**
- Create: `js/src/credit-card/index.ts`
- Modify: `js/src/index.ts`
- Test: `js/test/credit-card.conformance.spec.ts`

**Interfaces:**
- Produces: `export const CreditCard = { isValid, validate, normalize, format, tryFormat, network }`; `export type CardNetwork = 'visa' | 'mastercard' | 'amex' | 'discover' | 'unknown'`. `network(input): CardNetwork | null`.

- [ ] **Step 1: Write the conformance test**

`js/test/credit-card.conformance.spec.ts` — same shape as Task 4 (checks `isValid`/`code`/`normalized`/`format`) but loading `credit_card.json` and using `CreditCard`.

```ts
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { CreditCard } from '../src/credit-card/index';

type Vec = { input: string; isValid?: boolean; code?: string; normalized?: string; format?: string };
const vectors: Vec[] = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../test/vectors/credit_card.json', import.meta.url)), 'utf8'),
);

describe('credit-card conformance', () => {
  for (const v of vectors) {
    it(`credit_card: ${v.input}`, () => {
      const r = CreditCard.validate(v.input);
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
      if (v.format !== undefined) expect(CreditCard.format(v.input)).toBe(v.format);
    });
  }
});
```

- [ ] **Step 2: Run to verify it fails**

Run (in `js/`): `npx vitest run test/credit-card.conformance.spec.ts`
Expected: FAIL — module missing.

- [ ] **Step 3: Port `lib/src/credit_card/credit_card.dart`**

Read it and translate faithfully: `CardNetwork` as a string-literal union; `network()` detection (Visa `4`, Amex `34/37`, Mastercard `51-55`/`2221-2720`, Discover `6011/65/644-649`), `_luhnOk`, per-network length sets, the unknown-network 12–19 length guard, and the Amex `4-6-5` vs `4-4-4-4` grouping in `format`. Same issue codes. Export `const CreditCard = { isValid, validate, normalize, format, tryFormat, network }`.

- [ ] **Step 4: Export from the barrel**

Add `export { CreditCard, type CardNetwork } from './credit-card/index';` to `js/src/index.ts`.

- [ ] **Step 5: Run + build**

Run (in `js/`): `npx vitest run test/credit-card.conformance.spec.ts && npm run build`
Expected: all credit-card vectors pass; build clean.

- [ ] **Step 6: Commit**

```bash
git add js/src/credit-card js/src/index.ts js/test/credit-card.conformance.spec.ts
git commit -m "Port credit-card module to TypeScript"
```

---

### Task 6: Port the `iban` module (validate/normalize/format/parse)

**Files:**
- Create: `js/src/iban/index.ts`, `js/src/iban/metadata.ts` (typed loader over `data/iban-metadata.json`)
- Modify: `js/src/index.ts`
- Test: `js/test/iban.conformance.spec.ts`

**Interfaces:**
- Consumes: `js/src/data/iban-metadata.json` (Task 2).
- Produces: `export const Iban = { isValid, validate, normalize, format, tryFormat, parse }`; `export interface IbanInfo { country; checkDigits; bankCode; branchCode; accountNumber; bankName; bic; formatted }` (nullable string fields where the Dart type is nullable, `country` a `Country`-like `{ iso2, ... }` or its ISO2 — see below). `parse(input): IbanInfo | null`.
- `js/src/iban/metadata.ts` exposes `kIbanBban: Record<string, IbanBban>` and `kBanks: Record<string, Record<string, { name: string; bic: string }>>` typed views of the JSON, where `IbanBban = { length; bankStart; bankEnd; branchStart: number|null; branchEnd: number|null; example: string }`.

- [ ] **Step 1: Write the conformance test**

`js/test/iban.conformance.spec.ts` loads `iban.json`, checks `isValid`/`code`/`normalized`/`format`, and — when a vector has a `parse` object — checks `Iban.parse` fields (`country` via the info's country ISO2, `checkDigits`, `bankCode`, `branchCode`, `accountNumber`, `bankName`, `bic`):

```ts
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Iban } from '../src/iban/index';

type Parse = { country: string; checkDigits: string; bankCode: string | null; branchCode: string | null; accountNumber: string | null; bankName: string | null; bic: string | null };
type Vec = { input: string; isValid?: boolean; code?: string; normalized?: string; format?: string; parse?: Parse };
const vectors: Vec[] = JSON.parse(
  readFileSync(fileURLToPath(new URL('../../test/vectors/iban.json', import.meta.url)), 'utf8'),
);

describe('iban conformance', () => {
  for (const v of vectors) {
    it(`iban: ${v.input}`, () => {
      const r = Iban.validate(v.input);
      if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
      if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
      if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
      if (v.format !== undefined) expect(Iban.format(v.input)).toBe(v.format);
      if (v.parse) {
        const info = Iban.parse(v.input)!;
        expect(info.country).toBe(v.parse.country); // country exposed as ISO2 string
        expect(info.checkDigits).toBe(v.parse.checkDigits);
        expect(info.bankCode).toBe(v.parse.bankCode);
        expect(info.branchCode).toBe(v.parse.branchCode);
        expect(info.accountNumber).toBe(v.parse.accountNumber);
        expect(info.bankName).toBe(v.parse.bankName);
        expect(info.bic).toBe(v.parse.bic);
      }
    });
  }
});
```

Note the decision baked into the test: in TS, `IbanInfo.country` is the **ISO2 string** (the vectors store `"country": "AT"`), not a `Country` object — simpler and matches the vector. Document this in the type.

- [ ] **Step 2: Run to verify it fails**

Run (in `js/`): `npx vitest run test/iban.conformance.spec.ts`
Expected: FAIL — module missing.

- [ ] **Step 3: Create the typed metadata loader**

`js/src/iban/metadata.ts`:

```ts
import data from '../data/iban-metadata.json';

export interface IbanBban {
  length: number;
  bankStart: number;
  bankEnd: number;
  branchStart: number | null;
  branchEnd: number | null;
  example: string;
}
export interface Bank { name: string; bic: string }

export const kIbanBban = data.bban as Record<string, IbanBban>;
export const kBanks = data.banks as Record<string, Record<string, Bank>>;
```

- [ ] **Step 4: Port `lib/src/iban/iban.dart` to `js/src/iban/index.ts`**

Read `lib/src/iban/iban.dart` and translate faithfully:
- `strip` (remove whitespace, upper-case), the `^[A-Z]{2}[0-9]{2}[0-9A-Z]+$` structure check, the Mod-97 `checksumOk` (letters A–Z → 10–35, 7-digit chunking, remainder == 1).
- `validate`: empty → `ibanEmpty`; bad chars → `ibanBadChars`; length from `kIbanBban[country]?.length` → `ibanBadLength`; checksum → `ibanBadChecksum`; else `valid(compact)`.
- `normalize`/`format` (4-group) throwing `FormatError`; `tryFormat`.
- `parse`: mirror the Dart `parse` — resolve country (ISO2 string, null-guard: return null if the code has no entry we can describe; since the vectors only exercise AT/DE/CH/US, use the ISO2 directly and never return null for a valid IBAN), split via `kIbanBban` offsets (zero-width bank slice → null), enrich via `kBanks[code]?.[bankCode]`, `formatted` = 4-grouped.

Expose `interface IbanInfo { country: string; checkDigits: string; bankCode: string | null; branchCode: string | null; accountNumber: string | null; bankName: string | null; bic: string | null; formatted: string }` and `const Iban = { isValid, validate, normalize, format, tryFormat, parse }`.

- [ ] **Step 5: Export from the barrel**

Add `export { Iban, type IbanInfo } from './iban/index';` to `js/src/index.ts`.

- [ ] **Step 6: Run + build**

Run (in `js/`): `npx vitest run test/iban.conformance.spec.ts && npm run build`
Expected: all iban vectors (incl. the three `parse` cases: AT enriched, DE enriched, CH enriched, plus the invalid ones) pass; build clean.

- [ ] **Step 7: Commit**

```bash
git add js/src/iban js/src/index.ts js/test/iban.conformance.spec.ts
git commit -m "Port iban module to TypeScript"
```

---

### Task 7: Port `IbanCountry`

**Files:**
- Create: `js/src/iban/country.ts`
- Modify: `js/src/index.ts`, `js/src/iban/index.ts` (re-export if grouping under the iban subpath)
- Test: `js/test/iban-country.spec.ts`

**Interfaces:**
- Consumes: `kIbanBban` (Task 6 metadata).
- Produces: `export interface IbanCountry { iso2; length; bankCodeLength; branchCodeLength: number | null; accountLength; example; hasBranchCode }` and `export const IbanCountry = { of(code: string): IbanCountry | null; values(): IbanCountry[] }`.

- [ ] **Step 1: Write the test**

`js/test/iban-country.spec.ts` — mirror the Dart `test/iban_country_test.dart`:

```ts
import { describe, it, expect } from 'vitest';
import { IbanCountry } from '../src/iban/country';
import { Iban } from '../src/iban/index';

describe('IbanCountry', () => {
  it('describes the Austrian format', () => {
    const at = IbanCountry.of('AT')!;
    expect(at.iso2).toBe('AT');
    expect(at.length).toBe(20);
    expect(at.bankCodeLength).toBe(5);
    expect(at.branchCodeLength).toBeNull();
    expect(at.accountLength).toBe(11);
    expect(at.hasBranchCode).toBe(false);
    expect(at.example).toBe('AT61 1904 3002 3457 3201');
  });
  it('exposes a branch length for IT', () => {
    const it = IbanCountry.of('IT')!;
    expect(it.bankCodeLength).toBe(5);
    expect(it.branchCodeLength).toBe(5);
    expect(it.hasBranchCode).toBe(true);
  });
  it('is case-insensitive and null for unknown', () => {
    expect(IbanCountry.of('at')!.iso2).toBe('AT');
    expect(IbanCountry.of('XX')).toBeNull();
    expect(IbanCountry.of('US')).toBeNull();
  });
  it('every example is valid and values is sorted', () => {
    const values = IbanCountry.values();
    expect(values.length).toBeGreaterThan(100);
    for (const c of values) expect(Iban.isValid(c.example)).toBe(true);
    const codes = values.map((c) => c.iso2);
    expect(codes).toEqual([...codes].sort());
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run (in `js/`): `npx vitest run test/iban-country.spec.ts`
Expected: FAIL — module missing.

- [ ] **Step 3: Port `lib/src/iban/iban_country.dart` to `js/src/iban/country.ts`**

Read the Dart file and translate: derive `bankCodeLength = bankEnd - bankStart`, `branchCodeLength = branchStart == null ? null : branchEnd! - branchStart`, `accountLength = length - (branchEnd ?? bankEnd)`, `example` = the compact `IbanBban.example` grouped into fours; `of` upper-cases and returns null when absent; `values` = sorted keys mapped. Keep the doc note that field lengths need not sum to `length` (IT/SM national check char).

- [ ] **Step 4: Export from the barrel + iban subpath**

Add `export { IbanCountry, type IbanCountry as IbanCountryType } from './iban/country';` — actually export the value and interface cleanly: in `js/src/index.ts` add `export { IbanCountry } from './iban/country';` and `export type { IbanCountry as IbanCountryInfo } from './iban/country';` only if a name clash arises; otherwise a single `export { IbanCountry } from './iban/country';` plus `export type { IbanCountry } from './iban/country';` is fine since one is a value and one a type with the same name (allowed in TS). Also re-export from `js/src/iban/index.ts` so `@kreiseck/validator/iban` exposes it.

- [ ] **Step 5: Run + build**

Run (in `js/`): `npx vitest run test/iban-country.spec.ts && npm run build`
Expected: pass; build clean.

- [ ] **Step 6: Commit**

```bash
git add js/src/iban js/src/index.ts js/test/iban-country.spec.ts
git commit -m "Port IbanCountry to TypeScript"
```

---

### Task 8: Port the `phone` module

**Files:**
- Create: `js/src/phone/metadata.ts`, `js/src/phone/country.ts`, `js/src/phone/types.ts`, `js/src/phone/index.ts`
- Modify: `js/src/index.ts`
- Test: `js/test/phone.conformance.spec.ts`

**Interfaces:**
- Consumes: `js/src/data/phone-metadata.json`.
- Produces: `export const Phone = { isValid, validate, normalize, format, tryFormat, type, parse }`; `export interface Country { iso2; callingCode; displayName; nationalPrefix; possibleLengths; pattern; formats; intlFormats; example… }`; `export type PhoneNumberType`; `export interface PhoneInfo`.

- [ ] **Step 1: Write the conformance test**

`js/test/phone.conformance.spec.ts` loads BOTH `phone.json` and `phone_global.json` and mirrors `test/vectors_test.dart`'s phone handling: each vector may carry `country` (ISO2, passed as the `country` option), `international` (bool, default true, for `format`), `isValid`, `code`, `normalized`, `format`, and `type`.

```ts
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Phone } from '../src/phone/index';

type Vec = { input: string; country?: string; international?: boolean; isValid?: boolean; code?: string; normalized?: string; format?: string; type?: string };
function load(name: string): Vec[] {
  return JSON.parse(readFileSync(fileURLToPath(new URL(`../../test/vectors/${name}`, import.meta.url)), 'utf8'));
}

for (const file of ['phone.json', 'phone_global.json']) {
  describe(`phone conformance (${file})`, () => {
    for (const v of load(file)) {
      it(`${file}: ${v.input}`, () => {
        const opts = { country: v.country };
        const r = Phone.validate(v.input, opts);
        if (v.isValid !== undefined) expect(r.ok).toBe(v.isValid);
        if (v.code !== undefined) expect(r.ok ? undefined : r.issues[0].code).toBe(v.code);
        if (v.normalized !== undefined && r.ok) expect(r.normalized).toBe(v.normalized);
        if (v.format !== undefined) {
          const international = v.international ?? true;
          expect(Phone.format(v.input, { ...opts, international })).toBe(v.format);
        }
        if (v.type !== undefined) expect(Phone.type(v.input, opts).valueOf()).toBe(v.type);
      });
    }
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run (in `js/`): `npx vitest run test/phone.conformance.spec.ts`
Expected: FAIL — module missing.

- [ ] **Step 3: Port the phone metadata + `Country` type**

Read `lib/src/common/country.dart`, `lib/src/phone/phone_format.dart`, `lib/src/phone/phone_number_type.dart`, `lib/src/phone/phone_info.dart`. Create:
- `js/src/phone/types.ts` — `Country`, `PhoneFormat`, `PhoneNumberType` (string-literal union of the Dart enum names), `PhoneInfo` interfaces.
- `js/src/phone/metadata.ts` — load `../data/phone-metadata.json`, expose `countries: Country[]`, `fromIso2(code): Country | null`, `fromCallingCode(cc): Country | null`, and the `mainForCallingCode` map, matching `country.dart`'s helpers.
- `js/src/phone/country.ts` if AT-classification data lives separately (mirror whatever `country.g.dart` + the AT numbering carry). Read `lib/src/phone/phone.dart` to see exactly what classification data it uses (`AtNumbering.classify`) and where it comes from, and port that.

- [ ] **Step 4: Port `lib/src/phone/phone.dart` to `js/src/phone/index.ts`**

Read `lib/src/phone/phone.dart` fully and translate faithfully: `_allowedChars`, `_digits`, `_matchesPattern`, `_lengthOk`, `_resolve` (country + national-significant-number resolution, including the `+43 (0)…` trunk handling and calling-code inference), `validate`, `normalize` (E.164), `format({ country, international })` (national ↔ international via the country's `formats`/`intlFormats` rules), `tryFormat`, `type` (AT classification via the ported numbering data, `unknown` elsewhere), and `parse` → `PhoneInfo`. The `country` option is an ISO2 string (the vectors pass ISO2); resolve it via `metadata.fromIso2`. Export `const Phone = { isValid, validate, normalize, format, tryFormat, type, parse }`.

This is the largest module — expect to iterate against the conformance vectors until every case in `phone.json` (DACH incl. AT type classification) and `phone_global.json` (cross-country) passes.

- [ ] **Step 5: Export from the barrel**

Add to `js/src/index.ts`:

```ts
export { Phone } from './phone/index';
export type { Country, PhoneInfo, PhoneNumberType } from './phone/types';
```

- [ ] **Step 6: Run the conformance + build**

Run (in `js/`): `npx vitest run test/phone.conformance.spec.ts && npm run build`
Expected: every `phone.json` and `phone_global.json` vector passes; build clean.

- [ ] **Step 7: Commit**

```bash
git add js/src/phone js/src/index.ts js/test/phone.conformance.spec.ts
git commit -m "Port phone module to TypeScript"
```

---

### Task 9: Build verification, tree-shaking smoke test, CI, README

**Files:**
- Create: `js/test/treeshaking.spec.ts`
- Create: `js/README.md`
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: the whole built package. No new runtime code.

- [ ] **Step 1: Full suite + build from clean**

Run (in `js/`): `rm -rf dist && npm run build && npm test`
Expected: build emits `dist/index.*`, `dist/email/*`, `dist/phone/*`, `dist/url/*`, `dist/iban/*`, `dist/credit-card/*` (ESM + CJS + d.ts each); every spec passes.

- [ ] **Step 2: Tree-shaking smoke test**

`js/test/treeshaking.spec.ts` — assert that the built `dist/iban/index.js` does not inline the phone metadata (so an iban-only import stays small):

```ts
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

describe('bundle isolation', () => {
  it('the iban entry does not contain phone metadata', () => {
    const js = readFileSync(fileURLToPath(new URL('../dist/iban/index.js', import.meta.url)), 'utf8');
    // A libphonenumber-derived token that only appears in phone metadata.
    expect(js.includes('libphonenumberVersion')).toBe(false);
  });
});
```

Run (in `js/`): `npm run build && npx vitest run test/treeshaking.spec.ts`
Expected: PASS. (If it fails, the iban module is transitively importing phone data — fix the import graph so it does not.)

- [ ] **Step 3: Write `js/README.md`**

A concise README: install (`npm i @kreiseck/validator`), the four-operation API, one example per module, the subpath-import note for tree-shaking, "works in Node, browser, edge — zero dependencies", Apache-2.0. Match the tone of the root `README.md` (read it first) but keep it JS-focused. No AI/tool mentions.

- [ ] **Step 4: Add a CI workflow**

`.github/workflows/ci.yml` — a workflow with two jobs: one runs the Dart suite (`dart pub get && dart test`), one runs the JS suite (`cd js && npm ci && npm run build && npm test`). Both must pass. Do not add publish steps. Use standard `actions/checkout`, `dart-lang/setup-dart`, and `actions/setup-node` actions. Keep it minimal and provider-standard.

- [ ] **Step 5: Bump the Dart CHANGELOG note (cross-reference)**

In the root `CHANGELOG.md`, under a new top entry, note that a TypeScript port (`@kreiseck/validator`) now lives under `js/` with parity enforced by the shared vectors. (No Dart version bump — the Dart package behaviour is unchanged; this is a repo-level note. If the maintainer prefers no Dart CHANGELOG entry for a JS-only addition, keep it to one line.)

- [ ] **Step 6: Final verification**

Run: `cd js && npm test && npm run build` and, from the repo root, `dart test`.
Expected: JS suite green, build clean, Dart suite still green (171 tests).

- [ ] **Step 7: Commit**

```bash
git add js/test/treeshaking.spec.ts js/README.md .github/workflows/ci.yml CHANGELOG.md
git commit -m "Add TypeScript build verification, CI and README"
```

---

## Self-Review

**Spec coverage:**
- Monorepo `js/` layout, `@kreiseck/validator`, dual ESM/CJS + types — Task 1. ✓
- Common types (`ValidationResult` union, `IssueCode`, `FormatError`) — Task 1. ✓
- JSON data emission (IBAN + phone) from the generators — Task 2. ✓
- email / url / credit-card / iban / IbanCountry / phone ports — Tasks 3–8. ✓
- Conformance against every shared vector file — Tasks 3–8 specs. ✓
- Subpath exports + tree-shaking + smoke test — Tasks 1 & 9. ✓
- CI running both suites — Task 9. ✓
- README, version 0.6.0, no publish — Tasks 1 & 9. ✓

**Type consistency:** `ValidationResult`/`IssueCode`/`FormatError`/`valid`/`invalid` defined in Task 1 and consumed by every module. `IbanInfo.country` is an ISO2 string (decided in Task 6, used by its conformance test). `kIbanBban`/`kBanks` typed views defined in Task 6 and reused by Task 7. Module namespaces (`Email`/`Url`/`CreditCard`/`Iban`/`IbanCountry`/`Phone`) exported from the barrel incrementally.

**Placeholder scan:** the port steps intentionally say "translate the referenced Dart file" rather than inlining hundreds of lines — the Dart source in the repo is the authoritative behaviour spec and the per-module vector gate is the concrete acceptance test. All config, types, and test harnesses are given in full. No TODO/TBD left.
