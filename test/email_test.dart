import 'package:kreiseck_validator/src/common/issue_code.dart';
import 'package:kreiseck_validator/src/common/validation_result.dart';
import 'package:kreiseck_validator/src/email/email.dart';
import 'package:test/test.dart';

void main() {
  test('accepts a normal address', () {
    expect(Email.isValid('a.b+tag@example.com'), isTrue);
  });

  test('rejects a missing @', () {
    final r = Email.validate('ab.com');
    expect((r as Invalid).issues.first.code, IssueCode.emailMissingAt);
  });

  test('rejects an empty local part', () {
    final r = Email.validate('@example.com');
    expect((r as Invalid).issues.first.code, IssueCode.emailEmptyLocal);
  });

  test('normalize trims and lowercases', () {
    expect(Email.normalize('  A@B.COM '), 'a@b.com');
  });

  test('suggests a corrected domain on a likely typo', () {
    final r = Email.validate('user@gmial.com');
    expect(r, isA<Valid>());
    final s = (r as Valid).suggestions.single;
    expect(s.value, 'user@gmail.com');
    expect(s.reason, 'typo-domain');
  });
}
