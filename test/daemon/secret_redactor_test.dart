import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/daemon/secret_redactor.dart';

void main() {
  test('redacts common credentials while preserving surrounding context', () {
    const input = 'Authorization: Bearer abc.def-123; api_key="top-secret"; '
        'https://example.test/?access_token=query-secret';

    final output = SecretRedactor.redact(input);

    expect(output, contains('Authorization: Bearer [REDACTED]'));
    expect(output, contains('api_key=[REDACTED]'));
    expect(output, contains('access_token=[REDACTED]'));
    expect(output, isNot(contains('top-secret')));
    expect(output, isNot(contains('query-secret')));
  });

  test('redacts provider tokens and private keys', () {
    const input = '''sk-proj-12345678901234567890
-----BEGIN RSA PRIVATE KEY-----
secret-material
-----END RSA PRIVATE KEY-----''';

    final output = SecretRedactor.redact(input);

    expect(output, contains('[REDACTED TOKEN]'));
    expect(output, contains('[REDACTED PRIVATE KEY]'));
    expect(output, isNot(contains('secret-material')));
  });
}
