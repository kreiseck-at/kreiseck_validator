/// Returns true when [digits] (all `0-9`) satisfies the Luhn checksum
/// (rightmost digit is the check digit; every second digit doubled).
bool luhnOk(String digits) {
  var sum = 0;
  var alt = false;
  for (var i = digits.length - 1; i >= 0; i--) {
    var d = digits.codeUnitAt(i) - 0x30;
    if (alt) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
    alt = !alt;
  }
  return sum % 10 == 0;
}
