import 'dart:isolate';
import 'package:flutter/material.dart';
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

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  final List<BridgeNode> _nodes = [];
  final List<NodeEdge> _edges = [];
  final List<BridgeTask> _tasks = [];
  final List<String> _log = [];
  TaskStatus _status = TaskStatus.created;
  SendPort? _daemonSend;

  @override
  void initState() {
    super.initState();
    BridgeChannel.onHotKeyFired.listen((_) => setState(() {}));
    _startDaemon();
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
        } else if (event is TaskStatusChanged) {
          setState(() {
            _status = event.status;
          });
        } else if (event is ApprovalRequired) {
          final decision = await ApprovalModal.show(
            context,
            task: event.task,
            sourceName: event.sourceName,
            targetName: event.targetName,
          );
          switch (decision) {
            case ApprovalDecision.approveOnce:
            case ApprovalDecision.alwaysAllow:
              _daemonSend?.send({'type': 'APPROVE_TASK', 'taskId': event.task.id});
            case ApprovalDecision.deny:
            case ApprovalDecision.denyAll:
            case null:
              _daemonSend?.send({'type': 'DENY_TASK', 'taskId': event.task.id});
          }
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

  @override
  Widget build(BuildContext context) {
    return OverlayShell(
      nodes: _nodes,
      edges: _edges,
      tasks: _tasks,
      logEntries: _log,
      status: _status,
      logTail: _log.isNotEmpty ? _log.first : 'Bridge daemon starting…',
      onRun: () {
        if (_nodes.isEmpty) {
          setState(() => _log.insert(0, 'No nodes available to run'));
          return;
        }
        setState(() {
          _status = TaskStatus.working;
          _log.insert(0, 'Workflow dispatched');
        });
        _daemonSend?.send({
          'type': 'RUN_WORKFLOW',
          'taskText': _log.isNotEmpty ? _log.first : 'Run workflow',
          'nodes': _nodes.map((n) => {
            'id': n.id,
            'name': n.name,
            'kind': n.kind.name,
            'detail': n.detail,
            'tabId': n.tabId,
            'url': n.url,
          }).toList(),
          'edges': _edges.map((e) => {'from': e.from, 'to': e.to}).toList(),
        });
      },
      onStop: () {
        _daemonSend?.send({'type': 'STOP_ALL'});
        setState(() {
          _status = TaskStatus.stopped;
          _log.insert(0, 'Emergency stop');
        });
      },
      onAddEdge: (f, t) => setState(() => _edges.add(NodeEdge(f, t))),
      onDispatch: (text) {
        setState(() => _log.insert(0, 'Task dispatched: $text'));
        _daemonSend?.send({
          'type': 'RUN_WORKFLOW',
          'taskText': text,
          'nodes': _nodes.map((n) => {
            'id': n.id,
            'name': n.name,
            'kind': n.kind.name,
            'detail': n.detail,
            'tabId': n.tabId,
            'url': n.url,
          }).toList(),
          'edges': _edges.map((e) => {'from': e.from, 'to': e.to}).toList(),
        });
      },
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
