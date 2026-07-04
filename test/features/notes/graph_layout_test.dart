import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/notes/domain/graph_layout.dart';
import 'package:memento/features/notes/domain/note_graph.dart';

void main() {
  const Size canvasSize = Size(400, 300);

  const NoteGraph graph = NoteGraph(
    nodes: [
      GraphNode(id: 'a', title: 'A'),
      GraphNode(id: 'b', title: 'B'),
      GraphNode(id: 'c', title: 'C'),
    ],
    edges: [GraphEdge(fromId: 'a', toId: 'b')],
  );

  test('returns a position for every node', () {
    final Map<String, Offset> positions = layoutGraph(
      graph,
      canvasSize,
      random: Random(1),
    );

    expect(positions.keys.toSet(), {'a', 'b', 'c'});
  });

  test('keeps every position within the canvas bounds', () {
    final Map<String, Offset> positions = layoutGraph(
      graph,
      canvasSize,
      random: Random(1),
    );

    for (final Offset position in positions.values) {
      expect(position.dx, inInclusiveRange(0, canvasSize.width));
      expect(position.dy, inInclusiveRange(0, canvasSize.height));
    }
  });

  test('is deterministic for the same seed', () {
    final Map<String, Offset> first = layoutGraph(
      graph,
      canvasSize,
      random: Random(3),
    );
    final Map<String, Offset> second = layoutGraph(
      graph,
      canvasSize,
      random: Random(3),
    );

    expect(first, second);
  });

  test('places a single node without dividing by zero', () {
    const NoteGraph single = NoteGraph(
      nodes: [GraphNode(id: 'only', title: 'Only')],
      edges: [],
    );

    final Map<String, Offset> positions = layoutGraph(
      single,
      canvasSize,
      random: Random(1),
    );

    expect(positions.keys, ['only']);
  });

  test('returns an empty map for an empty graph', () {
    final Map<String, Offset> positions = layoutGraph(
      const NoteGraph(nodes: [], edges: []),
      canvasSize,
    );

    expect(positions, isEmpty);
  });
}
