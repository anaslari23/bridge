import 'package:flutter/material.dart';
import '../core/bridge_models.dart';
import 'node_canvas.dart';
import 'activity_inspector.dart';
import '../daemon/event_bus.dart';
import '../daemon/antigravity_connector.dart';
import '../daemon/claude_code_connector.dart';
import '../daemon/codex_connector.dart';
import '../daemon/opencode_connector.dart';

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
    this.edgesForInspector,
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
    this.onConnectCodex,
    this.onDisconnectCodex,
    this.onConnectAntigravity,
    this.onDisconnectAntigravity,
    this.onConnectClaudeCode,
    this.onDisconnectClaudeCode,
    this.artifacts = const [],
    this.onOpenArtifact,
    this.onRetry,
    this.onCancel,
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
  final List<NodeEdge>? edgesForInspector;
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
  final void Function(String serverUrl, String threadId)? onConnectCodex;
  final ValueChanged<String>? onDisconnectCodex;
  final void Function(String workingDirectory, String? conversationId)?
      onConnectAntigravity;
  final ValueChanged<String>? onDisconnectAntigravity;
  final void Function(String workingDirectory, String? sessionId)?
      onConnectClaudeCode;
  final ValueChanged<String>? onDisconnectClaudeCode;
  final List<ArtifactCreated> artifacts;
  final ValueChanged<String>? onOpenArtifact;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  @override
  State<ExpandedEditor> createState() => _ExpandedEditorState();
}

class _ExpandedEditorState extends State<ExpandedEditor> {
  String? _pendingFrom;
  final _searchController = TextEditingController();
  final _newProjectNameController = TextEditingController();
  final _nameController =
      TextEditingController(text: 'Research → build → verify');

