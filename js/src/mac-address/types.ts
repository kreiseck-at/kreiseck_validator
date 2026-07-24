// Output notation for MacAddress.format.
export type MacNotation = 'colon' | 'hyphen' | 'dot' | 'bare';

// The MAC address family: EUI-48 (12 hex digits) or EUI-64 (16 hex digits).
export type MacAddressType = 'eui48' | 'eui64';

export interface MacFormatOptions {
  notation?: MacNotation;
  upperCase?: boolean;
}

// Structured data parsed out of a MAC address by MacAddress.parse.
export interface MacInfo {
  // Organizationally Unique Identifier: the first 3 octets, in normalized
  // (lower-case colon) notation.
  oui: string;
  // Network Interface Controller identifier: the remaining octets, in
  // normalized (lower-case colon) notation.
  nic: string;
  // True when the address identifies a single station (I/G bit unset).
  isUnicast: boolean;
  // True when the address is a group/multicast address (I/G bit set).
  isMulticast: boolean;
  // True when the OUI is IEEE-assigned (U/L bit unset).
  isUniversal: boolean;
  // True when the address is locally administered (U/L bit set).
  isLocal: boolean;
  // Whether this is an EUI-48 (12 hex digits) or EUI-64 (16 hex digits)
  // address.
  type: MacAddressType;
}
