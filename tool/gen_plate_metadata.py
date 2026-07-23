#!/usr/bin/env python3
"""Dev-only generator for license-plate region metadata.

Emits, in one run:
  - lib/src/license_plate/plate_metadata.g.dart (`part of 'license_plate.dart';`,
    const Map<String, Map<String, String>> kPlateRegions).
  - js/src/data/plate-metadata.json (same maps as JSON).

Region tables are curated dicts below (public-domain administrative facts,
not sourced from any bundled third-party package). Stdlib only -- run with
the system `python3`:

    python3 tool/gen_plate_metadata.py

Not part of the shipped package (never imported by lib/ or js/src at runtime
other than the JSON data file it produces).
"""
from __future__ import annotations

import argparse
import json
import os
import re

HERE = os.path.dirname(__file__)
ROOT = os.path.normpath(os.path.join(HERE, ".."))
DART_OUT = os.path.join(ROOT, "lib", "src", "license_plate", "plate_metadata.g.dart")
JSON_OUT = os.path.join(ROOT, "js", "src", "data", "plate-metadata.json")

# Austrian Bezirkskennzeichen (district distinguishing codes) -> district /
# city name. Curated from the official/public-domain administrative record
# (the amtliche list of Kennzeichen-Unterscheidungscodes), cross-checked
# against the current, active code set (superseded codes from the 2012/2013
# Steiermark district mergers are intentionally omitted). Federal/authority
# special codes (diplomatic corps, armed forces, police, ...) are classified
# by pattern in the engine, not looked up here.
AT_REGIONS = {
    # Wien
    "W": "Wien",
    # Niederösterreich
    "AM": "Amstetten",
    "BL": "Bruck an der Leitha",
    "BN": "Baden",
    "GD": "Gmünd",
    "GF": "Gänserndorf",
    "HL": "Hollabrunn",
    "HO": "Horn",
    "KG": "Klosterneuburg",
    "KO": "Korneuburg",
    "KR": "Krems-Land",
    "KS": "Krems an der Donau",
    "LF": "Lilienfeld",
    "MD": "Mödling",
    "ME": "Melk",
    "MI": "Mistelbach",
    "NK": "Neunkirchen",
    "P": "St. Pölten",
    "PL": "St. Pölten-Land",
    "SB": "Scheibbs",
    "SW": "Schwechat",
    "TU": "Tulln",
    "WB": "Wiener Neustadt-Land",
    "WN": "Wiener Neustadt",
    "WT": "Waidhofen an der Thaya",
    "WY": "Waidhofen an der Ybbs",
    "ZT": "Zwettl",
    # Burgenland
    "E": "Eisenstadt",
    "EU": "Eisenstadt-Umgebung",
    "GS": "Güssing",
    "JE": "Jennersdorf",
    "MA": "Mattersburg",
    "ND": "Neusiedl am See",
    "OP": "Oberpullendorf",
    "OW": "Oberwart",
    # Steiermark
    "BM": "Bruck-Mürzzuschlag",
    "DL": "Deutschlandsberg",
    "G": "Graz",
    "GB": "Gröbming",
    "GU": "Graz-Umgebung",
    "HF": "Hartberg-Fürstenfeld",
    "LB": "Leibnitz",
    "LE": "Leoben",
    "LI": "Liezen",
    "LN": "Leoben-Umgebung",
    "MT": "Murtal",
    "MU": "Murau",
    "SO": "Südoststeiermark",
    "VO": "Voitsberg",
    "WZ": "Weiz",
    # Oberösterreich
    "BR": "Braunau am Inn",
    "EF": "Eferding",
    "FR": "Freistadt",
    "GM": "Gmunden",
    "GR": "Grieskirchen",
    "KI": "Kirchdorf an der Krems",
    "L": "Linz",
    "LL": "Linz-Land",
    "PE": "Perg",
    "RI": "Ried im Innkreis",
    "RO": "Rohrbach",
    "SD": "Schärding",
    "SE": "Steyr-Land",
    "SR": "Steyr",
    "UU": "Urfahr-Umgebung",
    "VB": "Vöcklabruck",
    "WE": "Wels",
    "WL": "Wels-Land",
    # Salzburg
    "HA": "Hallein",
    "JO": "St. Johann im Pongau",
    "S": "Salzburg",
    "SL": "Salzburg-Umgebung",
    "TA": "Tamsweg",
    "ZE": "Zell am See",
    # Kärnten
    "FE": "Feldkirchen",
    "HE": "Hermagor",
    "K": "Klagenfurt",
    "KL": "Klagenfurt-Land",
    "SP": "Spittal an der Drau",
    "SV": "St. Veit an der Glan",
    "VI": "Villach",
    "VK": "Völkermarkt",
    "VL": "Villach-Land",
    "WO": "Wolfsberg",
    # Tirol
    "I": "Innsbruck",
    "IL": "Innsbruck-Land",
    "IM": "Imst",
    "KB": "Kitzbühel",
    "KU": "Kufstein",
    "LA": "Landeck",
    "LZ": "Lienz",
    "RE": "Reutte",
    "SZ": "Schwaz",
    # Vorarlberg
    "B": "Bregenz",
    "BZ": "Bludenz",
    "DO": "Dornbirn",
    "FK": "Feldkirch",
}

