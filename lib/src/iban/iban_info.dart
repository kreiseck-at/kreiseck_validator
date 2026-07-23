import '../common/country.dart';

/// Structured data parsed out of an IBAN by `Iban.parse`.
///
/// Structural fields (`bankCode`, `branchCode`, `accountNumber`) are filled for
/// every country whose BBAN layout is known; they are null otherwise.
/// `bankName` and `bic` are filled only for Austrian IBANs with a known sort
/// code (Bankleitzahl).
class IbanInfo {
  /// Creates an [IbanInfo].
  const IbanInfo({
    required this.country,
    required this.checkDigits,
    this.bankCode,
    this.branchCode,
    this.accountNumber,
    this.bankName,
    this.bic,
    required this.formatted,
  });

  /// The country resolved from the IBAN's two-letter prefix.
  final Country country;

  /// The two ISO 13616 check digits (characters 3-4).
  final String checkDigits;

  /// National bank identifier (e.g. the Austrian BLZ), or null.
  final String? bankCode;

  /// Branch identifier for countries that have one, or null.
  final String? branchCode;

  /// The account-number portion of the BBAN, or null.
  final String? accountNumber;

  /// Registered bank name (Austrian IBANs with a known BLZ only), or null.
  final String? bankName;

  /// BIC (Austrian IBANs with a known BLZ only), or null.
  final String? bic;

  /// The IBAN grouped in blocks of four, e.g. `AT72 1200 0002 3457 3201`.
  final String formatted;
}
