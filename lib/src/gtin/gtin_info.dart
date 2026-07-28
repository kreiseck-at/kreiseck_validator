/// Structured data parsed out of a GTIN by `Gtin.parse`.
class GtinInfo {
  /// Creates a parsed GTIN.
  const GtinInfo({
    required this.length,
    required this.checkDigit,
    required this.gtin14,
  });

  /// Number of digits as entered: 8, 12, 13 or 14.
  ///
  /// Kept because it distinguishes an EAN-8 from a zero-padded EAN-13, which
  /// matters when printing a barcode.
  final int length;

  /// The final digit, the GS1 mod-10 check digit.
  final String checkDigit;

  /// The value left-padded with zeros to 14 digits.
  ///
  /// GS1 recommends this form for storage and comparison: it lets an EAN-13
  /// scanned at the till match an ITF-14 printed on the outer case without the
  /// caller writing the padding itself.
  final String gtin14;
}
