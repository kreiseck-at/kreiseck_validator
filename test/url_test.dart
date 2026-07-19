import 'package:input_validator/src/common/issue_code.dart';
import 'package:input_validator/src/common/validation_result.dart';
import 'package:input_validator/src/url/url.dart';
import 'package:test/test.dart';

void main() {
  test('accepts a bare domain', () {
    expect(Url.isValid('example.com'), isTrue);
  });

  test('rejects a host without a dot', () {
    final r = Url.validate('localhost');
    expect((r as Invalid).issues.first.code, IssueCode.urlBadHost);
  });

  test('rejects an unsupported scheme', () {
    final r = Url.validate('ftp://example.com');
    expect((r as Invalid).issues.first.code, IssueCode.urlBadScheme);
  });

  test('normalize adds https, lowercases host, strips trailing slash', () {
    expect(Url.normalize('Example.COM/Path/'), 'https://example.com/Path');
  });

  test('format strips scheme, www and trailing slash for display', () {
    expect(Url.format('https://www.example.com/'), 'example.com');
  });
}
