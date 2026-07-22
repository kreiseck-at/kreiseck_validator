"""Asserts the generated metadata.json against known, stable facts."""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(__file__)
JSON_PATH = os.path.join(HERE, "..", "lib", "src", "phone", "data", "metadata.json")


def _load():
    subprocess.run([sys.executable, os.path.join(HERE, "gen_phone_metadata.py")], check=True)
    with open(JSON_PATH, encoding="utf-8") as f:
        return json.load(f)


def _by_iso2(data):
    return {c["iso2"]: c for c in data["countries"]}


def test_known_facts():
    data = _load()
    assert data["libphonenumberVersion"]
    countries = _by_iso2(data)
    assert len(countries) > 200
    assert countries["AT"]["callingCode"] == "43"
    assert countries["DE"]["callingCode"] == "49"
    assert countries["CH"]["callingCode"] == "41"
    assert countries["US"]["callingCode"] == "1"
    assert countries["AT"]["name"] == "Austria"
    # Shared calling code +1: exactly one region is marked main.
    plus1 = [c for c in countries.values() if c["callingCode"] == "1"]
    assert sum(1 for c in plus1 if c["mainForCallingCode"]) == 1
    # Example numbers are present and E.164-shaped.
    assert countries["AT"]["example"]["e164"].startswith("+43")
    assert countries["FR"]["example"]["e164"].startswith("+33")
    # Every country has at least one possible length and a validation pattern.
    for c in countries.values():
        assert c["possibleLengths"], c["iso2"]
        assert c["pattern"], c["iso2"]


if __name__ == "__main__":
    test_known_facts()
    print("OK")
