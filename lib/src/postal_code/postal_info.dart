/// Structured data parsed out of a postal code by `PostalCode.parse`.
class PostalInfo {
  /// Creates a [PostalInfo].
  const PostalInfo({required this.country, required this.code});

  /// The ISO 3166-1 alpha-2 country code, e.g. `NL`.
  final String country;

  /// The canonical, normalized postal code, e.g. `1234 AB`.
  final String code;
}
