import 'package:flutter/material.dart';
import '../core/bridge_models.dart';

class NodeCanvas extends StatelessWidget {
  const NodeCanvas({
    super.key,
    required this.nodes,
    required this.edges,
    this.selectedId,
    this.onNodeTap,
  });
  final List<BridgeNode> nodes;
  final List<NodeEdge> edges;
  final String? selectedId;
  final void Function(String id)? onNodeTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final positions = _gridPositions(nodes.length, w, h);
      return Stack(children: [
        CustomPaint(
          size: Size(w, h),
          painter: _EdgePainter(
              nodes: nodes, edges: edges, positions: positions),
        ),
        ...nodes.asMap().entries.map((e) {
          final pos = positions[e.key];
          final n = e.value;
          final selected = selectedId == n.id;
          return Positioned(
            left: pos.dx,
            top: pos.dy,
            child: GestureDetector(
              onTap: () => onNodeTap?.call(n.id),
              child: _NodeCard(node: n, selected: selected),
            ),
          );
        }),
        const Positioned(
          bottom: 14,
          left: 16,
          child: Text(
            'Click a node, then another to connect',
            style: TextStyle(fontSize: 9, color: Color(0xff657084)),
          ),
        ),
      ]);
    });
  }

  List<Offset> _gridPositions(int count, double w, double h) {
    const cols = 2;
    final colW = w / cols;
    final rows = (count / cols).ceil();
    final rowH = h / (rows + 1);
    return List.generate(count, (i) => Offset(
      colW * (i % cols) + colW * 0.15,
      rowH * (i ~/ cols + 1) - 60,
    ));
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({required this.node, required this.selected});
  final BridgeNode node;
  final bool selected;

  Color get _accent {
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
      case NodeKind.agent:   return '✦';
      case NodeKind.browser: return '◈';
      case NodeKind.terminal: return '⌘';
      case NodeKind.desktop: return '◉';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff1a1f29),
        border: Border.all(
          color:
              selected ? const Color(0xff7f95ff) : const Color(0xff374153),
          width: selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(_glyph, style: TextStyle(color: _accent)),
          const SizedBox(width: 8),
          Text(node.name,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        Text(node.detail,
            style:
                const TextStyle(fontSize: 10, color: Color(0xff798497))),
        const SizedBox(height: 8),
        const Text('● READY · LOCAL SESSION',
            style: TextStyle(fontSize: 8, color: Color(0xff70d3a4))),
      ]),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter(
      {required this.nodes, required this.edges, required this.positions});
  final List<BridgeNode> nodes;
  final List<NodeEdge> edges;
  final List<Offset> positions;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xff7188ff).withValues(alpha: .6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final arrowPaint = Paint()
      ..color = const Color(0xff7188ff).withValues(alpha: .6)
      ..style = PaintingStyle.fill;

    for (final edge in edges) {
      final fromIdx = nodes.indexWhere((n) => n.id == edge.from);
      final toIdx = nodes.indexWhere((n) => n.id == edge.to);
      if (fromIdx < 0 || toIdx < 0) continue;
      final from = positions[fromIdx] + const Offset(90, 30);
      final to = positions[toIdx] + const Offset(0, 30);
      canvas.drawLine(from, to, linePaint);
      // Arrowhead
      final dir = to - from;
      final len = dir.distance;
      if (len < 1) continue;
      final unit = dir / len;
      final tip = to;
      final left =
          tip - unit * 10 + Offset(-unit.dy, unit.dx) * 5;
      final right =
          tip - unit * 10 - Offset(-unit.dy, unit.dx) * 5;
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(left.dx, left.dy)
          ..lineTo(right.dx, right.dy)
          ..close(),
        arrowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.edges != edges || old.nodes != nodes;
}
