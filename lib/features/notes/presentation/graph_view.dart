import 'package:flutter/material.dart';

import '../../../core/theme/memento_colors.dart';
import '../domain/graph_layout.dart';
import '../domain/note_graph.dart';

/// Interactive canvas for the knowledge graph: nodes settle in from the
/// center, sized by how many connections they have; hovering a node
/// highlights its edges and dims the rest; tapping a node opens it.
class GraphView extends StatefulWidget {
  const GraphView({super.key, required this.graph, required this.onNodeTap});

  final NoteGraph graph;
  final ValueChanged<GraphNode> onNodeTap;

  static const double baseNodeRadius = 6;
  static const double radiusPerConnection = 2;
  static const double maxNodeRadius = 22;
  static const Duration settleDuration = Duration(milliseconds: 800);

  @override
  State<GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<GraphView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settleController = AnimationController(
    vsync: this,
    duration: GraphView.settleDuration,
  );
  late final Animation<double> _settle = CurvedAnimation(
    parent: _settleController,
    curve: Curves.easeOut,
  );

  Size? _layoutSize;
  Map<String, Offset>? _targetPositions;
  String? _hoveredId;

  @override
  void initState() {
    super.initState();
    _settleController.forward();
  }

  @override
  void dispose() {
    _settleController.dispose();
    super.dispose();
  }

  double _radiusFor(String nodeId) {
    final int connections = widget.graph.connectionCount(nodeId);
    final double radius =
        GraphView.baseNodeRadius + connections * GraphView.radiusPerConnection;
    return radius.clamp(GraphView.baseNodeRadius, GraphView.maxNodeRadius);
  }

  bool _isConnectedToHovered(String nodeId) {
    final String? hovered = _hoveredId;
    if (hovered == null || hovered == nodeId) return true;
    return widget.graph.edges.any(
      (edge) =>
          (edge.fromId == hovered && edge.toId == nodeId) ||
          (edge.toId == hovered && edge.fromId == nodeId),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.graph.nodes.isEmpty) {
      return Center(
        child: Text(
          'Пока нет связанных заметок',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final Size canvasSize = constraints.biggest;
        if (_layoutSize != canvasSize) {
          _layoutSize = canvasSize;
          _targetPositions = layoutGraph(widget.graph, canvasSize);
        }
        final Map<String, Offset> targets = _targetPositions!;
        final Offset center = Offset(
          canvasSize.width / 2,
          canvasSize.height / 2,
        );
        final ThemeData theme = Theme.of(context);
        final MementoColors colors = theme.extension<MementoColors>()!;

        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 3,
          boundaryMargin: const EdgeInsets.all(200),
          child: AnimatedBuilder(
            animation: _settle,
            builder: (context, _) {
              final Map<String, Offset> current = {
                for (final MapEntry<String, Offset> entry in targets.entries)
                  entry.key: Offset.lerp(center, entry.value, _settle.value)!,
              };

              return SizedBox(
                width: canvasSize.width,
                height: canvasSize.height,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: canvasSize,
                      painter: _GraphEdgePainter(
                        graph: widget.graph,
                        positions: current,
                        edgeColor: theme.dividerColor,
                        highlightColor: colors.selectedBorder,
                        highlightedNodeId: _hoveredId,
                      ),
                    ),
                    for (final GraphNode node in widget.graph.nodes)
                      _buildNode(theme, node, current[node.id]!),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildNode(ThemeData theme, GraphNode node, Offset position) {
    final double radius = _radiusFor(node.id);
    final bool connected = _isConnectedToHovered(node.id);
    final Color fillColor = node.id == _hoveredId
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return Positioned(
      left: position.dx - radius,
      top: position.dy - radius,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredId = node.id),
        onExit: (_) => setState(() => _hoveredId = null),
        child: GestureDetector(
          onTap: () => widget.onNodeTap(node),
          child: Tooltip(
            message: node.title,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: connected ? 1 : 0.3,
              child: Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fillColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GraphEdgePainter extends CustomPainter {
  _GraphEdgePainter({
    required this.graph,
    required this.positions,
    required this.edgeColor,
    required this.highlightColor,
    required this.highlightedNodeId,
  });

  final NoteGraph graph;
  final Map<String, Offset> positions;
  final Color edgeColor;
  final Color highlightColor;
  final String? highlightedNodeId;

  @override
  void paint(Canvas canvas, Size size) {
    for (final GraphEdge edge in graph.edges) {
      final Offset? from = positions[edge.fromId];
      final Offset? to = positions[edge.toId];
      if (from == null || to == null) continue;

      final bool connected =
          highlightedNodeId != null &&
          (edge.fromId == highlightedNodeId || edge.toId == highlightedNodeId);
      final bool dimmed = highlightedNodeId != null && !connected;

      final Paint paint = Paint()
        ..color = (connected ? highlightColor : edgeColor).withValues(
          alpha: dimmed ? 0.15 : (connected ? 1 : 0.6),
        )
        ..strokeWidth = connected ? 2 : 1;
      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GraphEdgePainter oldDelegate) {
    return oldDelegate.positions != positions ||
        oldDelegate.highlightedNodeId != highlightedNodeId;
  }
}
