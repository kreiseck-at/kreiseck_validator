import data from '../data/iban-metadata.json';

// BBAN field layout for one country, as absolute offsets into the compact
// IBAN string. Indices 0-3 are the country code plus check digits.
export interface IbanBban {
  length: number;
  bankStart: number;
  bankEnd: number;
  branchStart: number | null;
  branchEnd: number | null;
  example: string;
}

// A bank resolved from its national bank code (BLZ / BC number).
export interface Bank {
  name: string;
  bic: string;
}

export const kIbanBban = data.bban as Record<string, IbanBban>;
export const kBanks = data.banks as Record<string, Record<string, Bank>>;
