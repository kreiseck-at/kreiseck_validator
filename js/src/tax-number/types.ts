// Structured data parsed out of a tax number by TaxNumber.parse.
export interface TaxNumberInfo {
  // The two-digit Finanzamt number the account was opened at.
  //
  // Informational only. Austria reorganised its tax administration on
  // 2021-01-01 and froze existing account numbers, so this is a historical
  // marker rather than a statement about which office is responsible today --
  // and it is deliberately never used to reject a number.
  //
  // No office name is offered for the same reason: most of the offices these
  // digits refer to no longer exist, so a bundled name table would hand out
  // stale answers with no way to tell.
  office: string;
  // The seven digits after the Finanzamt number, check digit included.
  number: string;
  // The final digit, the Luhn check digit over all nine.
  checkDigit: string;
}
