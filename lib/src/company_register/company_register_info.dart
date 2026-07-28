/// Structured data parsed out of a company-register number by
/// `CompanyRegister.parse`.
class CompanyRegisterInfo {
  /// Creates a parsed company-register number.
  const CompanyRegisterInfo({required this.number, required this.checkChar});

  /// The digits, as written — not zero-padded.
  final String number;

  /// The check letter, lower-case.
  final String checkChar;

  // No court field: the registering court is not encoded in the number. An
  // Austrian Firmenbuchnummer is assigned centrally and survives a move to a
  // different court's district, so any court derived from the number would be
  // a guess.
}
