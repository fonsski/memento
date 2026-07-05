import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memento/core/theme/app_theme.dart';
import 'package:memento/features/notes/presentation/markdown_editor.dart';
import 'package:memento/features/notes/presentation/markdown_syntax_controller.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    );
  }

  testWidgets('shows the initial content', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(MarkdownEditor(initialContent: '# Заголовок', onChanged: (_) {})),
    );

    expect(find.text('# Заголовок'), findsOneWidget);
  });

  testWidgets('calls onChanged as the user types', (WidgetTester tester) async {
    String? latest;
    await tester.pumpWidget(
      wrap(
        MarkdownEditor(
          initialContent: '',
          onChanged: (value) => latest = value,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'новый текст');

    expect(latest, 'новый текст');
  });

  double editorColumnWidth(WidgetTester tester) {
    final ConstrainedBox box = tester
        .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
        .firstWhere((box) => box.constraints.maxWidth.isFinite);
    return box.constraints.maxWidth;
  }

  testWidgets('caps the editor column at maxWidth on a wide window', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(2000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(MarkdownEditor(initialContent: '', onChanged: (_) {})),
    );

    expect(editorColumnWidth(tester), MarkdownEditor.maxWidth);
  });

  testWidgets('uses most of the available width on a narrow window', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(MarkdownEditor(initialContent: '', onChanged: (_) {})),
    );

    expect(editorColumnWidth(tester), lessThan(MarkdownEditor.maxWidth));
    expect(editorColumnWidth(tester), greaterThan(400));
  });

  testWidgets('uses the editor (serif) text style, not the UI font', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(MarkdownEditor(initialContent: 'x', onChanged: (_) {})),
    );

    final TextField field = tester.widget(find.byType(TextField));
    expect(field.style?.fontFamily, 'PT Serif');
  });

  testWidgets('renders syntax highlighting via MarkdownSyntaxController', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(MarkdownEditor(initialContent: '# x', onChanged: (_) {})),
    );

    final TextField field = tester.widget(find.byType(TextField));
    expect(field.controller, isA<MarkdownSyntaxController>());
  });

  testWidgets(
    'has no visible border, even under the app theme default outline',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(MarkdownEditor(initialContent: '', onChanged: (_) {})),
      );

      final TextField field = tester.widget(find.byType(TextField));
      final InputDecoration decoration = field.decoration!;
      // AppTheme sets an explicit enabledBorder/focusedBorder globally;
      // setting only `border: InputBorder.none` here would not suppress
      // those, so this editor's own decoration must null them out too.
      expect(decoration.border, InputBorder.none);
      expect(decoration.enabledBorder, InputBorder.none);
      expect(decoration.focusedBorder, InputBorder.none);
    },
  );

  group('slash command menu', () {
    testWidgets('typing "/" plus a query shows matching commands', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(MarkdownEditor(initialContent: '', onChanged: (_) {})),
      );

      await tester.enterText(find.byType(TextField), '/tab');
      await tester.pump();

      expect(find.text('Таблица'), findsOneWidget);
      expect(find.text('Заголовок 1'), findsNothing);
    });

    testWidgets('shows a "not found" placeholder for an unmatched query', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(MarkdownEditor(initialContent: '', onChanged: (_) {})),
      );

      await tester.enterText(find.byType(TextField), '/zzz');
      await tester.pump();

      expect(find.text('Ничего не найдено'), findsOneWidget);
    });

    testWidgets('tapping a command replaces the trigger with its snippet', (
      WidgetTester tester,
    ) async {
      String? latest;
      await tester.pumpWidget(
        wrap(
          MarkdownEditor(
            initialContent: '',
            onChanged: (value) => latest = value,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '/h2');
      await tester.pump();
      await tester.tap(find.text('Заголовок 2'));
      await tester.pump();

      expect(latest, '## ');
      expect(find.text('Ничего не найдено'), findsNothing);
      expect(find.text('Таблица'), findsNothing);
    });

    testWidgets('Enter applies the highlighted command', (
      WidgetTester tester,
    ) async {
      String? latest;
      await tester.pumpWidget(
        wrap(
          MarkdownEditor(
            initialContent: '',
            onChanged: (value) => latest = value,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '/table');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(latest, contains('| Колонка 1 | Колонка 2 |'));
    });

    testWidgets('Escape closes the menu without changing the text', (
      WidgetTester tester,
    ) async {
      String? latest;
      await tester.pumpWidget(
        wrap(
          MarkdownEditor(
            initialContent: '',
            onChanged: (value) => latest = value,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '/tab');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.text('Таблица'), findsNothing);
      expect(latest, '/tab');
    });

    testWidgets('hides the drawing command when onInsertDrawing is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(MarkdownEditor(initialContent: '', onChanged: (_) {})),
      );

      await tester.enterText(find.byType(TextField), '/рисун');
      await tester.pump();

      expect(find.text('Холст для рисования'), findsNothing);
      expect(find.text('Ничего не найдено'), findsOneWidget);
    });

    testWidgets(
      'shows and applies the drawing command when onInsertDrawing is set',
      (WidgetTester tester) async {
        String? latest;
        await tester.pumpWidget(
          wrap(
            MarkdownEditor(
              initialContent: '',
              onChanged: (value) => latest = value,
              onInsertDrawing: () async => '![Рисунок](attachments/a.png)',
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), '/рисун');
        await tester.pump();
        await tester.tap(find.text('Холст для рисования'));
        await tester.pumpAndSettle();

        expect(latest, '![Рисунок](attachments/a.png)');
      },
    );
  });
}
