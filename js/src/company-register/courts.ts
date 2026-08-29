// The Austrian company-register courts (Firmenbuchgerichte).
//
// Legal basis: § 120 JN -- the courts of first instance entrusted with
// commercial matters keep the register: the Handelsgericht Wien for Vienna,
// the Landesgericht für Zivilrechtssachen Graz for Graz, elsewhere the
// Landesgericht of the district (oesterreich.gv.at, lexicon "Firmenbuch";
// firmenbuchgrundbuch.at FAQ). The list of Landesgerichte comes from
// justiz.gv.at; Krems an der Donau, Steyr, Wels and Ried im Innkreis are
// separate Landesgerichte (checked 2026-08). Mirrored in
// test/vectors/company_register_courts.json and in the Dart package.
//
// The register number does not encode the court (see types.ts), so this list
// is for forms: a picker, and a tolerant `court()` for free text.

export interface CompanyRegisterCourt {
  // Stable identifier, e.g. `LG_SALZBURG`.
  code: string;
  // Official name, e.g. `Landesgericht Salzburg`.
  name: string;
  city: string;
  // ISO 3166-2:AT code of the federal state, e.g. `AT-5`.
  bundesland: string;
  bundeslandName: string;
}

const c = (code: string, name: string, city: string, bundesland: string, bundeslandName: string): CompanyRegisterCourt =>
  ({ code, name, city, bundesland, bundeslandName });

export const COURTS: readonly CompanyRegisterCourt[] = Object.freeze([
  c('HG_WIEN', 'Handelsgericht Wien', 'Wien', 'AT-9', 'Wien'),
  c('LG_EISENSTADT', 'Landesgericht Eisenstadt', 'Eisenstadt', 'AT-1', 'Burgenland'),
  c('LG_FELDKIRCH', 'Landesgericht Feldkirch', 'Feldkirch', 'AT-8', 'Vorarlberg'),
  c('LG_ZRS_GRAZ', 'Landesgericht für Zivilrechtssachen Graz', 'Graz', 'AT-6', 'Steiermark'),
  c('LG_INNSBRUCK', 'Landesgericht Innsbruck', 'Innsbruck', 'AT-7', 'Tirol'),
  c('LG_KLAGENFURT', 'Landesgericht Klagenfurt', 'Klagenfurt', 'AT-2', 'Kärnten'),
  c('LG_KORNEUBURG', 'Landesgericht Korneuburg', 'Korneuburg', 'AT-3', 'Niederösterreich'),
  c('LG_KREMS', 'Landesgericht Krems an der Donau', 'Krems an der Donau', 'AT-3', 'Niederösterreich'),
  c('LG_LEOBEN', 'Landesgericht Leoben', 'Leoben', 'AT-6', 'Steiermark'),
  c('LG_LINZ', 'Landesgericht Linz', 'Linz', 'AT-4', 'Oberösterreich'),
  c('LG_RIED', 'Landesgericht Ried im Innkreis', 'Ried im Innkreis', 'AT-4', 'Oberösterreich'),
  c('LG_SALZBURG', 'Landesgericht Salzburg', 'Salzburg', 'AT-5', 'Salzburg'),
  c('LG_ST_POELTEN', 'Landesgericht St. Pölten', 'St. Pölten', 'AT-3', 'Niederösterreich'),
  c('LG_STEYR', 'Landesgericht Steyr', 'Steyr', 'AT-4', 'Oberösterreich'),
  c('LG_WELS', 'Landesgericht Wels', 'Wels', 'AT-4', 'Oberösterreich'),
  c('LG_WIENER_NEUSTADT', 'Landesgericht Wiener Neustadt', 'Wiener Neustadt', 'AT-3', 'Niederösterreich'),
]);

// Spellings people use for the city part, already in key form (see `key`).
const ALIASES: Record<string, string> = {
  wien: 'HG_WIEN',
  graz: 'LG_ZRS_GRAZ',
  krems: 'LG_KREMS', kremsdonau: 'LG_KREMS', kremsanderdonau: 'LG_KREMS',
  ried: 'LG_RIED', riedii: 'LG_RIED', riediminnkreis: 'LG_RIED',
  stpoelten: 'LG_ST_POELTEN', sanktpoelten: 'LG_ST_POELTEN',
  wienerneustadt: 'LG_WIENER_NEUSTADT', wrneustadt: 'LG_WIENER_NEUSTADT',
};

// Key form: lower-case, umlauts unfolded, court words and punctuation removed.
// "Landesgericht für Zivilrechtssachen Graz" -> "graz", "LG Wr. Neustadt" -> "wrneustadt".
function key(input: string): string {
  return input
    .toLowerCase()
    .replace(/ä/g, 'ae').replace(/ö/g, 'oe').replace(/ü/g, 'ue').replace(/ß/g, 'ss')
    .replace(/\b(landesgericht|handelsgericht|gericht|fuer|zivilrechtssachen|lgz|lg|hg)\b/g, ' ')
    .replace(/[^a-z0-9]/g, '');
}

const BY_KEY: Record<string, CompanyRegisterCourt> = {};
for (const court of COURTS) {
  BY_KEY[key(court.city)] = court;
  BY_KEY[court.code.toLowerCase().replace(/[^a-z0-9]/g, '')] = court;
}
for (const [alias, code] of Object.entries(ALIASES)) {
  BY_KEY[alias] = COURTS.find((x) => x.code === code)!;
}

// Resolves free text (or a code) to a court, or null: "LG Salzburg",
// "Landesgericht Salzburg", "Salzburg", "LG_SALZBURG" all give the same entry.
// A federal state name or a foreign court is null -- no guessing.
export function court(input: string): CompanyRegisterCourt | null {
  const k = key(input ?? '');
  if (k.length === 0) return null;
  return BY_KEY[k] ?? null;
}
