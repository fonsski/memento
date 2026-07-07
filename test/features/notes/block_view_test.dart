import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memento/core/theme/app_theme.dart';
import 'package:memento/features/notes/domain/block.dart';
import 'package:memento/features/notes/presentation/block_view.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    );
  }

  BlockView build({
    required Block block,
    TextEditingController? controller,
    int? listIndex,
    VoidCallback? onSubmitted,
    VoidCallback? onDelete,
    ValueChanged<bool>? onToggleChecked,
    void Function(int, int, String)? onCellChanged,
    VoidCallback? onEditDrawing,
    VoidCallback? onAddRow,
    VoidCallback? onRemoveRow,
    VoidCallback? onAddColumn,
    VoidCallback? onRemoveColumn,
  }) {
    return BlockView(
      block: block,
      controller: controller,
      listIndex: listIndex,
      onSubmitted: onSubmitted ?? () {},
      onDelete: onDelete ?? () {},
      onToggleChecked: onToggleChecked,
      onCellChanged: onCellChanged,
      onEditDrawing: onEditDrawing,
      onAddRow: onAddRow,
      onRemoveRow: onRemoveRow,
      onAddColumn: onAddColumn,
      onRemoveColumn: onRemoveColumn,
    );
  }

  testWidgets('renders a paragraph as a multi-line field', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        build(
          block: const Block(id: '1', type: BlockType.paragraph, text: 'Текст'),
          controller: TextEditingController(text: 'Текст'),
        ),
      ),
    );

    final TextField field = tester.widget(find.byType(TextField));
    expect(field.maxLines, isNull);
    expect(find.text('Текст'), findsOneWidget);
  });

  testWidgets('renders heading levels with increasing font size', (
    WidgetTester tester,
  ) async {
    for (final (BlockType type, double size) in [
      (BlockType.heading1, 28.0),
      (BlockType.heading2, 24.0),
      (BlockType.heading3, 20.0),
    ]) {
      await tester.pumpWidget(
        wrap(
          build(
            block: Block(id: '1', type: type, text: 'H'),
            controller: TextEditingController(text: 'H'),
          ),
        ),
      );

      final TextField field = tester.widget(find.byType(TextField));
      expect(field.style?.fontSize, size);
      expect(field.maxLines, 1);
    }
  });

  testWidgets('renders a bullet list item with a bullet prefix', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        build(
          block: const Block(
            id: '1',
            type: BlockType.bulletListItem,
            text: 'Пункт',
          ),
          controller: TextEditingController(text: 'Пункт'),
        ),
      ),
    );

    expect(find.text('•'), findsOneWidget);
  });

  testWidgets('renders a numbered list item using listIndex', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        build(
          block: const Block(
            id: '1',
            type: BlockType.numberedListItem,
            text: 'Пункт',
          ),
          controller: TextEditingController(text: 'Пункт'),
          listIndex: 3,
        ),
      ),
    );

    expect(find.text('3.'), findsOneWidget);
  });

  testWidgets('renders a checkbox reflecting checked state and toggles it', (
    WidgetTester tester,
  ) async {
    bool? toggledTo;
    await tester.pumpWidget(
      wrap(
        build(
          block: const Block(
            id: '1',
            type: BlockType.checkboxItem,
            text: 'Дело',
            checked: false,
          ),
          controller: TextEditingController(text: 'Дело'),
          onToggleChecked: (value) => toggledTo = value,
        ),
      ),
    );

    final Checkbox checkbox = tester.widget(find.byType(Checkbox));
    expect(checkbox.value, isFalse);

    await tester.tap(find.byType(Checkbox));
    expect(toggledTo, isTrue);
  });

  testWidgets('renders a divider', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        build(
          block: const Block(id: '1', type: BlockType.divider),
        ),
      ),
    );

    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('code blocks use the monospace font', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        build(
          block: const Block(id: '1', type: BlockType.codeBlock, text: 'x=1'),
          controller: TextEditingController(text: 'x=1'),
        ),
      ),
    );

    final TextField field = tester.widget(find.byType(TextField));
    expect(field.style?.fontFamily, 'JetBrains Mono');
  });

  testWidgets('editing a table cell reports its row and column', (
    WidgetTester tester,
  ) async {
    (int, int, String)? edited;
    await tester.pumpWidget(
      wrap(
        build(
          block: const Block(
            id: '1',
            type: BlockType.table,
            tableRows: [
              ['A', 'B'],
              ['1', '2'],
            ],
          ),
          onCellChanged: (row, col, value) => edited = (row, col, value),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(2), 'изменено');

    expect(edited, (1, 0, 'изменено'));
  });

  testWidgets('table row/column buttons call their respective callbacks', (
    WidgetTester tester,
  ) async {
    var addedRow = false;
    var removedRow = false;
    var addedColumn = false;
    var removedColumn = false;

    await tester.pumpWidget(
      wrap(
        build(
          block: const Block(
            id: '1',
            type: BlockType.table,
            tableRows: [
              ['A', 'B'],
              ['1', '2'],
            ],
          ),
          onAddRow: () => addedRow = true,
          onRemoveRow: () => removedRow = true,
          onAddColumn: () => addedColumn = true,
          onRemoveColumn: () => removedColumn = true,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Добавить строку'));
    await tester.tap(find.byTooltip('Удалить строку'));
    await tester.tap(find.byTooltip('Добавить столбец'));
    await tester.tap(find.byTooltip('Удалить столбец'));

    expect(addedRow, isTrue);
    expect(removedRow, isTrue);
    expect(addedColumn, isTrue);
    expect(removedColumn, isTrue);
  });

  testWidgets(
    'shows a prompt for an empty drawing block and opens the canvas on tap',
    (WidgetTester tester) async {
      var opened = false;
      await tester.pumpWidget(
        wrap(
          build(
            block: const Block(id: '1', type: BlockType.drawing),
            onEditDrawing: () => opened = true,
          ),
        ),
      );

      expect(find.text('Нажмите, чтобы нарисовать'), findsOneWidget);

      await tester.tap(find.text('Нажмите, чтобы нарисовать'));

      expect(opened, isTrue);
    },
  );

  testWidgets('the delete button calls onDelete', (WidgetTester tester) async {
    var deleted = false;
    await tester.pumpWidget(
      wrap(
        build(
          block: const Block(id: '1', type: BlockType.divider),
          onDelete: () => deleted = true,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));

    expect(deleted, isTrue);
  });

  testWidgets('Enter on a single-line block calls onSubmitted', (
    WidgetTester tester,
  ) async {
    var submitted = false;
    await tester.pumpWidget(
      wrap(
        build(
          block: const Block(id: '1', type: BlockType.heading2, text: 'H'),
          controller: TextEditingController(text: 'H'),
          onSubmitted: () => submitted = true,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'H');
    await tester.testTextInput.receiveAction(TextInputAction.done);

    expect(submitted, isTrue);
  });
}
