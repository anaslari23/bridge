import 'dart:io';

/// A fake `agy` executable: a bash script that records how it was invoked and
/// answers with the documented stream-json events.
const _fakeAgy = r'''#!/bin/bash
DIR="$(dirname "$0")"
if [ "$1" = "models" ]; then
  if [ -f "$DIR/models_fail" ]; then echo "authentication required" >&2; exit 1; fi
  echo "Gemini 3.6 Flash (High)"; exit 0
fi
echo "$@" >> "$DIR/args.log"
pwd >> "$DIR/cwd.log"
read -r LINE
echo "$LINE" >> "$DIR/stdin.log"
CONV="c-new-123"
while [ $# -gt 0 ]; do [ "$1" = "--conversation" ] && CONV="$2"; shift; done
echo "{\"event\":\"init\",\"conversation_id\":\"$CONV\",\"init\":{\"permission_mode\":\"request-review\"}}"
case "$LINE" in
  *HOLD*)
    trap 'echo "{\"event\":\"result\",\"result\":{\"conversation_id\":\"'$CONV'\",\"status\":\"INTERRUPTED\",\"response\":\"\"}}"; exit 130' INT
    sleep 30 >/dev/null 2>&1 & wait $!
    ;;
  *NOTICE*)
    echo "permission notice: run_command was denied" >&2
    ;;&
  *FAIL*)
    echo "{\"event\":\"result\",\"result\":{\"conversation_id\":\"$CONV\",\"status\":\"ERROR\",\"response\":\"\",\"error\":\"model unavailable\"}}"
    exit 1
    ;;
  *CRASH*)
    echo "boom" >&2; exit 3
    ;;
  *DELTAS*)
    echo "{\"event\":\"step_update\",\"step_update\":{\"step_type\":\"agent_response\",\"state\":\"ACTIVE\",\"text_delta\":\"Hello \"}}"
    echo "{\"event\":\"step_update\",\"step_update\":{\"step_type\":\"agent_response\",\"state\":\"DONE\",\"text_delta\":\"world\"}}"
    echo "{\"event\":\"result\",\"result\":{\"conversation_id\":\"$CONV\",\"status\":\"SUCCESS\",\"response\":\"\"}}"
    ;;
  *"Continue your original task"*)
    printf '%s\n' '{"event":"result","result":{"conversation_id":"c1","status":"SUCCESS","response":"Antigravity final answer"}}'
    ;;
  *DELEGATE_ME*)
    printf '%s\n' '{"event":"result","result":{"conversation_id":"c1","status":"SUCCESS","response":"<<BRIGADE_DELEGATE>>{\"targetNodeId\":\"tab-77\",\"instruction\":\"Inspect the selected page\"}"}}'
    ;;
  *)
    echo "not json garbage line"
    echo "{\"event\":\"result\",\"result\":{\"conversation_id\":\"$CONV\",\"status\":\"SUCCESS\",\"response\":\"Antigravity answer\\n\"}}"
    ;;
esac
''';

/// Writes the fake `agy` into [dir] and returns its path.
Future<String> writeFakeAgy(Directory dir) async {
  final file = File('${dir.path}/agy')..writeAsStringSync(_fakeAgy);
  await Process.run('chmod', ['+x', file.path]);
  return file.path;
}
