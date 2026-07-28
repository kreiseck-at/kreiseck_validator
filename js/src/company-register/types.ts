// Structured data parsed out of a company-register number by
// CompanyRegister.parse.
//
// No court field: the registering court is not encoded in the number. An
// Austrian Firmenbuchnummer is assigned centrally and survives a move to a
// different court's district, so any court derived from the number would be a
// guess.
export interface CompanyRegisterInfo {
  // The digits, as written -- not zero-padded.
  number: string;
  // The check letter, lower-case.
  checkChar: string;
}
