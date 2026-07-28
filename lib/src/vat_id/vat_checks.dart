/// Per-country VAT check-digit verification and subtype classification.
///
/// Every function here receives the body **without** its prefix, already
/// upper-cased, separator-free and matched against the country's structure
/// pattern — so it may assume the length and character set are right and only
/// has to do arithmetic.
///
/// Each algorithm is documented in `doc/algorithms.md` together with the
/// source it was taken from, and every one of them is pinned by at least one
/// published number in `test/vectors/vat_id.json`. None of this code is
/// derived from another implementation's source.
library;

import '../common/iso7064.dart';
import '../common/luhn.dart';
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

/// The digit at [index] of [digits].
int _d(String digits, int index) => digits.codeUnitAt(index) - 0x30;

/// [digits] read as an integer, folded modulo [m] so no value ever exceeds
/// [m] * 10 + 9. Long identifiers would otherwise overflow a 32-bit int in the
/// JavaScript port.
int _modOf(String digits, int m) {
  var r = 0;
  for (var i = 0; i < digits.length; i++) {
    r = (r * 10 + _d(digits, i)) % m;
  }
  return r;
}

/// The Luhn check digit that makes `body + digit` satisfy the Luhn checksum.
int _luhnCheckDigit(String body) {
  for (var d = 0; d <= 9; d++) {
    if (luhnOk('$body$d')) return d;
  }
  return -1; // unreachable: exactly one digit always satisfies Luhn
}

/// True when the check digit of [body] is correct for [iso2].
///
/// Throws [StateError] when no algorithm is registered for [iso2]: every
/// country in `kVatFormats` must have one, and `test/vat_id_test.dart` proves
/// it. The dispatch deliberately has no "structure is enough" fallback.
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
  'BE': _checkBe,
  'BG': _checkBg,
  'CH': _checkCh,
  'CY': _checkCy,
  'CZ': _checkCz,
  'DE': _checkDe,
  'DK': _checkDk,
  'EE': _checkEe,
  'ES': _checkEs,
  'FI': _checkFi,
  'FR': _checkFr,
  'GB': _checkGb,
  'GR': _checkGr,
  'HR': _checkHr,
  'HU': _checkHu,
  'IE': _checkIe,
  'IT': _checkIt,
  'LT': _checkLt,
  'LU': _checkLu,
  'LV': _checkLv,
  'MT': _checkMt,
  'NL': _checkNl,
  'PL': _checkPl,
  'PT': _checkPt,
  'RO': _checkRo,
  'SE': _checkSe,
  'SI': _checkSi,
  'SK': _checkSk,
  'NO': _checkNo,
  'RS': _checkRs,
  'TR': _checkTr,
  'XI': _checkGb,
};

const Map<String, VatSubtype Function(String)> _subtypes = {
  'BG': _subtypeBg,
  'CZ': _subtypeCz,
  'ES': _subtypeEs,
  'GB': _subtypeGb,
  'LT': _subtypeLt,
  'LV': _subtypeLv,
  'NL': _subtypeNl,
  'XI': _subtypeGb,
};

// ---------------------------------------------------------------------------
// Single-formula countries
// ---------------------------------------------------------------------------

/// AT: Luhn over the eight digits, the check digit being
/// `(6 - luhn(first seven)) mod 10`.
bool _checkAt(String body) {
  var sum = 0;
  // Doubling alternates from the right of the seven-digit body, starting
  // undoubled: the seventh digit counts as itself, the sixth is doubled.
  var alt = false;
  for (var i = 6; i >= 0; i--) {
    var d = _d(body, i);
    if (alt) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
    alt = !alt;
  }
  return (6 - sum % 10) % 10 == _d(body, 7);
}

/// BE: the first eight digits read as a number, **plus** the last two read as
/// a number, is a multiple of 97. Note the addition — this is not one long
/// number taken modulo 97.
bool _checkBe(String body) =>
    (_modOf(body.substring(0, 8), 97) + int.parse(body.substring(8, 10))) %
        97 ==
    0;

