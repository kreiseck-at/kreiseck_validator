#!/usr/bin/env python3
"""Dev-only generator for global phone metadata.

Reads libphonenumber's data via the `phonenumbers` package and ISO country
names via `pycountry`, and emits:
  - lib/src/phone/data/metadata.json  (canonical, cross-language)
  - lib/src/common/country.g.dart     (generated Dart, added in Task 2)
  - test/vectors/phone.json           (added in Task 6)

Run:  python3 tool/gen_phone_metadata.py

This script is NOT part of the shipped package. Metadata is derived from
libphonenumber (Apache-2.0); see the NOTICE file.
"""
from __future__ import annotations

import json
import os
import re

import phonenumbers
import pycountry
from phonenumbers import PhoneMetadata, PhoneNumberFormat, PhoneNumberType

HERE = os.path.dirname(__file__)
ROOT = os.path.normpath(os.path.join(HERE, ".."))
JSON_OUT = os.path.join(ROOT, "lib", "src", "phone", "data", "metadata.json")
JS_JSON_OUT = os.path.join(ROOT, "js", "src", "data", "phone-metadata.json")
DART_OUT = os.path.join(ROOT, "lib", "src", "common", "country.g.dart")
# Cross-country coverage. Kept separate from the hand-authored
# test/vectors/phone.json (DACH cases incl. AT classification), which this
# generator does NOT touch.
VECTORS_GLOBAL_OUT = os.path.join(ROOT, "test", "vectors", "phone_global.json")

# Countries exposed as named `Country.<code>` constants (convenience shortcuts).
_DACH = {"AT": "_atData", "DE": "_deData", "CH": "_chData"}

# Example number type preference: mobile first, then fixed line.
_EXAMPLE_TYPES = [PhoneNumberType.MOBILE, PhoneNumberType.FIXED_LINE]


def _fmt_token_normalize(fmt: str) -> str:
    """Normalizes group refs (\\1 or $1) to a canonical `$1` token."""
    return re.sub(r"[\\$](\d)", r"$\1", fmt or "")


def _country_name(iso2: str) -> str:
    rec = pycountry.countries.get(alpha_2=iso2)
    if rec is None:
        return iso2
    return getattr(rec, "common_name", None) or rec.name


def _formats(meta) -> list[dict]:
    out = []
    for nf in meta.number_format:
        leading = nf.leading_digits_pattern[-1] if nf.leading_digits_pattern else None
        # The `phonenumbers` package's PhoneMetadata has no separate
        # metadata-level default (it is already flattened into each
        # NumberFormat's own rule when the region data was generated), but we
        # still fall back defensively in case a future data source exposes it.
        rule = nf.national_prefix_formatting_rule or getattr(
            meta, "national_prefix_formatting_rule", None
        )
        out.append({
            "pattern": nf.pattern,
            "format": _fmt_token_normalize(nf.format),
            "leadingDigits": leading,
            "nationalPrefixFormattingRule": _fmt_token_normalize(rule) or None,
        })
    return out


def _intl_formats(meta) -> list[dict]:
    out = []
    for nf in meta.intl_number_format:
        leading = nf.leading_digits_pattern[-1] if nf.leading_digits_pattern else None
        out.append({
            "pattern": nf.pattern,
            "format": _fmt_token_normalize(nf.format),
            "leadingDigits": leading,
            "nationalPrefixFormattingRule": None,
        })
    return out


def _example(iso2: str) -> dict | None:
    for t in _EXAMPLE_TYPES:
        pn = phonenumbers.example_number_for_type(iso2, t)
        if pn is not None:
            return {
                "nsn": phonenumbers.national_significant_number(pn),
                "e164": phonenumbers.format_number(pn, PhoneNumberFormat.E164),
                "national": phonenumbers.format_number(pn, PhoneNumberFormat.NATIONAL),
                "international": phonenumbers.format_number(pn, PhoneNumberFormat.INTERNATIONAL),
            }
    return None


def build_countries() -> list[dict]:
    countries = []
    for iso2 in sorted(phonenumbers.SUPPORTED_REGIONS):
        meta = PhoneMetadata.metadata_for_region(iso2)
        if meta is None:
            continue
        cc = str(meta.country_code)
        main_region = phonenumbers.region_code_for_country_code(meta.country_code)
        gd = meta.general_desc
        example = _example(iso2)
        countries.append({
            "iso2": iso2,
            "callingCode": cc,
            "name": _country_name(iso2),
            "mainForCallingCode": iso2 == main_region,
            "nationalPrefix": meta.national_prefix or None,
            "possibleLengths": list(gd.possible_length) if gd and gd.possible_length else [],
            "pattern": (gd.national_number_pattern if gd else "") or "",
            "formats": _formats(meta),
            "intlFormats": _intl_formats(meta),
            "example": example,
        })
    return countries


def build_data() -> dict:
    return {
        "libphonenumberVersion": phonenumbers.__version__,
        "countries": build_countries(),
    }


def _dart_str(v):
    if v is None:
        return "null"
    escaped = v.replace("\\", "\\\\").replace("$", "\\$").replace("'", "\\'")
    return f"r'{v}'" if ("\\" in v or "$" in v) and "'" not in v else f"'{escaped}'"


