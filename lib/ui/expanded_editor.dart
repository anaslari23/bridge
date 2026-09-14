import 'package:flutter/material.dart';
import '../core/bridge_models.dart';
import 'node_canvas.dart';
import 'activity_inspector.dart';

class ExpandedEditor extends StatefulWidget {
  const ExpandedEditor({
    super.key,
    required this.nodes,
    required this.edges,
    required this.tasks,
    required this.onAddEdge,
    required this.onRun,
    required this.onStop,
    required this.onCompact,
    required this.onDispatch,
    required this.onApprove,
    required this.onDeny,
    required this.logEntries,
    required this.status,
  });

  final List<BridgeNode> nodes;
  final List<NodeEdge> edges;
  final List<BridgeTask> tasks;
  final void Function(String from, String to) onAddEdge;
  final VoidCallback onRun;
  final VoidCallback onStop;
  final VoidCallback onCompact;
  final void Function(String text) onDispatch;
  final void Function(String taskId) onApprove;
  final void Function(String taskId) onDeny;
  final List<String> logEntries;
  final TaskStatus status;

  @override
  State<ExpandedEditor> createState() => _ExpandedEditorState();
}

class _ExpandedEditorState extends State<ExpandedEditor> {
  String? _pendingFrom;
  final _nameController =
      TextEditingController(text: 'Research → build → verify');

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleNodeTap(String id) {
    if (_pendingFrom == null) {
      setState(() => _pendingFrom = id);
    } else if (_pendingFrom != id) {
      widget.onAddEdge(_pendingFrom!, id);
      setState(() => _pendingFrom = null);
    } else {
      setState(() => _pendingFrom = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff10131a),
      body: Column(children: [
        // Top bar
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            color: Color(0xff141820),
            border:
                Border(bottom: BorderSide(color: Color(0xff2a303d))),
          ),
          child: Row(children: [
            const Text('✦',
                style:
                    TextStyle(color: Color(0xff8da5ff), fontSize: 20)),
            const SizedBox(width: 10),
            const Text('Brigade Bridge',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(width: 12),
            const Text('LOCAL ORCHESTRATOR',
                style: TextStyle(
                    fontSize: 8,
                    color: Color(0xff707a8c),
                    letterSpacing: 1.5)),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: widget.onCompact,
              icon: const Icon(Icons.compress, size: 12),
              label: const Text('Compact',
                  style: TextStyle(fontSize: 11)),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: widget.onStop,
              icon: const Icon(Icons.stop, size: 12),
              label:
                  const Text('Stop', style: TextStyle(fontSize: 11)),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: widget.onRun,
              icon: const Icon(Icons.play_arrow, size: 14),
              label: const Text('Run workflow',
                  style: TextStyle(fontSize: 11)),
            ),
          ]),
        ),
        // Three-column body
        Expanded(
          child: Row(children: [
            // Sidebar
            Container(
              width: 240,
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xff171b24),
                border: Border(
                    right: BorderSide(color: Color(0xff2a303d))),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('WORKFLOW',
                        style: TextStyle(
                            fontSize: 9,
                            color: Color(0xff737e92),
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Build a brigade',
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text(
                        'Connect tools open on your computer. No API keys.',
                        style: TextStyle(
                            fontSize: 11,
                            height: 1.5,
                            color: Color(0xff8790a2))),
                    const SizedBox(height: 18),
                    const Text('WORKFLOW NAME',
                        style: TextStyle(
                            fontSize: 9, color: Color(0xff8b95a8))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                          hintText: 'Research → build → verify'),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),
                    const Text('AVAILABLE NODES',
                        style: TextStyle(
                            fontSize: 9,
                            color: Color(0xff737e92),
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...widget.nodes.map((n) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${n.kind == NodeKind.agent ? "✦" : "◈"}  ${n.name}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _pendingFrom == n.id
                                  ? const Color(0xff7f95ff)
                                  : const Color(0xffcdd6f4),
                            ),
                          ),
                        )),
                    const Spacer(),
                    const Divider(color: Color(0xff2a303d)),
                    const SizedBox(height: 8),
                    const Text('● Bridge daemon online',
                        style: TextStyle(
                            fontSize: 10,
                            color: Color(0xff9ca8b9))),
                    const Text('   Listening on localhost:7432',
                        style: TextStyle(
                            fontSize: 9,
                            color: Color(0xff7d8798))),
                  ]),
            ),
            // Canvas
            Expanded(
              child: Container(
                color: const Color(0xff11151c),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('CANVAS / DRAFT',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Color(0xff737e92),
                                      letterSpacing: 1.4)),
                              Text(_nameController.text,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis),
                            ]),
                      ),
                      if (_pendingFrom != null) ...[
                        const SizedBox(width: 8),
                        const Text('Now click the target node',
                            style: TextStyle(
                                fontSize: 10,
                                color: Color(0xff7f95ff))),
                      ],
                    ]),
                  ),
                  Expanded(
                    child: NodeCanvas(
                      nodes: widget.nodes,
                      edges: widget.edges,
                      selectedId: _pendingFrom,
                      onNodeTap: _handleNodeTap,
                    ),
                  ),
                ]),
              ),
            ),
            // Inspector
            ActivityInspector(
              logEntries: widget.logEntries,
              status: widget.status,
              onDispatch: widget.onDispatch,
            ),
          ]),
        ),
      ]),
    );
  }
}