/// CH: weights 5, 4, 3, 2, 7, 6, 5, 4 over the first eight digits; the check
/// digit is `(11 - sum) mod 11`, and a computed 10 means no number was issued.
bool _checkCh(String body) {
  final sum = weighted(body, const [5, 4, 3, 2, 7, 6, 5, 4]);
  final check = (11 - sum % 11) % 11;
  return check != 10 && check == _d(body, 8);
}

/// CY: digits at even positions mapped through a substitution table, digits at
/// odd positions added as they are, the sum modulo 26 selecting a letter.
bool _checkCy(String body) {
  const map = [1, 0, 5, 7, 9, 13, 15, 17, 19, 21];
  var sum = 0;
  for (var i = 0; i < 8; i++) {
    sum += i.isEven ? map[_d(body, i)] : _d(body, i);
  }
  return 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'[sum % 26] == body[8];
}

/// DE and HR: ISO 7064 MOD 11,10 over the whole body.
bool _checkDe(String body) => mod1110Ok(body);

/// HR: the OIB, ISO 7064 MOD 11,10.
bool _checkHr(String body) => mod1110Ok(body);

/// DK: weights 2, 7, 6, 5, 4, 3, 2, 1; the weighted sum is a multiple of 11.
bool _checkDk(String body) =>
    weighted(body, const [2, 7, 6, 5, 4, 3, 2, 1]) % 11 == 0;

/// EE: weights 3, 7, 1 repeated; the weighted sum is a multiple of 10.
bool _checkEe(String body) =>
    weighted(body, const [3, 7, 1, 3, 7, 1, 3, 7, 1]) % 10 == 0;

/// FI: weights 7, 9, 10, 5, 8, 4, 2, 1; the weighted sum is a multiple of 11.
bool _checkFi(String body) =>
    weighted(body, const [7, 9, 10, 5, 8, 4, 2, 1]) % 11 == 0;

/// GR: an iterative doubling accumulator over the first eight digits; the
/// check digit is `2c mod 11 mod 10`.
bool _checkGr(String body) {
  var c = 0;
  for (var i = 0; i < 8; i++) {
    c = c * 2 + _d(body, i);
  }
  return c * 2 % 11 % 10 == _d(body, 8);
}

/// HU: weights 9, 7, 3, 1 repeated; the weighted sum is a multiple of 10.
bool _checkHu(String body) =>
    weighted(body, const [9, 7, 3, 1, 9, 7, 3, 1]) % 10 == 0;

/// IT: Luhn over all eleven digits, plus two structural rules the pattern
/// cannot express — the office code in positions 8-10 must be a real one, and
/// the seven-digit company part must not be all zeros.
bool _checkIt(String body) {
  if (!luhnOk(body)) return false;
  final office = body.substring(7, 10);
  final inRange = office.compareTo('001') >= 0 && office.compareTo('100') <= 0;
  const special = ['120', '121', '888', '999'];
  if (!inRange && !special.contains(office)) return false;
  return int.parse(body.substring(0, 7)) != 0;
}

/// LU: the first six digits modulo 89 equal the last two as a number.
bool _checkLu(String body) =>
    int.parse(body.substring(0, 6)) % 89 == int.parse(body.substring(6, 8));

/// MT: weights 3, 4, 6, 7, 8, 9, 10, 1; the weighted sum is a multiple of 37.
bool _checkMt(String body) =>
    weighted(body, const [3, 4, 6, 7, 8, 9, 10, 1]) % 37 == 0;

/// PL: weights 6, 5, 7, 2, 3, 4, 5, 6, 7 and -1 on the check digit; the
/// weighted sum is a multiple of 11.
bool _checkPl(String body) =>
    weighted(body, const [6, 5, 7, 2, 3, 4, 5, 6, 7, -1]) % 11 == 0;

/// PT: weights 9 down to 2; the check digit is `(11 - sum) mod 11 mod 10`.
bool _checkPt(String body) {
  final sum = weighted(body, const [9, 8, 7, 6, 5, 4, 3, 2]);
  return (11 - sum) % 11 % 10 == _d(body, 8);
}

/// RO: the body left-padded to nine digits, weights 7, 5, 3, 2, 1, 7, 5, 3, 2;
/// the check digit is `10 * sum mod 11 mod 10`.
bool _checkRo(String body) {
  final padded = body.substring(0, body.length - 1).padLeft(9, '0');
  final sum = weighted(padded, const [7, 5, 3, 2, 1, 7, 5, 3, 2]);
  return 10 * sum % 11 % 10 == _d(body, body.length - 1);
}

