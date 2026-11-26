import 'dart:io';
import 'package:flutter/material.dart';
import '../core/bridge_models.dart';
import '../daemon/event_bus.dart';

class ActivityInspector extends StatefulWidget {
  const ActivityInspector({
    super.key,
    required this.logEntries,
    required this.status,
    required this.onDispatch,
    this.tasks = const [],
    this.nodes = const [],
    this.onDispatchDetailed,
    this.onDispatchWithContext,
    this.onPickAttachments,
    this.edges = const [],
    this.onRemoveEdge,
    this.artifacts = const [],
    this.onOpenArtifact,
    this.onRetry,
    this.onCancel,
  });
  final List<String> logEntries;
  final TaskStatus status;
  final void Function(String text) onDispatch;
  final List<BridgeTask> tasks;
  final List<BridgeNode> nodes;
  final void Function(String text, String? sourceId, String? targetId)?
      onDispatchDetailed;
  final void Function(
      String text,
      String? sourceId,
      String? targetId,
      List<BridgeAttachment> attachments,
      List<String> contextNodeIds)? onDispatchWithContext;
  final Future<List<BridgeAttachment>?> Function()? onPickAttachments;
  final List<NodeEdge> edges;
  final ValueChanged<NodeEdge>? onRemoveEdge;
  final List<ArtifactCreated> artifacts;
  final ValueChanged<String>? onOpenArtifact;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  @override
  State<ActivityInspector> createState() => _ActivityInspectorState();
}

class _ActivityInspectorState extends State<ActivityInspector> {
  final _controller = TextEditingController();
  final _composerFocusNode = FocusNode();
  String? _sourceId;
  String? _targetId;
  final _attachments = <BridgeAttachment>[];
  final _contextNodeIds = <String>{};

