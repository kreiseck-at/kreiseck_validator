// Structured data parsed out of an IMEI by Imei.parse.
export interface ImeiInfo {
  tac: string;
  serialNumber: string;
  checkDigit: string | null;
  reportingBodyIdentifier: string;
  softwareVersion: string | null;
}
