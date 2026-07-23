import 'iban_metadata.dart';

/// A public description of one country's IBAN format: its total length, the
/// lengths of the bank / branch / account fields, and a valid example.
///
/// Obtained via [IbanCountry.of] or [IbanCountry.values]. Derived from the same
/// bundled metadata that drives IBAN validation.
class IbanCountry {
  const IbanCountry._({
    required this.iso2,
    required this.length,
    required this.bankCodeLength,
    required this.branchCodeLength,
    required this.accountLength,
    required this.example,
  });

  /// ISO 3166-1 alpha-2 code, upper-case (e.g. `AT`).
  final String iso2;

  /// Total IBAN length for this country.
  final int length;

  /// Length of the bank identifier (0 if the country has none).
  final int bankCodeLength;

  /// Length of the branch identifier, or null if the country has none.
  final int? branchCodeLength;

  /// Length of the account-number field.
  final int accountLength;

  /// A valid example IBAN, grouped in blocks of four, e.g.
  /// `AT61 1904 3002 3457 3201`.
  final String example;

  /// Whether this country's IBAN carries a branch identifier.
  bool get hasBranchCode => branchCodeLength != null;

  static IbanCountry _from(String iso2, IbanBban b) {
    final branchStart = b.branchStart;
    final branchEnd = b.branchEnd;
    final branchLen =
        branchStart == null ? null : branchEnd! - branchStart;
    final accountStart = branchEnd ?? b.bankEnd;
    return IbanCountry._(
      iso2: iso2,
      length: b.length,
      bankCodeLength: b.bankEnd - b.bankStart,
      branchCodeLength: branchLen,
      accountLength: b.length - accountStart,
      example: _group(b.example),
    );
  }

  static String _group(String compact) => RegExp(r'.{1,4}')
      .allMatches(compact)
      .map((m) => m.group(0))
      .join(' ');

  /// The descriptor for [code] (case-insensitive ISO2), or null if the country
  /// has no known IBAN format.
  static IbanCountry? of(String code) {
    final cc = code.toUpperCase();
    final b = kIbanBban[cc];
    return b == null ? null : _from(cc, b);
  }

  /// All known IBAN countries, sorted by ISO2 code.
  static List<IbanCountry> get values {
    final codes = kIbanBban.keys.toList()..sort();
    return [for (final cc in codes) _from(cc, kIbanBban[cc]!)];
  }
}
