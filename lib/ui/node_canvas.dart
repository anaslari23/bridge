import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/bridge_models.dart';

class NodeCanvas extends StatefulWidget {
  const NodeCanvas({super.key, required this.nodes, required this.edges, this.selectedId, this.onNodeTap, this.onNodeDoubleTap, this.onNodeCapture, this.onNodeRemoved, this.onLayoutChanged, this.initialPositions, this.initialSizes, this.initialPan, this.initialZoom, this.snapToGrid = false});
  final List<BridgeNode> nodes;
  final List<NodeEdge> edges;
  final String? selectedId;
  final ValueChanged<String>? onNodeTap;
  final ValueChanged<String>? onNodeDoubleTap;
  final ValueChanged<String>? onNodeCapture;
  final ValueChanged<String>? onNodeRemoved;
  final void Function(Map<String, Offset> positions, Map<String, Size> sizes, Offset pan, double zoom)? onLayoutChanged;
  final Map<String, Offset>? initialPositions;
  final Map<String, Size>? initialSizes;
  final Offset? initialPan;
  final double? initialZoom;
  final bool snapToGrid;
  @override State<NodeCanvas> createState() => _NodeCanvasState();
}

class _NodeCanvasState extends State<NodeCanvas> with SingleTickerProviderStateMixin {
  final positions = <String, Offset>{};
  final sizes = <String, Size>{};
  final minimized = <String>{};
  final selectedIds = <String>{};
  late final AnimationController _flowController;
  Offset pan = Offset.zero;
  double zoom = 1;
  @override void initState() { super.initState(); if (widget.initialPositions != null) positions.addAll(widget.initialPositions!); if (widget.initialSizes != null) sizes.addAll(widget.initialSizes!); pan = widget.initialPan ?? Offset.zero; zoom = widget.initialZoom ?? 1; _flowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400)); if (widget.edges.isNotEmpty) _flowController.repeat(); }
  @override void didUpdateWidget(covariant NodeCanvas oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.edges.isEmpty && widget.edges.isNotEmpty) _flowController.repeat(); if (oldWidget.edges.isNotEmpty && widget.edges.isEmpty) _flowController.stop(); }
  @override void dispose() { _flowController.dispose(); super.dispose(); }
  void notifyLayout() => widget.onLayoutChanged?.call(Map.unmodifiable(positions), Map.unmodifiable(sizes), pan, zoom);
  Offset basePosition(int index, double width) => positions.putIfAbsent(widget.nodes[index].id, () => Offset(30 + (index % 2) * (width / 2 < 204 ? 204.0 : width / 2), 35 + (index ~/ 2) * 174.0));
  @override Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final width = constraints.maxWidth;
    return ClipRect(child: GestureDetector(onScaleUpdate: (details) { setState(() { if (details.pointerCount > 1) { zoom = (zoom * details.scale).clamp(.65, 1.6); } else { pan += details.focalPointDelta; } }); notifyLayout(); }, child: Stack(children: [
      CustomPaint(size: constraints.biggest, painter: _GridPainter(pan, zoom)),
      AnimatedBuilder(animation: _flowController, builder: (_, __) => CustomPaint(size: constraints.biggest, painter: _EdgePainter(widget.nodes, widget.edges, positions, pan, zoom, _flowController.value))),
      ...widget.nodes.asMap().entries.map((entry) { final node = entry.value; final base = basePosition(entry.key, width); final size = sizes.putIfAbsent(node.id, () => const Size(180, 150)); return Positioned(left: (base.dx + pan.dx) * zoom, top: (base.dy + pan.dy) * zoom, child: GestureDetector(onTap: () { final modifiers = HardwareKeyboard.instance.logicalKeysPressed; if (modifiers.contains(LogicalKeyboardKey.meta) || modifiers.contains(LogicalKeyboardKey.control)) { setState(() { if (!selectedIds.add(node.id)) selectedIds.remove(node.id); }); } else { setState(() { selectedIds..clear()..add(node.id); }); widget.onNodeTap?.call(node.id); } }, onDoubleTap: () => widget.onNodeDoubleTap?.call(node.id), onPanUpdate: (details) { setState(() { final next = base + details.delta / zoom; positions[node.id] = widget.snapToGrid ? Offset((next.dx / 22).round() * 22.0, (next.dy / 22).round() * 22.0) : next; }); notifyLayout(); }, child: Transform.scale(scale: zoom, alignment: Alignment.topLeft, child: _NodeCard(node: node, size: size, selected: widget.selectedId == node.id || selectedIds.contains(node.id), minimized: minimized.contains(node.id), onMinimize: () => setState(() { if (!minimized.add(node.id)) minimized.remove(node.id); }), onResize: (delta) { setState(() => sizes[node.id] = Size((size.width + delta.dx / zoom).clamp(150, 420), (size.height + delta.dy / zoom).clamp(70, 320))); notifyLayout(); }, onRemove: () => widget.onNodeRemoved?.call(node.id), onCapture: node.kind == NodeKind.desktop ? () => widget.onNodeCapture?.call(node.id) : null)))); }),
      const Positioned(bottom: 14, left: 16, child: Text('Drag nodes · Pinch or scroll to zoom · Click nodes to connect', style: TextStyle(fontSize: 9, color: Color(0xff657084)))),
      Positioned(
        right: 16,
        bottom: 12,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xff1b202a),
            borderRadius: const BorderRadius.all(Radius.circular(7)),
            border: Border.all(color: const Color(0xff303847)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            child: Text('${(zoom * 100).round()}%', style: const TextStyle(fontSize: 10, color: Color(0xffa4adbd))),
          ),
        ),
      ),
    ])));
  });
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({required this.node, required this.size, required this.selected, required this.minimized, required this.onMinimize, required this.onResize, required this.onRemove, this.onCapture});
  final BridgeNode node; final Size size; final bool selected; final bool minimized; final VoidCallback onMinimize; final ValueChanged<Offset> onResize; final VoidCallback onRemove; final VoidCallback? onCapture;
  Color get accent => switch (node.kind) { NodeKind.agent => const Color(0xff7188ff), NodeKind.browser => const Color(0xffad81ff), NodeKind.terminal => const Color(0xfff2a65a), NodeKind.file => const Color(0xffe6c76a), NodeKind.desktop => const Color(0xff56d19a) };
  String get glyph => switch (node.kind) { NodeKind.agent => '✦', NodeKind.browser => '◈', NodeKind.terminal => '⌘', NodeKind.file => '▤', NodeKind.desktop => '◉' };
  @override
  Widget build(BuildContext context) => Container(
        width: size.width,
        height: minimized ? null : size.height,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xff1a1f29),
          border: Border.all(color: selected ? const Color(0xff7f95ff) : const Color(0xff374153), width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(glyph, style: TextStyle(color: accent)),
              const SizedBox(width: 8),
              Expanded(child: Text(node.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              if (onCapture != null) IconButton(tooltip: 'Capture window', onPressed: onCapture, padding: EdgeInsets.zero, style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap), constraints: const BoxConstraints.tightFor(width: 22, height: 22), icon: const Icon(Icons.camera_alt, size: 14, color: Color(0xff9aa5b8))),
              IconButton(tooltip: minimized ? 'Expand node' : 'Minimize node', onPressed: onMinimize, padding: EdgeInsets.zero, style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap), constraints: const BoxConstraints.tightFor(width: 22, height: 22), icon: const Icon(Icons.remove, size: 14, color: Color(0xff9aa5b8))),
              IconButton(tooltip: 'Close node', onPressed: onRemove, padding: EdgeInsets.zero, style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap), constraints: const BoxConstraints.tightFor(width: 22, height: 22), icon: const Icon(Icons.close, size: 14, color: Color(0xff9aa5b8))),
            ]),
            if (!minimized) ...[
              const SizedBox(height: 8),
              Text(node.detail, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xff798497))),
              const SizedBox(height: 8),
              Text('● ${node.health.toUpperCase()} · LOCAL SESSION', style: TextStyle(fontSize: 8, color: node.health == 'unavailable' ? const Color(0xffff6b6b) : const Color(0xff70d3a4))),
            ],
            if (!minimized) Align(alignment: Alignment.bottomRight, child: GestureDetector(behavior: HitTestBehavior.opaque, onPanUpdate: (details) => onResize(details.delta), child: const Icon(Icons.open_in_full, size: 12, color: Color(0xff657084)))),
          ],
        ),
      );
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.pan, this.zoom); final Offset pan; final double zoom;
  @override void paint(Canvas canvas, Size size) { final paint = Paint()..color = const Color(0xff27303d); const gap = 22.0; for (var x = (pan.dx % gap) * zoom; x < size.width; x += gap * zoom) { for (var y = (pan.dy % gap) * zoom; y < size.height; y += gap * zoom) { canvas.drawCircle(Offset(x, y), 1, paint); } } }
  @override bool shouldRepaint(_GridPainter old) => old.pan != pan || old.zoom != zoom;
}

class _EdgePainter extends CustomPainter {
  _EdgePainter(this.nodes, this.edges, this.positions, this.pan, this.zoom, this.phase); final List<BridgeNode> nodes; final List<NodeEdge> edges; final Map<String, Offset> positions; final Offset pan; final double zoom; final double phase;
  @override void paint(Canvas canvas, Size size) { final paint = Paint()..color = const Color(0xff7188ff).withValues(alpha: .65)..strokeWidth = 1.5; final flowPaint = Paint()..color = const Color(0xff9fb1ff); for (final edge in edges) { final from = positions[edge.from], to = positions[edge.to]; if (from == null || to == null) continue; final a = (from + pan + const Offset(90, 30)) * zoom; final b = (to + pan + const Offset(0, 30)) * zoom; canvas.drawLine(a, b, paint); canvas.drawCircle(Offset.lerp(a, b, phase)!, 3, flowPaint); } }
  @override bool shouldRepaint(_EdgePainter old) => old.edges != edges || old.positions != positions || old.pan != pan || old.zoom != zoom || old.phase != phase;
}
