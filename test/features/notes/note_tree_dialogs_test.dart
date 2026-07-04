import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memento/core/theme/app_theme.dart';
import 'package:memento/features/notes/presentation/note_tree_dialogs.dart';

void main() {
  Widget wrap(WidgetBuilder builder) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Builder(builder: builder),
    );
  }

  testWidgets('promptForTitle returns the trimmed entered text', (
    WidgetTester tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      wrap(
        (context) => ElevatedButton(
          onPressed: () async {
            result = await promptForTitle(context, dialogTitle: 'Заголовок');
          },
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Идея  ');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(result, 'Идея');
  });

  testWidgets('promptForTitle returns null when cancelled', (
    WidgetTester tester,
  ) async {
    String? result = 'unset';
    await tester.pumpWidget(
      wrap(
        (context) => ElevatedButton(
          onPressed: () async {
            result = await promptForTitle(context, dialogTitle: 'Заголовок');
          },
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('promptForTitle returns null for an empty value', (
    WidgetTester tester,
  ) async {
    String? result = 'unset';
    await tester.pumpWidget(
      wrap(
        (context) => ElevatedButton(
          onPressed: () async {
            result = await promptForTitle(context, dialogTitle: 'Заголовок');
          },
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('confirmDelete returns true when confirmed', (
    WidgetTester tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      wrap(
        (context) => ElevatedButton(
          onPressed: () async {
            result = await confirmDelete(context, 'Заметка');
          },
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('confirmDelete returns false when cancelled', (
    WidgetTester tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      wrap(
        (context) => ElevatedButton(
          onPressed: () async {
            result = await confirmDelete(context, 'Заметка');
          },
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
