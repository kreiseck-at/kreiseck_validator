/// A per-country postal-code pattern: an anchored validation regex plus a
/// canonical spacing rule.
///
/// [format] encodes where (if anywhere) a separator is inserted into the
/// compact (separator-stripped) form to produce the canonical form:
///  - `''`: no separator; the compact form is already canonical.
///  - `'N:C'`: insert literal separator `C` after `N` characters from the
///    start (e.g. `'2:-'` for PL: `00950` -> `00-950`).
///  - `'U'`: UK postcode style -- insert a single space before the last 3
///    characters, regardless of total length (e.g. GB: `SW1A1AA` ->
///    `SW1A 1AA`).
class PostalPattern {
  /// Creates a postal pattern from its [pattern], [format] rule, optional
  /// [example], [charset] and [length].
  const PostalPattern(this.pattern, this.format,
      [this.example, this.charset = 'digits', this.length]);

  /// Anchored regex (as a string) the canonical (separator-applied) form
  /// must match.
  final String pattern;

  /// The canonical spacing rule; see the class doc for the mini-language.
  final String format;

  /// A real postal code of this country in canonical form, or null when no
  /// verified example is on hand. Never invented.
  final String? example;

  /// `'digits'` when the code can only contain digits and separators,
  /// `'alnum'` when letters are possible.
  final String charset;

  /// The canonical formatted length (separators included), mechanically
  /// derived from [pattern] by `tool/gen_postal_metadata.py` -- never
  /// curated, so it is set for every country regardless of whether
  /// [example] is. For a variable-length pattern (the UK-style `U` [format]
  /// rule, or a bounded range like `\d{2,4}`) this is the MAXIMUM matchable
  /// length. Null only for a [PostalPattern] built by hand without one.
  final int? length;
}
