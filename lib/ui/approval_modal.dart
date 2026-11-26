import 'package:flutter/material.dart';
import '../core/bridge_models.dart';

class ApprovalModal {
  static Future<ApprovalDecision?> show(
    BuildContext context, {
    required BridgeTask task,
    required String sourceName,
    required String targetName,
    required String projectName,
    String? capability,
    String? preview,
  }) {
    return showDialog<ApprovalDecision>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff1a1f2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(children: [
          Text('⚠', style: TextStyle(fontSize: 18)),
          SizedBox(width: 10),
          Text('Approval required', style: TextStyle(fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$sourceName wants to send text to $targetName',
                style: const TextStyle(fontSize: 13)),
            Text('Project: $projectName',
                style: const TextStyle(fontSize: 11, color: Color(0xff9ca8b9))),
            if (capability != null)
              Text('Capability: $capability',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xff9ca8b9))),
            if (preview != null) ...[
              const SizedBox(height: 8),
              const Text('Proposed file change',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xff10131a),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    preview.length > 4000
                        ? '${preview.substring(0, 4000)}…'
                        : preview,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: Color(0xff9ca8b9)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xff10131a),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                task.instruction.length > 120
                    ? '${task.instruction.substring(0, 120)}…'
                    : task.instruction,
                style: const TextStyle(fontSize: 11, color: Color(0xff9ca8b9)),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ApprovalDecision.denyAll),
            child: const Text('Deny all',
                style: TextStyle(color: Color(0xffff6b6b))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ApprovalDecision.deny),
            child: const Text('Deny'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ApprovalDecision.approveOnce),
            child: const Text('Allow'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ApprovalDecision.alwaysAllow),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff56d19a)),
            child: const Text('Always allow for this project',
                style: TextStyle(color: Color(0xff10131a))),
          ),
        ],
      ),
    );
  }
}

enum ApprovalDecision { approveOnce, alwaysAllow, deny, denyAll }
