part 'iban_metadata.g.dart';

/// BBAN field layout for one country, as absolute offsets into the compact
/// IBAN string. Indices 0-3 are the country code plus check digits.
class IbanBban {
  /// Creates a BBAN layout.
  const IbanBban({
    required this.length,
    required this.bankStart,
    required this.bankEnd,
    this.branchStart,
    this.branchEnd,
  });

  /// Total IBAN length for this country.
  final int length;

  /// Start (inclusive) of the bank identifier slice.
  final int bankStart;

  /// End (exclusive) of the bank identifier slice.
  final int bankEnd;

  /// Start of the branch identifier slice, or null when there is none.
  final int? branchStart;

  /// End of the branch identifier slice, or null when there is none.
  final int? branchEnd;
}

/// An Austrian bank resolved from its sort code (Bankleitzahl).
class AtBank {
  /// Creates a bank record.
  const AtBank(this.name, this.bic);

  /// Registered bank name.
  final String name;

  /// BIC with the `XXX` head-office filler stripped (8 or 11 characters).
  final String bic;
}
