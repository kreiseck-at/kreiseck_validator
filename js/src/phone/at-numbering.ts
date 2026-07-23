import type { PhoneNumberType } from './types';

// Result of classifying an Austrian national number.
export interface AtClass {
  // The classified number type.
  readonly type: PhoneNumberType;
  // The leading digit group used for display spacing (area code, mobile or
  // service prefix); empty when it could not be determined.
  readonly prefix: string;
}

// RTR mobile prefixes (3 digits): 650-653, 655, 657, 659-661, 663-699.
// Note the deliberate gaps — 654, 656, 658 and 662 are NOT mobile
// (662 is the Salzburg geographic area code).
const MOBILE = new Set<string>(['650', '651', '652', '653', '655', '657', '659', '660', '661']);
for (let n = 663; n <= 699; n++) MOBILE.add(String(n));

// Service prefixes mapped to their type.
const SERVICE: Record<string, PhoneNumberType> = {
  '800': 'freephone',
  '810': 'sharedCost',
  '820': 'sharedCost',
  '821': 'sharedCost',
  '900': 'premium',
  '901': 'premium',
  '930': 'premium',
  '931': 'premium',
  '939': 'premium',
  '720': 'voip',
};

// Curated geographic area codes (without the trunk 0) for major cities.
// Longest-prefix match wins. Not exhaustive.
const AREA_CODES = new Set<string>([
  '1', '316', '732', '662', '512', '463', '4242', '7242', '2742', '5572',
  '5574', '2622', '7252', '5522', '2682', '3842', '2732', '7472', '5372',
]);

// Classifies an Austrian national significant number (without +43 or trunk 0).
export function classify(national: string): AtClass {
  const p3 = national.length >= 3 ? national.substring(0, 3) : national;

  // 1. Mobile — explicit allow-list (checked before geographic so that a
  //    geographic code numerically inside the mobile span, like 662, is not
  //    swept up here).
  if (MOBILE.has(p3)) return { type: 'mobile', prefix: p3 };

  // 2. Service ranges.
  const service = SERVICE[p3];
  if (service !== undefined) return { type: service, prefix: p3 };

  // 3. Geographic — longest known area-code prefix wins (4 → 3 → 1 digits).
  for (const len of [4, 3, 2, 1]) {
    if (national.length > len) {
      const code = national.substring(0, len);
      if (AREA_CODES.has(code)) return { type: 'landline', prefix: code };
    }
  }

  // 4. Corporate / private networks: 050x / 059x (not a known geographic code).
  if (national.startsWith('50') || national.startsWith('59')) {
    return { type: 'corporate', prefix: p3 };
  }

  // 5. Plausible geographic first digit → landline with an unknown area code.
  if (national.length > 0 && '2345678'.includes(national[0])) {
    return { type: 'landline', prefix: '' };
  }

  return { type: 'unknown', prefix: '' };
}
