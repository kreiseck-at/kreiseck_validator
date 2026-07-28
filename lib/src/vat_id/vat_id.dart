import 'dart:convert';

import '../common/field_descriptor.dart';
import '../common/issue_code.dart';
import '../common/partial_format.dart';
import '../common/validation_result.dart';
import 'vat_checks.dart';
import 'vat_info.dart';
import 'vies.dart';

part 'vat_metadata.g.dart';

/// The structure of one country's VAT ID: what precedes the number, what the
/// number itself may look like, and a published example.
class VatFormat {
  /// Creates a VAT structure entry.
  const VatFormat(this.prefix, this.body, this.maxLen, this.example);

  /// The string written before the number: `ATU`, `EL`, `CHE`, `XI` or the ISO
  /// country code.
  final String prefix;

  /// Anchored regex the body must match, prefix excluded.
  final String body;

  /// The body's longest permitted length, prefix excluded.
  final int maxLen;

  /// A published VAT ID in full written form, or null when none is bundled.
  final String? example;
}

/// Validation, normalization, formatting and parsing of European VAT
/// identification numbers.
///
/// Covers the 27 EU member states plus Switzerland, the United Kingdom,
/// Northern Ireland, Norway, Serbia and Türkiye. **Every one of them is
/// checked arithmetically**, not just
/// structurally: a documented check-digit algorithm exists for all of them, so
/// [IssueCode.vatBadChecksum] is always meaningful and a transposed digit is
/// always caught.
///
/// Two spellings differ between the tax world and ISO 3166, and both are
/// handled explicitly:
///
/// - **Greece** writes `EL`, ISO says `GR`. Either is accepted as [country],
///   [normalize] emits `EL`, and [VatInfo.country] reports `GR`.
/// - **Northern Ireland** writes `XI` post-Brexit; [VatInfo.country] reports
///   `GB`.
///
/// A value carrying its own prefix resolves itself and that prefix wins over
/// [country]; compare [VatInfo.country] against your own expectation if the
/// distinction matters. A bare number needs [country], otherwise it is
/// genuinely ambiguous — plain nine-digit bodies are valid in half a dozen
/// member states at once.
///
/// No network access. VAT registration is a fact about a company, not about
/// the string, and only the EU's VIES service knows it — see [viesRequest].
class VatId {
  VatId._();

  static final RegExp _separators = RegExp(r'[\s.\-/]');
  static final RegExp _twoLetters = RegExp(r'^[A-Z]{2}');
  static final Map<String, RegExp> _compiled = {};

  static RegExp _bodyRe(VatFormat f) =>
      _compiled.putIfAbsent(f.body, () => RegExp(f.body));

  /// VAT prefixes longest-first, so `ATU` is tried before any two-letter code.
  static final List<MapEntry<String, String>> _prefixes = () {
    final entries = kVatFormats.entries
        .map((e) => MapEntry(e.value.prefix, e.key))
        .toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    return entries;
  }();

  /// Resolves an explicit [country] to a key of [kVatFormats], accepting the
  /// tax spellings `EL` (Greece) alongside the ISO ones.
  static String? _keyForCountry(String? country) {
    if (country == null) return null;
    final upper = country.toUpperCase();
    if (upper == 'EL') return 'GR';
    return kVatFormats.containsKey(upper) ? upper : null;
  }

  /// Belgium's pre-2008 nine-digit numbers are the same number without their
  /// leading zero; everything downstream expects ten digits.
  static String _padBody(String key, String body) =>
      key == 'BE' && body.length == 9 ? '0$body' : body;

  static final RegExp _chSuffix = RegExp(r'(HR)?(MWST|TVA|IVA)$');

  /// Swiss numbers are commonly written with a register/tax marker —
  /// `CHE-116.281.710 MWST`, sometimes `HR/MWST` — where the suffix says the
  /// holder is VAT-registered. It is not part of the number, and someone
  /// copying a UID out of an imprint will bring it along, so it is dropped
  /// rather than rejected. `TVA` and `IVA` are the same marker in the other
  /// two national languages.
  static String _stripSuffix(String key, String body) =>
      key == 'CH' ? body.replaceFirst(_chSuffix, '') : body;

