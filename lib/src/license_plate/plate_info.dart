import 'plate_type.dart';

/// Structured data parsed out of a license plate by `LicensePlate.parse`.
///
/// [region] is null when the district/canton/province code is unknown (not
/// present in the curated region table) or when the country could not be
/// resolved unambiguously; the plate is still valid in that case.
class PlateInfo {
  /// Creates a [PlateInfo].
  const PlateInfo({
    required this.country,
    required this.districtCode,
    this.region,
    required this.serial,
    required this.type,
    required this.formatted,
  });

  /// The ISO 3166-1 alpha-2 country code, e.g. `AT`.
  final String country;

  /// The district/canton/province code, e.g. `W` (Wien) or `GU` (Graz-Umgebung).
  final String districtCode;

  /// The official region name for [districtCode], or null if unknown.
  final String? region;

  /// The individual (serial) part of the plate, normalized.
  final String serial;

  /// The classification of this plate.
  final PlateType type;

  /// The canonical display form, e.g. `W-12345A`.
  final String formatted;
}
