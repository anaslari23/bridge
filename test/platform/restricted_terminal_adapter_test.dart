import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:brigade_bridge/core/bridge_models.dart';
import 'package:brigade_bridge/platform/restricted_terminal_adapter.dart';

void main() {
  late Directory temp;
  late RestrictedTerminalAdapter adapter;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('bridge-terminal-test-');
    adapter = RestrictedTerminalAdapter(
      workingDirectory: temp,
      allowedCommands: const ['pwd'],
    );
  });

  tearDown(() => temp.delete(recursive: true));

  test('runs an allowlisted command in the approved directory', () async {
    final output = await adapter.execute(BridgeTask(
      id: 't1', sourceNodeId: 'user', targetNodeId: 'terminal-local', instruction: 'pwd'));
    expect(output.trim(), await temp.resolveSymbolicLinks());
  });

  test('rejects shell operators and non-allowlisted commands', () async {
    BridgeTask task(String command) => BridgeTask(
        id: command,
        sourceNodeId: 'user',
        targetNodeId: 'terminal-local',
        instruction: command);
    expect(() => adapter.execute(task('pwd; whoami')), throwsStateError);
    expect(() => adapter.execute(task('whoami')), throwsStateError);
    expect(() => adapter.execute(task('cat ../outside.txt')), throwsStateError);
    expect(() => adapter.execute(task('/bin/pwd')), throwsStateError);
  });
}
