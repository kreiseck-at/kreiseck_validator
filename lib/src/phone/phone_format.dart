/// A single national number-format rule (derived from libphonenumber).
class PhoneFormat {
  /// Creates a format rule.
  const PhoneFormat({
    required this.pattern,
    required this.format,
    this.leadingDigits,
    this.nationalPrefixFormattingRule,
  });

  /// Regex matched against the national significant number.
  final String pattern;

  /// Output template using `$1`, `$2`, ... group references.
  final String format;

  /// If set, this rule applies only when the number starts with this prefix.
  final String? leadingDigits;

  /// National-prefix rendering rule (e.g. `0$1`); applies to national form.
  final String? nationalPrefixFormattingRule;
}
