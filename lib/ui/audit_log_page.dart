import 'package:flutter/material.dart';
import '../daemon/database.dart';

class AuditLogPage extends StatelessWidget {
  const AuditLogPage({super.key, required this.entries});
  final List<AuditLogData> entries;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff10131a),
      appBar: AppBar(
        title: const Text('Audit Log', style: TextStyle(fontSize: 15)),
        backgroundColor: const Color(0xff141820),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        itemBuilder: (_, i) {
          final e = entries[i];
          final ts = DateTime.fromMillisecondsSinceEpoch(e.ts);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 8, height: 8, margin: const EdgeInsets.only(top: 4, right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: e.decision == 'approved' || e.decision == 'auto'
                      ? const Color(0xff56d19a) : const Color(0xffff6b6b),
                ),
              ),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${e.capability} on ${e.nodeId}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text('${e.decision}  ·  task ${e.taskId}',
                    style: const TextStyle(fontSize: 10, color: Color(0xff7d8798))),
                Text('${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')}:${ts.second.toString().padLeft(2,'0')}',
                    style: const TextStyle(fontSize: 9, color: Color(0xff4a5568))),
              ])),
            ]),
          );
        },
      ),
    );
  }
}
