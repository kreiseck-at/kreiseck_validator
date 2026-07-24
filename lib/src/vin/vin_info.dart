/// Structured data parsed out of a VIN by `Vin.parse`.
class VinInfo {
  /// Creates a [VinInfo].
  const VinInfo({
    required this.wmi,
    required this.vds,
    required this.vis,
    required this.checkDigit,
    required this.checkDigitValid,
    required this.modelYear,
    required this.plantCode,
  });

  /// World Manufacturer Identifier (chars 1-3).
  final String wmi;

  /// Vehicle Descriptor Section (chars 4-9).
  final String vds;

  /// Vehicle Identifier Section (chars 10-17).
  final String vis;

  /// The check digit character (char 9).
  final String checkDigit;

  /// Whether [checkDigit] matches the ISO 3779 weighted-sum checksum.
  ///
  /// Mandatory only for North American VINs; European VINs frequently carry
  /// no valid check digit, so this is informational only and never rejected
  /// by [Vin.validate].
  final bool checkDigitValid;

  /// The model year decoded from char 10, resolved against the 30-year
  /// cycle ambiguity using char 7.
  final int modelYear;

  /// The plant code character (char 11).
  final String plantCode;
}
