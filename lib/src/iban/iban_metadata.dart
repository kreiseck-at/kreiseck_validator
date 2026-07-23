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
    required this.example,
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

  /// A valid example IBAN for this country, in compact form.
  final String example;
}

/// A bank resolved from its national bank code (BLZ / BC number).
class Bank {
  /// Creates a bank record.
  const Bank(this.name, this.bic);

  /// Registered bank name.
  final String name;

  /// BIC with the `XXX` head-office filler stripped (8 or 11 characters).
  final String bic;
}
