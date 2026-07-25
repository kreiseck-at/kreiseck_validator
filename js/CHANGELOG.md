# Changelog

## 0.10.0

- Added `FieldDescriptor` (`keyboard`, `autofill`, `capitalization`,
  `maxLength`, `example`, `allowedChars`) and a `fieldDescriptor(...)` method
  on every type, taking the same options as `validate`.
- Added `formatPartial(...)` on every type: as-you-type formatting that never
  throws and, for the nine grouping types, agrees with `format` on valid input.
- `PostalPattern` gained `example`, `charset` and `length`; the postal metadata
  table was regenerated. `length` (the canonical formatted length, separators
  included) is mechanically derived from each country's pattern, so
  `PostalCode.fieldDescriptor({ country }).maxLength` and `formatPartial`'s
  truncation are now set for all 51 countries instead of only the 23 with a
  curated `example`.
- `Phone.fieldDescriptor(...).example` is now always `null`: the previous
  synthetic construction (`+{callingCode}1234567`) produced a plausible-
  looking but fabricated example for most countries and `null` for the rest,
  contradicting the never-invented-example principle applied to postal codes.
- `Host.formatPartial` no longer drops non-ASCII characters (e.g.
  `münchen.de` previously became the different, plausible-looking
  `mnchen.de`); it now leaves them in place since the module is ASCII-only
  and would reject the value either way.
- `Phone.formatPartial`'s options type no longer structurally accepts an
  `international` property (it was silently ignored — the value is always
  derived from a leading `+`).
