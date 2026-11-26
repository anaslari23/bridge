/// Removes common credential-shaped values before they are persisted or
/// emitted in daemon events. The original value remains available to the
/// in-memory workflow so an approved downstream step can still use its result.
class SecretRedactor {
  const SecretRedactor._();

  static String redact(String input) {
    var output = input;

    output = output.replaceAllMapped(
      RegExp(
          r'-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----'),
      (_) => '[REDACTED PRIVATE KEY]',
    );
    output = output.replaceAllMapped(
      RegExp(r'\bBearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
      (_) => 'Bearer [REDACTED]',
    );
    output = output.replaceAllMapped(
      RegExp(
          r'\b(?:sk-[A-Za-z0-9][A-Za-z0-9_-]{19,}|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16})\b'),
      (_) => '[REDACTED TOKEN]',
    );
    output = output.replaceAllMapped(
      RegExp(
        r'([?&](?:api[_-]?key|access[_-]?token|auth[_-]?token|client[_-]?secret|password|passwd|secret|token)=)[^&#\s]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[REDACTED]',
    );
    output = output.replaceAllMapped(
      RegExp(
        r"""\b(api[_-]?key|access[_-]?token|auth[_-]?token|client[_-]?secret|password|passwd|secret)\b\s*([:=])\s*["']?[^,\s"']+""",
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}${match.group(2)}[REDACTED]',
    );
    return output;
  }
}
