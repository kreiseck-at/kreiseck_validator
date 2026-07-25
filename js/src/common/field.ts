// Which on-screen keyboard a field should raise. Platform-neutral by design:
// the package has no DOM or framework dependency. See the README for the
// mapping to `inputmode` and to Flutter's TextInputType.
export type KeyboardType = 'text' | 'digits' | 'phone' | 'email' | 'url';

// How typed characters should be cased.
export type Capitalization = 'none' | 'characters' | 'words' | 'sentences';

// Platform autofill category. Only categories that exist on both the web and
// Flutter are listed; value types without a standard category (IBAN, VIN,
// IMEI, ICCID, MAC, license plate) carry a null autofill instead.
export type AutofillHint =
  | 'email'
  | 'telephoneNumber'
  | 'postalCode'
  | 'creditCardNumber'
  | 'url';

// The input characteristics of a field holding one kind of value. Obtained
// from any validator's fieldDescriptor, which takes the same options as its
// validate. Everything here is a hint for building an input field; none of it
// affects validation.
export interface FieldDescriptor {
  // Which on-screen keyboard the field should raise.
  readonly keyboard: KeyboardType;
  // Platform autofill category, or null when neither platform defines one.
  readonly autofill: AutofillHint | null;
  // How typed characters should be cased.
  readonly capitalization: Capitalization;
  // Maximum length of the FORMATTED text, separators included, or null when
  // the value has no useful hard bound.
  readonly maxLength: number | null;
  // A valid example value in formatted form, or null.
  readonly example: string | null;
  // Body of a regex character class listing the characters the field may
  // contain, e.g. `0-9A-Z `. Null means no filtering.
  readonly allowedChars: string | null;
}
