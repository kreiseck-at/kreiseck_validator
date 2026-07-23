// The kind of phone number, derived from the public numbering plan. Describes
// the number *type*, not the current operator (number portability means a
// prefix no longer identifies the carrier). Classification data currently
// exists only for AT; all other countries resolve to `unknown`.
export type PhoneNumberType =
  | 'mobile'
  | 'landline'
  | 'voip'
  | 'freephone'
  | 'sharedCost'
  | 'premium'
  | 'corporate'
  | 'unknown';

// A single national number-format rule (derived from libphonenumber).
export interface PhoneFormat {
  // Regex matched against the national significant number.
  readonly pattern: string;
  // Output template using $1, $2, ... group references.
  readonly format: string;
  // If set, this rule applies only when the number starts with this prefix.
  readonly leadingDigits: string | null;
  // National-prefix rendering rule (e.g. `0$1`); applies to national form.
  readonly nationalPrefixFormattingRule: string | null;
}

// A country/region with its phone-numbering metadata, derived from
// libphonenumber. All regions share the same fields; some (e.g. AT) carry
// additional classification data elsewhere.
export interface Country {
  // ISO 3166-1 alpha-2 code, upper-case (e.g. `AT`).
  readonly iso2: string;
  // E.164 country calling code without `+` (e.g. `43`).
  readonly callingCode: string;
  // English country name (e.g. `Austria`).
  readonly displayName: string;
  // National trunk prefix (e.g. `0`), or null.
  readonly nationalPrefix: string | null;
  // Allowed national significant number lengths.
  readonly possibleLengths: number[];
  // Regex (anchored at use) for a valid national significant number.
  readonly pattern: string;
  // National number-format rules.
  readonly formats: PhoneFormat[];
  // International number-format rules; empty when the national formats are
  // also used internationally.
  readonly intlFormats: PhoneFormat[];
  // Whether this is the main region for its calling code (e.g. US for +1).
  readonly mainForCallingCode: boolean;
  // Synthetic example national significant number, or null.
  readonly exampleNsn: string | null;
  // Synthetic example in E.164 (e.g. `+43...`), or null.
  readonly exampleE164: string | null;
  // Synthetic example in national display form, or null.
  readonly exampleNational: string | null;
  // Synthetic example in international display form, or null.
  readonly exampleInternational: string | null;
}

// A parsed, classified phone number with its canonical and display forms.
export interface PhoneInfo {
  // Canonical E.164 form, e.g. `+43316123456`.
  readonly e164: string;
  // The resolved country.
  readonly country: Country;
  // The classified number type (`unknown` for countries without
  // classification data — currently all but AT).
  readonly type: PhoneNumberType;
  // National display form, e.g. `0316 123456`.
  readonly national: string;
  // International display form, e.g. `+43 316 123456`.
  readonly international: string;
}
