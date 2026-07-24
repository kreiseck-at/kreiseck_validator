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
  /// Creates a postal pattern from its [pattern] and [format] rule.
  const PostalPattern(this.pattern, this.format);

  /// Anchored regex (as a string) the canonical (separator-applied) form
  /// must match.
  final String pattern;

  /// The canonical spacing rule; see the class doc for the mini-language.
  final String format;
}
