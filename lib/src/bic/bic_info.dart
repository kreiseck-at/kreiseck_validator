/// What the second character of a BIC's location code says about it.
///
/// ISO 9362 reserves three digits in that position; everything else is a
/// normal, connected institution.
enum BicKind {
  /// A normal, connected BIC.
  live,

  /// A test-and-training BIC (location code's second character is `0`).
  /// Never usable in a production payment file.
  test,

  /// A passive participant, not connected to the network (`1`), sometimes
  /// called a BIC1 or non-SWIFT BIC.
  passive,

  /// A reverse-billing BIC (`2`): the receiver pays for the message rather
  /// than the sender.
  reverseBilling,
}

/// Structured data parsed out of a BIC by `Bic.parse`.
class BicInfo {
  /// Creates a parsed BIC.
  const BicInfo({
    required this.institution,
    required this.country,
    required this.location,
    required this.branch,
    required this.kind,
  });

  /// Institution (bank) code, 4 letters.
  final String institution;

  /// ISO 3166-1 alpha-2 country code, 2 letters.
  final String country;

  /// Location code, 2 alphanumerics.
  final String location;

  /// Branch code, 3 alphanumerics, or null for the 8-character form.
  ///
  /// `XXX` denotes the primary office and is preserved rather than
  /// normalized away — it is meaningful in SEPA payloads.
  final String? branch;

  /// What the location code's second character marks this BIC as.
  final BicKind kind;
}
