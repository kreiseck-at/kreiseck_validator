// Options accepted by every PostalCode operation.
export interface PostalOptions {
  // ISO 3166-1 alpha-2 country code (e.g. 'DE'). Required: a bare postal
  // code is ambiguous across countries (plain 4-digit codes are valid in a
  // dozen of them).
  country: string;
}

// Structured data parsed out of a postal code by PostalCode.parse.
export interface PostalInfo {
  // The ISO 3166-1 alpha-2 country code, e.g. 'NL'.
  country: string;
  // The canonical, normalized postal code, e.g. '1234 AB'.
  code: string;
}
