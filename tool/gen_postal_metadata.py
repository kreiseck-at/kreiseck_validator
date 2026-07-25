#!/usr/bin/env python3
"""Dev-only generator for postal-code pattern metadata.

Emits, in one run:
  - lib/src/postal_code/postal_metadata.g.dart (`part of 'postal_code.dart';`,
    const Map<String, PostalPattern> kPostalPatterns).
  - js/src/data/postal-metadata.json (the same map as JSON).

`patterns` below is a curated dict of per-country postal-code formats for
European countries + Turkey, sourced from the public i18n postal-format data
(Google libaddressinput's per-country `zip` regex and `zipex` examples --
public administrative facts, not a bundled third-party package). Each entry
carries:

  - `pattern`: an anchored regex (as a string) that the CANONICAL
    (separator-applied) form must match.
  - `format`: the canonical spacing rule, in a small mini-language:
      - `''`   -- no separator; the compact (separator-stripped) form is
                  already canonical (e.g. DE `10115`).
      - `'N:C'` -- insert literal separator `C` after `N` characters from
                  the start (e.g. `'2:-'` for PL: `00950` -> `00-950`).
      - `'U'`  -- UK postcode style: insert a single space before the last
                  3 characters, regardless of total length (e.g. GB, GG,
                  GI, IM, JE: `SW1A1AA` -> `SW1A 1AA`).
  - `example` (optional): a real postal code in canonical form, curated by
    hand. Left out (`null`) when no verified real code is on hand -- an
    invented example is worse than none.

`charset` and `length` are never curated: both are derived mechanically from
`pattern` by `charset_of` / `max_length` below, so every one of the 51
countries gets them, including the 28 with no curated `example`. `length` is
the canonical formatted length (separators included); for a variable-length
pattern (the `U` rule, or `MT`'s `\\d{2,4}`) it is the MAXIMUM matchable
length.

Stdlib only -- run with the system `python3`:

    python3 tool/gen_postal_metadata.py

Not part of the shipped package (never imported by lib/ or js/src at runtime
other than the JSON data file it produces).
"""
from __future__ import annotations

import json
import os
import re

HERE = os.path.dirname(__file__)
ROOT = os.path.normpath(os.path.join(HERE, ".."))
DART_OUT = os.path.join(ROOT, "lib", "src", "postal_code", "postal_metadata.g.dart")
JSON_OUT = os.path.join(ROOT, "js", "src", "data", "postal-metadata.json")

