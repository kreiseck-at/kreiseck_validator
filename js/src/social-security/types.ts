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
  // The date of birth, or null when the number does not carry a real one.
  //
  // Austria issues numbers whose date part is deliberately fictitious: when
  // every serial for a real date is used up, months 13, 14 and 15 are issued,
  // and a person whose birthday is unknown gets 1 January or 1 July of their
  // birth year. Those are correct, valid numbers -- so validation never looks
  // at the date, and this field is simply null whenever the digits do not form
  // a real calendar date.
  birthDate: SsnBirthDate | null;
}
