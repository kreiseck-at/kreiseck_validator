/// Countries with dedicated formatting rules (DACH scope).
enum Country {
  /// Germany.
  de,

  /// Austria.
  at,

  /// Switzerland.
  ch;

  /// The E.164 country calling code without the leading `+`.
  String get callingCode => switch (this) {
        Country.de => '49',
        Country.at => '43',
        Country.ch => '41',
      };

  /// The ISO 3166-1 alpha-2 code.
  String get iso2 => switch (this) {
        Country.de => 'DE',
        Country.at => 'AT',
        Country.ch => 'CH',
      };
}
