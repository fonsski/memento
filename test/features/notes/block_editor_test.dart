import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memento/core/theme/app_theme.dart';
import 'package:memento/features/notes/presentation/block_editor.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    );
  }

  testWidgets('parses initial content into blocks and renders them', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        BlockEditor(
          initialContent: '# Заголовок\n\nАбзац текста',
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Заголовок'), findsOneWidget);
    expect(find.text('Абзац текста'), findsOneWidget);
  });

  testWidgets('Enter on a single-line block creates a new paragraph below', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(BlockEditor(initialContent: '# Заголовок', onChanged: (_) {})),
    );

    expect(find.byType(TextField), findsNWidgets(1));

    await tester.enterText(find.byType(TextField).first, 'Заголовок');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets(
    'a newline typed into a paragraph splits it into two paragraphs',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(BlockEditor(initialContent: 'Привет мир', onChanged: (_) {})),
      );

      expect(find.byType(TextField), findsNWidgets(1));

      await tester.enterText(find.byType(TextField).first, 'Привет\n мир');
      await tester.pump();

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Привет'), findsOneWidget);
      expect(find.text(' мир'), findsOneWidget);
    },
  );

  testWidgets('the delete button removes a block', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(BlockEditor(initialContent: '---\n\nАбзац', onChanged: (_) {})),
    );

    expect(find.byType(Divider), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pump();

    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('toggling a checkbox reports the change through onChanged', (
    WidgetTester tester,
  ) async {
    String? latest;
    await tester.pumpWidget(
      wrap(
        BlockEditor(
          initialContent: '- [ ] Дело',
          onChanged: (value) => latest = value,
        ),
      ),
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(latest, contains('- [x] Дело'));
  });

  testWidgets('editing a table cell reports the change through onChanged', (
    WidgetTester tester,
  ) async {
    String? latest;
    await tester.pumpWidget(
      wrap(
        BlockEditor(
          initialContent: '| A | B |\n| --- | --- |\n| 1 | 2 |',
          onChanged: (value) => latest = value,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(2), 'изменено');
    await tester.pump();

    expect(latest, contains('изменено'));
  });

  testWidgets('the add-row button grows the table by one row', (
    WidgetTester tester,
  ) async {
    String? latest;
    await tester.pumpWidget(
      wrap(
        BlockEditor(
          initialContent: '| A | B |\n| --- | --- |\n| 1 | 2 |',
          onChanged: (value) => latest = value,
        ),
      ),
    );

    expect(find.byType(TextField), findsNWidgets(5));

    await tester.tap(find.byTooltip('Добавить строку'));
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(7));
    expect(latest, contains('| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |'));
  });

  testWidgets('the add-column button grows every row by one cell', (
    WidgetTester tester,
  ) async {
    String? latest;
    await tester.pumpWidget(
      wrap(
        BlockEditor(
          initialContent: '| A | B |\n| --- | --- |\n| 1 | 2 |',
          onChanged: (value) => latest = value,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Добавить столбец'));
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(7));
    expect(latest, contains('| A | B |  |\n| --- | --- | --- |\n| 1 | 2 |  |'));
  });

  testWidgets('typing "/" on an empty paragraph opens the slash menu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(BlockEditor(initialContent: '', onChanged: (_) {})),
    );

    await tester.enterText(find.byType(TextField).first, '/');
    await tester.pump();

    expect(find.text('Заголовок 1'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Таблица'),
      find.byType(ListView).last,
      const Offset(0, -40),
    );
    expect(find.text('Таблица'), findsOneWidget);
  });

  testWidgets('choosing "heading1" transforms the block into a heading', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(BlockEditor(initialContent: '', onChanged: (_) {})),
    );

    await tester.enterText(find.byType(TextField).first, '/h1');
    await tester.pump();
    await tester.tap(find.text('Заголовок 1'));
    await tester.pump();

    final TextField field = tester.widget(find.byType(TextField).first);
    expect(field.maxLines, 1);
    expect(field.controller?.text, isEmpty);
  });

  testWidgets('choosing "table" transforms the block into a table', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(BlockEditor(initialContent: '', onChanged: (_) {})),
    );

    await tester.enterText(find.byType(TextField).first, '/table');
    await tester.pump();
    await tester.tap(find.text('Таблица'));
    await tester.pump();

    expect(find.byType(Table), findsOneWidget);
  });

  testWidgets('choosing "divider" transforms the block into a divider', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(BlockEditor(initialContent: '', onChanged: (_) {})),
    );

    await tester.enterText(find.byType(TextField).first, '/divider');
    await tester.pump();
    await tester.tap(find.text('Разделитель'));
    await tester.pump();

    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets(
    'choosing "drawing" calls onRequestDrawing and stores the returned path',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          BlockEditor(
            initialContent: '',
            onChanged: (_) {},
            onRequestDrawing: (existingPath) async => 'attachments/test.png',
            resolveAttachmentPath: (relative) => '/vault/$relative',
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).first, '/canvas');
      await tester.pump();
      await tester.tap(find.text('Холст для рисования'));
      await tester.pumpAndSettle();

      expect(find.text('Нажмите, чтобы нарисовать'), findsNothing);
    },
  );

  testWidgets(
    'reopening an existing drawing block passes its current attachment path',
    (WidgetTester tester) async {
      String? receivedExistingPath = 'not called';
      await tester.pumpWidget(
        wrap(
          BlockEditor(
            initialContent: '![Рисунок](attachments/existing.png)',
            onChanged: (_) {},
            onRequestDrawing: (existingPath) async {
              receivedExistingPath = existingPath;
              return existingPath;
            },
            resolveAttachmentPath: (relative) => '/vault/$relative',
          ),
        ),
      );

      await tester.tap(
        find.ancestor(
          of: find.byType(ClipRRect),
          matching: find.byType(GestureDetector),
        ),
      );
      await tester.pumpAndSettle();

      expect(receivedExistingPath, 'attachments/existing.png');
    },
  );
}
