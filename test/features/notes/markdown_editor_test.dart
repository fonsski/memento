import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memento/core/theme/app_theme.dart';
import 'package:memento/features/notes/presentation/markdown_editor.dart';

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

  testWidgets('constrains the editor to the book-width column', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(MarkdownEditor(initialContent: '', onChanged: (_) {})),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedBox &&
            widget.constraints.maxWidth == MarkdownEditor.maxWidth,
      ),
      findsOneWidget,
    );
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
}