  @override
  void dispose() {
    _searchController.dispose();
    _newProjectNameController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _handleNodeTap(String id) {
    if (_pendingFrom == null) {
      setState(() => _pendingFrom = id);
    } else if (_pendingFrom != id) {
      if (!widget.edges
          .any((edge) => edge.from == _pendingFrom && edge.to == id)) {
        widget.onAddEdge(_pendingFrom!, id);
      }
      setState(() => _pendingFrom = null);
    } else {
      setState(() => _pendingFrom = null);
    }
  }

  Future<void> _showSettings() async {
    var clickThrough = widget.clickThrough;
    var launchAtLogin = widget.launchAtLogin;
    var opacity = widget.opacity;
    final allowedDomainsController =
        TextEditingController(text: widget.allowedDomains.join(', '));
    await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('Overlay settings'),
                  scrollable: true,
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    SwitchListTile(
                        title: const Text('Click-through mode'),
                        subtitle: const Text(
                            'Allow clicks to pass to the app underneath'),
                        value: clickThrough,
                        onChanged: (value) {
                          clickThrough = value;
                          widget.onClickThroughChanged?.call(value);
                          setDialogState(() {});
                        }),
                    SwitchListTile(
                        title: const Text('Launch at login'),
                        subtitle: const Text(
                            'Start Brigade Bridge in the background'),
                        value: launchAtLogin,
                        onChanged: (value) {
                          launchAtLogin = value;
                          widget.onLaunchAtLoginChanged?.call(value);
                          setDialogState(() {});
                        }),
                    ListTile(
                        title: const Text('Overlay opacity'),
                        subtitle: Text('${(opacity * 100).round()}%'),
                        contentPadding: EdgeInsets.zero,
                        trailing: SizedBox(
                            width: 150,
                            child: Slider(
                                value: opacity,
                                min: 0.2,
                                max: 1,
                                onChanged: (value) {
                                  opacity = value;
                                  widget.onOpacityChanged?.call(value);
                                  setDialogState(() {});
                                }))),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.public, size: 20),
                      title: const Text('Allowed HTTPS domains'),
                      subtitle: const Text(
                          'open_link is blocked unless the domain is listed'),
                      isThreeLine: true,
                      trailing: SizedBox(
                        width: 210,
                        child: TextField(
                          controller: allowedDomainsController,
                          style: const TextStyle(fontSize: 11),
                          decoration: const InputDecoration(
                              hintText: 'example.com, docs.example.com',
                              isDense: true),
                        ),
                      ),
                    ),
                    Builder(builder: (context) {
                      final pairedNodes = widget.nodes
                          .where((node) => node.adapterId == 'opencode-http')
                          .toList();
                      final paired =
                          pairedNodes.isEmpty ? null : pairedNodes.first;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.terminal, size: 20),
                        title: const Text('OpenCode session'),
                        subtitle: Text(paired?.detail ??
                            'Connect to a session on a server you started'),
                        trailing: TextButton(
                          onPressed: paired == null
                              ? widget.onConnectOpenCode == null
                                  ? null
                                  : _showOpenCodeConnectDialog
                              : () =>
                                  widget.onDisconnectOpenCode?.call(paired.id),
                          child:
                              Text(paired == null ? 'Connect' : 'Disconnect'),
                        ),
                      );
                    }),
                    _connectorTile(
                      icon: Icons.code,
                      title: 'Codex thread',
                      idle:
                          'Connect to a thread on a codex app-server you started',
                      adapterId: CodexConnector.adapterId,
                      onConnect: widget.onConnectCodex == null
                          ? null
                          : _showCodexConnectDialog,
                      onDisconnect: widget.onDisconnectCodex,
                    ),
                    _connectorTile(
                      icon: Icons.rocket_launch_outlined,
                      title: 'Antigravity (CLI)',
                      idle: 'Run tasks through your signed-in agy command',
                      adapterId: AntigravityConnector.adapterId,
                      onConnect: widget.onConnectAntigravity == null
                          ? null
                          : _showAntigravityConnectDialog,
                      onDisconnect: widget.onDisconnectAntigravity,
                    ),
                    _connectorTile(
                      icon: Icons.chat_outlined,
                      title: 'Claude Code (CLI)',
                      idle: 'Run tasks through your signed-in claude command',
                      adapterId: ClaudeCodeConnector.adapterId,
                      onConnect: widget.onConnectClaudeCode == null
                          ? null
                          : _showClaudeCodeConnectDialog,
                      onDisconnect: widget.onDisconnectClaudeCode,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.key, size: 20),
                      title: const Text('Local Chrome pairing token'),
                      subtitle: Text(
                        widget.localAuthToken.isEmpty
                            ? 'Starting local daemon…'
                            : widget.localAuthToken,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10),
                      ),
                      trailing: IconButton(
                        tooltip: 'Copy token',
                        onPressed: widget.localAuthToken.isEmpty
                            ? null
                            : widget.onCopyLocalAuthToken,
                        icon: const Icon(Icons.copy, size: 18),
                      ),
                    ),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () {
                          final domains = allowedDomainsController.text
                              .split(',')
                              .map((domain) => domain.trim().toLowerCase())
                              .where((domain) => domain.isNotEmpty)
                              .toSet()
                              .toList();
                          widget.onAllowedDomainsChanged?.call(domains);
                          Navigator.pop(context);
                        },
                        child: const Text('Done'))
                  ],
                )));
    allowedDomainsController.dispose();
  }

  Future<void> _showOpenCodeConnectDialog() async {
    final serverController =
        TextEditingController(text: 'http://127.0.0.1:4096');
    final sessionController = TextEditingController();
    var errorText = '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Connect OpenCode session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Start the OpenCode server yourself, then enter its loopback URL and the session ID you want Bridge to use. Bridge will not find or start sessions.',
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('opencode-server-url'),
                controller: serverController,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'http://127.0.0.1:4096',
                ),
              ),
              TextField(
                key: const ValueKey('opencode-session-id'),
                controller: sessionController,
                decoration: const InputDecoration(labelText: 'Session ID'),
              ),
              if (errorText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(errorText,
                      style: const TextStyle(color: Color(0xfffa777c))),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  OpenCodeConnector.validateEndpoint(
                    serverUrl: serverController.text,
                    sessionId: sessionController.text,
                  );
                } on FormatException catch (error) {
                  setDialogState(() => errorText = error.message);
                  return;
                }
                widget.onConnectOpenCode?.call(
                  serverController.text.trim(),
                  sessionController.text,
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('Connect OpenCode'),
            ),
          ],
        ),
      ),
    );
    serverController.dispose();
    sessionController.dispose();
  }

  Widget _connectorTile({
    required IconData icon,
    required String title,
    required String idle,
    required String adapterId,
    required VoidCallback? onConnect,
    required ValueChanged<String>? onDisconnect,
  }) {
    final matches = widget.nodes.where((node) => node.adapterId == adapterId);
    final paired = matches.isEmpty ? null : matches.first;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20),
      title: Text(title),
      subtitle: Text(paired?.detail ?? idle),
      trailing: TextButton(
        onPressed: paired == null
            ? onConnect
            : onDisconnect == null
                ? null
                : () => onDisconnect(paired.id),
        child: Text(paired == null ? 'Connect' : 'Disconnect'),
      ),
    );
  }

  Future<void> _showCodexConnectDialog() => _showConnectorDialog(
        title: 'Connect Codex thread',
        intro:
            'Start the app yourself with codex app-server --listen ws://127.0.0.1:4500, then enter its loopback URL and the thread ID you want Bridge to use. Bridge reuses Codex\'s own sign-in and will not find or start threads.',
        fields: const [
          _DialogField('codex-server-url', 'Server URL', 'ws://127.0.0.1:4500',
              'ws://127.0.0.1:4500'),
          _DialogField('codex-thread-id', 'Thread ID', '', ''),
        ],
        connectLabel: 'Connect Codex',
        validate: (values) => CodexConnector.validateEndpoint(
            serverUrl: values[0], threadId: values[1]),
        onSubmit: (values) =>
            widget.onConnectCodex?.call(values[0].trim(), values[1]),
      );

  Future<void> _showAntigravityConnectDialog() => _showConnectorDialog(
        title: 'Connect Antigravity',
        intro:
            'Bridge starts your own agy command once per task in the folder below, using your existing Antigravity sign-in. Leave the conversation ID empty to start a new conversation. Actions agy would ask about are denied unless you allow them in Antigravity\'s settings.',
        fields: const [
          _DialogField('antigravity-working-directory', 'Working directory',
              '/absolute/path/to/project', ''),
          _DialogField('antigravity-conversation-id',
              'Conversation ID (optional)', '', ''),
        ],
        connectLabel: 'Connect Antigravity',
        validate: (values) => AntigravityConnector.validateConfig(
            workingDirectory: values[0].trim(),
            conversationId: values[1].trim()),
        onSubmit: (values) => widget.onConnectAntigravity?.call(
          values[0].trim(),
          values[1].trim().isEmpty ? null : values[1].trim(),
        ),
      );

  Future<void> _showClaudeCodeConnectDialog() => _showConnectorDialog(
        title: 'Connect Claude Code',
        intro:
            'Bridge starts your own claude command once per task in the folder below, using your Claude account sign-in (API keys are ignored). Leave the session ID empty to start a new session. Actions Claude Code would ask about are denied unless you allow them in Claude Code settings.',
        fields: const [
          _DialogField('claude-code-working-directory', 'Working directory',
              '/absolute/path/to/project', ''),
          _DialogField(
              'claude-code-session-id', 'Session ID (optional)', '', ''),
        ],
        connectLabel: 'Connect Claude Code',
        validate: (values) => ClaudeCodeConnector.validateConfig(
            workingDirectory: values[0].trim(), sessionId: values[1].trim()),
        onSubmit: (values) => widget.onConnectClaudeCode?.call(
          values[0].trim(),
          values[1].trim().isEmpty ? null : values[1].trim(),
        ),
      );

  Future<void> _showConnectorDialog({
    required String title,
    required String intro,
    required List<_DialogField> fields,
    required String connectLabel,
    required void Function(List<String> values) validate,
    required void Function(List<String> values) onSubmit,
  }) =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => _ConnectorDialog(
          title: title,
          intro: intro,
          fields: fields,
          connectLabel: connectLabel,
          validate: validate,
          onSubmit: onSubmit,
        ),
      );

  Future<void> _showCreateProjectDialog() async {
    _newProjectNameController.clear();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create project context'),
        content: TextField(
          controller: _newProjectNameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Project name'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(context, _newProjectNameController.text),
              child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      widget.onCreateProject?.call(name.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final visibleWorkspaces = widget.workspaces
        .where((workspace) => workspace.name.toLowerCase().contains(query))
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xff10131a),
      body: Column(children: [
        // Top bar
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            color: Color(0xff141820),
            border: Border(bottom: BorderSide(color: Color(0xff2a303d))),
          ),
          child: LayoutBuilder(builder: (context, constraints) {
            // Below this width the labelled buttons no longer fit next to the
            // project picker, so they collapse to icons (tooltips keep names).
            final narrow = constraints.maxWidth < 1100;
            return Row(children: [
              const Text('✦',
                  style: TextStyle(color: Color(0xff8da5ff), fontSize: 20)),
              const SizedBox(width: 10),
              const Flexible(
                child: Text('Brigade Bridge',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const ValueKey('active-project-dropdown'),
                      isExpanded: true,
                      value: widget.projects.any(
                              (project) => project.id == widget.activeProjectId)
                          ? widget.activeProjectId
                          : null,
                      hint: const Text('Choose project',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11)),
                      items: widget.projects
                          .map((project) => DropdownMenuItem<String>(
                                value: project.id,
                                child: Text(project.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11)),
                              ))
                          .toList(),
                      onChanged: (id) {
                        if (id != null) widget.onSelectProject?.call(id);
                      },
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Create project context',
                onPressed: _showCreateProjectDialog,
                icon: const Icon(Icons.add_circle_outline, size: 16),
              ),
              const Spacer(),
              IconButton(
                  tooltip: 'Overlay settings',
                  onPressed: _showSettings,
                  icon: const Icon(Icons.settings, size: 16)),
              const SizedBox(width: 4),
              if (narrow) ...[
                IconButton(
                  tooltip: 'Compact',
                  onPressed: widget.onCompact,
                  icon: const Icon(Icons.compress, size: 16),
                ),
                IconButton(
                  tooltip: 'Stop',
                  onPressed: widget.onStop,
                  icon: const Icon(Icons.stop, size: 16),
                ),
                IconButton.filled(
                  tooltip: 'Run workflow',
                  onPressed: widget.onRun,
                  icon: const Icon(Icons.play_arrow, size: 16),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: widget.onCompact,
                  icon: const Icon(Icons.compress, size: 12),
                  label: const Text('Compact', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: widget.onStop,
                  icon: const Icon(Icons.stop, size: 12),
                  label: const Text('Stop', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: widget.onRun,
                  icon: const Icon(Icons.play_arrow, size: 14),
                  label: const Text('Run workflow',
                      style: TextStyle(fontSize: 11)),
                ),
              ],
            ]);
          }),
        ),
        // Three-column body
        Expanded(
          child: Row(children: [
            // Sidebar
            Container(
              width: MediaQuery.sizeOf(context).width < 1000 ? 200 : 240,
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xff171b24),
                border: Border(right: BorderSide(color: Color(0xff2a303d))),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
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
                              const Text('Workspaces',
                                  style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              const Text(
                                  'Saved visual layouts. They do not copy or open project files.',
                                  style: TextStyle(
                                      fontSize: 11,
                                      height: 1.5,
                                      color: Color(0xff8790a2))),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(fontSize: 11),
                                decoration: const InputDecoration(
                                  hintText: 'Find workspace…',
                                  prefixIcon: Icon(Icons.search, size: 16),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 10),
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (visibleWorkspaces.isNotEmpty)
                                ...visibleWorkspaces.map((workspace) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => widget
                                                .onSelectWorkspace
                                                ?.call(workspace.id),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 5),
                                              child: Text(workspace.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: workspace.name ==
                                                              _nameController
                                                                  .text
                                                          ? const Color(
                                                              0xff7f95ff)
                                                          : const Color(
                                                              0xffcdd6f4))),
                                            ),
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.more_horiz,
                                              size: 15,
                                              color: Color(0xff7d8798)),
                                          onSelected: (action) async {
                                            if (action == 'rename') {
                                              final controller =
                                                  TextEditingController(
                                                      text: workspace.name);
                                              final name = await showDialog<
                                                      String>(
                                                  context: context,
                                                  builder: (context) =>
                                                      AlertDialog(
                                                          title: const Text(
                                                              'Rename workspace'),
                                                          content: TextField(
                                                              controller:
                                                                  controller,
                                                              autofocus: true),
                                                          actions: [
                                                            TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        context),
                                                                child: const Text(
                                                                    'Cancel')),
                                                            FilledButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        context,
                                                                        controller
                                                                            .text
                                                                            .trim()),
                                                                child:
                                                                    const Text(
                                                                        'Save'))
                                                          ]));
                                              controller.dispose();
                                              if (name != null &&
                                                  name.isNotEmpty)
                                                widget.onRenameWorkspace
                                                    ?.call(workspace.id, name);
                                            } else if (action == 'duplicate') {
                                              widget.onDuplicateWorkspace?.call(
                                                  workspace.id,
                                                  '${workspace.name} copy');
                                            } else if (action == 'pin') {
                                              widget.onPinWorkspace?.call(
                                                  workspace.id,
                                                  !workspace.pinned);
                                            } else if (action == 'delete') {
                                              final confirmed = await showDialog<
                                                          bool>(
                                                      context: context,
                                                      builder: (context) =>
                                                          AlertDialog(
                                                              title: const Text(
                                                                  'Delete workspace?'),
                                                              content: Text(
                                                                  'Delete “${workspace.name}” and its saved graph?'),
                                                              actions: [
                                                                TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            context,
                                                                            false),
                                                                    child: const Text(
                                                                        'Cancel')),
                                                                FilledButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            context,
                                                                            true),
                                                                    child: const Text(
                                                                        'Delete'))
                                                              ])) ??
                                                  false;
                                              if (confirmed)
                                                widget.onDeleteWorkspace
                                                    ?.call(workspace.id);
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(
                                                value: 'rename',
                                                child: Text('Rename')),
                                            const PopupMenuItem(
                                                value: 'duplicate',
                                                child: Text('Duplicate')),
                                            PopupMenuItem(
                                                value: 'pin',
                                                child: Text(workspace.pinned
                                                    ? 'Unpin'
                                                    : 'Pin')),
                                            const PopupMenuDivider(),
                                            const PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Delete')),
                                          ],
                                        ),
                                      ]),
                                    )),
                              OutlinedButton.icon(
                                onPressed: widget.onCreateWorkspace,
                                icon: const Icon(Icons.add, size: 13),
                                label: const Text('New workspace',
                                    style: TextStyle(fontSize: 11)),
                              ),
                              const SizedBox(height: 12),
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
                              Material(
                                color: Colors.transparent,
                                child: SwitchListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Snap to grid',
                                        style: TextStyle(fontSize: 11)),
                                    value: widget.snapToGrid,
                                    onChanged: widget.onSnapToGridChanged),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Expanded(
                                        child: Text('AVAILABLE NODES',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 9,
                                                color: Color(0xff737e92),
                                                letterSpacing: 1.4,
                                                fontWeight: FontWeight.bold))),
                                  ]),
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
                              if (widget.closedNodes.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const Text('CLOSED NODES',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: Color(0xff737e92),
                                        letterSpacing: 1.4,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                ...widget.closedNodes.map((n) => Material(
                                      color: Colors.transparent,
                                      child: ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(n.name,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xff8790a2))),
                                        trailing: IconButton(
                                            tooltip: 'Reopen node',
                                            onPressed: () => widget
                                                .onNodeReopened
                                                ?.call(n.id),
                                            icon: const Icon(Icons.restore,
                                                size: 14,
                                                color: Color(0xff8da5ff))),
                                      ),
                                    )),
                              ],
                            ]),
                      ),
                    ),
                    const Divider(color: Color(0xff2a303d)),
                    const SizedBox(height: 8),
                    const Text('● Bridge daemon online',
                        style:
                            TextStyle(fontSize: 10, color: Color(0xff9ca8b9))),
                    const Text('   Listening on localhost:7432',
                        style:
                            TextStyle(fontSize: 9, color: Color(0xff7d8798))),
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
                                fontSize: 10, color: Color(0xff7f95ff))),
                      ],
                    ]),
                  ),
                  Expanded(
                    child: NodeCanvas(
                      nodes: widget.nodes,
                      edges: widget.edges,
                      selectedId: _pendingFrom,
                      onNodeTap: _handleNodeTap,
                      onNodeDoubleTap: widget.onNodeDoubleTap,
                      onNodeCapture: widget.onNodeCapture,
                      onNodeRemoved: widget.onNodeRemoved,
                      onLayoutChanged: widget.onLayoutChanged,
                      initialPositions: widget.initialPositions,
                      initialSizes: widget.initialSizes,
                      initialPan: widget.initialPan,
                      initialZoom: widget.initialZoom,
                      snapToGrid: widget.snapToGrid,
                    ),
                  ),
                ]),
              ),
            ),
            // Inspector
            ActivityInspector(
              width: MediaQuery.sizeOf(context).width < 1000 ? 250 : 300,
              logEntries: widget.logEntries,
              status: widget.status,
              tasks: widget.tasks,
              onDispatch: widget.onDispatch,
              nodes: widget.nodes,
              edges: widget.edgesForInspector ?? widget.edges,
              onRemoveEdge: widget.onRemoveEdge,
              onDispatchDetailed: widget.onDispatchDetailed,
              onDispatchWithContext: widget.onDispatchWithContext,
              onPickAttachments: widget.onPickAttachments,
              artifacts: widget.artifacts,
              onOpenArtifact: widget.onOpenArtifact,
              onRetry: widget.onRetry,
              onCancel: widget.onCancel,
            ),
          ]),
        ),
      ]),
    );
  }
}

