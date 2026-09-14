import 'package:flutter/material.dart';
import '../core/bridge_models.dart';

class NodeChip extends StatelessWidget {
  const NodeChip({super.key, required this.node, this.isSelected = false});
  final BridgeNode node;
  final bool isSelected;

  Color get _color {
    switch (node.kind) {
      case NodeKind.agent:
        return const Color(0xff7188ff);
      case NodeKind.browser:
        return const Color(0xffad81ff);
      case NodeKind.terminal:
        return const Color(0xfff2a65a);
      case NodeKind.desktop:
        return const Color(0xff56d19a);
    }
  }

  String get _glyph {
    switch (node.kind) {
      case NodeKind.agent:
        return '✦';
      case NodeKind.browser:
        return '◈';
      case NodeKind.terminal:
        return '⌘';
      case NodeKind.desktop:
        return '◉';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xff1a1f29),
        border: Border.all(
          color: isSelected ? const Color(0xff7f95ff) : const Color(0xff2a303d),
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _color.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(_glyph, style: TextStyle(color: _color, fontSize: 12)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(node.name,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold)),
              Text(node.detail,
                  style: const TextStyle(
                      fontSize: 9, color: Color(0xff7d8798)),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const Icon(Icons.circle, size: 6, color: Color(0xff56d19a)),
      ]),
    );
  }
}
