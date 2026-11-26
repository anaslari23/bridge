import 'dart:convert';

class DelegationDirective {
  const DelegationDirective({
    required this.targetNodeId,
    required this.instruction,
  });

  final String targetNodeId;
  final String instruction;

  @override
  bool operator ==(Object other) =>
      other is DelegationDirective &&
      other.targetNodeId == targetNodeId &&
      other.instruction == instruction;

  @override
  int get hashCode => Object.hash(targetNodeId, instruction);
}

class BridgeProtocol {
  static const delegationMarker = '<<BRIGADE_DELEGATE>>';

  static DelegationDirective? parseDelegation(String response) {
    final text = response.trim();
    if (!text.startsWith(delegationMarker)) return null;
    final jsonText = text.substring(delegationMarker.length);
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic> ||
          decoded.length != 2 ||
          !decoded.containsKey('targetNodeId') ||
          !decoded.containsKey('instruction')) {
        return null;
      }
      final targetNodeId = decoded['targetNodeId'];
      final instruction = decoded['instruction'];
      if (targetNodeId is! String ||
          targetNodeId.trim().isEmpty ||
          instruction is! String ||
          instruction.trim().isEmpty) {
        return null;
      }
      return DelegationDirective(
        targetNodeId: targetNodeId.trim(),
        instruction: instruction.trim(),
      );
    } on FormatException {
      return null;
    }
  }

  static String taskPrompt(String instruction) => '''$instruction

If another explicitly connected app should handle a bounded subtask, return only this exact final response, replacing the values with JSON strings:
$delegationMarker{"targetNodeId":"connected-app-id","instruction":"specific subtask"}
Do not include prose around the delegation marker.''';

  static String continuationPrompt({
    required String instruction,
    required String appName,
    required String result,
  }) =>
      '''Continue your original task: $instruction

Connected app "$appName" completed the delegated subtask. Its result follows:
$result

Use this result and provide your final answer. You may request one more subtask with the exact delegation format if needed.''';
}
