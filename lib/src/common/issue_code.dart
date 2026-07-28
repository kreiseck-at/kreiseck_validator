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
  // vin
  vinEmpty,
  vinBadChars,
  vinBadLength,
  // postal code
  postalEmpty,
  postalBadFormat,
  postalUnknownCountry,
  // host
  hostEmpty,
  hostBadFormat,
  hostBadPort,
  // bic
  bicEmpty,
  bicBadLength,
  bicBadChars,
  bicUnknownCountry,
  // gtin
  gtinEmpty,
  gtinBadChars,
  gtinBadLength,
  gtinBadChecksum,
  // vat id
  vatEmpty,
  vatBadFormat,
  vatBadChecksum,
  vatUnknownCountry,
  vatAmbiguousCountry,
  // social security number
  ssnEmpty,
  ssnBadChars,
  ssnBadLength,
  ssnBadChecksum,
  ssnBadDate,
  ssnUnknownCountry,
  // company register
  companyRegisterEmpty,
  companyRegisterBadFormat,
  companyRegisterBadChecksum,
  companyRegisterUnknownCountry,
  // tax number
  taxNumberEmpty,
  taxNumberBadChars,
  taxNumberBadLength,
  taxNumberBadChecksum,
  taxNumberUnknownCountry,
}
