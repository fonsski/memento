import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/notes/domain/block.dart';

void main() {
  group('Block equality', () {
    test('two blocks with the same fields are equal', () {
      const Block a = Block(id: '1', type: BlockType.paragraph, text: 'hi');
      const Block b = Block(id: '1', type: BlockType.paragraph, text: 'hi');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differing text makes blocks unequal', () {
      const Block a = Block(id: '1', type: BlockType.paragraph, text: 'hi');
      const Block b = Block(id: '1', type: BlockType.paragraph, text: 'bye');

      expect(a, isNot(b));
    });

    test('differing tableRows content makes blocks unequal', () {
      const Block a = Block(
        id: '1',
        type: BlockType.table,
        tableRows: [
          ['a', 'b'],
        ],
      );
      const Block b = Block(
        id: '1',
        type: BlockType.table,
        tableRows: [
          ['a', 'c'],
        ],
      );

      expect(a, isNot(b));
    });

    test('equal tableRows content (different list instances) are equal', () {
      // Deliberately non-const: the point is that two *distinct* list
      // instances with the same content still compare equal.
      // ignore: prefer_const_constructors
      final Block a = Block(
        id: '1',
        type: BlockType.table,
        tableRows: [
          ['a', 'b'],
        ],
      );
      // ignore: prefer_const_constructors
      final Block b = Block(
        id: '1',
        type: BlockType.table,
        tableRows: [
          ['a', 'b'],
        ],
      );

      expect(a, b);
    });
  });

  group('Block.copyWith', () {
    test('keeps the id and unspecified fields unchanged', () {
      const Block original = Block(
        id: '1',
        type: BlockType.paragraph,
        text: 'old',
      );

      final Block updated = original.copyWith(text: 'new');

      expect(updated.id, '1');
      expect(updated.type, BlockType.paragraph);
      expect(updated.text, 'new');
    });

    test(
      'can change the type (used when a slash command transforms a block)',
      () {
        const Block original = Block(
          id: '1',
          type: BlockType.paragraph,
          text: 'Заголовок',
        );

        final Block updated = original.copyWith(type: BlockType.heading2);

        expect(updated.type, BlockType.heading2);
        expect(updated.text, 'Заголовок');
      },
    );
  });

  test('textBlockTypes excludes divider/table/drawing', () {
    expect(textBlockTypes.contains(BlockType.divider), isFalse);
    expect(textBlockTypes.contains(BlockType.table), isFalse);
    expect(textBlockTypes.contains(BlockType.drawing), isFalse);
    expect(textBlockTypes.contains(BlockType.paragraph), isTrue);
    expect(textBlockTypes.contains(BlockType.checkboxItem), isTrue);
  });
}
