/// Classification of a license plate's special-purpose form.
///
/// Classification is best-effort: it never blocks validation, and a country
/// whose special-plate rules are not yet modelled always resolves to
/// [standard] rather than guessing.
enum PlateType {
  /// An ordinary civilian plate.
  standard,

  /// A diplomatic-corps plate.
  diplomatic,

  /// A government / Behörden plate.
  authority,

  /// A military plate.
  military,

  /// A transit / short-term plate (Kurzzeit, Probefahrt, Überstellung).
  temporary,

  /// A seasonal plate (Saisonkennzeichen).
  seasonal,

  /// A historic-vehicle plate (Oldtimer / H-Kennzeichen).
  historic,

  /// An electric-vehicle plate.
  electric,

  /// Could not be classified.
  unknown,
}