# country -> {pattern, format}. Digit-only fixed-length countries with no
# canonical separator make up the majority; the remainder either insert a
# separator at a fixed offset from the start (`N:C`) or follow the UK
# postcode convention of a space before the last 3 characters (`U`).
patterns: dict[str, dict[str, str]] = {
    "AD": {"pattern": r"^AD[1-7]0\d$", "format": ""},
    "AL": {"pattern": r"^\d{4}$", "format": ""},
    "AT": {"pattern": r"^\d{4}$", "format": "", "example": "1010"},
    "BA": {"pattern": r"^\d{5}$", "format": ""},
    "BE": {"pattern": r"^\d{4}$", "format": "", "example": "1000"},
    "BG": {"pattern": r"^\d{4}$", "format": ""},
    "BY": {"pattern": r"^\d{6}$", "format": ""},
    "CH": {"pattern": r"^\d{4}$", "format": "", "example": "8001"},
    "CY": {"pattern": r"^\d{4}$", "format": ""},
    "CZ": {"pattern": r"^\d{3} \d{2}$", "format": "3: ", "example": "110 00"},
    "DE": {"pattern": r"^\d{5}$", "format": "", "example": "10115"},
    "DK": {"pattern": r"^\d{4}$", "format": "", "example": "1050"},
    "EE": {"pattern": r"^\d{5}$", "format": ""},
    "ES": {"pattern": r"^\d{5}$", "format": "", "example": "28001"},
    "FI": {"pattern": r"^\d{5}$", "format": "", "example": "00100"},
    "FO": {"pattern": r"^\d{3}$", "format": ""},
    "FR": {"pattern": r"^\d{5}$", "format": "", "example": "75008"},
    "GB": {
        "pattern": r"^(?:GIR|[A-Z]{1,2}\d[A-Z0-9]?) \d[ABD-HJLN-UW-Z]{2}$",
        "format": "U",
        "example": "SW1A 1AA",
    },
    "GG": {"pattern": r"^GY\d[\dA-Z]? \d[ABD-HJLN-UW-Z]{2}$", "format": "U"},
    "GI": {"pattern": r"^GX11 1AA$", "format": "U"},
    "GR": {"pattern": r"^\d{3} \d{2}$", "format": "3: ", "example": "104 31"},
    "HR": {"pattern": r"^\d{5}$", "format": "", "example": "10000"},
    "HU": {"pattern": r"^\d{4}$", "format": "", "example": "1011"},
    "IE": {"pattern": r"^[0-9A-Z]{3} [0-9A-Z]{4}$", "format": "3: ", "example": "D02 AF30"},
    "IM": {"pattern": r"^IM\d[\dA-Z]? \d[ABD-HJLN-UW-Z]{2}$", "format": "U"},
    "IS": {"pattern": r"^\d{3}$", "format": ""},
    "IT": {"pattern": r"^\d{5}$", "format": "", "example": "00184"},
    "JE": {"pattern": r"^JE\d[\dA-Z]? \d[ABD-HJLN-UW-Z]{2}$", "format": "U"},
    "LI": {"pattern": r"^(?:948[5-9]|949[0-8])$", "format": ""},
    "LT": {"pattern": r"^\d{5}$", "format": ""},
    "LU": {"pattern": r"^\d{4}$", "format": ""},
    "LV": {"pattern": r"^LV-\d{4}$", "format": "2:-"},
    "MC": {"pattern": r"^980\d{2}$", "format": ""},
    "MD": {"pattern": r"^\d{4}$", "format": ""},
    "ME": {"pattern": r"^8\d{4}$", "format": ""},
    "MK": {"pattern": r"^\d{4}$", "format": ""},
    "MT": {"pattern": r"^[A-Z]{3} \d{2,4}$", "format": "3: "},
    "NL": {"pattern": r"^[1-9]\d{3} (?:[A-RT-Z][A-Z]|S[BCE-RT-Z])$", "format": "4: ", "example": "1234 AB"},
    "NO": {"pattern": r"^\d{4}$", "format": "", "example": "0010"},
    "PL": {"pattern": r"^\d{2}-\d{3}$", "format": "2:-", "example": "00-950"},
    "PT": {"pattern": r"^\d{4}-\d{3}$", "format": "4:-", "example": "1000-001"},
    "RO": {"pattern": r"^\d{6}$", "format": ""},
    "RS": {"pattern": r"^\d{5,6}$", "format": ""},
    "RU": {"pattern": r"^\d{6}$", "format": ""},
    "SE": {"pattern": r"^\d{5}$", "format": "", "example": "11120"},
    "SI": {"pattern": r"^\d{4}$", "format": "", "example": "1000"},
    "SK": {"pattern": r"^\d{3} \d{2}$", "format": "3: ", "example": "811 01"},
    "SM": {"pattern": r"^4789\d$", "format": ""},
    "TR": {"pattern": r"^\d{5}$", "format": "", "example": "34000"},
    "UA": {"pattern": r"^\d{5}$", "format": ""},
    "VA": {"pattern": r"^00120$", "format": ""},
}

_FORMAT_RE = re.compile(r"^\d+:.$")


def _split_top(s: str, delim: str) -> list[str]:
    """Splits `s` on `delim` at paren-depth 0, ignoring delimiters inside a
    `[...]` character class or a backslash escape."""
    parts: list[str] = []
    depth = 0
    cur = ""
    in_class = False
    i = 0
    while i < len(s):
        c = s[i]
        if c == "\\":
            cur += s[i : i + 2]
            i += 2
            continue
        if c == "[" and not in_class:
            in_class = True
            cur += c
            i += 1
            continue
        if c == "]" and in_class:
            in_class = False
            cur += c
            i += 1
            continue
        if not in_class and c == "(":
            depth += 1
            cur += c
            i += 1
            continue
        if not in_class and c == ")":
            depth -= 1
            cur += c
            i += 1
            continue
        if not in_class and depth == 0 and c == delim:
            parts.append(cur)
            cur = ""
            i += 1
            continue
        cur += c
        i += 1
    parts.append(cur)
    return parts


def _parse_alt(s: str) -> int:
    """Max matched length of `s`, the top-level alternation of a group body
    (or of a whole anchored pattern with `^`/`$` already stripped)."""
    return max(_parse_seq(a) for a in _split_top(s, "|"))


