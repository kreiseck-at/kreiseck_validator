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
  // letter runs sitting back-to-back once separators are stripped), so which
  // substring is the code vs. the serial prefix is ambiguous from the
  // compact form alone (e.g. `MAB1234` could split as `MA`+`B`+`1234` just as
  // validly as `M`+`AB`+`1234`). This pattern is used only to decide overall
  // well-formedness (accept/reject); the actual code/serial boundary is
  // resolved separately by [_splitDe], which is separator- and table-aware.
  static final RegExp _deStructure =
      RegExp(r'^([A-ZÄÖÜ]{1,3})([A-Z]{1,2})(\d{1,4})([HE]?)$');

  // DE: nationwide authority codes that are not Stadt/Kreis codes (see
  // `tool/data/de-kennzeichen.csv`, which deliberately omits them).
  static const Set<String> _deAuthorityCodes = {'BW', 'BP', 'BD', 'THW'};

  // DE: leading letter run followed by an explicit separator, used to
  // resolve the code/serial boundary unambiguously when the caller wrote one
  // in (e.g. `GG-A 1234`, `BOR-X 1234`). Because the letter class and the
  // separator class are disjoint, the greedy `{1,3}` here is deterministic:
  // it can only ever match as many letters as actually precede the
  // separator (up to 3), unlike the compact-form ambiguity above.
  static final RegExp _deSeparatorSplit =
      RegExp(r'^([A-ZÄÖÜ]{1,3})[-. ]+(.+)$');

  // DE: a bare serial (letters + digits + optional suffix), used both to
  // validate the tail of a separator-aware split and to validate candidate
  // remainders in the table-aware fallback.
  static final RegExp _deSerial = RegExp(r'^([A-Z]{1,2})(\d{1,4})([HE]?)$');

  static final RegExp _deLettersOnly = RegExp(r'^[A-ZÄÖÜ]+$');

  /// Resolves the DE code/serial split when [trimmedUpper] (the original,
  /// pre-compaction input) has an explicit separator right after the
  /// leading letter run, e.g. `GG-A 1234` or `BOR-X 1234`. Returns null when
  /// there is no such separator, or the remainder is not a valid serial --
  /// callers then fall back to [_deSplitTableAware].
  static ({String code, String serialLetters, String digits, String suffix})?
      _deSplitSeparatorAware(String trimmedUpper) {
    final m = _deSeparatorSplit.firstMatch(trimmedUpper);
    if (m == null) return null;
    final rest = _compact(m.group(2)!);
    final sm = _deSerial.firstMatch(rest);
    if (sm == null) return null;
    return (
      code: m.group(1)!,
      serialLetters: sm.group(1)!,
      digits: sm.group(2)!,
      suffix: sm.group(3) ?? '',
    );
  }

  /// Resolves the DE code/serial split from the compact form alone (no
  /// separator to go by, e.g. `MAB1234`). Tries code lengths 3, 2, 1 --
  /// longest first -- among splits whose remainder is a valid serial, and
  /// prefers the longest one whose code is a known DE district (in
  /// [kPlateRegions]); falls back to the longest merely-valid split if none
  /// of them is known.
  static ({String code, String serialLetters, String digits, String suffix})?
      _deSplitTableAware(String compact) {
    ({String code, String serialLetters, String digits, String suffix})?
        firstValid;
    for (final len in const [3, 2, 1]) {
      if (len >= compact.length) continue;
      final codeCandidate = compact.substring(0, len);
      if (!_deLettersOnly.hasMatch(codeCandidate)) continue;
      final sm = _deSerial.firstMatch(compact.substring(len));
      if (sm == null) continue;
      final candidate = (
        code: codeCandidate,
        serialLetters: sm.group(1)!,
        digits: sm.group(2)!,
        suffix: sm.group(3) ?? '',
      );
      if (kPlateRegions['DE']!.containsKey(codeCandidate)) return candidate;
      firstValid ??= candidate;
    }
    return firstValid;
  }

  /// Resolves the DE code/serial split for an already-validated plate.
  /// Separator-aware splitting takes priority; the table-aware fallback is
  /// only consulted when no explicit separator disambiguates the code.
  static ({String code, String serialLetters, String digits, String suffix})
      _splitDe(String trimmedUpper, String compact) =>
          _deSplitSeparatorAware(trimmedUpper) ??
          _deSplitTableAware(compact)!;

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

  static String _formatDe(String trimmedUpper, String compact) {
    final s = _splitDe(trimmedUpper, compact);
    return '${s.code}-${s.serialLetters} ${s.digits}${s.suffix}';
  }

  /// Returns the canonical display form. Throws [FormatException].
  static String format(String input, {String? country}) {
    final compact = normalize(input, country: country);
    final resolved = _resolveCountry(country)!;
    return switch (resolved) {
      'AT' => _formatAt(compact),
      'DE' => _formatDe(input.trim().toUpperCase(), compact),
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
        final trimmedUpper = input.trim().toUpperCase();
        final s = _splitDe(trimmedUpper, compact);
        final region = kPlateRegions['DE']?[s.code];
        return PlateInfo(
          country: 'DE',
          districtCode: s.code,
          region: region,
          serial: '${s.serialLetters} ${s.digits}',
          type: _classifyDe(s.code, s.suffix),
          formatted: _formatDe(trimmedUpper, compact),
        );
      default:
        return null;
    }
  }
}
