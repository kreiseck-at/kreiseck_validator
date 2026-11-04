import '../common/issue_code.dart';
import '../common/validation_result.dart';

/// One entry of [Gender.options]: the code and its display label.
class GenderOption {
  /// Creates an option.
  const GenderOption(this.value, this.label);

  /// One-letter code (`m`, `f`, `d`, `i`, `o`).
  final String value;

  /// Display label in the requested locale.
  final String label;
}

/// Gender as recorded in the Austrian civil register (Personenstand): male,
/// female, diverse, inter, open. "No entry" is deliberately not a value: forms
/// that require a gender (payroll: the L16 wage slip) have no way to report it.
/// Codes are single lower-case letters. [validate] also accepts the German and
/// English words and "w" (weiblich), case-insensitive, surrounding blanks
/// ignored.
class Gender {
  Gender._();

  /// The five codes in a fixed order.
  static const List<String> values = ['m', 'f', 'd', 'i', 'o'];

  static const Map<String, Map<String, String>> _labels = {
    'de': {
      'm': 'männlich',
      'f': 'weiblich',
      'd': 'divers',
      'i': 'inter',
      'o': 'offen'
    },
    'en': {
      'm': 'male',
      'f': 'female',
      'd': 'diverse',
      'i': 'inter',
      'o': 'open'
    },
  };

  static const Map<String, String> _aliases = {
    'm': 'm',
    'männlich': 'm',
    'maennlich': 'm',
    'male': 'm',
    'f': 'f',
    'w': 'f',
    'weiblich': 'f',
    'female': 'f',
    'd': 'd',
    'divers': 'd',
    'diverse': 'd',
    'i': 'i',
    'inter': 'i',
    'o': 'o',
    'offen': 'o',
    'open': 'o',
  };

  /// Validates [input], returning a [Valid] with the one-letter code or an
  /// [Invalid] describing why it was rejected.
  static ValidationResult validate(String input) {
    final s = input.trim().toLowerCase();
    if (s.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.genderEmpty, 'Gender is empty.')]);
    }
    final code = _aliases[s];
    if (code == null) {
      return const Invalid(
          [ValidationIssue(IssueCode.genderUnknown, 'Unknown gender.')]);
    }
    return Valid(code);
  }

  /// True when [validate] returns a [Valid].
  static bool isValid(String input) => validate(input) is Valid;

  /// Returns the one-letter code. Throws [FormatException] if [input] is not a
  /// gender.
  static String normalize(String input) => switch (validate(input)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };

  /// Display label of a gender (German by default). Throws [FormatException]
  /// if [input] is not a gender.
  static String label(String input, {String locale = 'de'}) =>
      _labels[locale]![normalize(input)]!;

  /// The values with their labels, in the order of [values] – for a select.
  static List<GenderOption> options({String locale = 'de'}) =>
      [for (final v in values) GenderOption(v, _labels[locale]![v]!)];
}
