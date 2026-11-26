import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/daemon/security_policy.dart';

void main() {
  test('allows only configured HTTPS domains and subdomains', () {
    final policy = SecurityPolicy(allowedDomains: const ['Example.com']);

    expect(policy.allowsOpenLink('open https://example.com/docs'), isTrue);
    expect(policy.allowsOpenLink('open https://sub.example.com/docs'), isTrue);
    expect(
        policy.allowsOpenLink('open https://example.com.evil.test'), isFalse);
    expect(policy.allowsOpenLink('open http://example.com/docs'), isFalse);
    expect(policy.allowsOpenLink('open https://unknown.test/docs'), isFalse);
  });

  test('normalizes and round-trips the persisted allowlist', () {
    final policy = SecurityPolicy(
        allowedDomains: const [' https://docs.example.com/path ', '*bad']);

    expect(policy.allowedDomains, ['docs.example.com']);
    expect(SecurityPolicy.decode(policy.encode()), ['docs.example.com']);
  });
}
