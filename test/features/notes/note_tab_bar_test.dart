import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memento/core/theme/app_theme.dart';
import 'package:memento/features/notes/domain/note_tree_node.dart';
import 'package:memento/features/notes/presentation/note_tab_bar.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    );
  }

  const List<NoteTreeNode> notes = [
    NoteTreeNode(id: 'a', title: 'Первая'),
    NoteTreeNode(id: 'b', title: 'Вторая'),
  ];

  testWidgets('shows nothing when there are no open notes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        NoteTabBar(
          openNotes: const [],
          activeId: null,
          onSelect: (_) {},
          onClose: (_) {},
        ),
      ),
    );

    expect(find.byType(NoteTabBar), findsOneWidget);
    expect(find.text('Первая'), findsNothing);
  });

  testWidgets('renders a tab per open note', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        NoteTabBar(
          openNotes: notes,
          activeId: 'a',
          onSelect: (_) {},
          onClose: (_) {},
        ),
      ),
    );

    expect(find.text('Первая'), findsOneWidget);
    expect(find.text('Вторая'), findsOneWidget);
  });

  testWidgets('tapping a tab calls onSelect with that note', (
    WidgetTester tester,
  ) async {
    NoteTreeNode? selected;
    await tester.pumpWidget(
      wrap(
        NoteTabBar(
          openNotes: notes,
          activeId: 'a',
          onSelect: (note) => selected = note,
          onClose: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Вторая'));

    expect(selected?.id, 'b');
  });

  testWidgets('tapping a tab close button calls onClose with that note', (
    WidgetTester tester,
  ) async {
    NoteTreeNode? closed;
    await tester.pumpWidget(
      wrap(
        NoteTabBar(
          openNotes: notes,
          activeId: 'a',
          onSelect: (_) {},
          onClose: (note) => closed = note,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.close).first);

    expect(closed?.id, 'a');
  });
}
