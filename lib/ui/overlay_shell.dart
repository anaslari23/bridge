import 'package:flutter/material.dart';
import '../core/bridge_models.dart';
import 'compact_hud.dart';
import 'expanded_editor.dart';
import '../daemon/event_bus.dart';

class OverlayShell extends StatefulWidget {
  const OverlayShell({
    super.key,
    required this.nodes,
    required this.edges,
    required this.tasks,
    required this.logEntries,
    required this.onRun,
    required this.onStop,
    required this.onAddEdge,
    required this.onDispatch,
    required this.onApprove,
    required this.onDeny,
    required this.status,
    required this.logTail,
    this.onLayoutChanged,
    this.initialPositions = const {},
    this.initialSizes = const {},
    this.initialPan = Offset.zero,
    this.initialZoom = 1,
    this.workspaces = const [],
    this.projects = const [],
    this.activeProjectId = 'project-default',
    this.onSelectProject,
    this.onCreateProject,
    this.onSelectWorkspace,
    this.onCreateWorkspace,
    this.onRenameWorkspace,
    this.onDeleteWorkspace,
    this.onDuplicateWorkspace,
    this.onPinWorkspace,
    this.onNodeDoubleTap,
    this.onNodeCapture,
    this.onNodeRemoved,
    this.onNodeReopened,
    this.onDispatchDetailed,
    this.onDispatchWithContext,
    this.onPickAttachments,
    this.closedNodes = const [],
    this.onRemoveEdge,
    this.snapToGrid = false,
    this.onSnapToGridChanged,
    this.clickThrough = false,
    this.onClickThroughChanged,
    this.launchAtLogin = false,
    this.onLaunchAtLoginChanged,
    this.opacity = 1,
    this.onOpacityChanged,
    this.allowedDomains = const [],
    this.onAllowedDomainsChanged,
    this.localAuthToken = '',
    this.onCopyLocalAuthToken,
    this.onConnectOpenCode,
    this.onDisconnectOpenCode,
    this.artifacts = const [],
    this.onOpenArtifact,
    this.onRetry,
    this.onCancel,
  });

  final List<BridgeNode> nodes;
  final List<NodeEdge> edges;
  final List<BridgeTask> tasks;
  final List<String> logEntries;
  final VoidCallback onRun;
  final VoidCallback onStop;
  final void Function(String from, String to) onAddEdge;
  final void Function(String text) onDispatch;
  final void Function(String taskId) onApprove;
  final void Function(String taskId) onDeny;
  final TaskStatus status;
  final String logTail;
  final void Function(Map<String, Offset> positions, Map<String, Size> sizes,
      Offset pan, double zoom)? onLayoutChanged;
  final Map<String, Offset> initialPositions;
  final Map<String, Size> initialSizes;
  final Offset initialPan;
  final double initialZoom;
  final List<WorkspaceSummary> workspaces;
  final List<ProjectContext> projects;
  final String activeProjectId;
  final ValueChanged<String>? onSelectProject;
  final ValueChanged<String>? onCreateProject;
  final ValueChanged<String>? onSelectWorkspace;
  final VoidCallback? onCreateWorkspace;
  final void Function(String id, String name)? onRenameWorkspace;
  final ValueChanged<String>? onDeleteWorkspace;
  final void Function(String id, String name)? onDuplicateWorkspace;
  final void Function(String id, bool pinned)? onPinWorkspace;
  final ValueChanged<String>? onNodeDoubleTap;
  final ValueChanged<String>? onNodeCapture;
  final ValueChanged<String>? onNodeRemoved;
  final ValueChanged<String>? onNodeReopened;
  final void Function(String text, String? sourceId, String? targetId)?
      onDispatchDetailed;
  final void Function(
      String text,
      String? sourceId,
      String? targetId,
      List<BridgeAttachment> attachments,
      List<String> contextNodeIds)? onDispatchWithContext;
  final Future<List<BridgeAttachment>?> Function()? onPickAttachments;
  final List<BridgeNode> closedNodes;
  final ValueChanged<NodeEdge>? onRemoveEdge;
  final bool snapToGrid;
  final ValueChanged<bool>? onSnapToGridChanged;
  final bool clickThrough;
  final ValueChanged<bool>? onClickThroughChanged;
  final bool launchAtLogin;
  final ValueChanged<bool>? onLaunchAtLoginChanged;
  final double opacity;
  final ValueChanged<double>? onOpacityChanged;
  final List<String> allowedDomains;
  final ValueChanged<List<String>>? onAllowedDomainsChanged;
  final String localAuthToken;
  final VoidCallback? onCopyLocalAuthToken;
  final void Function(String serverUrl, String sessionId)? onConnectOpenCode;
  final ValueChanged<String>? onDisconnectOpenCode;
  final List<ArtifactCreated> artifacts;
  final ValueChanged<String>? onOpenArtifact;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  @override
  State<OverlayShell> createState() => _OverlayShellState();
}

