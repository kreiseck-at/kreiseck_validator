// What the second character of a BIC's location code says about it. ISO 9362
// reserves three digits in that position; everything else is a normal,
// connected institution.
//
// - test: a test-and-training BIC, never usable in a production payment file
// - passive: not connected to the network (a BIC1 / non-SWIFT BIC)
// - reverseBilling: the receiver pays for the message, not the sender
export type BicKind = 'live' | 'test' | 'passive' | 'reverseBilling';

// Structured data parsed out of a BIC by Bic.parse.
export interface BicInfo {
  // Institution (bank) code, 4 letters.
  institution: string;
  // ISO 3166-1 alpha-2 country code, 2 letters.
  country: string;
  // Location code, 2 alphanumerics.
  location: string;
  // Branch code, 3 alphanumerics, or null for the 8-character form. 'XXX'
  // denotes the primary office and is preserved rather than normalized away —
  // it is meaningful in SEPA payloads.
  branch: string | null;
  // What the location code's second character marks this BIC as.
  kind: BicKind;
}
