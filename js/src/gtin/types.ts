// Structured data parsed out of a GTIN by Gtin.parse.
export interface GtinInfo {
  // Number of digits as entered: 8, 12, 13 or 14. Kept because it
  // distinguishes an EAN-8 from a zero-padded EAN-13, which matters when
  // printing a barcode.
  length: number;
  // The final digit, the GS1 mod-10 check digit.
  checkDigit: string;
  // The value left-padded with zeros to 14 digits. GS1 recommends this form
  // for storage and comparison: it lets an EAN-13 scanned at the till match an
  // ITF-14 printed on the outer case without the caller writing the padding.
  gtin14: string;
}
