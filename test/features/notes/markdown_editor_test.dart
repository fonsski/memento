import 'package:flutter/material.dart';
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
}
