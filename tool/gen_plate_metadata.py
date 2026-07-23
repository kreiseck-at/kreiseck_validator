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

# Swiss canton distinguishing codes (Kontrollschild-Kantonskürzel) -> canton
# name. Fixed, closed set of the 26 cantons -- a public administrative fact,
# not sourced from any bundled third-party package.
CH_REGIONS = {
    "ZH": "Zürich",
    "BE": "Bern",
    "LU": "Luzern",
    "UR": "Uri",
    "SZ": "Schwyz",
    "OW": "Obwalden",
    "NW": "Nidwalden",
    "GL": "Glarus",
    "ZG": "Zug",
    "FR": "Fribourg",
    "SO": "Solothurn",
    "BS": "Basel-Stadt",
    "BL": "Basel-Landschaft",
    "SH": "Schaffhausen",
    "AR": "Appenzell Ausserrhoden",
    "AI": "Appenzell Innerrhoden",
    "SG": "St. Gallen",
    "GR": "Graubünden",
    "AG": "Aargau",
    "TG": "Thurgau",
    "TI": "Ticino",
    "VD": "Vaud",
    "VS": "Valais",
    "NE": "Neuchâtel",
    "GE": "Genève",
    "JU": "Jura",
}

# Croatian registration-area codes (a two-letter city code on the plate) ->
# the code's namesake city, cross-checked against the official HAK
# (Hrvatski autoklub) list of registration areas. A closed, fixed set of 34
# currently-issued codes -- two historic codes superseded by renamed towns
# (PS, formerly Podravska Slatina; SP, formerly Slavonska Požega) are
# intentionally omitted as no longer issued.
HR_REGIONS = {
    "BJ": "Bjelovar",
    "BM": "Beli Manastir",
    "ČK": "Čakovec",
    "DA": "Daruvar",
    "DE": "Delnice",
    "DJ": "Đakovo",
    "DU": "Dubrovnik",
    "GS": "Gospić",
    "IM": "Imotski",
    "KA": "Karlovac",
    "KC": "Koprivnica",
    "KR": "Krapina",
    "KT": "Kutina",
    "KŽ": "Križevci",
    "MA": "Makarska",
    "NA": "Našice",
    "NG": "Nova Gradiška",
    "OG": "Ogulin",
    "OS": "Osijek",
    "PU": "Pula",
    "PŽ": "Požega",
    "RI": "Rijeka",
    "SB": "Slavonski Brod",
    "SK": "Sisak",
    "SL": "Slatina",
    "ST": "Split",
    "ŠI": "Šibenik",
    "VK": "Vinkovci",
    "VT": "Virovitica",
    "VU": "Vukovar",
    "VŽ": "Varaždin",
    "ZD": "Zadar",
    "ZG": "Zagreb",
    "ŽU": "Županja",
}

# Turkish province plate codes (Turkiye Plaka Kodu) -> province name, the
# standard numbered list (01-81) assigned to every province, a fixed and
# closed public administrative fact. Turkish letters are written as literal
# UTF-8 in the names.
TR_REGIONS = {
    "01": "Adana",
    "02": "Adıyaman",
    "03": "Afyonkarahisar",
    "04": "Ağrı",
    "05": "Amasya",
    "06": "Ankara",
    "07": "Antalya",
    "08": "Artvin",
    "09": "Aydın",
    "10": "Balıkesir",
    "11": "Bilecik",
    "12": "Bingöl",
    "13": "Bitlis",
    "14": "Bolu",
    "15": "Burdur",
    "16": "Bursa",
    "17": "Çanakkale",
    "18": "Çankırı",
    "19": "Çorum",
    "20": "Denizli",
    "21": "Diyarbakır",
    "22": "Edirne",
    "23": "Elazığ",
    "24": "Erzincan",
    "25": "Erzurum",
    "26": "Eskişehir",
    "27": "Gaziantep",
    "28": "Giresun",
    "29": "Gümüşhane",
    "30": "Hakkari",
    "31": "Hatay",
    "32": "Isparta",
    "33": "Mersin",
    "34": "İstanbul",
    "35": "İzmir",
    "36": "Kars",
    "37": "Kastamonu",
    "38": "Kayseri",
    "39": "Kırklareli",
    "40": "Kırşehir",
    "41": "Kocaeli",
    "42": "Konya",
    "43": "Kütahya",
    "44": "Malatya",
    "45": "Manisa",
    "46": "Kahramanmaraş",
    "47": "Mardin",
    "48": "Muğla",
    "49": "Muş",
    "50": "Nevşehir",
    "51": "Niğde",
    "52": "Ordu",
    "53": "Rize",
    "54": "Sakarya",
    "55": "Samsun",
    "56": "Siirt",
    "57": "Sinop",
    "58": "Sivas",
    "59": "Tekirdağ",
    "60": "Tokat",
    "61": "Trabzon",
    "62": "Tunceli",
    "63": "Şanlıurfa",
    "64": "Uşak",
    "65": "Van",
    "66": "Yozgat",
    "67": "Zonguldak",
    "68": "Aksaray",
    "69": "Bayburt",
    "70": "Karaman",
    "71": "Kırıkkale",
    "72": "Batman",
    "73": "Şırnak",
    "74": "Bartın",
    "75": "Ardahan",
    "76": "Iğdır",
    "77": "Yalova",
    "78": "Karabük",
    "79": "Kilis",
    "80": "Osmaniye",
    "81": "Düzce",
}

REGIONS = {
    "AT": AT_REGIONS,
    "CH": CH_REGIONS,
    "HR": HR_REGIONS,
    "TR": TR_REGIONS,
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

    if len(CH_REGIONS) != 26:
        raise ValueError(f"expected 26 CH cantons, got {len(CH_REGIONS)}")

    if len(HR_REGIONS) != 34:
        raise ValueError(f"expected 34 HR registration codes, got {len(HR_REGIONS)}")

    if len(TR_REGIONS) != 81:
        raise ValueError(f"expected 81 TR province codes, got {len(TR_REGIONS)}")

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
