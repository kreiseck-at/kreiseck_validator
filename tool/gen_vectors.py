#!/usr/bin/env python3
"""Dev-only helper for authoring test/vectors/*.json.

This script is NOT part of the input_validator package: it lives outside
lib/, is never imported by the package, and ships with no third-party
dependencies (Python 3 standard library only). Its only job is to compute
correct check digits and example numbers -- Luhn for credit cards, Mod-97
for IBANs, and a couple of E.164 phone examples -- so that the values in
test/vectors/ don't have to be worked out by hand. It intentionally
mirrors the algorithms implemented in lib/src/, see doc/algorithms.md for
the write-up.

Usage:
    python3 tool/gen_vectors.py
"""

from __future__ import annotations


# ---------------------------------------------------------------------------
# Luhn (credit_card.json)
# ---------------------------------------------------------------------------

def luhn_check_digit(prefix: str) -> str:
    """Returns the digit that makes ``prefix + digit`` pass the Luhn check.

    In the final number the check digit itself is never doubled, so within
    ``prefix`` doubling starts at its last digit and alternates leftward.
    """
    total = 0
    alt = True  # the prefix's last digit is doubled first.
    for ch in reversed(prefix):
        d = int(ch)
        if alt:
            d *= 2
            if d > 9:
                d -= 9
        total += d
        alt = not alt
    return str((10 - total % 10) % 10)


def luhn_is_valid(number: str) -> bool:
    """True when ``number`` (all digits) satisfies the Luhn checksum."""
    total = 0
    alt = False  # the rightmost digit (the check digit) is never doubled.
    for ch in reversed(number):
        d = int(ch)
        if alt:
            d *= 2
            if d > 9:
                d -= 9
        total += d
        alt = not alt
    return total % 10 == 0


# ---------------------------------------------------------------------------
# Mod-97 (iban.json)
# ---------------------------------------------------------------------------

_LETTER_VALUES = {chr(c): str(c - ord('A') + 10) for c in range(ord('A'), ord('Z') + 1)}


def _iban_numeric(chars: str) -> str:
    """Expands letters to their two-digit numeric value (A=10 ... Z=35)."""
    return ''.join(_LETTER_VALUES.get(ch, ch) for ch in chars)


def _mod97(numeric: str) -> int:
    """Mod-97 of a decimal digit string, reduced in 7-digit chunks so the
    intermediate value never needs more than a handful of digits."""
    remainder = 0
    for i in range(0, len(numeric), 7):
        remainder = int(f'{remainder}{numeric[i:i + 7]}') % 97
    return remainder


def iban_check_digits(country: str, bban: str) -> str:
    """Computes the two ISO 13616 check digits for ``country`` + ``bban``.

    Rearranges as BBAN + country + provisional "00", converts letters to
    digits, and takes 98 minus the Mod-97 remainder.
    """
    rearranged = bban.upper() + country.upper() + '00'
    remainder = _mod97(_iban_numeric(rearranged))
    return f'{98 - remainder:02d}'


def iban_is_valid(iban: str) -> bool:
    """True when ``iban`` (no spaces, upper-case) has a valid Mod-97 checksum."""
    rearranged = iban[4:] + iban[:4]
    return _mod97(_iban_numeric(rearranged)) == 1


# ---------------------------------------------------------------------------
# E.164 (phone.json)
# ---------------------------------------------------------------------------

_CALLING_CODES = {'DE': '49', 'AT': '43', 'CH': '41'}


def national_to_e164(country: str, national_number: str) -> str:
    """Converts DACH national input (with an optional leading trunk '0')
    to E.164 by stripping non-digits, dropping the trunk prefix, and
    prepending the country's calling code."""
    digits = ''.join(ch for ch in national_number if ch.isdigit())
    if digits.startswith('0'):
        digits = digits[1:]
    return f'+{_CALLING_CODES[country]}{digits}'


def main() -> None:
    print('Luhn check digits:')
    for prefix in ('411111111111111', '37828224631000'):
        digit = luhn_check_digit(prefix)
        number = prefix + digit
        print(f'  prefix {prefix} -> check digit {digit} -> {number} '
              f'(valid: {luhn_is_valid(number)})')

    print('\nIBAN check digits:')
    for country, bban in (
        ('AT', '1904300234573201'),
        ('AT', '1200000234573201'),
        ('DE', '370400440532013000'),
    ):
        check = iban_check_digits(country, bban)
        iban = f'{country}{check}{bban}'
        print(f'  {country} + bban {bban} -> check {check} -> {iban} '
              f'(valid: {iban_is_valid(iban)})')

    print('\nE.164 examples:')
    for country, national in (
        ('AT', '0660 1234567'),
        ('DE', '030 1234567'),
        ('CH', '079 123 45 67'),
    ):
        print(f'  {country} national {national!r} -> {national_to_e164(country, national)}')


if __name__ == '__main__':
    main()
