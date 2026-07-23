#!/usr/bin/env python3
"""Dev-only generator for IBAN metadata.

Emits lib/src/iban/iban_metadata.g.dart with two const maps:
  - kIbanBban: BBAN field offsets per country, from the SWIFT IBAN Registry
    bundled by the `schwifty` package.
  - kBanks:    country code -> national bank code -> (bank name, BIC).

Run:  python3 tool/gen_iban_metadata.py [--csv path/to/sepa-zv-vz_gesamt.csv]

Not part of the shipped package (never imported by lib/). schwifty bundles the
SWIFT IBAN Registry; the Austrian bank data is (c) Oesterreichische
Nationalbank, see the NOTICE file.
"""
from __future__ import annotations

import argparse
import csv
import io
import os
import re
import ssl
import urllib.request
import zipfile

import pycountry
from schwifty import registry
from schwifty.registry import Component

HERE = os.path.dirname(__file__)
ROOT = os.path.normpath(os.path.join(HERE, ".."))
OUT = os.path.join(ROOT, "lib", "src", "iban", "iban_metadata.g.dart")
OENB_URL = "https://www.oenb.at/docroot/downloads_observ/sepa-zv-vz_gesamt.csv"
DE_PAGE = "https://www.bundesbank.de/de/startseite/bankleitzahlendateien-csv--926194"
SIX_URL = "https://api.six-group.com/api/epcd/bankmaster/v3/bankmaster_V3.csv"


def bban_structures() -> dict:
    """ISO2 -> dict(length, bank_start, bank_end, branch_start, branch_end).

    schwifty exposes BBAN-relative (start, end) ranges; we shift them by 4 so
    they index the full IBAN string (country code + check digits = 4 chars).
    A zero-width branch range means the country has no branch identifier.
    """
    out: dict[str, dict] = {}
    for country in pycountry.countries:
        cc = country.alpha_2
        try:
            spec = registry.get_iban_spec(cc)
        except Exception:
            continue
        pos = spec.positions
        bank = pos[Component.BANK_CODE]
        branch = pos[Component.BRANCH_CODE]
        entry = {
            "length": spec.iban_length,
            "bank_start": 4 + bank.start,
            "bank_end": 4 + bank.end,
            "branch_start": None,
            "branch_end": None,
        }
        if branch.end > branch.start:
            entry["branch_start"] = 4 + branch.start
            entry["branch_end"] = 4 + branch.end
        out[cc] = entry
    return out


def load_oenb(path: str | None) -> tuple[str, dict]:
    """Returns (snapshot_date, {BLZ: (name, bic)}) from the OeNB SEPA CSV."""
    if path:
        raw = open(path, "rb").read()
    else:
        ctx = ssl.create_default_context()
        raw = urllib.request.urlopen(OENB_URL, timeout=60, context=ctx).read()
    lines = raw.decode("latin-1").splitlines()
    date = next(
        (re.search(r"vom\s+([\d.]+)", ln).group(1)
         for ln in lines if "SEPA-Verzeichnis-Abfrage" in ln),
        "unknown",
    )
    hidx = next(i for i, ln in enumerate(lines) if ln.startswith("Kennzeichen;"))
    reader = csv.DictReader(io.StringIO("\n".join(lines[hidx:])), delimiter=";")
    banks: dict[str, tuple[str, str]] = {}
    for row in reader:
        blz = (row.get("Bankleitzahl") or "").strip()
        name = (row.get("Bankenname") or "").strip()
        swift = (row.get("SWIFT-Code") or "").strip()
        if not blz or not swift:
            continue
        bic = swift[:-3] if swift.endswith("XXX") else swift
        banks.setdefault(blz, (name, bic))
    return date, banks


def load_bundesbank(path: str | None, de_date: str) -> tuple[str, dict]:
    """Returns (snapshot_date, {BLZ: (name, bic)}) from the Bundesbank BLZ file.

    Uses head-office rows only (Merkmal == '1') that carry a BIC. When `path`
    is given it must point to an unpacked BLZ.CSV; otherwise the current quarter's
    ZIP is located on the Bundesbank landing page and unpacked in memory.
    """
    if path:
        raw = open(path, "rb").read()
        date = de_date
    else:
        ctx = ssl.create_default_context()
        page = urllib.request.urlopen(DE_PAGE, timeout=60, context=ctx).read().decode(
            "utf-8", "replace")
        m = re.search(
            r"/resource/blob/\d+/[a-f0-9]+/[A-F0-9]+/blz-aktuell-csv-zip-data\.zip", page)
        if not m:
            raise RuntimeError("Bundesbank BLZ zip link not found on landing page")
        zip_bytes = urllib.request.urlopen(
            "https://www.bundesbank.de" + m.group(0), timeout=60, context=ctx).read()
        dm = re.search(r"gültig vom\s+([\d.]+)", page)
        date = dm.group(1) if dm else de_date
        zf = zipfile.ZipFile(io.BytesIO(zip_bytes))
        name = next(n for n in zf.namelist() if n.upper().endswith(".CSV"))
        raw = zf.read(name)
    reader = csv.DictReader(io.StringIO(raw.decode("latin-1")), delimiter=";")
    banks: dict[str, tuple[str, str]] = {}
    for row in reader:
        blz = (row.get("Bankleitzahl") or "").strip()
        merkmal = (row.get("Merkmal") or "").strip()
        bic = (row.get("BIC") or "").strip()
        name = (row.get("Bezeichnung") or "").strip()
        if merkmal != "1" or not blz or not bic:
            continue
        bic = bic[:-3] if bic.endswith("XXX") else bic
        banks.setdefault(blz, (name, bic))
    return date, banks


