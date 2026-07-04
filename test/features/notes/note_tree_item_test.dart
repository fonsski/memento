import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memento/core/theme/app_theme.dart';
import 'package:memento/features/notes/domain/note_tree_node.dart';
import 'package:memento/features/notes/presentation/note_tree_context_menu.dart';
import 'package:memento/features/notes/presentation/note_tree_item.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    );
  }

  testWidgets('shows folder icon and chevron for a folder node', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        NoteTreeItem(
          node: const NoteTreeNode(
            id: 'a',
            title: 'Архив',
            type: NoteTreeNodeType.folder,
          ),
          depth: 0,
          expanded: false,
          selected: false,
          onTap: () {},
          onAction: (_) {},
        ),
      ),
    );

    expect(find.text('Архив'), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('shows note icon and no chevron for a leaf node', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        NoteTreeItem(
          node: const NoteTreeNode(id: 'b', title: 'Заметка'),
          depth: 0,
          expanded: false,
          selected: false,
          onTap: () {},
          onAction: (_) {},
        ),
      ),
    );

    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('calls onTap when tapped', (WidgetTester tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        NoteTreeItem(
          node: const NoteTreeNode(id: 'c', title: 'Заметка'),
          depth: 0,
          expanded: false,
          selected: false,
          onTap: () => tapped = true,
          onAction: (_) {},
        ),
      ),
    );

    await tester.tap(find.byType(NoteTreeItem));
    expect(tapped, isTrue);
  });

  testWidgets(
    'right-click on a folder offers new note/folder, rename, delete',
    (WidgetTester tester) async {
      NoteTreeAction? chosen;
      await tester.pumpWidget(
        wrap(
          NoteTreeItem(
            node: const NoteTreeNode(
              id: 'a',
              title: 'Архив',
              type: NoteTreeNodeType.folder,
            ),
            depth: 0,
            expanded: false,
            selected: false,
            onTap: () {},
            onAction: (action) => chosen = action,
          ),
        ),
      );

      await tester.tap(find.byType(NoteTreeItem), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(find.text('Новая заметка'), findsOneWidget);
      expect(find.text('Новая папка'), findsOneWidget);
      expect(find.text('Переименовать'), findsOneWidget);
      expect(find.text('Удалить'), findsOneWidget);

      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();

      expect(chosen, NoteTreeAction.delete);
    },
  );

  testWidgets('right-click on a note only offers rename and delete', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        NoteTreeItem(
          node: const NoteTreeNode(id: 'b', title: 'Заметка'),
          depth: 0,
          expanded: false,
          selected: false,
          onTap: () {},
          onAction: (_) {},
        ),
      ),
    );

    await tester.tap(find.byType(NoteTreeItem), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    expect(find.text('Новая заметка'), findsNothing);
    expect(find.text('Новая папка'), findsNothing);
    expect(find.text('Переименовать'), findsOneWidget);
    expect(find.text('Удалить'), findsOneWidget);
  });
}
