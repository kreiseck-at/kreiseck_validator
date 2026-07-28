import 'dart:io';

import 'package:kreiseck_validator/kreiseck_validator.dart';
import 'package:test/test.dart';

/// The `IssueCode` union in the TypeScript port must list exactly the same
/// codes, in the same order, as the Dart enum. Nothing else pins that: the two
/// languages share JSON vectors, but a vector only exercises the codes it
/// happens to reference.
void main() {
  test('the TypeScript IssueCode union mirrors the Dart enum', () {
    final source = File('js/src/common/types.ts').readAsStringSync();
    final union = source.substring(
      source.indexOf('export type IssueCode ='),
      source.indexOf(';', source.indexOf('export type IssueCode =')),
    );
    final tsCodes = RegExp("'([A-Za-z]+)'")
        .allMatches(union)
        .map((m) => m.group(1))
        .toList();
    final dartCodes = IssueCode.values.map((c) => c.name).toList();
    expect(tsCodes, dartCodes);
  });
}
