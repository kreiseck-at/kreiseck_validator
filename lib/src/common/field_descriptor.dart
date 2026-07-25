/// Which on-screen keyboard a field should raise.
///
/// Platform-neutral by design: the package has no Flutter or DOM dependency.
/// See the README for the mapping to `TextInputType` and to `inputmode`.
enum KeyboardType {
  /// A normal text keyboard.
  text,

  /// A digits-only keypad.
  digits,

  /// A telephone keypad.
  phone,

  /// A text keyboard optimized for email addresses.
  email,

  /// A text keyboard optimized for URLs.
  url,
}

/// How typed characters should be cased.
enum Capitalization {
  /// Leave input as typed.
  none,

  /// Upper-case every character.
  characters,

  /// Upper-case the first character of each word.
  words,

  /// Upper-case the first character of each sentence.
  sentences,
}

/// Platform autofill category for a field.
///
/// Only categories that exist on both Flutter and the web are listed; value
/// types without a standard category (IBAN, VIN, IMEI, ICCID, MAC, license
/// plate) carry a null [FieldDescriptor.autofill] rather than an invented one.
enum AutofillHint {
  /// An email address.
  email,

  /// A telephone number.
  telephoneNumber,

  /// A postal code.
  postalCode,

  /// A payment-card number.
  creditCardNumber,

  /// A URL.
  url,
}

/// The input characteristics of a field holding one kind of value.
///
/// Obtained from any validator's `fieldDescriptor` method, which takes the
/// same options as its `validate`. Everything here is a hint for building an
/// input field; none of it affects validation.
class FieldDescriptor {
  /// Creates a descriptor.
  const FieldDescriptor({
    required this.keyboard,
    this.autofill,
    this.capitalization = Capitalization.none,
    this.maxLength,
    this.example,
    this.allowedChars,
  });

  /// Which on-screen keyboard the field should raise.
  final KeyboardType keyboard;

  /// Platform autofill category, or null when neither platform defines one
  /// for this kind of value.
  final AutofillHint? autofill;

  /// How typed characters should be cased.
  final Capitalization capitalization;

  /// Maximum length of the *formatted* text, separators included, or null
  /// when the value has no useful hard bound.
  final int? maxLength;

  /// A valid example value in formatted form, or null when the type has no
  /// meaningful single example.
  final String? example;

  /// The body of a regex character class listing the characters the field
  /// may contain, e.g. `0-9A-Z `. Null means no filtering.
  ///
  /// Use it directly: `RegExp('[^${d.allowedChars}]')` to strip rejected
  /// characters, `RegExp('[${d.allowedChars}]')` to test one.
  final String? allowedChars;
}