class _OverlayShellState extends State<OverlayShell> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _expanded
          ? ExpandedEditor(
              key: const ValueKey('expanded'),
              nodes: widget.nodes,
              edges: widget.edges,
              tasks: widget.tasks,
              onAddEdge: widget.onAddEdge,
              onRun: widget.onRun,
              onStop: widget.onStop,
              onCompact: () => setState(() => _expanded = false),
              onDispatch: widget.onDispatch,
              onApprove: widget.onApprove,
              onDeny: widget.onDeny,
              logEntries: widget.logEntries,
              status: widget.status,
              onLayoutChanged: widget.onLayoutChanged,
              initialPositions: widget.initialPositions,
              initialSizes: widget.initialSizes,
              initialPan: widget.initialPan,
              initialZoom: widget.initialZoom,
              workspaces: widget.workspaces,
              projects: widget.projects,
              activeProjectId: widget.activeProjectId,
              onSelectProject: widget.onSelectProject,
              onCreateProject: widget.onCreateProject,
              onSelectWorkspace: widget.onSelectWorkspace,
              onCreateWorkspace: widget.onCreateWorkspace,
              onRenameWorkspace: widget.onRenameWorkspace,
              onDeleteWorkspace: widget.onDeleteWorkspace,
              onDuplicateWorkspace: widget.onDuplicateWorkspace,
              onPinWorkspace: widget.onPinWorkspace,
              onNodeDoubleTap: widget.onNodeDoubleTap,
              onNodeCapture: widget.onNodeCapture,
              onNodeRemoved: widget.onNodeRemoved,
              onNodeReopened: widget.onNodeReopened,
              onDispatchDetailed: widget.onDispatchDetailed,
              onDispatchWithContext: widget.onDispatchWithContext,
              onPickAttachments: widget.onPickAttachments,
              closedNodes: widget.closedNodes,
              onRemoveEdge: widget.onRemoveEdge,
              snapToGrid: widget.snapToGrid,
              onSnapToGridChanged: widget.onSnapToGridChanged,
              clickThrough: widget.clickThrough,
              onClickThroughChanged: widget.onClickThroughChanged,
              launchAtLogin: widget.launchAtLogin,
              onLaunchAtLoginChanged: widget.onLaunchAtLoginChanged,
              opacity: widget.opacity,
              onOpacityChanged: widget.onOpacityChanged,
              allowedDomains: widget.allowedDomains,
              onAllowedDomainsChanged: widget.onAllowedDomainsChanged,
              localAuthToken: widget.localAuthToken,
              onCopyLocalAuthToken: widget.onCopyLocalAuthToken,
              onConnectOpenCode: widget.onConnectOpenCode,
              onDisconnectOpenCode: widget.onDisconnectOpenCode,
              artifacts: widget.artifacts,
              onOpenArtifact: widget.onOpenArtifact,
              onRetry: widget.onRetry,
              onCancel: widget.onCancel,
            )
          : CompactHud(
              key: const ValueKey('compact'),
              nodes: widget.nodes,
              onExpand: () => setState(() => _expanded = true),
              onRun: widget.onRun,
              onStop: widget.onStop,
              logTail: widget.logTail,
              status: widget.status,
            ),
    );
  }
}
