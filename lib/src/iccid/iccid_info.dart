import '../common/country.dart';

/// Structured data parsed out of an ICCID by `Iccid.parse`.
class IccidInfo {
  /// Creates an [IccidInfo].
  const IccidInfo({
    required this.mii,
    required this.country,
    required this.issuerIdentifier,
    required this.checkDigit,
  });

  /// Major Industry Identifier for telecom, always `'89'`.
  final String mii;

  /// Country resolved from the E.164 calling code following the MII, or
  /// null if the calling code is unrecognized.
  final Country? country;

  /// Digits identifying the issuer, between the country calling code and
  /// the (optional) check digit.
  final String issuerIdentifier;

  /// Luhn check digit (last digit) when the ICCID is 20 digits long, or
  /// null for 19-digit ICCIDs (which carry no check digit).
  final String? checkDigit;
}
