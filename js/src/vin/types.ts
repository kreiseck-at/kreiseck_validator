// Structured data parsed out of a VIN by Vin.parse.
export interface VinInfo {
  // World Manufacturer Identifier (chars 1-3).
  wmi: string;
  // Vehicle Descriptor Section (chars 4-9).
  vds: string;
  // Vehicle Identifier Section (chars 10-17).
  vis: string;
  // The check digit character (char 9).
  checkDigit: string;
  // Whether checkDigit matches the ISO 3779 weighted-sum checksum.
  //
  // Mandatory only for North American VINs; European VINs frequently carry
  // no valid check digit, so this is informational only and never rejected
  // by Vin.validate.
  checkDigitValid: boolean;
  // The model year decoded from char 10, resolved against the 30-year
  // cycle ambiguity using char 7.
  modelYear: number;
  // The plant code character (char 11).
  plantCode: string;
}