  /// Validates [input], returning [Valid] with the prefixed, separator-free
  /// canonical form.
  static ValidationResult validate(String input, {String? country}) {
    final compact = input.toUpperCase().replaceAll(_separators, '');
    if (compact.isEmpty) {
      return const Invalid(
          [ValidationIssue(IssueCode.vatEmpty, 'VAT ID is empty.')]);
    }

    String? key;
    String body = compact;
    for (final entry in _prefixes) {
      if (compact.startsWith(entry.key)) {
        key = entry.value;
        body = compact.substring(entry.key.length);
        break;
      }
    }

    if (key == null) {
      if (_twoLetters.hasMatch(compact)) {
        return const Invalid([
          ValidationIssue(
              IssueCode.vatUnknownCountry, 'Unknown VAT country prefix.')
        ]);
      }
      key = _keyForCountry(country);
      if (key == null) {
        return Invalid([
          ValidationIssue(
              country == null
                  ? IssueCode.vatAmbiguousCountry
                  : IssueCode.vatUnknownCountry,
              country == null
                  ? 'VAT ID has no country prefix; pass country.'
                  : 'Unknown VAT country.')
        ]);
      }
    }

    final format = kVatFormats[key]!;
    body = _padBody(key, _stripSuffix(key, body));
    if (!_bodyRe(format).hasMatch(body)) {
      return const Invalid([
        ValidationIssue(IssueCode.vatBadFormat, 'VAT ID has invalid format.')
      ]);
    }
    if (!checkVat(key, body)) {
      return const Invalid([
        ValidationIssue(IssueCode.vatBadChecksum, 'VAT ID check digit is wrong.')
      ]);
    }
    return Valid('${format.prefix}$body');
  }

  /// True when [validate] returns [Valid].
  static bool isValid(String input, {String? country}) =>
      validate(input, country: country) is Valid;

  /// Returns the prefixed, separator-free canonical form. Throws
  /// [FormatException] if [input] is not a valid VAT ID.
  static String normalize(String input, {String? country}) =>
      switch (validate(input, country: country)) {
        Valid(:final normalized) => normalized,
        Invalid(:final issues) => throw FormatException(issues.first.message),
      };

  /// Returns the canonical form. VAT IDs have no conventional grouping, so
  /// this equals [normalize]. Throws [FormatException] if invalid.
  static String format(String input, {String? country}) =>
      normalize(input, country: country);

  /// Like [format] but returns null instead of throwing on invalid input.
  static String? tryFormat(String input, {String? country}) {
    try {
      return format(input, country: country);
    } on FormatException {
      return null;
    }
  }

  /// Parses [input] into a [VatInfo], or null when it is not a valid VAT ID.
  static VatInfo? parse(String input, {String? country}) {
    final r = validate(input, country: country);
    if (r is! Valid) return null;
    final normalized = r.normalized;
    for (final entry in _prefixes) {
      if (normalized.startsWith(entry.key)) {
        final key = entry.value;
        final body = normalized.substring(entry.key.length);
        return VatInfo(
          country: key == 'XI' ? 'GB' : key,
          prefix: entry.key,
          number: body,
          subtype: vatSubtypeOf(key, body),
        );
      }
    }
    return null;
  }

  /// The VAT prefix [country] writes in front of its number, or null when the
  /// country has no VAT ID in this package.
  ///
  /// Mostly the ISO code, but not always: Austria writes `ATU`, Switzerland
  /// `CHE`, Greece `EL` and Northern Ireland `XI`. A form that shows the prefix
  /// as a fixed label next to the input — or that re-prefixes a number when the
  /// user switches country — needs exactly this, and guessing it from the ISO
  /// code is wrong for four countries.
  ///
  /// Also the cheapest way to ask "does this country have a VAT ID at all?"
  /// before rendering the field.
  static String? prefixFor(String country) {
    final key = _keyForCountry(country);
    return key == null ? null : kVatFormats[key]!.prefix;
  }

