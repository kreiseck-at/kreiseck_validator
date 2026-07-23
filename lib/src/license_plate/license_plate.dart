import '../common/issue_code.dart';
import '../common/validation_result.dart';
import 'plate_info.dart';
import 'plate_type.dart';

part 'plate_metadata.g.dart';

/// Validation, normalization, formatting and parsing of vehicle license
/// plates ("Kennzeichen"). See `doc/algorithms.md`.
///
/// Currently `AT`, `DE`, `CH`, `HR` and `TR` are modelled; other countries
/// resolve to [IssueCode.plateUnknownCountry].
class LicensePlate {
  LicensePlate._();

  static final RegExp _allowedChars =
      RegExp(r'^[A-ZÄÖÜČŠŽ0-9 \-.]+$');

  static const Set<String> _knownCountries = {'AT', 'DE', 'CH', 'HR', 'TR'};

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

  // CH: canton code (2 letters) + serial (1-6 digits), e.g. `ZH123456`.
  // Unlike AT/DE, the canton set is closed and small (26 entries): a
  // 2-letter prefix that structurally matches but is not a known canton is
  // rejected as `plateBadFormat` rather than accepted with a null region --
  // see [_matchesChStructure].
  static final RegExp _chStructure = RegExp(r'^([A-Z]{2})(\d{1,6})$');

  // HR: registration-area code (2 letters, may include Č/Š/Ž) + serial
  // digits (3-4) + serial letters (1-2), e.g. `ZG1234AB`. Like CH, the
  // registration-area set is closed and small (34 entries): a 2-letter
  // prefix that structurally matches but is not a known code is rejected as
  // `plateBadFormat` -- see [_matchesHrStructure]. Unlike DE, the digit and
  // letter groups are disjoint character classes, so the split is always
  // unambiguous.
  static final RegExp _hrStructure =
      RegExp(r'^([A-ZČŠŽ]{2})(\d{3,4})([A-Z]{1,2})$');

  // TR: province code (2 digits) + serial letters (1-3) + serial digits
  // (2-4), e.g. `34ABC123`. Like CH/HR, the province set is closed and
  // small (81 entries, 01-81): a 2-digit prefix that structurally matches
  // but is not a known province is rejected as `plateBadFormat` -- see
  // [_matchesTrStructure]. The digit and letter groups are disjoint
  // character classes, so the split is always unambiguous.
  static final RegExp _trStructure =
      RegExp(r'^(\d{2})([A-Z]{1,3})(\d{2,4})$');

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

  /// CH's canton set is closed and small: unlike AT/DE (where an unknown
  /// district/Unterscheidungszeichen still validates with a null [region]),
  /// a CH plate whose 2-letter prefix is not one of the 26 cantons in
  /// [kPlateRegions] is `plateBadFormat`, not merely unresolved.
  static bool _matchesChStructure(String compact) {
    final m = _chStructure.firstMatch(compact);
    if (m == null) return false;
    return kPlateRegions['CH']!.containsKey(m.group(1)!);
  }

  /// HR's registration-area set is closed and small, same as CH: an HR
  /// plate whose 2-letter prefix is not one of the 34 codes in
  /// [kPlateRegions] is `plateBadFormat`, not merely unresolved.
  static bool _matchesHrStructure(String compact) {
    final m = _hrStructure.firstMatch(compact);
    if (m == null) return false;
    return kPlateRegions['HR']!.containsKey(m.group(1)!);
  }

  /// TR's province set is closed and small, same as CH/HR: a TR plate whose
  /// 2-digit prefix is not one of the 81 provinces in [kPlateRegions] is
  /// `plateBadFormat`, not merely unresolved (e.g. `82`, which does not
  /// exist).
  static bool _matchesTrStructure(String compact) {
    final m = _trStructure.firstMatch(compact);
    if (m == null) return false;
    return kPlateRegions['TR']!.containsKey(m.group(1)!);
  }

  static bool _matchesStructure(String country, String compact) =>
      switch (country) {
        'AT' => _atStructure.hasMatch(compact),
        'DE' => _deStructure.hasMatch(compact),
        'CH' => _matchesChStructure(compact),
        'HR' => _matchesHrStructure(compact),
        'TR' => _matchesTrStructure(compact),
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

  static String _formatCh(String compact) {
    final m = _chStructure.firstMatch(compact)!;
    return '${m.group(1)} ${m.group(2)}';
  }

  static String _formatHr(String compact) {
    final m = _hrStructure.firstMatch(compact)!;
    return '${m.group(1)} ${m.group(2)}-${m.group(3)}';
  }

  static String _formatTr(String compact) {
    final m = _trStructure.firstMatch(compact)!;
    return '${m.group(1)} ${m.group(2)} ${m.group(3)}';
  }

  /// Returns the canonical display form. Throws [FormatException].
  static String format(String input, {String? country}) {
    final compact = normalize(input, country: country);
    final resolved = _resolveCountry(country)!;
    return switch (resolved) {
      'AT' => _formatAt(compact),
      'DE' => _formatDe(input.trim().toUpperCase(), compact),
      'CH' => _formatCh(compact),
      'HR' => _formatHr(compact),
      'TR' => _formatTr(compact),
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

  /// Classifies a CH plate. There is no reliable text-only signal to
  /// distinguish federal/diplomatic CH plates from civilian ones, so every
  /// (structurally valid, known-canton) CH plate classifies as `standard`.
  static PlateType _classifyCh(String districtCode) => PlateType.standard;

  /// Classifies an HR plate. As with CH, there is no reliable text-only
  /// signal to distinguish special (diplomatic, military, ...) HR plates
  /// from civilian ones, so every (structurally valid, known-code) HR plate
  /// classifies as `standard`.
  static PlateType _classifyHr(String districtCode) => PlateType.standard;

  /// Classifies a TR plate. As with CH/HR, there is no reliable text-only
  /// signal to distinguish special (diplomatic, military, ...) TR plates
  /// from civilian ones, so every (structurally valid, known-province) TR
  /// plate classifies as `standard`.
  static PlateType _classifyTr(String districtCode) => PlateType.standard;

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
      case 'CH':
        final m = _chStructure.firstMatch(compact)!;
        final code = m.group(1)!;
        final serial = m.group(2)!;
        return PlateInfo(
          country: 'CH',
          districtCode: code,
          region: kPlateRegions['CH']?[code],
          serial: serial,
          type: _classifyCh(code),
          formatted: _formatCh(compact),
        );
      case 'HR':
        final m = _hrStructure.firstMatch(compact)!;
        final code = m.group(1)!;
        final digits = m.group(2)!;
        final letters = m.group(3)!;
        return PlateInfo(
          country: 'HR',
          districtCode: code,
          region: kPlateRegions['HR']?[code],
          serial: '$digits-$letters',
          type: _classifyHr(code),
          formatted: _formatHr(compact),
        );
      case 'TR':
        final m = _trStructure.firstMatch(compact)!;
        final code = m.group(1)!;
        final letters = m.group(2)!;
        final digits = m.group(3)!;
        return PlateInfo(
          country: 'TR',
          districtCode: code,
          region: kPlateRegions['TR']?[code],
          serial: '$letters $digits',
          type: _classifyTr(code),
          formatted: _formatTr(compact),
        );
      default:
        return null;
    }
  }
}
