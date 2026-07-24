/// Stable, translation-friendly identifiers for validation failures.
enum IssueCode {
  // email
  emailEmpty,
  emailMissingAt,
  emailMultipleAt,
  emailEmptyLocal,
  emailBadDomain,
  // phone
  phoneEmpty,
  phoneBadChars,
  phoneTooShort,
  phoneTooLong,
  phoneAmbiguousCountry,
  phoneUnknownCountry,
  phoneInvalid,
  // url
  urlEmpty,
  urlBadScheme,
  urlBadHost,
  urlBadTld,
  // iban
  ibanEmpty,
  ibanBadChars,
  ibanBadChecksum,
  ibanBadLength,
  // credit card
  cardEmpty,
  cardBadChars,
  cardBadLength,
  cardBadLuhn,
  // license plate
  plateEmpty,
  plateBadChars,
  plateBadFormat,
  plateUnknownCountry,
  plateAmbiguousCountry,
  // imei
  imeiEmpty,
  imeiBadChars,
  imeiBadLength,
  imeiBadChecksum,
  // iccid
  iccidEmpty,
  iccidBadChars,
  iccidBadLength,
  iccidBadChecksum,
  // mac address
  macEmpty,
  macBadFormat,
}
