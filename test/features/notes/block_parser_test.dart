import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/notes/domain/block.dart';
import 'package:memento/features/notes/domain/block_parser.dart';

void main() {
  test('empty text parses to a single empty paragraph', () {
    final List<Block> blocks = parseBlocks('');

    expect(blocks, hasLength(1));
    expect(blocks.single.type, BlockType.paragraph);
    expect(blocks.single.text, isEmpty);
  });

  test('parses a plain paragraph', () {
    final List<Block> blocks = parseBlocks('Просто текст');

    expect(blocks, hasLength(1));
    expect(blocks.single.type, BlockType.paragraph);
    expect(blocks.single.text, 'Просто текст');
  });

  test('joins consecutive lines into one paragraph', () {
    final List<Block> blocks = parseBlocks('Строка 1\nСтрока 2');

    expect(blocks, hasLength(1));
    expect(blocks.single.text, 'Строка 1\nСтрока 2');
  });

  test('a blank line separates two paragraphs', () {
    final List<Block> blocks = parseBlocks('Первый\n\nВторой');

    expect(blocks.map((b) => b.text), ['Первый', 'Второй']);
  });

  test('parses headings 1 through 3', () {
    final List<Block> blocks = parseBlocks('# H1\n## H2\n### H3');

    expect(blocks.map((b) => b.type), [
      BlockType.heading1,
      BlockType.heading2,
      BlockType.heading3,
    ]);
    expect(blocks.map((b) => b.text), ['H1', 'H2', 'H3']);
  });

  test('four hashes are not treated as a heading', () {
    final List<Block> blocks = parseBlocks('#### Not a heading');

    expect(blocks.single.type, BlockType.paragraph);
  });

  test('parses a bullet list item', () {
    final Block block = parseBlocks('- Пункт').single;

    expect(block.type, BlockType.bulletListItem);
    expect(block.text, 'Пункт');
  });

  test('parses a numbered list item', () {
    final Block block = parseBlocks('1. Пункт').single;

    expect(block.type, BlockType.numberedListItem);
    expect(block.text, 'Пункт');
  });

  test('parses an unchecked checkbox item', () {
    final Block block = parseBlocks('- [ ] Дело').single;

    expect(block.type, BlockType.checkboxItem);
    expect(block.checked, isFalse);
    expect(block.text, 'Дело');
  });

  test('parses a checked checkbox item', () {
    final Block block = parseBlocks('- [x] Готово').single;

    expect(block.type, BlockType.checkboxItem);
    expect(block.checked, isTrue);
  });

  test('a checkbox item is not also parsed as a plain bullet', () {
    final List<Block> blocks = parseBlocks('- [ ] Дело');

    expect(blocks, hasLength(1));
  });

  test('parses a quote', () {
    final Block block = parseBlocks('> Цитата').single;

    expect(block.type, BlockType.quote);
    expect(block.text, 'Цитата');
  });

  test('parses a divider', () {
    expect(parseBlocks('---').single.type, BlockType.divider);
    expect(parseBlocks('***').single.type, BlockType.divider);
  });

  test('parses a fenced code block', () {
    final Block block = parseBlocks('```\nlet x = 1;\n```').single;

    expect(block.type, BlockType.codeBlock);
    expect(block.text, 'let x = 1;');
  });

  test('parses an unclosed fenced code block to end of document', () {
    final Block block = parseBlocks('```\nlet x = 1;').single;

    expect(block.type, BlockType.codeBlock);
    expect(block.text, 'let x = 1;');
  });

  test('parses a multi-row table', () {
    final Block block = parseBlocks(
      '| A | B |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |',
    ).single;

    expect(block.type, BlockType.table);
    expect(block.tableRows, [
      ['A', 'B'],
      ['1', '2'],
      ['3', '4'],
    ]);
  });

  test('parses a standalone image reference as a drawing block', () {
    final Block block = parseBlocks('![Рисунок](attachments/a.png)').single;

    expect(block.type, BlockType.drawing);
    expect(block.attachmentPath, 'attachments/a.png');
  });

  test('parses a mixed document into the right block sequence', () {
    const String markdown = '''
# Заголовок

Обычный абзац.

- Пункт 1
- Пункт 2

> Цитата

---
''';

    final List<Block> blocks = parseBlocks(markdown);

    expect(blocks.map((b) => b.type), [
      BlockType.heading1,
      BlockType.paragraph,
      BlockType.bulletListItem,
      BlockType.bulletListItem,
      BlockType.quote,
      BlockType.divider,
    ]);
  });
}
