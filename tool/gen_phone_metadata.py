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
        out.append({
            "pattern": nf.pattern,
            "format": _fmt_token_normalize(nf.format),
            "leadingDigits": leading,
            "nationalPrefixFormattingRule": nf.national_prefix_formatting_rule or None,
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
            "example": example,
        })
    return countries


def build_data() -> dict:
    return {
        "libphonenumberVersion": phonenumbers.__version__,
        "countries": build_countries(),
    }


def main() -> None:
    data = build_data()
    os.makedirs(os.path.dirname(JSON_OUT), exist_ok=True)
    with open(JSON_OUT, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")
    print(f"Wrote {len(data['countries'])} countries to {JSON_OUT}")


if __name__ == "__main__":
    main()
