# Changelog

## 0.10.0

- Added `FieldDescriptor` (`keyboard`, `autofill`, `capitalization`,
  `maxLength`, `example`, `allowedChars`) and a `fieldDescriptor(...)` method
  on every type, taking the same options as `validate`.
- Added `formatPartial(...)` on every type: as-you-type formatting that never
  throws and, for the nine grouping types, agrees with `format` on valid input.
- `PostalPattern` gained `example` and `charset`; the postal metadata table was
  regenerated.
