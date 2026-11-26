import 'dart:io';

/// A fake `claude` executable: records how it was invoked and answers with the
/// documented stream-json events. Behaviour is chosen by words in the prompt.
const _fakeClaude = r'''#!/bin/bash
DIR="$(dirname "$0")"
if [ "$1" = "--version" ]; then echo "9.9.9 (Claude Code)"; exit 0; fi
if [ "$1" = "auth" ] && [ "$2" = "status" ]; then
  if [ -f "$DIR/not_logged_in" ]; then echo '{"loggedIn":false}'; exit 1; fi
  if [ -f "$DIR/api_key_auth" ]; then echo '{"loggedIn":true,"authMethod":"api_key"}'; exit 0; fi
  echo '{"loggedIn":true,"authMethod":"claude.ai"}'; exit 0
fi
echo "$@" >> "$DIR/args.log"
pwd >> "$DIR/cwd.log"
echo "KEY=${ANTHROPIC_API_KEY-unset} TOKEN=${ANTHROPIC_AUTH_TOKEN-unset}" >> "$DIR/env.log"
PROMPT="$(cat)"
echo "$PROMPT" | tr '\n' '~' >> "$DIR/stdin.log"; echo >> "$DIR/stdin.log"
SID="sess-new-1"
while [ $# -gt 0 ]; do [ "$1" = "--resume" ] && SID="$2"; shift; done
echo "{\"type\":\"system\",\"subtype\":\"init\",\"session_id\":\"$SID\"}"
case "$PROMPT" in
  *HOLD*)
    trap 'exit 130' INT
    sleep 30 >/dev/null 2>&1 & wait $!
    ;;
  *DENY*)
    echo "{\"type\":\"system\",\"subtype\":\"permission_denied\",\"tool_name\":\"Bash\",\"session_id\":\"$SID\"}"
    echo "{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false,\"result\":\"done without the command\",\"session_id\":\"$SID\"}"
    ;;
  *FAIL*)
    echo "{\"type\":\"result\",\"subtype\":\"error_during_execution\",\"is_error\":true,\"result\":\"Invalid API key\",\"session_id\":\"$SID\"}"
    exit 1
    ;;
  *CRASH*)
    echo "boom" >&2; exit 3
    ;;
  *ASSISTANT*)
    echo "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"text\",\"text\":\"Streamed answer\"}]},\"session_id\":\"$SID\"}"
    echo "{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false,\"result\":\"\",\"session_id\":\"$SID\"}"
    ;;
  *"Continue your original task"*)
    echo "{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false,\"result\":\"Claude final answer\",\"session_id\":\"$SID\"}"
    ;;
  *DELEGATE_ME*)
    printf '%s\n' '{"type":"result","subtype":"success","is_error":false,"result":"<<BRIGADE_DELEGATE>>{\"targetNodeId\":\"tab-77\",\"instruction\":\"Inspect the selected page\"}","session_id":"sess-new-1"}'
    ;;
  *)
    echo "not json garbage line"
    echo "{\"type\":\"result\",\"subtype\":\"success\",\"is_error\":false,\"result\":\"Claude answer\\n\",\"session_id\":\"$SID\"}"
    ;;
esac
''';

/// Writes the fake `claude` into [dir] and returns its path.
Future<String> writeFakeClaude(Directory dir) async {
  final file = File('${dir.path}/claude')..writeAsStringSync(_fakeClaude);
  await Process.run('chmod', ['+x', file.path]);
  return file.path;
}
