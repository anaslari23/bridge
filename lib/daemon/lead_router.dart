import '../core/bridge_models.dart';

class TaskDomainClassifier {
  static const _patterns = <String, List<String>>{
    'planning': [
      r'\bplan(?:ning)?\b',
      r'\barchitect(?:ure|ing)?\b',
      r'\bdesign\b',
      r'\broadmap\b',
      r'\brequirements?\b',
      r'\bstrategy\b',
    ],
    'coding': [
      r'\b(?:implement|build|code|refactor|debug|fix|test|compile)\b',
      r'\b(?:function|class|api|parser|component|bug)\b',
    ],
    'web_research': [
      r'\b(?:search|research|browse|look up|find sources|latest|current)\b',
      r'\b(?:web|internet|online|pricing|news)\b',
    ],
  };

  static Set<String> classify(String taskText) {
    final text = taskText.toLowerCase();
    final matches = <String>{};
    for (final entry in _patterns.entries) {
      if (entry.value.any((pattern) => RegExp(pattern).hasMatch(text))) {
        matches.add(entry.key);
      }
    }
    if (matches.isEmpty) matches.add('general');
    return matches;
  }
}

class LeadRouter {
  const LeadRouter();

  BridgeNode? selectLead({
    required String taskText,
    required List<BridgeNode> connectedNodes,
    String? overrideNodeId,
  }) {
    final eligible = connectedNodes
        .where((node) =>
            node.health == 'connected' &&
            node.capabilities.contains('receive_task'))
        .toList(growable: false);

    if (overrideNodeId != null) {
      for (final node in eligible) {
        if (node.id == overrideNodeId) return node;
      }
      return null;
    }

    final requestedDomains = TaskDomainClassifier.classify(taskText);
    BridgeNode? best;
    var bestScore = 0;
    for (final node in eligible) {
      final score = node.taskDomains
              .where((domain) => requestedDomains.contains(domain))
              .length +
          (requestedDomains.contains('web_research') &&
                  node.capabilities.contains('web_research')
              ? 1
              : 0);
      if (score > bestScore) {
        best = node;
        bestScore = score;
      }
    }
    if (best != null) return best;

    // A connector that only declares general work can accept any command.
    for (final node in eligible) {
      if (node.taskDomains.contains('general')) return node;
    }
    return null;
  }
}
