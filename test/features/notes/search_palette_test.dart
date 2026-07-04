import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memento/core/theme/app_theme.dart';
import 'package:memento/features/notes/domain/note_tree_node.dart';
import 'package:memento/features/notes/presentation/search_palette.dart';

void main() {
  const List<NoteTreeNode> notes = [
    NoteTreeNode(id: 'a', title: 'Архив мыслей'),
    NoteTreeNode(id: 'b', title: 'О проекте'),
  ];

  Widget wrap(WidgetBuilder builder) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Builder(builder: builder),
    );
  }

  testWidgets('shows every note when the query is empty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        (context) => ElevatedButton(
          onPressed: () => showSearchPalette(context, notes),
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Архив мыслей'), findsOneWidget);
    expect(find.text('О проекте'), findsOneWidget);
  });

  testWidgets('filters results as the query changes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        (context) => ElevatedButton(
          onPressed: () => showSearchPalette(context, notes),
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'проект');
    await tester.pump();

    expect(find.text('О проекте'), findsOneWidget);
    expect(find.text('Архив мыслей'), findsNothing);
  });

  testWidgets('tapping a result resolves showSearchPalette with it', (
    WidgetTester tester,
  ) async {
    NoteTreeNode? selected;
    await tester.pumpWidget(
      wrap(
        (context) => ElevatedButton(
          onPressed: () async {
            selected = await showSearchPalette(context, notes);
          },
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('О проекте'));
    await tester.pumpAndSettle();

    expect(selected?.id, 'b');
  });

  testWidgets('Escape dismisses without a selection', (
    WidgetTester tester,
  ) async {
    NoteTreeNode? selected = notes.first;
    await tester.pumpWidget(
      wrap(
        (context) => ElevatedButton(
          onPressed: () async {
            selected = await showSearchPalette(context, notes);
          },
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(selected, isNull);
  });

  testWidgets('Enter selects the highlighted result', (
    WidgetTester tester,
  ) async {
    NoteTreeNode? selected;
    await tester.pumpWidget(
      wrap(
        (context) => ElevatedButton(
          onPressed: () async {
            selected = await showSearchPalette(context, notes);
          },
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(selected?.id, 'b');
  });
}