/// SE: the last two digits are always `01`, and the first ten satisfy Luhn.
bool _checkSe(String body) =>
    body.substring(10) == '01' && luhnOk(body.substring(0, 10));

/// SI: weights 8 down to 2; the check digit is `11 - (sum mod 11)`, where a
/// computed 10 becomes 0 and 11 cannot occur for an issued number.
bool _checkSi(String body) {
  final sum = weighted(body, const [8, 7, 6, 5, 4, 3, 2]);
  var check = 11 - sum % 11;
  if (check == 10) check = 0;
  return check != 11 && check == _d(body, 7);
}

/// SK: the whole ten-digit number is a multiple of 11.
bool _checkSk(String body) => _modOf(body, 11) == 0;


/// NO: `MVA`-Suffix hinter dem Organisasjonsnummer; Gewichte
/// 3, 2, 7, 6, 5, 4, 3, 2, 1 ueber alle neun Ziffern, Summe ein Vielfaches
/// von 11.
bool _checkNo(String body) =>
    weighted(body.substring(0, 9), const [3, 2, 7, 6, 5, 4, 3, 2, 1]) % 11 == 0;

/// RS: neun Ziffern, ISO 7064 MOD 11,10.
bool _checkRs(String body) => mod1110Ok(body);

/// TR: zehn Ziffern. Jede der ersten neun wird um ihre Position von rechts
/// erhoeht, verdoppelt sich positionsabhaengig und wird modulo 9 gefaltet;
/// die Pruefziffer ergaenzt die Summe auf ein Vielfaches von 10.
bool _checkTr(String body) {
  var sum = 0;
  for (var i = 1; i <= 9; i++) {
    final n = _d(body, 9 - i);
    final c1 = (n + i) % 10;
    if (c1 == 0) continue;
    var pow = 1;
    for (var k = 0; k < i; k++) {
      pow *= 2;
    }
    final c2 = (c1 * pow) % 9;
    sum += c2 == 0 ? 9 : c2;
  }
  return (10 - sum % 10) % 10 == _d(body, 9);
}

// ---------------------------------------------------------------------------
// Branching countries
// ---------------------------------------------------------------------------

/// BG: legal entities (9 digits) and natural persons (10) use different sums.
bool _checkBg(String body) {
  if (body.length == 9) {
    var sum = 0;
    for (var i = 0; i < 8; i++) {
      sum += (i + 1) * _d(body, i);
    }
    var check = sum % 11;
    if (check == 10) {
      sum = 0;
      for (var i = 0; i < 8; i++) {
        sum += (i + 3) * _d(body, i);
      }
      check = sum % 11;
    }
    return check % 10 == _d(body, 8);
  }
  final sum = weighted(body, const [4, 3, 2, 7, 6, 5, 4, 3, 2]);
  return (11 - sum) % 11 == _d(body, 9);
}

VatSubtype _subtypeBg(String body) =>
    body.length == 9 ? VatSubtype.legal : VatSubtype.person;

/// CZ: three different numbers share one field.
///
/// Eight digits is a legal entity and may not start with `9`. Nine digits
/// starting with `6` is a historical special form. Nine or ten digits
/// otherwise is a rodné číslo (birth number): the ten-digit form carries a
/// check digit, the nine-digit form carries none at all, so for that one
/// length there is nothing to verify beyond the structure — the embedded
/// birth date is a plausibility rule about a person, not a checksum, and is
/// deliberately not enforced here.
bool _checkCz(String body) {
  if (body.length == 8) {
    if (body[0] == '9') return false;
    final sum = weighted(body, const [8, 7, 6, 5, 4, 3, 2]);
    var check = (11 - sum) % 11;
    if (check == 0) check = 1;
    return check % 10 == _d(body, 7);
  }
  if (body.length == 9 && body[0] == '6') {
    final sum = weighted(body.substring(1), const [8, 7, 6, 5, 4, 3, 2]);
    final check = (8 - (10 - sum % 11) % 11) % 10;
    return check == _d(body, 8);
  }
  if (body.length == 10) {
    return _modOf(body.substring(0, 9), 11) % 10 == _d(body, 9);
  }
  return true; // nine-digit birth number: no check digit exists
}

