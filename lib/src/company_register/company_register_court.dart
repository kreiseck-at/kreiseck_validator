/// The Austrian company-register courts (Firmenbuchgerichte).
///
/// Legal basis: § 120 JN — the courts of first instance entrusted with
/// commercial matters keep the register: the Handelsgericht Wien for Vienna,
/// the Landesgericht für Zivilrechtssachen Graz for Graz, elsewhere the
/// Landesgericht of the district (oesterreich.gv.at, lexicon „Firmenbuch";
/// firmenbuchgrundbuch.at FAQ). The list of Landesgerichte comes from
/// justiz.gv.at; Krems an der Donau, Steyr, Wels and Ried im Innkreis are
/// separate Landesgerichte (checked 2026-08). Mirrored in
/// `test/vectors/company_register_courts.json` and in the JS package.
///
/// The register number does not encode the court, so this list is for forms:
/// a picker, and a tolerant [CompanyRegisterCourt.resolve] for free text.
class CompanyRegisterCourt {
  const CompanyRegisterCourt._(
      this.code, this.name, this.city, this.bundesland, this.bundeslandName);

  /// Stable identifier, e.g. `LG_SALZBURG`.
  final String code;

  /// Official name, e.g. `Landesgericht Salzburg`.
  final String name;
  final String city;

  /// ISO 3166-2:AT code of the federal state, e.g. `AT-5`.
  final String bundesland;
  final String bundeslandName;

  /// All sixteen courts, Handelsgericht Wien first, then alphabetically.
  static const List<CompanyRegisterCourt> all = [
    CompanyRegisterCourt._('HG_WIEN', 'Handelsgericht Wien', 'Wien', 'AT-9', 'Wien'),
    CompanyRegisterCourt._('LG_EISENSTADT', 'Landesgericht Eisenstadt', 'Eisenstadt', 'AT-1', 'Burgenland'),
    CompanyRegisterCourt._('LG_FELDKIRCH', 'Landesgericht Feldkirch', 'Feldkirch', 'AT-8', 'Vorarlberg'),
    CompanyRegisterCourt._('LG_ZRS_GRAZ', 'Landesgericht für Zivilrechtssachen Graz', 'Graz', 'AT-6', 'Steiermark'),
    CompanyRegisterCourt._('LG_INNSBRUCK', 'Landesgericht Innsbruck', 'Innsbruck', 'AT-7', 'Tirol'),
    CompanyRegisterCourt._('LG_KLAGENFURT', 'Landesgericht Klagenfurt', 'Klagenfurt', 'AT-2', 'Kärnten'),
    CompanyRegisterCourt._('LG_KORNEUBURG', 'Landesgericht Korneuburg', 'Korneuburg', 'AT-3', 'Niederösterreich'),
    CompanyRegisterCourt._('LG_KREMS', 'Landesgericht Krems an der Donau', 'Krems an der Donau', 'AT-3', 'Niederösterreich'),
    CompanyRegisterCourt._('LG_LEOBEN', 'Landesgericht Leoben', 'Leoben', 'AT-6', 'Steiermark'),
    CompanyRegisterCourt._('LG_LINZ', 'Landesgericht Linz', 'Linz', 'AT-4', 'Oberösterreich'),
    CompanyRegisterCourt._('LG_RIED', 'Landesgericht Ried im Innkreis', 'Ried im Innkreis', 'AT-4', 'Oberösterreich'),
    CompanyRegisterCourt._('LG_SALZBURG', 'Landesgericht Salzburg', 'Salzburg', 'AT-5', 'Salzburg'),
    CompanyRegisterCourt._('LG_ST_POELTEN', 'Landesgericht St. Pölten', 'St. Pölten', 'AT-3', 'Niederösterreich'),
    CompanyRegisterCourt._('LG_STEYR', 'Landesgericht Steyr', 'Steyr', 'AT-4', 'Oberösterreich'),
    CompanyRegisterCourt._('LG_WELS', 'Landesgericht Wels', 'Wels', 'AT-4', 'Oberösterreich'),
    CompanyRegisterCourt._('LG_WIENER_NEUSTADT', 'Landesgericht Wiener Neustadt', 'Wiener Neustadt', 'AT-3', 'Niederösterreich'),
  ];

  // Spellings people use for the city part, already in key form.
  static const Map<String, String> _aliases = {
    'wien': 'HG_WIEN',
    'graz': 'LG_ZRS_GRAZ',
    'krems': 'LG_KREMS', 'kremsdonau': 'LG_KREMS', 'kremsanderdonau': 'LG_KREMS',
    'ried': 'LG_RIED', 'riedii': 'LG_RIED', 'riediminnkreis': 'LG_RIED',
    'stpoelten': 'LG_ST_POELTEN', 'sanktpoelten': 'LG_ST_POELTEN',
    'wienerneustadt': 'LG_WIENER_NEUSTADT', 'wrneustadt': 'LG_WIENER_NEUSTADT',
  };

  static final RegExp _courtWords = RegExp(
      r'\b(landesgericht|handelsgericht|gericht|fuer|zivilrechtssachen|lgz|lg|hg)\b');
  static final RegExp _nonAlnum = RegExp('[^a-z0-9]');

  /// Key form: lower-case, umlauts unfolded, court words and punctuation
  /// removed. „Landesgericht für Zivilrechtssachen Graz" → `graz`.
  static String _key(String input) => input
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll(_courtWords, ' ')
      .replaceAll(_nonAlnum, '');

  static final Map<String, CompanyRegisterCourt> _byKey = () {
    final m = <String, CompanyRegisterCourt>{};
    for (final c in all) {
      m[_key(c.city)] = c;
      m[c.code.toLowerCase().replaceAll(_nonAlnum, '')] = c;
    }
    _aliases.forEach((alias, code) {
      m[alias] = all.firstWhere((c) => c.code == code);
    });
    return m;
  }();

  /// Resolves free text (or a code) to a court, or `null`: „LG Salzburg",
  /// „Landesgericht Salzburg", „Salzburg", `LG_SALZBURG` all give the same
  /// entry. A federal state name or a foreign court is `null` — no guessing.
  static CompanyRegisterCourt? resolve(String input) {
    final k = _key(input);
    if (k.isEmpty) return null;
    return _byKey[k];
  }

  @override
  String toString() => 'CompanyRegisterCourt($code, $name)';
}
