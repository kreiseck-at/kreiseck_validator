/// Structured data parsed out of an IMEI by `Imei.parse`.
class ImeiInfo {
  /// Creates an [ImeiInfo].
  const ImeiInfo({
    required this.tac,
    required this.serialNumber,
    required this.checkDigit,
    required this.reportingBodyIdentifier,
  });

  /// Type Allocation Code (first 8 digits).
  final String tac;

  /// Serial number (next 6 digits).
  final String serialNumber;

  /// Luhn check digit (last digit).
  final String checkDigit;

  /// Reporting Body Identifier (first 2 digits of the TAC).
  final String reportingBodyIdentifier;
}
