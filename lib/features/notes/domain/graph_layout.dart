import 'dart:math';
import 'dart:ui';

import 'note_graph.dart';

/// Computes a node position for every node in [graph] within
/// [canvasSize], using a Fruchterman-Reingold force-directed layout:
/// every pair of nodes repels, edges pull their endpoints together, and
/// positions cool/settle over [iterations] steps.
///
/// Deterministic for a given [random] seed, so callers (and tests) get a
/// stable layout rather than a new one on every rebuild.
Map<String, Offset> layoutGraph(
  NoteGraph graph,
  Size canvasSize, {
  int iterations = 200,
  Random? random,
}) {
  final Random rng = random ?? Random(7);
  const double margin = 24;

  final Map<String, Offset> positions = {
    for (final GraphNode node in graph.nodes)
      node.id: Offset(
        margin + rng.nextDouble() * (canvasSize.width - 2 * margin),
        margin + rng.nextDouble() * (canvasSize.height - 2 * margin),
      ),
  };

  if (graph.nodes.length <= 1) return positions;

  final double idealDistance = sqrt(
    (canvasSize.width * canvasSize.height) / graph.nodes.length,
  );
  final Offset center = Offset(canvasSize.width / 2, canvasSize.height / 2);

  for (int iteration = 0; iteration < iterations; iteration++) {
    final Map<String, Offset> displacement = {
      for (final GraphNode node in graph.nodes) node.id: Offset.zero,
    };

    for (int i = 0; i < graph.nodes.length; i++) {
      for (int j = i + 1; j < graph.nodes.length; j++) {
        final String idA = graph.nodes[i].id;
        final String idB = graph.nodes[j].id;
        final Offset delta = positions[idA]! - positions[idB]!;
        final double distance = max(delta.distance, 0.01);
        final Offset direction = delta / distance;
        final double force = idealDistance * idealDistance / distance;
        displacement[idA] = displacement[idA]! + direction * force;
        displacement[idB] = displacement[idB]! - direction * force;
      }
    }

    for (final GraphEdge edge in graph.edges) {
      final Offset delta = positions[edge.fromId]! - positions[edge.toId]!;
      final double distance = max(delta.distance, 0.01);
      final Offset direction = delta / distance;
      final double force = (distance * distance) / idealDistance;
      displacement[edge.fromId] =
          displacement[edge.fromId]! - direction * force;
      displacement[edge.toId] = displacement[edge.toId]! + direction * force;
    }

    final double temperature = idealDistance * (1 - iteration / iterations);
    for (final GraphNode node in graph.nodes) {
      final Offset disp = displacement[node.id]!;
      final double distance = max(disp.distance, 0.01);
      final Offset limited = disp / distance * min(distance, temperature);

      Offset next = positions[node.id]! + limited;
      next += (center - next) * 0.01; // gentle pull back to center
      next = Offset(
        next.dx.clamp(margin, canvasSize.width - margin),
        next.dy.clamp(margin, canvasSize.height - margin),
      );
      positions[node.id] = next;
    }
  }

  return positions;
}
