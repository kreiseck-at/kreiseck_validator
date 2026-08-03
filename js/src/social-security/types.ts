// The date-of-birth portion of a social-security number, as written.
//
// The year is two digits and the century is deliberately not resolved: any
// rule for doing so is an age heuristic, and that belongs to the calling
// application. A library that guesses the century is how wrong birth dates get
// stored.
export interface SsnBirthDate {
  // Day of month as written, 1-31.
  day: number;
  // Month as written, 1-12.
  month: number;
  // Year as written, 0-99, without a century.
  twoDigitYear: number;
}

// Structured data parsed out of a social-security number by
// SocialSecurityNumber.parse.
export interface SocialSecurityInfo {
  // The three-digit serial number.
  serial: string;
  // The check digit, position 4.
  checkDigit: string;
  // The date of birth as written in the number, or null when the digits do
  // not form a real calendar date.
  //
  // A non-null value is not a verified date of birth. Austria issues numbers
  // whose date part is deliberately fictitious: when every serial for a real
  // date is used up, months 13, 14 and 15 are issued, and a person whose
  // birthday is unknown is registered as 1 January or 1 July of their birth
  // year. The last case produces a perfectly ordinary calendar date that no
  // amount of inspection can tell apart from a real one.
  //
  // § 358 ASVG settles what that means: social-insurance records do not have
  // the quality of civil-status records, and the date carried in the number
  // plays no part in establishing when someone was born. Treat this as the
  // digits the number happens to contain, and collect a date of birth
  // separately if you need one.
  birthDate: SsnBirthDate | null;
}