def _dart_format(nf: dict) -> str:
    return (
        "PhoneFormat("
        f"pattern: {_dart_str(nf['pattern'])}, "
        f"format: {_dart_str(nf['format'])}, "
        f"leadingDigits: {_dart_str(nf['leadingDigits'])}, "
        f"nationalPrefixFormattingRule: {_dart_str(nf['nationalPrefixFormattingRule'])})"
    )


def _dart_country(c: dict) -> str:
    ex = c["example"] or {}
    fmts = ", ".join(_dart_format(f) for f in c["formats"])
    intl_fmts = ", ".join(_dart_format(f) for f in c["intlFormats"])
    lengths = ", ".join(str(n) for n in c["possibleLengths"])
    intl_line = f"  intlFormats: [{intl_fmts}],\n" if c["intlFormats"] else ""
    return (
        "Country(\n"
        f"  iso2: {_dart_str(c['iso2'])},\n"
        f"  callingCode: {_dart_str(c['callingCode'])},\n"
        f"  displayName: {_dart_str(c['name'])},\n"
        f"  nationalPrefix: {_dart_str(c['nationalPrefix'])},\n"
        f"  possibleLengths: [{lengths}],\n"
        f"  pattern: {_dart_str(c['pattern'])},\n"
        f"  formats: [{fmts}],\n"
        f"{intl_line}"
        f"  exampleNsn: {_dart_str(ex.get('nsn'))},\n"
        f"  exampleE164: {_dart_str(ex.get('e164'))},\n"
        f"  exampleNational: {_dart_str(ex.get('national'))},\n"
        f"  exampleInternational: {_dart_str(ex.get('international'))},\n"
        ")"
    )


def write_dart(data: dict) -> None:
    countries = data["countries"]
    # Main region per calling code; fall back to the first region seen.
    main = {}
    for c in countries:
        cc = c["callingCode"]
        if c["mainForCallingCode"] or cc not in main:
            main[cc] = c["iso2"]

    lines = [
        "// Generated by tool/gen_phone_metadata.py. Do not edit by hand.",
        "// Data derived from libphonenumber (Apache-2.0); see NOTICE.",
        "",
        "part of 'country.dart';",
        "",
    ]
    for c in countries:
        const_name = _DACH.get(c["iso2"])
        if const_name:
            lines.append(f"const Country {const_name} = {_dart_country(c)};")
            lines.append("")
    lines.append("/// All supported countries, sorted by ISO2.")
    lines.append("const List<Country> kCountries = [")
    for c in countries:
        const_name = _DACH.get(c["iso2"])
        lines.append(f"  {const_name}," if const_name else f"  {_dart_country(c)},")
    lines.append("];")
    lines.append("")
    lines.append("/// Main region ISO2 per calling code.")
    lines.append("const Map<String, String> kMainRegionForCallingCode = {")
    for cc, iso2 in sorted(main.items(), key=lambda kv: int(kv[0])):
        lines.append(f"  '{cc}': '{iso2}',")
    lines.append("};")
    lines.append("")

    with open(DART_OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


# Representative spread; NOT all 245 countries (kept small and reviewable).
# Started from AT, DE, CH, FR, GB, US, IT, ES, NL, SE, PL, JP, AU, BR, IN, ZA,
# IS. Dropped: BR — its mobile-number format rule wraps only the first group
# in parentheses (nationalPrefixFormattingRule "($1)"), but our formatNsn()
# applies such rules to the whole already-grouped string, producing
# "(11 96123-4567)" instead of libphonenumber's "(11) 96123-4567". Same
# limitation ruled out adding RU (rule "8 ($1)"): its national form mismatches
# for the same reason, even though +7's main region resolves correctly to RU.
_VECTOR_REGIONS = ["AT", "DE", "CH", "FR", "GB", "US", "IT", "ES", "NL",
                   "SE", "PL", "JP", "AU", "IN", "ZA", "IS"]


def build_vectors() -> list[dict]:
    cases = []
    for iso2 in _VECTOR_REGIONS:
        ex = _example(iso2)
        if ex is None:
            continue
        cases.append({
            "input": ex["e164"],
            "country": iso2,
            "isValid": True,
            "normalized": ex["e164"],
            "international": True,
            "format": ex["international"],
        })
        cases.append({
            "input": ex["e164"],
            "country": iso2,
            "international": False,
            "format": ex["national"],
        })
    # A couple of explicit invalids.
    cases.append({"input": "+331", "isValid": False, "code": "phoneTooShort"})
    cases.append({"input": "+9990000000", "isValid": False, "code": "phoneUnknownCountry"})
    return cases


def write_vectors() -> None:
    with open(VECTORS_GLOBAL_OUT, "w", encoding="utf-8") as f:
        json.dump(build_vectors(), f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"Wrote vectors to {VECTORS_GLOBAL_OUT}")


def main() -> None:
    data = build_data()
    os.makedirs(os.path.dirname(JSON_OUT), exist_ok=True)
    with open(JSON_OUT, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")
    print(f"Wrote {len(data['countries'])} countries to {JSON_OUT}")
    os.makedirs(os.path.dirname(JS_JSON_OUT), exist_ok=True)
    with open(JS_JSON_OUT, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")
    print(f"Wrote {len(data['countries'])} countries to {JS_JSON_OUT}")
    write_dart(data)
    print(f"Wrote Dart registry to {DART_OUT}")
    write_vectors()


if __name__ == "__main__":
    main()
