// Returns true when digits (all 0-9, check digit included) satisfies the
// ISO 7064 MOD 11,10 checksum. A hybrid system: each step takes a remainder
// modulo 11 and then modulo 10. Used by the German VAT number and the
// Croatian OIB.
export function mod1110Ok(digits: string): boolean {
  if (digits.length === 0) return false;
  let check = 5;
  for (let i = 0; i < digits.length; i++) {
    const d = digits.charCodeAt(i) - 48;
    if (d < 0 || d > 9) return false;
    check = (((check === 0 ? 10 : check) * 2) % 11 + d) % 10;
  }
  return check === 1;
}

// Returns true when value (upper-case 0-9A-Z) satisfies the ISO 7064
// MOD 97,10 checksum: the whole value read as one integer after expanding
// letters to two digits (A -> 10 ... Z -> 35) leaves remainder 1 modulo 97.
// Processed digit by digit so no big integer is needed. This is the algorithm
// behind IBAN check digits, and the Dutch VAT number reuses it over 'NL' plus
// the number.
export function mod9710Ok(value: string): boolean {
  if (value.length === 0) return false;
  let remainder = 0;
  for (let i = 0; i < value.length; i++) {
    const c = value.charCodeAt(i);
    let expanded: number;
    if (c >= 48 && c <= 57) expanded = c - 48;
    else if (c >= 65 && c <= 90) expanded = c - 65 + 10;
    else return false;
    remainder = expanded >= 10
      ? (remainder * 100 + expanded) % 97
      : (remainder * 10 + expanded) % 97;
  }
  return remainder === 1;
}
