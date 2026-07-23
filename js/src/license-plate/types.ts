// Classification of a license plate's special-purpose form.
//
// Classification is best-effort: it never blocks validation, and a country
// whose special-plate rules are not yet modelled always resolves to
// 'standard' rather than guessing.
export type PlateType =
  | 'standard'
  | 'diplomatic'
  | 'authority'
  | 'military'
  | 'temporary'
  | 'seasonal'
  | 'historic'
  | 'electric'
  | 'unknown';

// Structured data parsed out of a license plate by LicensePlate.parse.
//
// region is null when the district/canton/province code is unknown (not
// present in the curated region table) or when the country could not be
// resolved unambiguously; the plate is still valid in that case.
export interface PlateInfo {
  // The ISO 3166-1 alpha-2 country code, e.g. 'AT'.
  country: string;
  // The district/canton/province code, e.g. 'W' (Wien) or 'GU' (Graz-Umgebung).
  districtCode: string;
  // The official region name for districtCode, or null if unknown.
  region: string | null;
  // The individual (serial) part of the plate, normalized.
  serial: string;
  // The classification of this plate.
  type: PlateType;
  // The canonical display form, e.g. 'W-12345A'.
  formatted: string;
}

// Options accepted by every LicensePlate operation.
export interface PlateOptions {
  // ISO 3166-1 alpha-2 country code (e.g. 'AT'). When omitted, the
  // implementation infers the country from the format + code tables.
  country?: string;
}
