import 'package:input_validator/src/common/country.dart';
import 'package:input_validator/src/common/issue_code.dart';
import 'package:input_validator/src/common/validation_result.dart';
import 'package:test/test.dart';

void main() {
  test('Country exposes calling code and iso2', () {
    expect(Country.at.callingCode, '43');
    expect(Country.de.iso2, 'DE');
  });

  test('Valid carries normalized value and defaults to no suggestions', () {
    const r = Valid('a@b.com');
    expect(r.normalized, 'a@b.com');
    expect(r.suggestions, isEmpty);
  });

  test('Invalid carries at least one issue', () {
    const r = Invalid([ValidationIssue(IssueCode.emailMissingAt, 'no @')]);
    expect(r.issues.single.code, IssueCode.emailMissingAt);
  });

  test('ValidationResult is sealed and switchable', () {
    ValidationResult r = const Valid('x');
    final label = switch (r) { Valid() => 'ok', Invalid() => 'bad' };
    expect(label, 'ok');
  });
}
