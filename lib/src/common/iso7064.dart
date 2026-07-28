/// Returns true when [digits] (all `0-9`, check digit included) satisfies the
/// ISO 7064 MOD 11,10 checksum.
///
/// A hybrid system: each step takes a remainder modulo 11 and then modulo 10.
/// Used by the German VAT number and the Croatian OIB.
bool mod1110Ok(String digits) {
  if (digits.isEmpty) return false;
  var check = 5;
  for (var i = 0; i < digits.length; i++) {
    final d = digits.codeUnitAt(i) - 0x30;
    if (d < 0 || d > 9) return false;
    check = (((check == 0 ? 10 : check) * 2) % 11 + d) % 10;
  }
  return check == 1;
}

/// Returns true when [value] (upper-case `0-9A-Z`) satisfies the ISO 7064
/// MOD 97,10 checksum.
///
/// The whole value is read as one integer after expanding letters to two
/// digits (`A` -> 10 … `Z` -> 35); it is valid when that integer leaves
/// remainder 1 modulo 97. Processed digit by digit so no big integer is
/// needed. This is the algorithm behind IBAN check digits, and the Dutch VAT
/// number reuses it over `'NL'` plus the number.
bool mod9710Ok(String value) {
  if (value.isEmpty) return false;
  var remainder = 0;
  for (var i = 0; i < value.length; i++) {
    final c = value.codeUnitAt(i);
    final int expanded;
    if (c >= 0x30 && c <= 0x39) {
      expanded = c - 0x30;
    } else if (c >= 0x41 && c <= 0x5A) {
      expanded = c - 0x41 + 10;
    } else {
      return false;
    }
    remainder = expanded >= 10
        ? (remainder * 100 + expanded) % 97
        : (remainder * 10 + expanded) % 97;
  }
  return remainder == 1;
}
