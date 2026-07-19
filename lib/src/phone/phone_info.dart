import '../common/country.dart';
import 'phone_number_type.dart';

/// A parsed, classified phone number with its canonical and display forms.
class PhoneInfo {
  /// Creates a [PhoneInfo].
  const PhoneInfo({
    required this.e164,
    required this.country,
    required this.type,
    required this.national,
    required this.international,
  });

  /// Canonical E.164 form, e.g. `+43316123456`.
  final String e164;

  /// The resolved country.
  final Country country;

  /// The classified number type (`unknown` for non-AT numbers).
  final PhoneNumberType type;

  /// National display form, e.g. `0316 123456`.
  final String national;

  /// International display form, e.g. `+43 316 123456`.
  final String international;
}