def load_six(path: str | None) -> tuple[str, dict]:
    """Returns (snapshot_date, {BC: (name, bic)}) from the SIX Bank Master CSV.

    The IID/QR-IID clearing number is zero-padded to 5 digits to match the
    bank-code field in a Swiss IBAN. Snapshot date is the 'Valid on' column.
    """
    if path:
        raw = open(path, "rb").read()
    else:
        ctx = ssl.create_default_context()
        raw = urllib.request.urlopen(SIX_URL, timeout=60, context=ctx).read()
    reader = csv.DictReader(io.StringIO(raw.decode("utf-8")), delimiter=";")
    banks: dict[str, tuple[str, str]] = {}
    date = "unknown"
    for row in reader:
        iid = (row.get("IID/QR-IID") or "").strip()
        bic = (row.get("BIC") or "").strip()
        name = (row.get("Name of bank/institution") or "").strip()
        if date == "unknown":
            date = (row.get("Valid on") or "").strip() or "unknown"
        if not iid or not bic:
            continue
        code = iid.zfill(5)
        bic = bic[:-3] if bic.endswith("XXX") else bic
        banks.setdefault(code, (name, bic))
    return date, banks


def dart_str(s: str) -> str:
    """A single-quoted Dart string literal for arbitrary text."""
    return "'" + s.replace("\\", "\\\\").replace("$", "\\$").replace("'", "\\'") + "'"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", help="local OeNB CSV instead of downloading")
    ap.add_argument("--de-csv", help="local Bundesbank BLZ.CSV instead of downloading")
    ap.add_argument("--de-date", default="unknown",
                    help="Bundesbank validity date to record when --de-csv is used")
    ap.add_argument("--ch-csv", help="local SIX bank master CSV instead of downloading")
    args = ap.parse_args()

    structures = bban_structures()
    directories = {
        "AT": load_oenb(args.csv),
        "DE": load_bundesbank(args.de_csv, args.de_date),
        "CH": load_six(args.ch_csv),
    }

    buf = io.StringIO()
    buf.write("// Generated by tool/gen_iban_metadata.py. Do not edit by hand.\n")
    buf.write("// BBAN structure: SWIFT IBAN Registry, bundled via schwifty.\n")
    at_date = directories["AT"][0]
    buf.write(f"// AT banks: OeNB SEPA directory, snapshot {at_date}.\n")
    buf.write(f"// Source: {OENB_URL} -- (c) Oesterreichische Nationalbank; see NOTICE.\n")
    de_date = directories["DE"][0]
    ch_date = directories["CH"][0]
    buf.write(f"// DE banks: Deutsche Bundesbank Bankleitzahlen, snapshot {de_date}.\n")
    buf.write(f"// CH banks: SIX Bank Master, snapshot {ch_date}.\n")
    buf.write("\n")
    buf.write("part of 'iban_metadata.dart';\n\n")

    buf.write("const Map<String, IbanBban> kIbanBban = {\n")
    for cc in sorted(structures):
        e = structures[cc]
        bs = "null" if e["branch_start"] is None else e["branch_start"]
        be = "null" if e["branch_end"] is None else e["branch_end"]
        buf.write(
            f"  '{cc}': IbanBban(length: {e['length']}, "
            f"bankStart: {e['bank_start']}, bankEnd: {e['bank_end']}, "
            f"branchStart: {bs}, branchEnd: {be}),\n"
        )
    buf.write("};\n\n")

    buf.write("const Map<String, Map<String, Bank>> kBanks = {\n")
    for cc in sorted(directories):
        _, banks = directories[cc]
        buf.write(f"  '{cc}': {{\n")
        for code in sorted(banks):
            name, bic = banks[code]
            buf.write(f"    '{code}': Bank({dart_str(name)}, '{bic}'),\n")
        buf.write("  },\n")
    buf.write("};\n")

    with open(OUT, "w", encoding="utf-8") as f:
        f.write(buf.getvalue())
    counts = ", ".join(f"{cc}={len(directories[cc][1])}" for cc in sorted(directories))
    print(f"Wrote {OUT}: {len(structures)} countries; banks {counts}")


if __name__ == "__main__":
    main()