  @override
  void dispose() {
    _controller.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  void _takeOver(BridgeTask task) {
    setState(() {
      _controller.text = task.instruction;
      _sourceId = task.sourceNodeId == 'user' ? null : task.sourceNodeId;
      _targetId = task.targetNodeId;
      _attachments
        ..clear()
        ..addAll(task.attachments);
      _contextNodeIds
        ..clear()
        ..addAll(task.contextNodeIds);
    });
    _composerFocusNode.requestFocus();
  }

  String _statusLabel(TaskStatus s) {
    switch (s) {
      case TaskStatus.working:
        return 'RUNNING';
      case TaskStatus.waitingForApproval:
        return 'WAITING';
      case TaskStatus.paused:
        return 'PAUSED';
      case TaskStatus.completed:
        return 'DONE';
      case TaskStatus.failed:
        return 'FAILED';
      case TaskStatus.stopped:
      case TaskStatus.cancelled:
        return 'STOPPED';
      default:
        return 'READY';
    }
  }

  Future<void> _previewArtifact(ArtifactCreated artifact) async {
    final file = File(artifact.path);
    if (!await file.exists()) return;
    if (!mounted) return;
    if (artifact.mimeType.startsWith('image/')) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Artifact preview'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700, maxHeight: 500),
            child: Image.file(file, fit: BoxFit.contain),
          ),
        ),
      );
      return;
    }
    final bytes = await file.readAsBytes();
    final text = String.fromCharCodes(bytes.take(12000));
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Artifact preview'),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: SelectableText(text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
        ),
      ),
    );
  }

  Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.working:
        return const Color(0xff9fb1ff);
      case TaskStatus.waitingForApproval:
        return const Color(0xfff2a65a);
      case TaskStatus.paused:
        return const Color(0xfff2a65a);
      case TaskStatus.failed:
      case TaskStatus.stopped:
      case TaskStatus.cancelled:
        return const Color(0xffff6b6b);
      default:
        return const Color(0xff56d19a);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eligibleLeads = widget.nodes
        .where((node) =>
            node.health == 'connected' &&
            node.capabilities.contains('receive_task'))
        .toList();
    final selectedLeadId =
        eligibleLeads.any((node) => node.id == _targetId) ? _targetId : null;
    return Container(
      width: 300,
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Color(0xff171b24),
        border: Border(left: BorderSide(color: Color(0xff2a303d))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ACTIVITY',
            style: TextStyle(
                fontSize: 9,
                color: Color(0xff737e92),
                letterSpacing: 1.4,
                fontWeight: FontWeight.bold)),
        Row(children: [
          const Expanded(
            child: Text('Task stream',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          Text(_statusLabel(widget.status),
              style: TextStyle(
                  fontSize: 9,
                  color: _statusColor(widget.status),
                  fontWeight: FontWeight.bold)),
          if ((widget.status == TaskStatus.paused ||
                  widget.status == TaskStatus.failed) &&
              widget.onRetry != null)
            TextButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Retry', style: TextStyle(fontSize: 10)),
              style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
          if ((widget.status == TaskStatus.queued ||
                  widget.status == TaskStatus.working ||
                  widget.status == TaskStatus.waitingForApproval) &&
              widget.onCancel != null)
            TextButton.icon(
              onPressed: widget.onCancel,
              icon: const Icon(Icons.cancel_outlined, size: 14),
              label: const Text('Cancel', style: TextStyle(fontSize: 10)),
              style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              key: const ValueKey('task-composer'),
              controller: _controller,
              focusNode: _composerFocusNode,
              maxLines: 3,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                filled: true,
                fillColor: Color(0xff151a23),
                hintText: 'Enter task instruction…',
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Attach local files',
            onPressed: widget.onPickAttachments == null
                ? null
                : () async {
                    final picked = await widget.onPickAttachments!.call();
                    if (!mounted || picked == null) return;
                    setState(() {
                      for (final attachment in picked) {
                        if (!_attachments.any((item) =>
                            item.path == attachment.path &&
                            item.contentHash == attachment.contentHash)) {
                          _attachments.add(attachment);
                        }
                      }
                    });
                  },
            icon: const Icon(Icons.attach_file, size: 18),
          ),
        ]),
        if (_attachments.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _attachments
                .map((attachment) => InputChip(
                      label: Text(attachment.name,
                          overflow: TextOverflow.ellipsis),
                      onDeleted: () => setState(() => _attachments
                          .removeWhere((item) => item.path == attachment.path)),
                    ))
                .toList(),
          ),
        ],
        if (eligibleLeads.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const ValueKey('lead-selector'),
            initialValue: selectedLeadId,
            isExpanded: true,
            decoration:
                const InputDecoration(labelText: 'Lead app', isDense: true),
            items: [
              const DropdownMenuItem<String>(
                  value: null, child: Text('Automatic (recommended)')),
              ...eligibleLeads.map((node) => DropdownMenuItem<String>(
                    value: node.id,
                    child: Text(node.name, overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: (value) => setState(() => _targetId = value),
          ),
          const SizedBox(height: 4),
          const Text('Choose Automatic to let Bridge select one connected app.',
              style: TextStyle(fontSize: 9, color: Color(0xff8790a2))),
          const SizedBox(height: 6),
          Text('Context nodes',
              style: TextStyle(fontSize: 10, color: Color(0xff8790a2))),
          Wrap(
            spacing: 4,
            children: widget.nodes
                .map((node) => FilterChip(
                      label: Text(node.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9)),
                      selected: _contextNodeIds.contains(node.id),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _contextNodeIds.add(node.id);
                        } else {
                          _contextNodeIds.remove(node.id);
                        }
                      }),
                    ))
                .toList(),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              final text = _controller.text.trim();
              if (text.isEmpty) return;
              if (widget.onDispatchWithContext != null) {
                widget.onDispatchWithContext!(
                  text,
                  null,
                  selectedLeadId,
                  List.unmodifiable(_attachments),
                  _contextNodeIds.toList(),
                );
              } else if (widget.onDispatchDetailed != null) {
                widget.onDispatchDetailed!(text, null, selectedLeadId);
              } else {
                widget.onDispatch(text);
              }
            },
            child: const Text('Dispatch task', style: TextStyle(fontSize: 12)),
          ),
        ),
        if (widget.tasks.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('TASKS',
              style: TextStyle(
                  fontSize: 9,
                  color: Color(0xff737e92),
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 170),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.tasks.length,
              itemBuilder: (_, index) {
                final task = widget.tasks[index];
                final statusColor = _statusColor(task.status);
                final parents = widget.tasks
                    .where((candidate) => candidate.id == task.parentTaskId);
                final parentLabel = parents.isEmpty
                    ? task.parentTaskId
                    : _nodeLabel(parents.first.targetNodeId);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xff151a23),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xff2a303d)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text(
                                  '${_nodeLabel(task.sourceNodeId)}  →  ${_nodeLabel(task.targetNodeId)}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text(_statusLabel(task.status),
                                  style: TextStyle(
                                      fontSize: 8,
                                      color: statusColor,
                                      fontWeight: FontWeight.bold)),
                            ]),
                            const SizedBox(height: 4),
                            if (task.parentTaskId != null) ...[
                              Text('Delegated · depth ${task.handoffDepth}',
                                  style: const TextStyle(
                                      fontSize: 8, color: Color(0xff9aa9ff))),
                              Text('Delegated from $parentLabel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 8, color: Color(0xff737e92))),
                            ],
                            Text(task.instruction,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 9, color: Color(0xffa4adbd))),
                            if (task.error != null) ...[
                              const SizedBox(height: 3),
                              Text(task.error!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 9, color: Color(0xffff8b8b))),
                            ],
                            if (task.result != null) ...[
                              const SizedBox(height: 3),
                              Text(task.result!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 9, color: Color(0xff8ed6b3))),
                            ],
                            if ((task.status == TaskStatus.failed ||
                                    task.status == TaskStatus.paused) &&
                                widget.onDispatchWithContext != null) ...[
                              const SizedBox(height: 3),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _takeOver(task),
                                  icon: const Icon(Icons.edit, size: 12),
                                  label: const Text('Take over',
                                      style: TextStyle(fontSize: 9)),
                                  style: TextButton.styleFrom(
                                      minimumSize: Size.zero,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2)),
                                ),
                              ),
                            ],
                          ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if (widget.edges.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('CONNECTIONS',
              style: TextStyle(
                  fontSize: 9,
                  color: Color(0xff737e92),
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 100),
            child: ListView(
              shrinkWrap: true,
              children: widget.edges
                  .map((edge) => Material(
                        color: Colors.transparent,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              '${_nodeLabel(edge.from)}  →  ${_nodeLabel(edge.to)}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xffcdd6f4))),
                          trailing: IconButton(
                              tooltip: 'Delete connection',
                              onPressed: () => widget.onRemoveEdge?.call(edge),
                              icon: const Icon(Icons.close,
                                  size: 14, color: Color(0xff9aa5b8))),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (widget.artifacts.isNotEmpty) ...[
          const Text('ARTIFACTS',
              style: TextStyle(
                  fontSize: 9,
                  color: Color(0xff737e92),
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: ListView(
              shrinkWrap: true,
              children: widget.artifacts
                  .map((artifact) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                            artifact.mimeType.startsWith('image/')
                                ? Icons.image
                                : Icons.insert_drive_file,
                            size: 15,
                            color: const Color(0xffe6c76a)),
                        title: Text(artifact.path.split('/').last,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10)),
                        subtitle: Text(
                            '${artifact.sizeBytes} bytes · ${artifact.contentHash.substring(0, 8)}',
                            style: const TextStyle(
                                fontSize: 9, color: Color(0xff7d8798))),
                        trailing: IconButton(
                          tooltip: 'Open artifact',
                          onPressed: widget.onOpenArtifact == null
                              ? null
                              : () => widget.onOpenArtifact!(artifact.path),
                          icon: const Icon(Icons.open_in_new, size: 14),
                        ),
                        onTap: () => _previewArtifact(artifact),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const Text('EVENT LOG',
            style: TextStyle(
                fontSize: 9,
                color: Color(0xff737e92),
                letterSpacing: 1.4,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            reverse: true,
            itemCount: widget.logEntries.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('● ${widget.logEntries[i]}',
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xffa4adbd))),
            ),
          ),
        ),
        const Divider(color: Color(0xff2a303d)),
        const SizedBox(height: 10),
        const Text('PERMISSIONS',
            style: TextStyle(
                fontSize: 9,
                color: Color(0xff737e92),
                letterSpacing: 1.4,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('⌾  Read-only by default',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        const Text('     Text input requires approval',
            style: TextStyle(fontSize: 10, color: Color(0xff7d8798))),
      ]),
    );
  }

  String _nodeLabel(String id) =>
      widget.nodes
          .where((node) => node.id == id)
          .map((node) => node.name)
          .firstOrNull ??
      id;
}
