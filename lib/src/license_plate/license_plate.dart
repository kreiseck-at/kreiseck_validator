import '../common/issue_code.dart';
import '../common/validation_result.dart';
import 'plate_info.dart';
import 'plate_type.dart';

part 'plate_metadata.g.dart';

/// Validation, normalization, formatting and parsing of vehicle license
/// plates ("Kennzeichen"). See `doc/algorithms.md`.
///
/// Currently only Austria (`AT`) is modelled; other countries resolve to
/// [IssueCode.plateUnknownCountry].
class LicensePlate {
  LicensePlate._();

  static final RegExp _allowedChars = RegExp(r'^[A-Z0-9 \-.]+$');

  // Code (1-2 letters, greedily matched) + serial (letters/digits). Because
  // the code and serial character classes are disjoint (letters vs. the
  // mixed alphanumeric serial always follows a purely-alphabetic prefix
  // boundary), the greedy `{1,2}` deterministically captures both known
  // 2-letter codes (e.g. `GU`) and 1-letter codes (e.g. `W`) without needing
  // a region-table lookup to disambiguate.
  static final RegExp _structure = RegExp(r'^([A-Z]{1,2})([A-Z0-9]+)$');

  // State-level diplomatic-corps convention: a single state letter + `D`.
  static final RegExp _diplomatic = RegExp(r'^[A-Z]D$');

  static String _compact(String upperTrimmed) =>
      upperTrimmed.replaceAll(RegExp(r'[\s\-.]'), '');

  /// Resolves the country to validate against. Stage 1 only knows AT, so an
  /// omitted [country] infers AT; any other explicit code is unsupported.
  static String? _resolveCountry(String? country) =>
      country == null ? 'AT' : country.toUpperCase();

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
    final resolved = _resolveCountry(country);
    if (resolved != 'AT') {
      return const Invalid([
        ValidationIssue(IssueCode.plateUnknownCountry, 'Unknown country.')
      ]);
    }
    final compact = _compact(trimmedUpper);
    if (!_structure.hasMatch(compact)) {
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

  /// Returns the canonical `CODE-SERIAL` display form. Throws [FormatException].
  static String format(String input, {String? country}) {
    final compact = normalize(input, country: country);
    final m = _structure.firstMatch(compact)!;
    return '${m.group(1)}-${m.group(2)}';
  }

  /// Like [format] but returns null on invalid input.
  static String? tryFormat(String input, {String? country}) {
    try {
      return format(input, country: country);
    } on FormatException {
      return null;
    }
  }

  /// Classifies a valid [districtCode] into a [PlateType]. AT: a state
  /// letter followed by `D` is the diplomatic-corps convention; everything
  /// else is a standard civilian plate.
  static PlateType _classify(String districtCode) =>
      _diplomatic.hasMatch(districtCode) ? PlateType.diplomatic : PlateType.standard;

  /// Parses [input] into a [PlateInfo], or null when it is not a valid plate.
  static PlateInfo? parse(String input, {String? country}) {
    final r = validate(input, country: country);
    if (r is! Valid) return null;
    final compact = r.normalized;
    final m = _structure.firstMatch(compact)!;
    final code = m.group(1)!;
    final serial = m.group(2)!;
    final resolved = _resolveCountry(country)!;
    return PlateInfo(
      country: resolved,
      districtCode: code,
      region: kPlateRegions[resolved]?[code],
      serial: serial,
      type: _classify(code),
      formatted: format(input, country: country),
    );
  }
}
