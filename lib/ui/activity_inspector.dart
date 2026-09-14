import 'package:flutter/material.dart';
import '../core/bridge_models.dart';

class ActivityInspector extends StatefulWidget {
  const ActivityInspector({
    super.key,
    required this.logEntries,
    required this.status,
    required this.onDispatch,
  });
  final List<String> logEntries;
  final TaskStatus status;
  final void Function(String text) onDispatch;

  @override
  State<ActivityInspector> createState() => _ActivityInspectorState();
}

class _ActivityInspectorState extends State<ActivityInspector> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _statusLabel(TaskStatus s) {
    switch (s) {
      case TaskStatus.working:
        return 'RUNNING';
      case TaskStatus.waitingForApproval:
        return 'WAITING';
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

  Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.working:
        return const Color(0xff9fb1ff);
      case TaskStatus.waitingForApproval:
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
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Task stream',
              style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          Text(_statusLabel(widget.status),
              style: TextStyle(
                  fontSize: 9,
                  color: _statusColor(widget.status),
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: _controller,
          maxLines: 3,
          style: const TextStyle(fontSize: 12),
          decoration: const InputDecoration(
            filled: true,
            fillColor: Color(0xff151a23),
            hintText: 'Enter task instruction…',
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => widget.onDispatch(_controller.text),
            child: const Text('Dispatch task',
                style: TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(height: 18),
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
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xffa4adbd))),
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
            style:
                TextStyle(fontSize: 10, color: Color(0xff7d8798))),
      ]),
    );
  }
}
