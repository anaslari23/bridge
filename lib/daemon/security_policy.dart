import 'dart:convert';

/// Local policy for actions that can leave the current app or expose data to a
/// remote origin. An empty domain allowlist is intentionally deny-by-default.
class SecurityPolicy {
  SecurityPolicy({Iterable<String> allowedDomains = const []})
      : _allowedDomains = _normalizeDomains(allowedDomains);

  Set<String> _allowedDomains;

  List<String> get allowedDomains => _allowedDomains.toList()..sort();

  void setAllowedDomains(Iterable<String> domains) {
    _allowedDomains = _normalizeDomains(domains);
  }

  bool allowsOpenLink(String rawInstruction) {
    final matches =
        RegExp(r"""https://[^\s<>"']+""").allMatches(rawInstruction);
    if (matches.isEmpty) return false;
    return matches.every((match) => _allowsUrl(match.group(0)!));
  }

  bool _allowsUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
    final host = uri.host.toLowerCase();
    return _allowedDomains
        .any((domain) => host == domain || host.endsWith('.$domain'));
  }

  String encode() => jsonEncode(allowedDomains);

  static List<String> decode(String? value) {
    if (value == null) return const [];
    try {
      final decoded = jsonDecode(value);
      return decoded is List ? decoded.whereType<String>().toList() : const [];
    } catch (_) {
      return const [];
    }
  }

  static Set<String> _normalizeDomains(Iterable<String> domains) => domains
      .map((domain) => domain.trim().toLowerCase())
      .map((domain) => domain.replaceFirst(RegExp(r'^https?://'), ''))
      .map((domain) => domain.split('/').first)
      .where((domain) =>
          domain.isNotEmpty &&
          !domain.contains(':') &&
          !domain.contains(' ') &&
          !domain.contains('*'))
      .toSet();
}
