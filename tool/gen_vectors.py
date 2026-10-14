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


# ---------------------------------------------------------------------------
# Damm over GF(32) (voucher_code.json)
# ---------------------------------------------------------------------------

VC_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"


def gf32_mul(a: int, b: int) -> int:
    """Multiplication in GF(32) modulo x^5 + x^2 + 1."""
    r = 0
    while b:
        if b & 1:
            r ^= a
        b >>= 1
        a <<= 1
        if a & 32:
            a ^= 0x25
    return r


def vc_check_symbol(payload: str) -> str:
    """Check symbol for an 11-symbol payload (x o y = 2*x xor y)."""
    interim = 0
    for ch in payload:
        interim = gf32_mul(2, interim) ^ VC_ALPHABET.index(ch)
    return VC_ALPHABET[gf32_mul(2, interim)]


def voucher_vectors() -> list:
    """Builds the entries of test/vectors/voucher_code.json."""
    out = []

    def ok(inp, norm):
        out.append({'input': inp, 'isValid': True, 'normalized': norm,
                    'format': f'{norm[:4]}-{norm[4:8]}-{norm[8:]}'})

    def bad(inp, code):
        out.append({'input': inp, 'isValid': False, 'code': code})

    codes = []
    for payload in ('K7QM3XRP9DW', '00000000000', 'ZZZZZZZZZZZ', 'ABCDEFGHJKM'):
        code = payload + vc_check_symbol(payload)
        codes.append(code)
        ok(code, code)
    main = codes[0]
    ok(f'{main[:4]}-{main[4:8]}-{main[8:]}'.lower(), main)
    ok(f' {main[:4].lower()} {main[4:8]} {main[8:]} ', main)
    # O reads as 0, I and L read as 1: derive from a code containing 0/1.
    payload = '10M0R1Z0N1E'
    zero_one = payload + vc_check_symbol(payload)
    ok(zero_one.replace('0', 'O', 1), zero_one)
    ok(zero_one.replace('1', 'I', 1), zero_one)
    ok(zero_one.replace('1', 'l', 1), zero_one)
    bad(main[:6] + 'U' + main[7:], 'voucherCodeBadChars')
    bad(main[:11], 'voucherCodeBadLength')
    bad(main + '0', 'voucherCodeBadLength')
    bad('', 'voucherCodeEmpty')
    bad(' - ', 'voucherCodeEmpty')
    last = main[-1]
    other = VC_ALPHABET[(VC_ALPHABET.index(last) + 1) % 32]
    bad(main[:-1] + other, 'voucherCodeBadChecksum')
    return out


def main() -> None:
    import json
    import os
    path = os.path.join(os.path.dirname(__file__), '..', 'test', 'vectors',
                        'voucher_code.json')
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(voucher_vectors(), f, indent=2, ensure_ascii=False)
        f.write('\n')
    print(f'wrote {os.path.normpath(path)}')

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
