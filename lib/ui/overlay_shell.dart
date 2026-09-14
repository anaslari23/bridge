import 'package:flutter/material.dart';
import '../core/bridge_models.dart';
import 'compact_hud.dart';
import 'expanded_editor.dart';

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
