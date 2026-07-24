export type IssueCode =
  | 'emailEmpty' | 'emailMissingAt' | 'emailMultipleAt' | 'emailEmptyLocal' | 'emailBadDomain'
  | 'phoneEmpty' | 'phoneBadChars' | 'phoneTooShort' | 'phoneTooLong'
  | 'phoneAmbiguousCountry' | 'phoneUnknownCountry' | 'phoneInvalid'
  | 'urlEmpty' | 'urlBadScheme' | 'urlBadHost' | 'urlBadTld'
  | 'ibanEmpty' | 'ibanBadChars' | 'ibanBadChecksum' | 'ibanBadLength'
  | 'cardEmpty' | 'cardBadChars' | 'cardBadLength' | 'cardBadLuhn'
  | 'plateEmpty' | 'plateBadChars' | 'plateBadFormat' | 'plateUnknownCountry' | 'plateAmbiguousCountry'
  | 'imeiEmpty' | 'imeiBadChars' | 'imeiBadLength' | 'imeiBadChecksum'
  | 'iccidEmpty' | 'iccidBadChars' | 'iccidBadLength' | 'iccidBadChecksum'
  | 'macEmpty' | 'macBadFormat'
  | 'vinEmpty' | 'vinBadChars' | 'vinBadLength'
  | 'postalEmpty' | 'postalBadFormat' | 'postalUnknownCountry';

export interface ValidationIssue { readonly code: IssueCode; readonly message: string }
export interface Suggestion { readonly value: string; readonly reason: string }

export type ValidationResult =
  | { readonly ok: true; readonly normalized: string; readonly suggestions: Suggestion[] }
  | { readonly ok: false; readonly issues: ValidationIssue[] };

export function valid(normalized: string, suggestions: Suggestion[] = []): ValidationResult {
  return { ok: true, normalized, suggestions };
}

export function invalid(code: IssueCode, message: string): ValidationResult {
  return { ok: false, issues: [{ code, message }] };
}
