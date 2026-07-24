import data from '../data/postal-metadata.json';

// A per-country postal-code pattern: an anchored validation regex plus a
// canonical spacing rule.
//
// format encodes where (if anywhere) a separator is inserted into the
// compact (separator-stripped) form to produce the canonical form:
//  - '': no separator; the compact form is already canonical.
//  - 'N:C': insert literal separator C after N characters from the start
//    (e.g. '2:-' for PL: 00950 -> 00-950).
//  - 'U': UK postcode style -- insert a single space before the last 3
//    characters, regardless of total length (e.g. GB: SW1A1AA -> SW1A 1AA).
export interface PostalPattern {
  pattern: string;
  format: string;
}

// country -> postal pattern.
export const kPostalPatterns = data as Record<string, PostalPattern>;