  /// Builds the VIES request for [value], or null when [value] is not a valid
  /// VAT ID or its country is outside VIES.
  ///
  /// Switzerland is the one supported country VIES does not cover — it is not
  /// an EU member state — so a Swiss number always yields null.
  ///
  /// The package performs no request. Send [ViesRequest] yourself and hand the
  /// response body to [parseViesResponse].
  static ViesRequest? viesRequest(String value, {String? country}) {
    final r = validate(value, country: country);
    if (r is! Valid) return null;
    final normalized = r.normalized;
    final ms = normalized.substring(0, 2);
    if (ms == 'CH') return null;
    final number = normalized.substring(2);
    return ViesRequest(
      url: '$_viesBase/$ms/vat/$number',
      method: 'GET',
      headers: const {'Accept': 'application/json'},
    );
  }

  static const String _viesBase =
      'https://ec.europa.eu/taxation_customs/vies/rest-api/ms';

  /// Parses a VIES response [body] into a [VatRegistration], or null when the
  /// service gave no conclusive answer.
  ///
  /// **Null does not mean "not registered."** VIES forwards the question to
  /// the member state, and that state is regularly busy or down; the service
  /// then answers with `isValid: false` and a `userError` such as
  /// `MS_MAX_CONCURRENT_REQ` or `MS_UNAVAILABLE`. Treating that as a rejection
  /// would refuse perfectly good customers whenever a tax office is having a
  /// bad afternoon, so only `VALID` and `INVALID` produce a result here and
  /// everything else — including malformed JSON — produces null. Callers
  /// should read null as "ask again later" and fall back to the offline
  /// structural check, which is what [validate] already gave them.
  static VatRegistration? parseViesResponse(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) return null;
    final userError = decoded['userError'];
    if (userError != 'VALID' && userError != 'INVALID') return null;
    return VatRegistration(
      valid: userError == 'VALID',
      name: _disclosed(decoded['name']),
      address: _disclosed(decoded['address']),
      requestDate: decoded['requestDate'] as String?,
    );
  }

  /// VIES writes `---` for a value the member state withholds, and an empty
  /// string when there is nothing to say. Neither is a name.
  static String? _disclosed(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '---') return null;
    return trimmed;
  }

  /// Describes a VAT-ID input field.
  ///
  /// The field is assumed to hold the whole VAT ID including its prefix, so
  /// the keyboard is always textual and the character set always alphanumeric
  /// — several countries put letters in the body (CY, ES, FR, GB, NL). Only
  /// [FieldDescriptor.maxLength] and [FieldDescriptor.example] vary by country.
  static FieldDescriptor fieldDescriptor({String? country}) {
    final key = _keyForCountry(country);
    final format = key == null ? null : kVatFormats[key];
    return FieldDescriptor(
      keyboard: KeyboardType.text,
      capitalization: Capitalization.characters,
      maxLength:
          format == null ? null : format.prefix.length + format.maxLen,
      example: format?.example,
      // Irlands historische Form traegt an zweiter Stelle ein `+` oder `*`.
      // Ohne die beiden im Zeichenvorrat wuerde `formatPartial` sie beim
      // Tippen wieder loeschen, und die Nummer waere in ein Feld, das diesem
      // Descriptor folgt, ueberhaupt nicht einzugeben.
      allowedChars: key == 'IE' ? r'0-9A-Z+*' : '0-9A-Z',
    );
  }

  /// Formats partially typed [input]: upper-cased, non-alphanumerics dropped,
  /// capped at the country's length when one is known. VAT IDs have no
  /// grouping, so nothing is inserted. Never throws.
  static String formatPartial(String input, {String? country}) {
    final d = fieldDescriptor(country: country);
    return prepare(input, d, maxSignificant: d.maxLength);
  }
}
