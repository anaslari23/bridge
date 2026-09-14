import 'package:flutter/material.dart';
import '../core/bridge_models.dart';
import 'node_chip.dart';

class CompactHud extends StatelessWidget {
  const CompactHud({
    super.key,
    required this.nodes,
    required this.onExpand,
    required this.onRun,
    required this.onStop,
    required this.logTail,
    required this.status,
  });

  final List<BridgeNode> nodes;
  final VoidCallback onExpand;
  final VoidCallback onRun;
  final VoidCallback onStop;
  final String logTail;
  final TaskStatus status;

  String get _statusLabel {
    switch (status) {
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

  Color get _statusColor {
    switch (status) {
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
      width: 280,
      color: const Color(0xff10131a),
      child: Column(children: [
        // Header
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            color: Color(0xff141820),
            border: Border(bottom: BorderSide(color: Color(0xff2a303d))),
          ),
          child: Row(children: [
            const Text('✦',
                style: TextStyle(color: Color(0xff8da5ff), fontSize: 16)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Brigade Bridge',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(_statusLabel,
                style: TextStyle(
                    fontSize: 9,
                    color: _statusColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2)),
          ]),
        ),
        // Node list
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NODES',
                    style: TextStyle(
                        fontSize: 9,
                        color: Color(0xff737e92),
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...nodes.map((n) => NodeChip(node: n)),
                const Spacer(),
                if (logTail.isNotEmpty)
                  Text('● $logTail',
                      style: const TextStyle(
                          fontSize: 9, color: Color(0xff7d8798)),
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
        // Action bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xff2a303d))),
          ),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onExpand,
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                child:
                    const Text('Expand', style: TextStyle(fontSize: 11)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: onStop,
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                child: const Text('Stop', style: TextStyle(fontSize: 11)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: onRun,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                child: const Text('Run', style: TextStyle(fontSize: 11)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
