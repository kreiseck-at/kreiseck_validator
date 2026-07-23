import data from '../data/phone-metadata.json';
import type { Country, PhoneFormat } from './types';

// Raw shape of a country entry in phone-metadata.json.
interface RawFormat {
  pattern: string;
  format: string;
  leadingDigits: string | null;
  nationalPrefixFormattingRule: string | null;
}
interface RawCountry {
  iso2: string;
  callingCode: string;
  name: string;
  nationalPrefix: string | null;
  possibleLengths: number[];
  pattern: string;
  formats: RawFormat[];
  intlFormats: RawFormat[];
  mainForCallingCode: boolean;
  example: { nsn: string | null; e164: string | null; national: string | null; international: string | null } | null;
}

function toFormat(f: RawFormat): PhoneFormat {
  return {
    pattern: f.pattern,
    format: f.format,
    leadingDigits: f.leadingDigits,
    nationalPrefixFormattingRule: f.nationalPrefixFormattingRule,
  };
}

function toCountry(c: RawCountry): Country {
  const ex = c.example;
  return {
    iso2: c.iso2,
    callingCode: c.callingCode,
    displayName: c.name,
    nationalPrefix: c.nationalPrefix,
    possibleLengths: c.possibleLengths,
    pattern: c.pattern,
    formats: c.formats.map(toFormat),
    intlFormats: c.intlFormats.map(toFormat),
    mainForCallingCode: c.mainForCallingCode,
    exampleNsn: ex?.nsn ?? null,
    exampleE164: ex?.e164 ?? null,
    exampleNational: ex?.national ?? null,
    exampleInternational: ex?.international ?? null,
  };
}

// All supported countries, in metadata order.
export const countries: Country[] = (data.countries as RawCountry[]).map(toCountry);

const byIso2 = new Map<string, Country>();
for (const c of countries) byIso2.set(c.iso2, c);

// Maps a calling code to the ISO2 of its main region (mirrors Dart's
// kMainRegionForCallingCode).
const mainRegionForCallingCode = new Map<string, string>();
for (const c of countries) {
  if (c.mainForCallingCode) mainRegionForCallingCode.set(c.callingCode, c.iso2);
}

// Looks up a country by ISO2 code (case-insensitive); null if unknown.
export function fromIso2(code: string): Country | null {
  return byIso2.get(code.toUpperCase()) ?? null;
}

// Returns the main region for a calling code, or null if none.
export function fromCallingCode(callingCode: string): Country | null {
  const iso2 = mainRegionForCallingCode.get(callingCode);
  if (iso2 === undefined) return null;
  return fromIso2(iso2);
}
