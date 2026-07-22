import '../phone/phone_format.dart';

part 'country.g.dart';

/// A country/region with its phone-numbering metadata, derived from
/// libphonenumber. All regions share the same fields; some (e.g. AT) carry
/// additional classification data elsewhere.
class Country {
  const Country({
    required this.iso2,
    required this.callingCode,
    required this.displayName,
    required this.nationalPrefix,
    required this.possibleLengths,
    required this.pattern,
    required this.formats,
    required this.exampleNsn,
    required this.exampleE164,
    required this.exampleNational,
    required this.exampleInternational,
  });

  /// ISO 3166-1 alpha-2 code, upper-case (e.g. `AT`).
  final String iso2;

  /// E.164 country calling code without `+` (e.g. `43`).
  final String callingCode;

  /// English country name (e.g. `Austria`).
  final String displayName;

  /// National trunk prefix (e.g. `0`), or null.
  final String? nationalPrefix;

  /// Allowed national significant number lengths.
  final List<int> possibleLengths;

  /// Regex (anchored at use) for a valid national significant number.
  final String pattern;

  /// National number-format rules.
  final List<PhoneFormat> formats;

  /// Synthetic example national significant number, or null.
  final String? exampleNsn;

  /// Synthetic example in E.164 (e.g. `+43...`), or null.
  final String? exampleE164;

  /// Synthetic example in national display form, or null.
  final String? exampleNational;

  /// Synthetic example in international display form, or null.
  final String? exampleInternational;

  /// Flag emoji derived from [iso2] (regional-indicator symbols).
  String get flag {
    if (iso2.length != 2) return '';
    const base = 0x1F1E6;
    final a = iso2.codeUnitAt(0) - 0x41;
    final b = iso2.codeUnitAt(1) - 0x41;
    if (a < 0 || a > 25 || b < 0 || b > 25) return '';
    return String.fromCharCode(base + a) + String.fromCharCode(base + b);
  }

  /// All supported countries.
  static const List<Country> values = kCountries;

  /// Austria.
  static const Country at = _atData;

  /// Germany.
  static const Country de = _deData;

  /// Switzerland.
  static const Country ch = _chData;

  /// Looks up a country by ISO2 code (case-insensitive); null if unknown.
  static Country? fromIso2(String code) {
    final up = code.toUpperCase();
    for (final c in kCountries) {
      if (c.iso2 == up) return c;
    }
    return null;
  }

  /// Returns the main region for a calling code, or null if none.
  static Country? fromCallingCode(String callingCode) {
    final iso2 = kMainRegionForCallingCode[callingCode];
    if (iso2 == null) return null;
    return fromIso2(iso2);
  }
}
