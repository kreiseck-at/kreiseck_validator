/// Stable, translation-friendly identifiers for validation failures.
enum IssueCode {
  // email
  emailEmpty, emailMissingAt, emailMultipleAt, emailEmptyLocal, emailBadDomain,
  // phone
  phoneEmpty, phoneBadChars, phoneTooShort, phoneTooLong,
  phoneAmbiguousCountry, phoneUnknownCountry,
  // url
  urlEmpty, urlBadScheme, urlBadHost, urlBadTld,
  // iban
  ibanEmpty, ibanBadChars, ibanBadChecksum, ibanBadLength,
  // credit card
  cardEmpty, cardBadChars, cardBadLength, cardBadLuhn,
}
