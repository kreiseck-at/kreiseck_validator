// The ISO 3166-1 alpha-2 codes this package knows, as one packed string of
// two-character codes.
//
// The Dart library reads the same set off its bundled Country table, but the
// TypeScript port cannot: that table lives in the phone metadata, and pulling
// it into the `bic` entry point would drag 245 countries' phone data along
// with it — which `test/treeshaking.spec.ts` explicitly forbids. Two letters
// per country is under a kilobyte, so the BIC entry carries its own copy.
//
// `test/bic_country_parity_test.dart` fails if this string ever stops matching
// the Dart country table.
const PACKED =
  'ACADAEAFAGAIALAMAOARASATAUAWAXAZBABBBDBEBFBGBHBIBJBLBMBNBOBQ' +
  'BRBSBTBWBYBZCACCCDCFCGCHCICKCLCMCNCOCRCUCVCWCXCYCZDEDJDKDMDO' +
  'DZECEEEGEHERESETFIFJFKFMFOFRGAGBGDGEGFGGGHGIGLGMGNGPGQGRGTGU' +
  'GWGYHKHNHRHTHUIDIEILIMINIOIQIRISITJEJMJOJPKEKGKHKIKMKNKPKRKW' +
  'KYKZLALBLCLILKLRLSLTLULVLYMAMCMDMEMFMGMHMKMLMMMNMOMPMQMRMSMT' +
  'MUMVMWMXMYMZNANCNENFNGNINLNONPNRNUNZOMPAPEPFPGPHPKPLPMPRPSPT' +
  'PWPYQARERORSRURWSASBSCSDSESGSHSISJSKSLSMSNSOSRSSSTSVSXSYSZTA' +
  'TCTDTGTHTJTKTLTMTNTOTRTTTVTWTZUAUGUSUYUZVAVCVEVGVIVNVUWFWSXK' +
  'YEYTZAZMZW';

const CODES: ReadonlySet<string> = new Set(
  Array.from({ length: PACKED.length / 2 }, (_, i) => PACKED.substring(i * 2, i * 2 + 2)),
);

// True when code is an ISO 3166-1 alpha-2 code this package recognises.
export function isIsoCountry(code: string): boolean {
  return CODES.has(code);
}

// Every recognised code, for parity testing.
export function isoCountries(): string[] {
  return [...CODES];
}