def _parse_seq(s: str) -> int:
    """Max matched length of `s`, a sequence with no top-level `|`."""
    total = 0
    i = 0
    n = len(s)
    while i < n:
        c = s[i]
        if c == "\\":
            atom_len = 1
            i += 2
        elif c == "[":
            j = i + 1
            while s[j] != "]":
                if s[j] == "\\":
                    j += 1
                j += 1
            atom_len = 1
            i = j + 1
        elif c == "(":
            depth = 1
            j = i + 1
            while depth > 0:
                if s[j] == "\\":
                    j += 2
                    continue
                if s[j] == "(":
                    depth += 1
                elif s[j] == ")":
                    depth -= 1
                j += 1
            inner = s[i + 1 : j - 1]
            if inner.startswith("?:"):
                inner = inner[2:]
            atom_len = _parse_alt(inner)
            i = j
        else:
            atom_len = 1
            i += 1
        if i < n and s[i] == "?":
            i += 1  # 0 or 1 occurrence: max length is the atom itself.
        elif i < n and s[i] == "{":
            j = s.index("}", i)
            spec = s[i + 1 : j]
            if "," in spec:
                hi = spec.split(",")[1].strip()
                if hi == "":
                    raise ValueError(f"unbounded quantifier not supported: {s!r}")
                mult = int(hi)
            else:
                mult = int(spec)
            atom_len *= mult
            i = j + 1
        total += atom_len
    return total


def max_length(pattern: str) -> int:
    """The length of the longest string `pattern` (an anchored `^...$` regex,
    restricted to the small subset used by `patterns` -- literals, `\\d`,
    character classes, non-capturing groups, alternation, and `{n}`/`{n,m}`/
    `?` quantifiers) can match.

    Because every pattern here is the CANONICAL (separator-applied) form, a
    literal separator in the pattern (e.g. the space in CZ's
    `^\\d{3} \\d{2}$`) is already counted -- there is no need to add it back
    separately.
    """
    if not (pattern.startswith("^") and pattern.endswith("$")):
        raise ValueError(f"pattern not anchored: {pattern!r}")
    return _parse_alt(pattern[1:-1])


def self_check() -> None:
    if len(patterns) < 40:
        raise ValueError(f"expected >= 40 countries, got {len(patterns)}")
    for cc, meta in patterns.items():
        if cc != cc.upper() or len(cc) != 2:
            raise ValueError(f"bad country code {cc!r}")
        try:
            re.compile(meta["pattern"])
        except re.error as e:
            raise ValueError(f"{cc}: pattern does not compile: {e}") from e
        fmt = meta["format"]
        if fmt not in ("", "U") and not _FORMAT_RE.match(fmt):
            raise ValueError(f"{cc}: bad format rule {fmt!r}")
        derived_length = max_length(meta["pattern"])
        example = meta.get("example")
        if example is not None:
            if not re.match(meta["pattern"], example):
                raise ValueError(f"{cc}: example {example!r} does not match its pattern")
            if len(example) != derived_length:
                raise ValueError(
                    f"{cc}: example {example!r} has length {len(example)}, "
                    f"but the pattern's derived length is {derived_length}"
                )


def dart_str(s: str) -> str:
    """A single-quoted Dart string literal for arbitrary text."""
    return "'" + s.replace("\\", "\\\\").replace("$", "\\$").replace("'", "\\'") + "'"


def charset_of(pattern: str) -> str:
    """'digits' when the pattern can only match digits and separators."""
    stripped = re.sub(r"\\d|\{\d+(,\d+)?\}|[\^\$\(\)\?\:\|]", "", pattern)
    return "alnum" if re.search(r"[A-Za-z]", stripped) else "digits"


def main() -> None:
    self_check()

    buf = []
    buf.append("// Generated by tool/gen_postal_metadata.py. Do not edit by hand.\n")
    buf.append("// Patterns: curated from public i18n postal-format data.\n")
    buf.append("\n")
    buf.append("part of 'postal_code.dart';\n\n")
    buf.append("const Map<String, PostalPattern> kPostalPatterns = {\n")
    for cc in sorted(patterns):
        meta = patterns[cc]
        example = meta.get("example")
        example_lit = dart_str(example) if example is not None else "null"
        buf.append(
            f"  '{cc}': PostalPattern({dart_str(meta['pattern'])}, "
            f"{dart_str(meta['format'])}, {example_lit}, "
            f"{dart_str(charset_of(meta['pattern']))}, "
            f"{max_length(meta['pattern'])}),\n"
        )
    buf.append("};\n")

    os.makedirs(os.path.dirname(DART_OUT), exist_ok=True)
    with open(DART_OUT, "w", encoding="utf-8") as f:
        f.write("".join(buf))

    for cc, meta in patterns.items():
        meta.setdefault("example", None)
        meta["charset"] = charset_of(meta["pattern"])
        meta["length"] = max_length(meta["pattern"])

    os.makedirs(os.path.dirname(JSON_OUT), exist_ok=True)
    with open(JSON_OUT, "w", encoding="utf-8") as f:
        json.dump(patterns, f, ensure_ascii=False, separators=(",", ":"), sort_keys=True)

    print(f"Wrote {DART_OUT} and {JSON_OUT}: {len(patterns)} countries")


if __name__ == "__main__":
    main()
