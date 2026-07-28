/// Per-country VAT check-digit verification and subtype classification.
///
/// Every function here receives the body **without** its prefix, already
/// upper-cased, separator-free and matched against the country's structure
/// pattern — so it may assume the length and character set are right and only
/// has to do arithmetic.
///
/// Each algorithm is documented in `doc/algorithms.md` together with the
/// source it was taken from. None of this code is derived from another
/// implementation's source.
library;

import 'vat_info.dart';

/// Sum of each digit of [digits] times the weight at the same index.
int weighted(String digits, List<int> weights) {
  var sum = 0;
  final n = weights.length < digits.length ? weights.length : digits.length;
  for (var i = 0; i < n; i++) {
    sum += (digits.codeUnitAt(i) - 0x30) * weights[i];
  }
  return sum;
}

/// True when the check digit of [body] is correct for [iso2].
///
/// Throws [StateError] when no algorithm is registered for [iso2]: every
/// country in `kVatFormats` must have one, and `vat_id_test.dart` proves it.
bool checkVat(String iso2, String body) {
  final check = _checks[iso2];
  if (check == null) {
    throw StateError('No VAT check digit implemented for $iso2');
  }
  return check(body);
}

/// Which kind of number [body] is for [iso2].
VatSubtype vatSubtypeOf(String iso2, String body) {
  final classify = _subtypes[iso2];
  return classify == null ? VatSubtype.standard : classify(body);
}

const Map<String, bool Function(String)> _checks = {
  'AT': _checkAt,
};

const Map<String, VatSubtype Function(String)> _subtypes = {};

/// AT: Luhn over the eight digits, with the check digit being
/// `(6 - luhn(first seven)) mod 10`.
bool _checkAt(String body) {
  var sum = 0;
  // Doubling alternates from the right of the seven-digit body, starting
  // undoubled: the seventh digit counts as itself, the sixth is doubled.
  var alt = false;
  for (var i = 6; i >= 0; i--) {
    var d = body.codeUnitAt(i) - 0x30;
    if (alt) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
    alt = !alt;
  }
  return (6 - sum % 10) % 10 == body.codeUnitAt(7) - 0x30;
}
