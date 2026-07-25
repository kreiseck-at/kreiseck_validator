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
        example = meta.get("example")
        if example is not None and not re.match(meta["pattern"], example):
            raise ValueError(f"{cc}: example {example!r} does not match its pattern")


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
            f"{dart_str(charset_of(meta['pattern']))}),\n"
        )
    buf.append("};\n")

    os.makedirs(os.path.dirname(DART_OUT), exist_ok=True)
    with open(DART_OUT, "w", encoding="utf-8") as f:
        f.write("".join(buf))

    for cc, meta in patterns.items():
        meta.setdefault("example", None)
        meta["charset"] = charset_of(meta["pattern"])

    os.makedirs(os.path.dirname(JSON_OUT), exist_ok=True)
    with open(JSON_OUT, "w", encoding="utf-8") as f:
        json.dump(patterns, f, ensure_ascii=False, separators=(",", ":"), sort_keys=True)

    print(f"Wrote {DART_OUT} and {JSON_OUT}: {len(patterns)} countries")


if __name__ == "__main__":
    main()