VatSubtype _subtypeCz(String body) {
  if (body.length == 8) return VatSubtype.legal;
  if (body.length == 9 && body[0] == '6') return VatSubtype.special;
  return VatSubtype.individual;
}

/// ES: four different identifiers share one field, told apart by the first
/// character.
bool _checkEs(String body) {
  const dniLetters = 'TRWAGMYFPDXBNJZSQVHLCKE';
  final first = body[0];
  if (_isDigit(first)) {
    return dniLetters[int.parse(body.substring(0, 8)) % 23] == body[8];
  }
  if ('XYZ'.contains(first)) {
    final lead = 'XYZ'.indexOf(first);
    final digits = '$lead${body.substring(1, 8)}';
    return dniLetters[int.parse(digits) % 23] == body[8];
  }
  if ('KLM'.contains(first)) {
    return dniLetters[int.parse(body.substring(1, 8)) % 23] == body[8];
  }
  if ('ABCDEFGHJNPQRSUVW'.contains(first)) {
    // A legal entity: the Luhn check digit over the seven digits, accepted
    // either as that digit or as the letter it maps to. Sources disagree on
    // which organisation types must use which form, so both are allowed.
    final check = _luhnCheckDigit(body.substring(1, 8));
    return body[8] == '$check' || body[8] == 'JABCDEFGHI'[check];
  }
  return false;
}

VatSubtype _subtypeEs(String body) {
  final first = body[0];
  if (_isDigit(first) || 'KLM'.contains(first)) return VatSubtype.dni;
  if ('XYZ'.contains(first)) return VatSubtype.nie;
  return VatSubtype.cif;
}

bool _isDigit(String c) => c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;

/// FR: two digits or characters in front of a nine-digit SIREN.
///
/// An all-numeric prefix is the SIREN followed by `12`, modulo 97. A prefix
/// containing a letter uses an alphabet-index formula instead. Either way the
/// SIREN itself must satisfy Luhn, except for the Monegasque `000` block,
/// which is a valid TVA number but not a SIREN.
bool _checkFr(String body) {
  const alphabet = '0123456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  final siren = body.substring(2);
  if (siren.substring(0, 3) != '000' && !luhnOk(siren)) return false;
  final numericPrefix = _isDigit(body[0]) && _isDigit(body[1]);
  if (numericPrefix) {
    return int.parse(body.substring(0, 2)) == _modOf('${siren}12', 97);
  }
  final check = _isDigit(body[0])
      ? alphabet.indexOf(body[0]) * 24 + alphabet.indexOf(body[1]) - 10
      : alphabet.indexOf(body[0]) * 34 + alphabet.indexOf(body[1]) - 100;
  return (int.parse(siren) + 1 + check ~/ 11) % 11 == check % 11;
}

/// GB and XI: weights 8, 7, 6, 5, 4, 3, 2, 10, 1 over the first nine digits,
/// modulo 97.
///
/// Numbers whose first three digits reach 100 belong to a later allocation
/// block and accept three residues rather than one. A twelve-digit number is a
/// branch trader: only its first nine digits are checked. The `GD`/`HA` forms
/// are government departments and health authorities, distinguished by their
/// numeric range rather than a checksum.
bool _checkGb(String body) {
  if (body.startsWith('GD') || body.startsWith('HA')) {
    // Zwei Schreibweisen: kurz (`GD001`, drei Ziffern) und lang
    // (`GD8888` + drei Ziffern + zwei Pruefziffern). Die Kennzahl selbst
    // entscheidet, ob es eine Regierungsstelle (< 500) oder eine
    // Gesundheitsbehoerde (>= 500) ist; in der Langform sind die letzten
    // beiden Stellen ihr Rest modulo 97.
    final long = body.length == 11;
    final n = int.parse(body.substring(long ? 6 : 2, long ? 9 : 5));
    if (body.startsWith('GD') ? n >= 500 : n < 500) return false;
    if (long && n % 97 != int.parse(body.substring(9, 11))) return false;
    return true;
  }
  final nine = body.substring(0, 9);
  final sum = weighted(nine, const [8, 7, 6, 5, 4, 3, 2, 10, 1]) % 97;
  if (int.parse(nine.substring(0, 3)) >= 100) {
    return sum == 0 || sum == 42 || sum == 55;
  }
  return sum == 0;
}

