// Which kind of number a VAT ID turned out to be.
//
// Several member states pack genuinely different entities into one field, and
// the difference changes what a caller may assume -- whether a name can be
// looked up, whether reverse charge applies, whether the holder is a natural
// person. Reporting it here saves every consumer from re-parsing the number.
//
// - standard: the country has only one kind, or this is the ordinary one
// - legal / person: countries that distinguish them (BG, CZ, LV)
// - individual: a CZ number derived from a national personal code (10 digits)
// - special: the CZ nine-digit variant beginning with 6
// - dni / nie / cif: the three Spanish forms (national, foreign, entity)
// - temporary: a LT number for a temporarily registered taxpayer (12 digits)
// - branch: a UK branch trader (12 digits; only the first nine are checked)
// - government / healthAuthority: the UK GD and HA forms
// - bsn: a NL number whose first nine digits are a BSN (issued before 2020)
// - btwId: a NL btw-identificatienummer issued from 2020, carrying no BSN
export type VatSubtype =
  | 'standard' | 'legal' | 'person' | 'individual' | 'special'
  | 'dni' | 'nie' | 'cif' | 'temporary'
  | 'branch' | 'government' | 'healthAuthority'
  | 'bsn' | 'btwId';

// Structured data parsed out of a VAT ID by VatId.parse.
export interface VatInfo {
  // ISO 3166-1 alpha-2 country code.
  //
  // Greece is 'GR' here even though its VAT prefix is 'EL', and Northern
  // Ireland is 'GB' even though its VAT prefix is 'XI' -- prefix carries the
  // tax-side spelling, this field carries the ISO one.
  country: string;
  // The prefix as used for VAT: 'ATU', 'EL', 'CHE', 'XI', or the ISO code.
  prefix: string;
  // The number without its prefix.
  number: string;
  // Which kind of number this is.
  subtype: VatSubtype;
}
