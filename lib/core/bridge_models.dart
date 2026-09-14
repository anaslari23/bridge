enum NodeKind { agent, browser, terminal, desktop }

enum TaskStatus { created, queued, working, waitingForApproval, completed, failed, stopped, cancelled }

class BridgeNode {
  const BridgeNode({
    required this.id,
    required this.name,
    required this.kind,
    required this.detail,
    this.capabilities = const [],
    this.tabId,
    this.url,
  });
  final String id;
  final String name;
  final NodeKind kind;
  final String detail;
  final List<String> capabilities;
  final int? tabId;
  final String? url;
}

class BridgeTask {
  BridgeTask({
    required this.id,
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.instruction,
  }) : createdAt = DateTime.now();
  final String id;
  final String sourceNodeId;
  final String targetNodeId;
  final String instruction;
  final DateTime createdAt;
  TaskStatus status = TaskStatus.created;
  String? result;
  String? error;
}

class NodeEdge {
  const NodeEdge(this.from, this.to);
  final String from;
  final String to;
}
