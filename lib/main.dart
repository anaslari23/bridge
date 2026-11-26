import 'dart:io';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'core/bridge_models.dart';
import 'daemon/daemon.dart';
import 'daemon/event_bus.dart';
import 'platform/bridge_channel.dart';
import 'ui/approval_modal.dart';
import 'ui/overlay_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  BridgeChannel.init();
  runApp(const BridgeApp());
}

class BridgeApp extends StatelessWidget {
  const BridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Brigade Bridge',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xff10131a),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff7188ff),
          brightness: Brightness.dark,
        ),
      ),
      home: const _AppShell(),
    );
  }
}

class _SetupBullet extends StatelessWidget {
  const _SetupBullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.check_circle, size: 14, color: Color(0xff56d19a)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ]),
      );
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  final List<BridgeNode> _nodes = [];
  final List<BridgeNode> _closedNodes = [];
  final List<NodeEdge> _edges = [];
  final List<BridgeTask> _tasks = [];
  final List<String> _log = [];
  final List<ArtifactCreated> _artifacts = [];
  Map<String, dynamic>? _lastWorkflowPayload;
  final List<WorkspaceSummary> _workspaces = [];
  final List<ProjectContext> _projects = [];
  String _projectId = 'project-default';
  TaskStatus _status = TaskStatus.created;
  SendPort? _daemonSend;
  String _workspaceId = 'workspace-default';
  String _workspaceName = 'Research → build → verify';
  Map<String, Offset> _layoutPositions = {};
  Map<String, Size> _layoutSizes = {};
  Offset _layoutPan = Offset.zero;
  double _layoutZoom = 1;
  bool _snapToGrid = false;
  bool _clickThrough = false;
  bool _launchAtLogin = false;
  bool _setupWizardShown = false;
  List<String> _allowedDomains = const [];
  String _localAuthToken = '';
  double _overlayOpacity = 1;

  @override
  void initState() {
    super.initState();
    BridgeChannel.onHotKeyFired.listen((_) => setState(() {}));
    _loadNativeSettings();
    _startDaemon();
  }

  Future<void> _loadNativeSettings() async {
    try {
      final launchAtLogin = await BridgeChannel.isLaunchAtLoginEnabled();
      final clickThrough = await BridgeChannel.isClickThroughEnabled();
      final opacity = await BridgeChannel.getOpacity();
      if (mounted) {
        setState(() {
          _launchAtLogin = launchAtLogin;
          _clickThrough = clickThrough;
          _overlayOpacity = opacity;
        });
      }
      if (Platform.isMacOS) {
        final complete = await BridgeChannel.isOnboardingComplete();
        if (!complete && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showFirstRunWizard();
          });
        }
      }
    } catch (_) {
      // Desktop method channels are unavailable on non-macOS test targets.
    }
  }

  Future<void> _showFirstRunWizard() async {
    if (_setupWizardShown || !Platform.isMacOS || !mounted) return;
    _setupWizardShown = true;
    var page = 0;
    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final pageBody = switch (page) {
            0 => const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('A local bridge for your open apps',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Text(
                      'Brigade Bridge runs on this computer and routes work between the windows and tabs you choose. It does not require provider API keys.'),
                  SizedBox(height: 16),
                  _SetupBullet('Read-only by default'),
                  _SetupBullet('Sensitive actions require approval'),
                  _SetupBullet('No cookie, password, or API-key extraction'),
                  _SetupBullet('Emergency Stop is always available'),
                ],
              ),
            _ => const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Connect Chrome tabs',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Text('To connect a browser-based agent session:'),
                  SizedBox(height: 12),
                  _SetupBullet('Open chrome://extensions'),
                  _SetupBullet('Enable Developer mode'),
                  _SetupBullet(
                      'Choose Load unpacked and select the shipped Chrome Connector folder'),
                  _SetupBullet(
                      'During development, this folder is named chrome-extension/'),
                  _SetupBullet(
                      'Open Extension options and paste the local pairing token from Settings'),
                  _SetupBullet(
                      'Use the extension popup to connect only the current tab'),
                  _SetupBullet('Keep the connected tab open while it works'),
                  SizedBox(height: 12),
                  Text(
                      'The connector communicates only with the local daemon on port 7432.'),
                ],
              ),
          };

          return AlertDialog(
            title: Row(children: [
              const Icon(Icons.hub, color: Color(0xff8da5ff)),
              const SizedBox(width: 8),
              const Text('Brigade Bridge setup'),
              const Spacer(),
              Text('${page + 1}/2',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xff8790a2))),
            ]),
            content: SizedBox(width: 500, child: pageBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Set up later'),
              ),
              if (page > 0)
                TextButton(
                  onPressed: () => setDialogState(() => page--),
                  child: const Text('Back'),
                ),
              FilledButton(
                onPressed: () {
                  if (page < 1) {
                    setDialogState(() => page++);
                  } else {
                    Navigator.pop(dialogContext, true);
                  }
                },
                child: Text(page < 1 ? 'Continue' : 'Finish'),
              ),
            ],
          );
        },
      ),
    );
    if (completed == true) {
      try {
        await BridgeChannel.setOnboardingComplete(true);
      } catch (_) {}
    }
  }

  Future<void> _startDaemon() async {
    try {
      final result = await Daemon.start();
      _daemonSend = result.send;
      result.events.listen((event) async {
        if (!mounted) return;
        if (event is LogEntry) {
          setState(() {
            _log.insert(0, event.message);
          });
        } else if (event is NodeRegistered) {
          setState(() {
            if (!_nodes.any((n) => n.id == event.node.id)) {
              _nodes.add(event.node);
            }
          });
        } else if (event is NodeRemoved) {
          setState(() => _nodes.removeWhere((node) => node.id == event.nodeId));
        } else if (event is AdapterHealthEvent) {
          final index = _nodes.indexWhere((node) => node.id == event.nodeId);
          if (index >= 0) {
            setState(() {
              _nodes[index] = _nodes[index].copyWith(health: event.health);
              _log.insert(0, '${_nodes[index].name}: ${event.health}');
            });
          }
        } else if (event is WorkspaceIndexLoaded) {
          setState(() {
            _workspaces
              ..clear()
              ..addAll(event.workspaces
                ..sort((a, b) {
                  if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
                  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                }));
          });
        } else if (event is ProjectIndexLoaded) {
          setState(() {
            _projects
              ..clear()
              ..addAll(event.projects);
            _projectId = event.activeProjectId;
          });
        } else if (event is SecuritySettingsLoaded) {
          setState(() => _allowedDomains = event.allowedDomains);
        } else if (event is LocalAuthReady) {
          setState(() => _localAuthToken = event.token);
        } else if (event is TaskStatusChanged) {
          setState(() {
            _status = event.status;
            final task = event.task;
            if (task != null) {
              _tasks.removeWhere((item) => item.id == task.id);
              _tasks.insert(0, task);
              if (event.result != null) task.result = event.result;
              if (event.error != null) task.error = event.error;
            }
          });
        } else if (event is TaskRetrying) {
          setState(() => _log.insert(0,
              'Retrying task ${event.taskId} (${event.attempt}/${event.maxAttempts})'));
        } else if (event is WorkflowPaused) {
          setState(() {
            _status = TaskStatus.paused;
            _log.insert(
                0, 'Workflow paused: ${event.nodeName} is ${event.health}');
          });
        } else if (event is RecoveryRequired) {
          setState(() {
            _status = TaskStatus.failed;
            _log.insert(0,
                '${event.taskIds.length} interrupted task(s) need review; retry or take over manually');
          });
        } else if (event is ArtifactCreated) {
          setState(() {
            _artifacts
                .removeWhere((artifact) => artifact.taskId == event.taskId);
            _artifacts.insert(0, event);
            _log.insert(0, 'Artifact saved: ${event.path}');
          });
        } else if (event is ApprovalRequired) {
          final matchingProjects =
              _projects.where((project) => project.id == event.projectId);
          final projectName = matchingProjects.isEmpty
              ? event.projectId
              : matchingProjects.first.name;
          final decision = await ApprovalModal.show(
            context,
            task: event.task,
            sourceName: event.sourceName,
            targetName: event.targetName,
            projectName: projectName,
            capability: event.capability,
            preview: event.preview,
          );
          switch (decision) {
            case ApprovalDecision.approveOnce:
              _daemonSend?.send({
                'type': 'APPROVE_TASK',
                'approvalId': event.approvalId,
              });
            case ApprovalDecision.alwaysAllow:
              _daemonSend?.send({
                'type': 'ALLOW_FOR_PROJECT',
                'approvalId': event.approvalId,
                'nodeId': event.task.targetNodeId,
                'capability': event.capability,
                'projectId': event.projectId,
              });
            case ApprovalDecision.deny:
            case ApprovalDecision.denyAll:
            case null:
              _daemonSend?.send({
                'type': 'DENY_TASK',
                'approvalId': event.approvalId,
              });
          }
        } else if (event is WorkspaceLoaded) {
          _workspaceId = event.id;
          _workspaceName = event.name;
          final history = event.graph['taskHistory'];
          if (history is List) {
            _log
              ..clear()
              ..addAll(history.whereType<String>().take(100));
          }
          final rawNodes = event.graph['nodes'];
          final rawEdges = event.graph['edges'];
          if (rawNodes is List) {
            _nodes
              ..clear()
              ..addAll(rawNodes.whereType<Map>().map((raw) => BridgeNode(
                    id: raw['id'] as String,
                    name: raw['name'] as String? ?? raw['id'] as String,
                    kind: NodeKind.values.firstWhere(
                      (kind) =>
                          kind.name == (raw['kind'] as String? ?? 'agent'),
                      orElse: () => NodeKind.agent,
                    ),
                    detail: raw['detail'] as String? ?? '',
                    tabId: raw['tabId'] as int?,
                    url: raw['url'] as String?,
                    processId: raw['processId'] as int?,
                    windowId: raw['windowId'] as String?,
                    adapterId: raw['adapterId'] as String?,
                    adapterVersion: raw['adapterVersion'] as String?,
                    capabilities: raw['capabilities'] is List
                        ? (raw['capabilities'] as List)
                            .whereType<String>()
                            .toList()
                        : const [],
                    health: raw['health'] as String? ?? 'unknown',
                    permissionState:
                        raw['permissionState'] as String? ?? 'unknown',
                  )));
          }
          final rawClosedNodes = event.graph['closedNodes'];
          if (rawClosedNodes is List) {
            _closedNodes
              ..clear()
              ..addAll(rawClosedNodes.whereType<Map>().map((raw) => BridgeNode(
                    id: raw['id'] as String,
                    name: raw['name'] as String? ?? raw['id'] as String,
                    kind: NodeKind.values.firstWhere(
                        (kind) =>
                            kind.name == (raw['kind'] as String? ?? 'agent'),
                        orElse: () => NodeKind.agent),
                    detail: raw['detail'] as String? ?? '',
                    tabId: raw['tabId'] as int?,
                    url: raw['url'] as String?,
                    processId: raw['processId'] as int?,
                    windowId: raw['windowId'] as String?,
                    adapterId: raw['adapterId'] as String?,
                    adapterVersion: raw['adapterVersion'] as String?,
                    capabilities: raw['capabilities'] is List
                        ? (raw['capabilities'] as List)
                            .whereType<String>()
                            .toList()
                        : const [],
                    health: raw['health'] as String? ?? 'unknown',
                    permissionState:
                        raw['permissionState'] as String? ?? 'unknown',
                  )));
          } else {
            _closedNodes.clear();
          }
          if (rawEdges is List) {
            _edges
              ..clear()
              ..addAll(rawEdges.whereType<Map>().map((raw) => NodeEdge(
                    raw['from'] as String,
                    raw['to'] as String,
                  )));
          }
          final rawWorkflow = event.graph['lastWorkflow'];
          _lastWorkflowPayload = rawWorkflow is Map
              ? Map<String, dynamic>.from(rawWorkflow)
              : null;
          _log.insert(0, 'Workspace restored: $_workspaceName');
          final rawLayout = event.graph['layout'];
          if (rawLayout is Map) {
            final rawSizes = rawLayout['sizes'];
            if (rawSizes is Map) {
              _layoutSizes = {
                for (final entry in rawSizes.entries)
                  entry.key as String: Size(
                      ((entry.value as Map)['width'] as num).toDouble(),
                      ((entry.value as Map)['height'] as num).toDouble())
              };
            }
            final rawPositions = rawLayout['positions'];
            if (rawPositions is Map) {
              _layoutPositions = {
                for (final entry in rawPositions.entries)
                  entry.key as String: Offset(
                    ((entry.value as Map)['x'] as num).toDouble(),
                    ((entry.value as Map)['y'] as num).toDouble(),
                  ),
              };
            }
            _layoutPan = Offset(
              (rawLayout['panX'] as num?)?.toDouble() ?? 0,
              (rawLayout['panY'] as num?)?.toDouble() ?? 0,
            );
            _layoutZoom = (rawLayout['zoom'] as num?)?.toDouble() ?? 1;
            _snapToGrid = rawLayout['snapToGrid'] == true;
          }
          setState(() {});
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _log.insert(0, 'Daemon startup error: $e');
        });
      }
    }
  }

  void _saveWorkspace() {
    _daemonSend?.send({
      'type': 'SAVE_WORKSPACE',
      'id': _workspaceId,
      'name': _workspaceName,
      'graph': {
        'nodes': _nodes.map(_nodeJson).toList(),
        'edges':
            _edges.map((edge) => {'from': edge.from, 'to': edge.to}).toList(),
        'layout': {
          'positions': {
            for (final entry in _layoutPositions.entries)
              entry.key: {'x': entry.value.dx, 'y': entry.value.dy},
          },
          'sizes': {
            for (final entry in _layoutSizes.entries)
              entry.key: {
                'width': entry.value.width,
                'height': entry.value.height
              }
          },
          'panX': _layoutPan.dx,
          'panY': _layoutPan.dy,
          'zoom': _layoutZoom,
          'snapToGrid': _snapToGrid,
        },
        'taskHistory': _log.take(100).toList(),
        if (_lastWorkflowPayload != null) 'lastWorkflow': _lastWorkflowPayload,
        'closedNodes': _closedNodes.map(_nodeJson).toList(),
      },
    });
  }

  Map<String, dynamic> _nodeJson(BridgeNode node) => {
        'id': node.id,
        'name': node.name,
        'kind': node.kind.name,
        'detail': node.detail,
        'capabilities': node.capabilities,
        'taskDomains': node.taskDomains,
        'tabId': node.tabId,
        'url': node.url,
        'processId': node.processId,
        'windowId': node.windowId,
        'adapterId': node.adapterId,
        'adapterVersion': node.adapterVersion,
        'health': node.health,
        'permissionState': node.permissionState,
      };

  void _dispatchTask(String text,
      {String? sourceId,
      String? targetId,
      List<BridgeAttachment> attachments = const [],
      List<String> contextNodeIds = const []}) {
    setState(() => _log.insert(0, 'Task dispatched: $text'));
    final payload = <String, dynamic>{
      'type': 'RUN_WORKFLOW',
      'taskText': text,
      'projectId': _projectId,
      'workflowId': 'workflow-${DateTime.now().microsecondsSinceEpoch}',
      if (sourceId != null) 'sourceNodeId': sourceId,
      if (targetId != null) 'targetNodeId': targetId,
      if (attachments.isNotEmpty)
        'attachments':
            attachments.map((attachment) => attachment.toJson()).toList(),
      if (contextNodeIds.isNotEmpty) 'contextNodeIds': contextNodeIds,
      'nodes': _nodes.map(_nodeJson).toList(),
      'edges': _edges.map((e) => {'from': e.from, 'to': e.to}).toList(),
    };
    _lastWorkflowPayload = payload;
    _saveWorkspace();
    _daemonSend?.send(payload);
  }

  Future<List<BridgeAttachment>?> _chooseAttachments() async {
    List<String>? paths;
    try {
      paths = await BridgeChannel.chooseFiles();
    } catch (_) {
      return const [];
    }
    if (paths == null || paths.isEmpty) return const [];
    const maxFileBytes = 8 * 1024 * 1024;
    const maxTotalBytes = 20 * 1024 * 1024;
    var totalBytes = 0;
    final attachments = <BridgeAttachment>[];
    for (final path in paths) {
      final file = File(path);
      try {
        if (!await file.exists()) continue;
        final size = await file.length();
        if (size > maxFileBytes || totalBytes + size > maxTotalBytes) {
          _log.insert(0, 'Attachment skipped: size limit exceeded');
          continue;
        }
        final digest = await sha256.bind(file.openRead()).first;
        totalBytes += size;
        attachments.add(BridgeAttachment(
          path: path,
          name: p.basename(path),
          sizeBytes: size,
          mimeType: _attachmentMimeType(path),
          contentHash: digest.toString(),
        ));
      } catch (error) {
        _log.insert(0, 'Attachment skipped: $error');
      }
    }
    return attachments;
  }

  String _attachmentMimeType(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.txt':
      case '.md':
      case '.dart':
      case '.js':
      case '.ts':
      case '.json':
      case '.yaml':
      case '.yml':
        return 'text/plain';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  void _retryWorkflow() {
    final payload = _lastWorkflowPayload;
    if (payload == null) {
      setState(
          () => _log.insert(0, 'No previous workflow is available to retry'));
      return;
    }
    setState(() {
      _status = TaskStatus.working;
      _log.insert(0, 'Retrying workflow');
    });
    final retryPayload = Map<String, dynamic>.from(payload)
      ..['resumeCompleted'] = true;
    _lastWorkflowPayload = retryPayload;
    _saveWorkspace();
    _daemonSend?.send(retryPayload);
  }

  void _cancelWorkflow() {
    _daemonSend?.send({'type': 'CANCEL_WORKFLOW'});
    setState(() {
      _status = TaskStatus.cancelled;
      _log.insert(0, 'Workflow cancelled');
    });
  }

  Map<String, dynamic> _workflowPayload(String text) {
    return <String, dynamic>{
      'type': 'RUN_WORKFLOW',
      'taskText': text,
      'projectId': _projectId,
      'workflowId': 'workflow-${DateTime.now().microsecondsSinceEpoch}',
      'nodes': _nodes.map(_nodeJson).toList(),
      'edges': _edges.map((e) => {'from': e.from, 'to': e.to}).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return OverlayShell(
      nodes: _nodes,
      edges: _edges,
      tasks: _tasks,
      logEntries: _log,
      status: _status,
      logTail: _log.isNotEmpty ? _log.first : 'Bridge daemon starting…',
      initialPositions: _layoutPositions,
      initialSizes: _layoutSizes,
      initialPan: _layoutPan,
      initialZoom: _layoutZoom,
      workspaces: _workspaces,
      projects: _projects,
      activeProjectId: _projectId,
      closedNodes: _closedNodes,
      snapToGrid: _snapToGrid,
      onSnapToGridChanged: (value) {
        setState(() => _snapToGrid = value);
        _saveWorkspace();
      },
      clickThrough: _clickThrough,
      onClickThroughChanged: (value) async {
        try {
          await BridgeChannel.setClickThrough(value);
          if (mounted) setState(() => _clickThrough = value);
        } catch (error) {
          if (mounted)
            setState(
                () => _log.insert(0, 'Click-through setting failed: $error'));
        }
      },
      launchAtLogin: _launchAtLogin,
      onLaunchAtLoginChanged: (value) async {
        try {
          await BridgeChannel.setLaunchAtLogin(value);
          if (mounted) setState(() => _launchAtLogin = value);
        } catch (error) {
          if (mounted)
            setState(
                () => _log.insert(0, 'Launch-at-login setting failed: $error'));
        }
      },
      opacity: _overlayOpacity,
      onOpacityChanged: (value) async {
        try {
          await BridgeChannel.setOpacity(value);
          if (mounted) setState(() => _overlayOpacity = value);
        } catch (error) {
          if (mounted)
            setState(() => _log.insert(0, 'Opacity setting failed: $error'));
        }
      },
      artifacts: _artifacts,
      onOpenArtifact: (path) async {
        final opened = await BridgeChannel.openFile(path);
        if (!opened && mounted) {
          setState(() => _log.insert(0, 'Could not open artifact: $path'));
        }
      },
      onRetry: _retryWorkflow,
      onCancel: _cancelWorkflow,
      allowedDomains: _allowedDomains,
      onAllowedDomainsChanged: (domains) {
        setState(() => _allowedDomains = domains);
        _daemonSend?.send({
          'type': 'SET_ALLOWED_DOMAINS',
          'domains': domains,
        });
      },
      localAuthToken: _localAuthToken,
      onCopyLocalAuthToken: () async {
        if (_localAuthToken.isEmpty) return;
        await Clipboard.setData(ClipboardData(text: _localAuthToken));
        if (mounted) {
          setState(() => _log.insert(0, 'Local pairing token copied'));
        }
      },
      onConnectOpenCode: (serverUrl, sessionId) {
        _daemonSend?.send({
          'type': 'CONNECT_OPENCODE',
          'serverUrl': serverUrl,
          'sessionId': sessionId,
        });
      },
      onDisconnectOpenCode: (nodeId) => _daemonSend?.send({
        'type': 'DISCONNECT_OPENCODE',
        'nodeId': nodeId,
      }),
      onSelectWorkspace: (id) =>
          _daemonSend?.send({'type': 'LOAD_WORKSPACE', 'id': id}),
      onSelectProject: (id) {
        setState(() => _projectId = id);
        _daemonSend?.send({'type': 'SET_ACTIVE_PROJECT', 'id': id});
      },
      onCreateProject: (name) {
        final id = 'project-${DateTime.now().microsecondsSinceEpoch}';
        setState(() {
          _projects.add(ProjectContext(id: id, name: name));
          _projectId = id;
        });
        _daemonSend?.send({'type': 'CREATE_PROJECT', 'id': id, 'name': name});
      },
      onCreateWorkspace: () {
        final id = 'workspace-${DateTime.now().millisecondsSinceEpoch}';
        setState(() {
          _workspaceId = id;
          _workspaceName = 'Untitled workspace';
          _nodes.clear();
          _closedNodes.clear();
          _edges.clear();
          _layoutPositions = {};
          _layoutSizes = {};
          _layoutPan = Offset.zero;
          _layoutZoom = 1;
          _snapToGrid = false;
          _lastWorkflowPayload = null;
        });
        _daemonSend?.send(
            {'type': 'CREATE_WORKSPACE', 'id': id, 'name': _workspaceName});
        _saveWorkspace();
      },
      onRenameWorkspace: (id, name) {
        if (id == _workspaceId) setState(() => _workspaceName = name);
        _daemonSend?.send({'type': 'RENAME_WORKSPACE', 'id': id, 'name': name});
      },
      onDeleteWorkspace: (id) {
        _daemonSend?.send({'type': 'DELETE_WORKSPACE', 'id': id});
        if (id == _workspaceId) {
          setState(() {
            _workspaceId = 'workspace-default';
            _workspaceName = 'Untitled workspace';
            _nodes.clear();
            _closedNodes.clear();
            _edges.clear();
            _layoutPositions = {};
            _layoutSizes = {};
            _layoutPan = Offset.zero;
            _layoutZoom = 1;
            _snapToGrid = false;
            _lastWorkflowPayload = null;
          });
        }
      },
      onDuplicateWorkspace: (sourceId, name) {
        final id = 'workspace-${DateTime.now().millisecondsSinceEpoch}';
        _daemonSend?.send({
          'type': 'DUPLICATE_WORKSPACE',
          'sourceId': sourceId,
          'id': id,
          'name': name
        });
      },
      onPinWorkspace: (id, pinned) {
        _daemonSend
            ?.send({'type': 'PIN_WORKSPACE', 'id': id, 'pinned': pinned});
      },
      onNodeRemoved: (id) {
        final removed = _nodes.where((node) => node.id == id).toList();
        setState(() {
          _nodes.removeWhere((node) => node.id == id);
          _closedNodes.addAll(removed.where((node) =>
              !_closedNodes.any((existing) => existing.id == node.id)));
          _edges.removeWhere((edge) => edge.from == id || edge.to == id);
          _layoutPositions.remove(id);
          _log.insert(0, 'Node closed');
        });
        _saveWorkspace();
      },
      onNodeReopened: (id) {
        final matches = _closedNodes.where((node) => node.id == id).toList();
        if (matches.isEmpty) return;
        setState(() {
          _closedNodes.removeWhere((node) => node.id == id);
          if (!_nodes.any((node) => node.id == id)) _nodes.add(matches.first);
          _log.insert(0, 'Node reopened: ${matches.first.name}');
        });
        _saveWorkspace();
      },
      onRun: () {
        if (_nodes.isEmpty) {
          setState(() => _log.insert(0, 'No nodes available to run'));
          return;
        }
        setState(() {
          _status = TaskStatus.working;
          _log.insert(0, 'Workflow dispatched');
        });
        final payload =
            _workflowPayload(_log.isNotEmpty ? _log.first : 'Run workflow');
        _lastWorkflowPayload = payload;
        _saveWorkspace();
        _daemonSend?.send(payload);
      },
      onStop: () {
        _daemonSend?.send({'type': 'STOP_ALL'});
        setState(() {
          _status = TaskStatus.stopped;
          _log.insert(0, 'Emergency stop');
        });
      },
      onAddEdge: (f, t) {
        if (f == t ||
            !_nodes.any((node) => node.id == f) ||
            !_nodes.any((node) => node.id == t) ||
            _edges.any((edge) => edge.from == f && edge.to == t)) return;
        setState(() => _edges.add(NodeEdge(f, t)));
        _saveWorkspace();
      },
      onRemoveEdge: (edge) {
        setState(() => _edges.removeWhere((candidate) =>
            candidate.from == edge.from && candidate.to == edge.to));
        _saveWorkspace();
      },
      onLayoutChanged: (positions, sizes, pan, zoom) {
        _layoutPositions = positions;
        _layoutSizes = sizes;
        _layoutPan = pan;
        _layoutZoom = zoom;
        _saveWorkspace();
      },
      onDispatch: (text) {
        _dispatchTask(text);
      },
      onDispatchDetailed: (text, sourceId, targetId) =>
          _dispatchTask(text, sourceId: sourceId, targetId: targetId),
      onDispatchWithContext:
          (text, sourceId, targetId, attachments, contextNodeIds) =>
              _dispatchTask(text,
                  sourceId: sourceId,
                  targetId: targetId,
                  attachments: attachments,
                  contextNodeIds: contextNodeIds),
      onPickAttachments: _chooseAttachments,
      onApprove: (id) {
        _daemonSend?.send({'type': 'APPROVE_TASK', 'taskId': id});
        setState(() => _log.insert(0, 'Task approved: $id'));
      },
      onDeny: (id) {
        _daemonSend?.send({'type': 'DENY_TASK', 'taskId': id});
        setState(() => _log.insert(0, 'Task denied: $id'));
      },
    );
  }
}
