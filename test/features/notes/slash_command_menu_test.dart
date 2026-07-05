import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memento/core/theme/app_theme.dart';
import 'package:memento/features/notes/domain/slash_command.dart';
import 'package:memento/features/notes/presentation/slash_command_menu.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    );
  }

  const List<SlashCommand> commands = [
    SlashCommand(id: 'heading2', label: 'Заголовок 2', keywords: ['h2']),
    SlashCommand(id: 'table', label: 'Таблица', keywords: ['table']),
  ];

  testWidgets('shows a placeholder when there are no matches', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SlashCommandMenu(
          commands: const [],
          highlightedIndex: 0,
          onSelect: (_) {},
        ),
      ),
    );

    expect(find.text('Ничего не найдено'), findsOneWidget);
  });

  testWidgets('renders one row per matching command', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SlashCommandMenu(
          commands: commands,
          highlightedIndex: 0,
          onSelect: (_) {},
        ),
      ),
    );

    expect(find.text('Заголовок 2'), findsOneWidget);
    expect(find.text('Таблица'), findsOneWidget);
  });

  testWidgets('tapping a row calls onSelect with that command', (
    WidgetTester tester,
  ) async {
    SlashCommand? selected;
    await tester.pumpWidget(
      wrap(
        SlashCommandMenu(
          commands: commands,
          highlightedIndex: 0,
          onSelect: (command) => selected = command,
        ),
      ),
    );

    await tester.tap(find.text('Таблица'));

    expect(selected?.id, 'table');
  });

  testWidgets('marks the row at highlightedIndex as selected', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SlashCommandMenu(
          commands: commands,
          highlightedIndex: 1,
          onSelect: (_) {},
        ),
      ),
    );

    final ListTile tableTile = tester.widget(
      find.widgetWithText(ListTile, 'Таблица'),
    );
    final ListTile headingTile = tester.widget(
      find.widgetWithText(ListTile, 'Заголовок 2'),
    );
    expect(tableTile.selected, isTrue);
    expect(headingTile.selected, isFalse);
  });
}
