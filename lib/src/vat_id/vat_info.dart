/// Which kind of number a VAT ID turned out to be.
///
/// Several member states pack genuinely different entities into one field, and
/// the difference changes what a caller may assume — whether a name can be
/// looked up, whether reverse charge applies, whether the holder is a natural
/// person. Reporting it here saves every consumer from re-parsing the number.
enum VatSubtype {
  /// The country has only one kind of number, or the number is the ordinary
  /// one.
  standard,

  /// A legal entity, where the country distinguishes them from persons
  /// (BG, CZ, LV).
  legal,

  /// A natural person, where the country distinguishes them (BG, LV).
  person,

  /// An individual's number derived from a national personal code
  /// (CZ, 10 digits).
  individual,

  /// The Czech nine-digit variant beginning with `6`.
  special,

  /// A Spanish DNI-based number (natural person, Spanish national).
  dni,

  /// A Spanish NIE-based number (natural person, foreign national).
  nie,

  /// A Spanish CIF-based number (legal entity).
  cif,

  /// A Lithuanian number issued to a temporarily registered taxpayer
  /// (12 digits).
  temporary,

  /// A UK branch trader (12 digits; only the first nine are checked).
  branch,

  /// A UK government department (`GD` form).
  government,

  /// A UK health authority (`HA` form).
  healthAuthority,

  /// A Dutch number whose first nine digits are a BSN, i.e. issued before the
  /// 2020 change.
  bsn,

  /// A Dutch btw-identificatienummer issued from 2020, which carries no BSN
  /// and uses the ISO 7064 MOD 97,10 check instead.
  btwId,
}

/// Structured data parsed out of a VAT ID by `VatId.parse`.
class VatInfo {
  /// Creates a parsed VAT ID.
  const VatInfo({
    required this.country,
    required this.prefix,
    required this.number,
    required this.subtype,
  });

  /// ISO 3166-1 alpha-2 country code.
  ///
  /// Greece is `GR` here even though its VAT prefix is `EL`, and Northern
  /// Ireland is `GB` even though its VAT prefix is `XI` — [prefix] carries the
  /// tax-side spelling, this field carries the ISO one.
  final String country;

  /// The prefix as used for VAT: `ATU`, `EL`, `CHE`, `XI`, or the ISO code.
  final String prefix;

  /// The number without its prefix.
  final String number;

  /// Which kind of number this is.
  final VatSubtype subtype;
}
