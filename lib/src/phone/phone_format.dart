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

/// Formats a national significant number [nsn] for [country].
/// Returns null if no format rule matches.
String? formatNsn(
  List<PhoneFormat> formats,
  String nsn, {
  required bool international,
  String? nationalPrefix,
}) {
  for (final f in formats) {
    if (f.leadingDigits != null &&
        !RegExp('^(?:${f.leadingDigits})').hasMatch(nsn)) {
      continue;
    }
    final m = RegExp('^(?:${f.pattern})\$').firstMatch(nsn);
    if (m == null) continue;
    var out = f.format;
    for (var i = m.groupCount; i >= 1; i--) {
      out = out.replaceAll('\$$i', m.group(i) ?? '');
    }
    if (!international) {
      final rule = f.nationalPrefixFormattingRule;
      final np = nationalPrefix ?? '';
      if (rule != null && rule.isNotEmpty) {
        // Pragmatic subset: `$1`/`$FG` = the whole grouped number, `$NP` = the
        // national prefix. Reproduces the common `0$1` case (DACH and most
        // European national forms). Carrier codes (`$CC`) are not supported.
        out = rule
            .replaceAll(r'$NP', np)
            .replaceAll(r'$FG', out)
            .replaceAll(r'$1', out);
      } else if (np.isNotEmpty) {
        out = '$np$out';
      }
    }
    return out;
  }
  return null;
}
