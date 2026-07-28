import data from '../data/vat-metadata.json';

// The structure of one country's VAT ID: what precedes the number, what the
// number itself may look like, and a published example.
export interface VatFormat {
  // The string written before the number: 'ATU', 'EL', 'CHE', 'XI' or the ISO
  // country code.
  prefix: string;
  // Anchored regex the body must match, prefix excluded.
  body: string;
  // The body's longest permitted length, prefix excluded.
  maxLen: number;
  // A published VAT ID in full written form, or null when none is bundled.
  example: string | null;
}

// Keys are ISO 3166-1 alpha-2 except XI (Northern Ireland), which is a VAT
// prefix rather than a country.
export const kVatFormats = data as unknown as Record<string, VatFormat>;
