/// The date-of-birth portion of a social-security number, as written.
///
/// The year is two digits and the century is deliberately not resolved: any
/// rule for doing so is an age heuristic, and that belongs to the calling
/// application. A library that guesses the century is how wrong birth dates
/// get stored.
class SsnBirthDate {
  /// Creates a date-of-birth portion.
  const SsnBirthDate({
    required this.day,
    required this.month,
    required this.twoDigitYear,
  });

  /// Day of month as written, 1-31.
  final int day;

  /// Month as written, 1-12.
  final int month;

  /// Year as written, 0-99, without a century.
  final int twoDigitYear;
}

/// Structured data parsed out of a social-security number by
/// `SocialSecurityNumber.parse`.
class SocialSecurityInfo {
  /// Creates a parsed social-security number.
  const SocialSecurityInfo({
    required this.serial,
    required this.checkDigit,
    required this.birthDate,
  });

  /// The three-digit serial number.
  final String serial;

  /// The check digit, position 4.
  final String checkDigit;

  /// The date of birth **as written in the number**, or null when the digits
  /// do not form a real calendar date.
  ///
  /// A non-null value is not a verified date of birth. Austria issues numbers
  /// whose date part is deliberately fictitious: when every serial for a real
  /// date is used up, months 13, 14 and 15 are issued, and a person whose
  /// birthday is unknown is registered as 1 January or 1 July of their birth
  /// year. The last case produces a perfectly ordinary calendar date that no
  /// amount of inspection can tell apart from a real one.
  ///
  /// § 358 ASVG settles what that means: social-insurance records do not have
  /// the quality of civil-status records, and the date carried in the number
  /// plays no part in establishing when someone was born. Treat this as the
  /// digits the number happens to contain, and collect a date of birth
  /// separately if you need one.
  final SsnBirthDate? birthDate;
}