class _DialogField {
  const _DialogField(this.key, this.label, this.hint, this.initial);
  final String key;
  final String label;
  final String hint;
  final String initial;
}

/// Owns its text controllers so they are disposed only after the dialog route
/// has fully left the tree (disposing right after `showDialog` returns races
/// the closing animation).
class _ConnectorDialog extends StatefulWidget {
  const _ConnectorDialog({
    required this.title,
    required this.intro,
    required this.fields,
    required this.connectLabel,
    required this.validate,
    required this.onSubmit,
  });

  final String title;
  final String intro;
  final List<_DialogField> fields;
  final String connectLabel;
  final void Function(List<String> values) validate;
  final void Function(List<String> values) onSubmit;

  @override
  State<_ConnectorDialog> createState() => _ConnectorDialogState();
}

class _ConnectorDialogState extends State<_ConnectorDialog> {
  late final List<TextEditingController> _controllers = [
    for (final field in widget.fields)
      TextEditingController(text: field.initial),
  ];
  String _errorText = '';

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final values = [for (final c in _controllers) c.text];
    try {
      widget.validate(values);
    } on FormatException catch (error) {
      setState(() => _errorText = error.message);
      return;
    }
    widget.onSubmit(values);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        scrollable: true,
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.intro),
              const SizedBox(height: 12),
              for (var i = 0; i < widget.fields.length; i++)
                TextField(
                  key: ValueKey(widget.fields[i].key),
                  controller: _controllers[i],
                  decoration: InputDecoration(
                    labelText: widget.fields[i].label,
                    hintText: widget.fields[i].hint,
                  ),
                ),
              if (_errorText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_errorText,
                      style: const TextStyle(color: Color(0xfffa777c))),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: _submit, child: Text(widget.connectLabel)),
        ],
      );
}