VatSubtype _subtypeGb(String body) {
  if (body.startsWith('GD')) return VatSubtype.government;
  if (body.startsWith('HA')) return VatSubtype.healthAuthority;
  return body.length == 12 ? VatSubtype.branch : VatSubtype.standard;
}

/// IE: a 23-letter alphabet indexed by a weighted sum modulo 23.
///
/// The current form is seven digits and one or two letters; the historical
/// form puts a letter or symbol in second position. Both feed the same
/// weighting, just over differently assembled digits.
bool _checkIe(String body) {
  const alphabet = 'WABCDEFGHIJKLMNOPQRSTUV';

  String checkCharFor(String digits, String second) {
    final padded = digits.padLeft(7, '0');
    final sum = weighted(padded, const [8, 7, 6, 5, 4, 3, 2]);
    final extra = second.isEmpty ? 0 : 9 * alphabet.indexOf(second);
    return alphabet[(sum + extra) % 23];
  }

  final firstSeven = body.substring(0, 7);
  if (!firstSeven.split('').every(_isDigit)) {
    // Historical form: digit, letter or symbol, five digits, check letter.
    return body[7] == checkCharFor('${body.substring(2, 7)}${body[0]}', '');
  }
  final second = body.length > 8 ? body.substring(8) : '';
  if (second.isNotEmpty && !alphabet.contains(second)) return false;
  return body[7] == checkCharFor(firstSeven, second);
}

/// LT: nine digits for a company, twelve for a temporarily registered
/// taxpayer. A first pass whose remainder is 10 is recomputed with the weight
/// sequence shifted by two.
bool _checkLt(String body) {
  final n = body.length - 1;
  var sum = 0;
  for (var i = 0; i < n; i++) {
    sum += (1 + i % 9) * _d(body, i);
  }
  var check = sum % 11;
  if (check == 10) {
    sum = 0;
    for (var i = 0; i < n; i++) {
      sum += (1 + (i + 2) % 9) * _d(body, i);
    }
    check = sum % 11;
  }
  return check % 11 % 10 == _d(body, n);
}

VatSubtype _subtypeLt(String body) =>
    body.length == 12 ? VatSubtype.temporary : VatSubtype.standard;

/// LV: a legal entity when the first digit exceeds 3, otherwise a personal
/// code, and the two use unrelated weightings.
bool _checkLv(String body) {
  if (_d(body, 0) > 3) {
    return weighted(body, const [9, 1, 4, 8, 3, 10, 2, 5, 7, 6, 1]) % 11 == 3;
  }
  final sum = weighted(body, const [10, 5, 8, 4, 2, 1, 6, 3, 7, 9]);
  return (1 + sum) % 11 % 10 == _d(body, 10);
}

VatSubtype _subtypeLv(String body) =>
    _d(body, 0) > 3 ? VatSubtype.legal : VatSubtype.person;

/// NL: nine digits, `B`, two digits.
///
/// Numbers issued before 2020 embed a BSN and satisfy the Dutch eleven-proof.
/// Sole traders were reissued in 2020 with a btw-identificatienummer that
/// carries no BSN and is checked with ISO 7064 MOD 97,10 over `NL` plus the
/// whole number instead. Either passing is enough — insisting on the
/// eleven-proof would reject every reissued sole trader.
bool _checkNl(String body) =>
    _nlElevenProof(body.substring(0, 9)) || mod9710Ok('NL$body');

bool _nlElevenProof(String nine) {
  var sum = 0;
  for (var i = 0; i < 8; i++) {
    sum += (9 - i) * _d(nine, i);
  }
  return (sum - _d(nine, 8)) % 11 == 0;
}

VatSubtype _subtypeNl(String body) => _nlElevenProof(body.substring(0, 9))
    ? VatSubtype.bsn
    : VatSubtype.btwId;