REGIONS = {
    "AT": AT_REGIONS,
}

_DE_CODE_RE = re.compile(r"^[A-ZÄÖÜ]{1,3}$")


def load_de(path: str) -> dict[str, str]:
    """Parses the DE Unterscheidungszeichen snapshot (`code;region` per line)
    into a `code -> Stadt/Kreis` dict, self-checking the result against the
    invariants the engine relies on (letters-only codes, no duplicates, a
    total in the plausible current-count range)."""
    regions: dict[str, str] = {}
    with open(path, encoding="utf-8") as f:
        for lineno, raw in enumerate(f, start=1):
            line = raw.strip()
            if not line:
                continue
            if ";" not in line:
                raise ValueError(f"{path}:{lineno}: expected 'code;region', got {raw!r}")
            code, region = line.split(";", 1)
            code = code.strip()
            region = region.strip()
            if not _DE_CODE_RE.match(code):
                raise ValueError(f"{path}:{lineno}: bad DE code {code!r}")
            if code in regions:
                raise ValueError(f"{path}:{lineno}: duplicate DE code {code!r}")
            if not region:
                raise ValueError(f"{path}:{lineno}: empty region for code {code!r}")
            regions[code] = region

    if not (700 <= len(regions) <= 800):
        raise ValueError(
            f"{path}: expected 700-800 DE codes, got {len(regions)}"
        )
    return regions


def dart_str(s: str) -> str:
    """A single-quoted Dart string literal for arbitrary text."""
    return "'" + s.replace("\\", "\\\\").replace("$", "\\$").replace("'", "\\'") + "'"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--de-csv",
        default=os.path.join(ROOT, "tool", "data", "de-kennzeichen.csv"),
        help="Path to the DE Unterscheidungszeichen snapshot (code;region per line).",
    )
    args = parser.parse_args()

    REGIONS["DE"] = load_de(args.de_csv)

    buf = []
    buf.append("// Generated by tool/gen_plate_metadata.py. Do not edit by hand.\n")
    buf.append("// Region tables: curated from public-domain administrative sources.\n")
    buf.append("\n")
    buf.append("part of 'license_plate.dart';\n\n")
    buf.append("const Map<String, Map<String, String>> kPlateRegions = {\n")
    for cc in sorted(REGIONS):
        buf.append(f"  '{cc}': {{\n")
        codes = REGIONS[cc]
        for code in sorted(codes):
            buf.append(f"    '{code}': {dart_str(codes[code])},\n")
        buf.append("  },\n")
    buf.append("};\n")

    os.makedirs(os.path.dirname(DART_OUT), exist_ok=True)
    with open(DART_OUT, "w", encoding="utf-8") as f:
        f.write("".join(buf))

    os.makedirs(os.path.dirname(JSON_OUT), exist_ok=True)
    with open(JSON_OUT, "w", encoding="utf-8") as f:
        json.dump(REGIONS, f, ensure_ascii=False, separators=(",", ":"), sort_keys=True)

    counts = ", ".join(f"{cc}={len(REGIONS[cc])}" for cc in sorted(REGIONS))
    print(f"Wrote {DART_OUT} and {JSON_OUT}: {len(REGIONS)} countries; codes {counts}")


if __name__ == "__main__":
    main()
