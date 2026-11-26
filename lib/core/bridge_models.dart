enum NodeKind { agent, browser, terminal, file, desktop }

enum TaskStatus {
  created,
  queued,
  working,
  waitingForApproval,
  paused,
  completed,
  failed,
  stopped,
  cancelled
}

class BridgeAttachment {
  const BridgeAttachment({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.mimeType,
    this.contentHash,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final String mimeType;
  final String? contentHash;

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'sizeBytes': sizeBytes,
        'mimeType': mimeType,
        if (contentHash != null) 'contentHash': contentHash,
      };

  static BridgeAttachment? fromJson(Object? value) {
    if (value is! Map || value['path'] is! String || value['name'] is! String)
      return null;
    return BridgeAttachment(
      path: value['path'] as String,
      name: value['name'] as String,
      sizeBytes: (value['sizeBytes'] as num?)?.toInt() ?? 0,
      mimeType: value['mimeType'] as String? ?? 'application/octet-stream',
      contentHash: value['contentHash'] as String?,
    );
  }
}

class BridgeNode {
  const BridgeNode({
    required this.id,
    required this.name,
    required this.kind,
    required this.detail,
    this.capabilities = const [],
    this.taskDomains = const [],
    this.tabId,
    this.url,
    this.processId,
    this.windowId,
    this.adapterId,
    this.adapterVersion,
    this.health = 'unknown',
    this.permissionState = 'unknown',
  });
  final String id;
  final String name;
  final NodeKind kind;
  final String detail;
  final List<String> capabilities;
  final List<String> taskDomains;
  final int? tabId;
  final String? url;
  final int? processId;
  final String? windowId;
  final String? adapterId;
  final String? adapterVersion;
  final String health;
  final String permissionState;

  BridgeNode copyWith({
    String? name,
    String? detail,
    List<String>? capabilities,
    List<String>? taskDomains,
    String? health,
    String? permissionState,
  }) =>
      BridgeNode(
        id: id,
        name: name ?? this.name,
        kind: kind,
        detail: detail ?? this.detail,
        capabilities: capabilities ?? this.capabilities,
        taskDomains: taskDomains ?? this.taskDomains,
        tabId: tabId,
        url: url,
        processId: processId,
        windowId: windowId,
        adapterId: adapterId,
        adapterVersion: adapterVersion,
        health: health ?? this.health,
        permissionState: permissionState ?? this.permissionState,
      );
}

class BridgeTask {
  BridgeTask({
    required this.id,
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.instruction,
    this.projectId = 'project-default',
    this.workflowId,
    this.parentTaskId,
    this.handoffDepth = 0,
    this.attachments = const [],
    this.contextNodeIds = const [],
  }) : createdAt = DateTime.now();
  final String id;
  final String? workflowId;
  final String projectId;
  final String? parentTaskId;
  final int handoffDepth;
  final String sourceNodeId;
  final String targetNodeId;
  final String instruction;
  final List<BridgeAttachment> attachments;
  final List<String> contextNodeIds;
  final DateTime createdAt;
  TaskStatus status = TaskStatus.created;
  String? result;
  String? error;
}

class ProjectContext {
  const ProjectContext({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is ProjectContext && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

class NodeEdge {
  const NodeEdge(this.from, this.to);
  final String from;
  final String to;
}
