import '../common/issue_code.dart';
import '../common/validation_result.dart';
import 'plate_info.dart';
import 'plate_type.dart';

part 'plate_metadata.g.dart';

/// Validation, normalization, formatting and parsing of vehicle license
/// plates ("Kennzeichen"). See `doc/algorithms.md`.
///
/// Currently `AT` and `DE` are modelled; other countries resolve to
/// [IssueCode.plateUnknownCountry].
class LicensePlate {
  LicensePlate._();

  static final RegExp _allowedChars = RegExp(r'^[A-ZÄÖÜ0-9 \-.]+$');

  static const Set<String> _knownCountries = {'AT', 'DE'};

  // AT: code (1-2 letters, greedily matched) + serial (letters/digits).
  // Because the code and serial character classes are disjoint (letters vs.
  // the mixed alphanumeric serial always follows a purely-alphabetic prefix
  // boundary), the greedy `{1,2}` deterministically captures both known
  // 2-letter codes (e.g. `GU`) and 1-letter codes (e.g. `W`) without needing
  // a region-table lookup to disambiguate.
  static final RegExp _atStructure = RegExp(r'^([A-Z]{1,2})([A-Z0-9]+)$');

  // AT: state-level diplomatic-corps convention: a single state letter + `D`.
  static final RegExp _atDiplomatic = RegExp(r'^[A-Z]D$');

  // DE: district code (1-3 letters) + serial letters (1-2) + serial digits
  // (1-4) + optional historic/electric suffix. Unlike AT, the code and
  // serial-letters groups are NOT disjoint character classes (both are pure
  // letter runs sitting back-to-back once separators are stripped), so a
  // greedy first group would over-consume (e.g. `MAB1234` could split as
  // `MA`+`B`+`1234` just as validly as `M`+`AB`+`1234`). The district-code
  // group is therefore made *lazy* (`{1,3}?`) so it claims as few letters as
  // possible, leaving the greedy serial-letters group to claim up to 2 --
  // matching the overwhelmingly common real-world shape (short code, 1-2
  // letter serial prefix). A three-letter code followed by a single-letter
  // serial is the one shape this cannot disambiguate without a table lookup;
  // accepted as a known limitation (out of scope per the design doc).
  static final RegExp _deStructure =
      RegExp(r'^([A-ZÄÖÜ]{1,3}?)([A-Z]{1,2})(\d{1,4})([HE]?)$');

  // DE: nationwide authority codes that are not Stadt/Kreis codes (see
  // `tool/data/de-kennzeichen.csv`, which deliberately omits them).
  static const Set<String> _deAuthorityCodes = {'BW', 'BP', 'BD', 'THW'};

  static String _compact(String upperTrimmed) =>
      upperTrimmed.replaceAll(RegExp(r'[\s\-.]'), '');

  /// Resolves the country to validate against. An omitted [country] infers
  /// `AT`; any other explicit code is looked up against [_knownCountries].
  static String? _resolveCountry(String? country) =>
      country == null ? 'AT' : country.toUpperCase();

  static bool _matchesStructure(String country, String compact) =>
      switch (country) {
        'AT' => _atStructure.hasMatch(compact),
        'DE' => _deStructure.hasMatch(compact),
        _ => false,
      };

  /// Validates [input], returning [Valid] with the compact upper-case form.
  static ValidationResult validate(String input, {String? country}) {
    final trimmedUpper = input.trim().toUpperCase();
    if (trimmedUpper.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.plateEmpty, 'Plate is empty.')]);
    }
    if (!_allowedChars.hasMatch(trimmedUpper)) {
      return const Invalid([
        ValidationIssue(IssueCode.plateBadChars, 'Plate has invalid characters.')
      ]);
    }
    final resolved = _resolveCountry(country)!;
    if (!_knownCountries.contains(resolved)) {
      return const Invalid([
        ValidationIssue(IssueCode.plateUnknownCountry, 'Unknown country.')
      ]);
    }
    final compact = _compact(trimmedUpper);
    if (!_matchesStructure(resolved, compact)) {
      return const Invalid([
        ValidationIssue(IssueCode.plateBadFormat, 'Plate has invalid format.')
      ]);
    }
    return Valid(compact);
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input, {String? country}) =>
      validate(input, country: country) is Valid;

  /// Returns the compact upper-case canonical form. Throws [FormatException].
  static String normalize(String input, {String? country}) =>
      switch (validate(input, country: country)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };

  static String _formatAt(String compact) {
    final m = _atStructure.firstMatch(compact)!;
    return '${m.group(1)}-${m.group(2)}';
  }

  static String _formatDe(String compact) {
    final m = _deStructure.firstMatch(compact)!;
    return '${m.group(1)}-${m.group(2)} ${m.group(3)}${m.group(4)}';
  }

  /// Returns the canonical display form. Throws [FormatException].
  static String format(String input, {String? country}) {
    final compact = normalize(input, country: country);
    final resolved = _resolveCountry(country)!;
    return switch (resolved) {
      'AT' => _formatAt(compact),
      'DE' => _formatDe(compact),
      _ => throw StateError('unreachable: $resolved'),
    };
  }

  /// Like [format] but returns null on invalid input.
  static String? tryFormat(String input, {String? country}) {
    try {
      return format(input, country: country);
    } on FormatException {
      return null;
    }
  }

  /// Classifies an AT [districtCode] into a [PlateType]. Known district codes
  /// (present in [kPlateRegions]) are always `standard`, even when they
  /// happen to match the diplomatic pattern (e.g. `MD` is Mödling, not a
  /// diplomatic code); only when the code is unknown does a state letter
  /// followed by `D` fall back to the diplomatic-corps convention.
  static PlateType _classifyAt(String districtCode, String? region) {
    if (region != null) return PlateType.standard;
    return _atDiplomatic.hasMatch(districtCode)
        ? PlateType.diplomatic
        : PlateType.standard;
  }

  /// Classifies a DE plate from its district [code] and H/E [suffix]. The
  /// suffix takes priority over the code-based rules (a historic/electric
  /// plate on an authority code is still classified by its suffix).
  static PlateType _classifyDe(String code, String suffix) {
    if (suffix == 'H') return PlateType.historic;
    if (suffix == 'E') return PlateType.electric;
    if (code == 'Y') return PlateType.military;
    if (_deAuthorityCodes.contains(code)) return PlateType.authority;
    return PlateType.standard;
  }

  /// Parses [input] into a [PlateInfo], or null when it is not a valid plate.
  static PlateInfo? parse(String input, {String? country}) {
    final r = validate(input, country: country);
    if (r is! Valid) return null;
    final compact = r.normalized;
    final resolved = _resolveCountry(country)!;
    switch (resolved) {
      case 'AT':
        final m = _atStructure.firstMatch(compact)!;
        final code = m.group(1)!;
        final serial = m.group(2)!;
        final region = kPlateRegions['AT']?[code];
        return PlateInfo(
          country: 'AT',
          districtCode: code,
          region: region,
          serial: serial,
          type: _classifyAt(code, region),
          formatted: _formatAt(compact),
        );
      case 'DE':
        final m = _deStructure.firstMatch(compact)!;
        final code = m.group(1)!;
        final serialLetters = m.group(2)!;
        final digits = m.group(3)!;
        final suffix = m.group(4) ?? '';
        final region = kPlateRegions['DE']?[code];
        return PlateInfo(
          country: 'DE',
          districtCode: code,
          region: region,
          serial: '$serialLetters $digits',
          type: _classifyDe(code, suffix),
          formatted: _formatDe(compact),
        );
      default:
        return null;
    }
  }
}
