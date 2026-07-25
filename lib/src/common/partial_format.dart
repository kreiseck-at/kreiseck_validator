import 'field_descriptor.dart';

/// Applies the first three steps of a `formatPartial` pipeline to [input]:
/// capitalization, character filtering, and truncation to [maxSignificant]
/// characters. Grouping (step four) is the caller's job.
///
/// Casing runs before filtering on purpose: VIN allows `0-9A-HJ-NPR-Z`, so
/// filtering a freshly typed lower-case `h` first would delete it instead of
/// upper-casing it into a valid character.
///
/// [separators] is a character-class body of separator characters to remove
/// before truncating, for types whose [FieldDescriptor.allowedChars] admits
/// the separators the grouping step re-inserts.
String prepare(
  String input,
  FieldDescriptor d, {
  String? separators,
  int? maxSignificant,
}) {
  var s = input;
  if (d.capitalization == Capitalization.characters) s = s.toUpperCase();
  final allowed = d.allowedChars;
  if (allowed != null) s = s.replaceAll(RegExp('[^$allowed]'), '');
  if (separators != null) s = s.replaceAll(RegExp('[$separators]'), '');
  if (maxSignificant != null && s.length > maxSignificant) {
    s = s.substring(0, maxSignificant);
  }
  return s;
}

/// Inserts [sep] after every [size] characters of [s], never trailing.
String groupEvery(String s, int size, String sep) {
  if (s.length <= size) return s;
  final b = StringBuffer();
  for (var i = 0; i < s.length; i += size) {
    if (i > 0) b.write(sep);
    b.write(s.substring(i, i + size < s.length ? i + size : s.length));
  }
  return b.toString();
}

/// Inserts [sep] between runs of [s] of the given [widths]. Characters left
/// over after the last width are appended without a further separator.
String groupWidths(String s, List<int> widths, String sep) {
  final b = StringBuffer();
  var i = 0;
  for (final w in widths) {
    if (i >= s.length) break;
    if (i > 0) b.write(sep);
    final end = i + w < s.length ? i + w : s.length;
    b.write(s.substring(i, end));
    i = end;
  }
  if (i < s.length) b.write(s.substring(i));
  return b.toString();
}
