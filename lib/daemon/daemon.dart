import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:drift/native.dart';
import 'database.dart';
import 'event_bus.dart';
import 'node_registry.dart';
import 'permission_manager.dart';
import 'task_scheduler.dart';
import 'artifact_store.dart';
import 'workflow_engine.dart';
import 'ws_server.dart';
import 'recovery_manager.dart';

class Daemon {
  static const port = 7432;

  // Call from the main isolate
  static Future<({Stream<dynamic> events, SendPort send})> start() async {
    final fromDaemon = ReceivePort();
    final toMain = fromDaemon.sendPort;
    final supportDir = await getApplicationSupportDirectory();

    await Isolate.spawn(_daemonMain, (toMain, supportDir.path));

    // The daemon sends its SendPort as its first message
    final completer = Completer<SendPort>();
    final sub = fromDaemon.listen((msg) {
      if (msg is SendPort) completer.complete(msg);
    });
    final daemonSend = await completer.future;
    sub.cancel();

    return (events: fromDaemon.asBroadcastStream(), send: daemonSend);
  }

  static Future<void> _daemonMain((SendPort, String) args) async {
    final toMain = args.$1;
    final supportDirPath = args.$2;

    final fromMain = ReceivePort();
    toMain.send(fromMain.sendPort); // hand shake

    final dbPath = p.join(supportDirPath, 'BrigadeBridge', 'brigade.db');
    await Directory(p.dirname(dbPath)).create(recursive: true);
    final db = BridgeDatabase(NativeDatabase(File(dbPath)));

    final bus = EventBus();
    final registry = NodeRegistry(db, bus);
    final pm = PermissionManager(db, bus);
    final scheduler = TaskScheduler(db, bus);
    final artifactDir = Directory(
        p.join(supportDirPath, 'BrigadeBridge', 'artifacts'));
    await artifactDir.create(recursive: true);
    final store = ArtifactStore(artifactDir);
    final engine = WorkflowEngine(
      registry: registry,
      scheduler: scheduler,
      permissionManager: pm,
      artifactStore: store,
      bus: bus,
    );
    final recovery = RecoveryManager(db, bus);
    await recovery.replayIncomplete(engine);

    final server = WsServer(
      port: port, bus: bus, engine: engine,
      registry: registry, pm: pm,
    );
    await server.start();

    // Forward bus events to main isolate
    bus.stream.listen((event) => toMain.send(event));

    // Listen for commands from main isolate
    fromMain.listen((msg) {
      if (msg is Map) {
        final type = msg['type'] as String?;
        if (type == 'STOP_ALL') engine.emergencyStop();
        if (type == 'APPROVE_TASK') pm.approve(msg['taskId'] as String);
        if (type == 'DENY_TASK') pm.deny(msg['taskId'] as String);
        if (type == 'RUN_WORKFLOW') {
          server.runWorkflow({
            'nodes': msg['nodes'] ?? [],
            'edges': msg['edges'] ?? [],
            'taskText': msg['taskText'] ?? '',
          });
        }
      }
    });
  }
}
