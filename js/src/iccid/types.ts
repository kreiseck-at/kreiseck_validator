import type { Country } from '../phone/types';

// Structured data parsed out of an ICCID by Iccid.parse.
export interface IccidInfo {
  // Major Industry Identifier for telecom, always '89'.
  readonly mii: string;
  // Country resolved from the E.164 calling code following the MII, or
  // null if the calling code is unrecognized.
  readonly country: Country | null;
  // Digits identifying the issuer, between the country calling code and
  // the (optional) check digit.
  readonly issuerIdentifier: string;
  // Luhn check digit (last digit) when the ICCID is 20 digits long, or
  // null for 19-digit ICCIDs (which carry no check digit).
  readonly checkDigit: string | null;
}
