import 'phone_number_type.dart';

/// Result of classifying an Austrian national number.
class AtClass {
  /// Creates a classification with the [type] and the grouping [prefix].
  const AtClass(this.type, this.prefix);

  /// The classified number type.
  final PhoneNumberType type;

  /// The leading digit group used for display spacing (area code, mobile or
  /// service prefix); empty when it could not be determined.
  final String prefix;
}

/// Austrian (AT) numbering-plan data and classifier, sourced from the public
/// RTR numbering plan. All inputs are the *national significant number*: the
/// number without the international `+43` or the national trunk `0`.
abstract final class AtNumbering {
  AtNumbering._();

  /// RTR mobile prefixes (3 digits): 650-653, 655, 657, 659-661, 663-699.
  /// Note the deliberate gaps — 654, 656, 658 and 662 are NOT mobile
  /// (662 is the Salzburg geographic area code).
  static final Set<String> _mobile = {
    '650',
    '651',
    '652',
    '653',
    '655',
    '657',
    '659',
    '660',
    '661',
    for (var n = 663; n <= 699; n++) '$n',
  };

  /// Service prefixes mapped to their type.
  static const Map<String, PhoneNumberType> _service = {
    '800': PhoneNumberType.freephone,
    '810': PhoneNumberType.sharedCost,
    '820': PhoneNumberType.sharedCost,
    '821': PhoneNumberType.sharedCost,
    '900': PhoneNumberType.premium,
    '901': PhoneNumberType.premium,
    '930': PhoneNumberType.premium,
    '931': PhoneNumberType.premium,
    '939': PhoneNumberType.premium,
    '720': PhoneNumberType.voip,
  };

  /// Curated geographic area codes (without the trunk 0) for major cities.
  /// Longest-prefix match wins. Not exhaustive — unknown numbers are handled
  /// by the [format] method.
  static const Map<String, String> areaCodes = {
    '1': 'Wien',
    '316': 'Graz',
    '732': 'Linz',
    '662': 'Salzburg',
    '512': 'Innsbruck',
    '463': 'Klagenfurt',
    '4242': 'Villach',
    '7242': 'Wels',
    '2742': 'St. Pölten',
    '5572': 'Dornbirn',
    '5574': 'Bregenz',
    '2622': 'Wiener Neustadt',
    '7252': 'Steyr',
    '5522': 'Feldkirch',
    '2682': 'Eisenstadt',
    '3842': 'Leoben',
    '2732': 'Krems',
    '7472': 'Amstetten',
    '5372': 'Kufstein',
  };

  /// Classifies an Austrian national significant [national] number.
  static AtClass classify(String national) {
    final p3 = national.length >= 3 ? national.substring(0, 3) : national;

    // 1. Mobile — explicit allow-list (checked before geographic so that a
    //    geographic code numerically inside the mobile span, like 662, is not
    //    swept up here).
    if (_mobile.contains(p3)) return AtClass(PhoneNumberType.mobile, p3);

    // 2. Service ranges.
    final service = _service[p3];
    if (service != null) return AtClass(service, p3);

    // 3. Geographic — longest known area-code prefix wins (4 → 3 → 1 digits).
    for (final len in const [4, 3, 2, 1]) {
      if (national.length > len) {
        final code = national.substring(0, len);
        if (areaCodes.containsKey(code)) {
          return AtClass(PhoneNumberType.landline, code);
        }
      }
    }

    // 4. Corporate / private networks: 050x / 059x (not a known geographic code).
    if (national.startsWith('50') || national.startsWith('59')) {
      return AtClass(PhoneNumberType.corporate, p3);
    }

    // 5. Plausible geographic first digit → landline with an unknown area code.
    //    Includes 6: the 06xx range holds real regional landlines (e.g. Bad
    //    Ischl 06132, Zell am See 06542) — mobile 06xx is already caught by the
    //    allow-list above, so anything reaching here is geographic.
    if (national.isNotEmpty && '2345678'.contains(national[0])) {
      return const AtClass(PhoneNumberType.landline, '');
    }

    return const AtClass(PhoneNumberType.unknown, '');
  }

  /// Formats an Austrian national significant [national] number with
  /// type-aware spacing. [international] chooses `+43 <area> <rest>` vs
  /// `0<area> <rest>`. Never throws; unknown area codes use an approximate
  /// 2- or 4-digit split.
  static String format(String national, {required bool international}) {
    final c = classify(national);
    var area = c.prefix;
    if (area.isEmpty) {
      // Fallback: approximate area code (min 2, max 4 digits) for readability.
      final len = national.length >= 6 ? 4 : 2;
      area =
          national.substring(0, national.length > len ? len : national.length);
    }
    final rest = national.substring(area.length);
    return international ? '+43 $area $rest' : '0$area $rest';
  }
}
