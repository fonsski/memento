import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memento/core/theme/app_theme.dart';
import 'package:memento/features/notes/domain/note_graph.dart';
import 'package:memento/features/notes/presentation/graph_view.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: SizedBox(width: 400, height: 400, child: child)),
    );
  }

  const NoteGraph graph = NoteGraph(
    nodes: [
      GraphNode(id: 'a', title: 'Первая'),
      GraphNode(id: 'b', title: 'Вторая'),
    ],
    edges: [GraphEdge(fromId: 'a', toId: 'b')],
  );

  testWidgets('shows a message when the graph has no notes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        GraphView(
          graph: const NoteGraph(nodes: [], edges: []),
          onNodeTap: (_) {},
        ),
      ),
    );

    expect(find.text('Пока нет связанных заметок'), findsOneWidget);
  });

  testWidgets('renders a node for each graph node', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(GraphView(graph: graph, onNodeTap: (_) {})));
    await tester.pumpAndSettle();

    expect(find.byType(Tooltip), findsNWidgets(2));
  });

  testWidgets('tapping a node calls onNodeTap with it', (
    WidgetTester tester,
  ) async {
    GraphNode? tapped;
    await tester.pumpWidget(
      wrap(GraphView(graph: graph, onNodeTap: (node) => tapped = node)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Tooltip).first);

    expect(tapped, isNotNull);
  });
}
