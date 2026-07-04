import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memento/core/theme/app_theme.dart';
import 'package:memento/features/notes/domain/note_tree_node.dart';
import 'package:memento/features/notes/presentation/note_tree.dart';

void main() {
  const List<NoteTreeNode> nodes = [
    NoteTreeNode(
      id: 'folder',
      title: 'Архив',
      type: NoteTreeNodeType.folder,
      children: [NoteTreeNode(id: 'folder/note', title: 'Заметка')],
    ),
    NoteTreeNode(id: 'root-note', title: 'О проекте'),
  ];

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: SizedBox(height: 400, child: child)),
    );
  }

  testWidgets('folder children are hidden until expanded', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(const NoteTree(nodes: nodes)));

    expect(find.text('Заметка'), findsNothing);

    await tester.tap(find.text('Архив'));
    await tester.pumpAndSettle();

    expect(find.text('Заметка'), findsOneWidget);
  });

  testWidgets('tapping a note calls onNoteSelected', (
    WidgetTester tester,
  ) async {
    NoteTreeNode? selected;
    await tester.pumpWidget(
      wrap(NoteTree(nodes: nodes, onNoteSelected: (node) => selected = node)),
    );

    await tester.tap(find.text('О проекте'));
    await tester.pump();

    expect(selected?.id, 'root-note');
  });

  testWidgets('tapping a folder does not call onNoteSelected', (
    WidgetTester tester,
  ) async {
    var called = false;
    await tester.pumpWidget(
      wrap(NoteTree(nodes: nodes, onNoteSelected: (_) => called = true)),
    );

    await tester.tap(find.text('Архив'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
  });
}
