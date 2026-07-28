import 'dart:io';

import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:test/test.dart';

/// The TypeScript port keeps its own packed list of ISO 3166-1 alpha-2 codes
/// for `Bic`, because reaching the shared country table there would pull the
/// whole phone metadata into the `bic` entry point (see
/// `js/test/treeshaking.spec.ts`). That copy has to stay in step with the Dart
/// table, or the two languages would disagree on which BICs have a real
/// country.
void main() {
  test('the packed TypeScript country list matches the Dart country table',
      () {
    final source =
        File('js/src/bic/iso-countries.ts').readAsStringSync();
    final packed = RegExp("'([A-Z]{2,})'")
        .allMatches(source)
        .map((m) => m.group(1)!)
        .join();
    final tsCodes = <String>[
      for (var i = 0; i < packed.length; i += 2) packed.substring(i, i + 2),
    ]..sort();

    final dartCodes = <String>[
      for (final code in tsCodes)
        if (Country.fromIso2(code) != null) code,
    ];

    expect(tsCodes, dartCodes,
        reason: 'the TypeScript list has codes the Dart table does not know');
    expect(tsCodes.length, 245);
    expect(Country.fromIso2('ZZ'), isNull);
  });
}
