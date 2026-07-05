import 'block.dart';

final RegExp _headingPattern = RegExp(r'^(#{1,3})\s+(.*)$');
final RegExp _checkboxPattern = RegExp(r'^\s*[-*+]\s+\[([ xX])\]\s+(.*)$');
final RegExp _bulletPattern = RegExp(r'^\s*[-*+]\s+(.*)$');
final RegExp _numberedPattern = RegExp(r'^\s*\d+\.\s+(.*)$');
final RegExp _quotePattern = RegExp(r'^>\s?(.*)$');
final RegExp _dividerPattern = RegExp(r'^(-{3,}|\*{3,}|_{3,})$');
final RegExp _imagePattern = RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)$');
final RegExp _tableCellPattern = RegExp(r'^:?-+:?$');

const List<BlockType> _headingLevels = [
  BlockType.heading1,
  BlockType.heading2,
  BlockType.heading3,
];

/// Parses [markdown] into a block-based document, one [Block] per
/// paragraph/heading/list item/quote/code block/divider/table/image.
/// Never returns an empty list — a fresh, empty document parses to a
/// single empty paragraph block, so the editor always has somewhere to
/// place the cursor.
///
/// Tables are only recognized with a leading `|` on every row (the
/// GitHub-flavored-Markdown allowance to omit outer pipes isn't
/// supported) — a deliberate simplification, since this only needs to
/// round-trip [serializeBlocks]' own output plus reasonably
/// conventional hand-written Markdown.
List<Block> parseBlocks(String markdown) {
  final List<String> lines = markdown.split('\n');
  final List<Block> blocks = [];
  int counter = 0;
  String nextId() => 'b${counter++}';

  final List<String> paragraphBuffer = [];
  void flushParagraph() {
    if (paragraphBuffer.isEmpty) return;
    blocks.add(
      Block(
        id: nextId(),
        type: BlockType.paragraph,
        text: paragraphBuffer.join('\n'),
      ),
    );
    paragraphBuffer.clear();
  }

  int i = 0;
  while (i < lines.length) {
    final String line = lines[i];
    final String trimmed = line.trim();

    if (trimmed.startsWith('```')) {
      flushParagraph();
      final List<String> codeLines = [];
      i++;
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        codeLines.add(lines[i]);
        i++;
      }
      if (i < lines.length) i++; // consume the closing fence, if present
      blocks.add(
        Block(
          id: nextId(),
          type: BlockType.codeBlock,
          text: codeLines.join('\n'),
        ),
      );
      continue;
    }

    if (trimmed.startsWith('|') &&
        i + 1 < lines.length &&
        _isTableSeparator(lines[i + 1])) {
      flushParagraph();
      final List<List<String>> rows = [_parseTableRow(lines[i])];
      i += 2;
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        rows.add(_parseTableRow(lines[i]));
        i++;
      }
      blocks.add(Block(id: nextId(), type: BlockType.table, tableRows: rows));
      continue;
    }

    final RegExpMatch? image = _imagePattern.firstMatch(trimmed);
    if (image != null) {
      flushParagraph();
      blocks.add(
        Block(
          id: nextId(),
          type: BlockType.drawing,
          attachmentPath: image.group(2),
        ),
      );
      i++;
      continue;
    }

    if (_dividerPattern.hasMatch(trimmed)) {
      flushParagraph();
      blocks.add(Block(id: nextId(), type: BlockType.divider));
      i++;
      continue;
    }

    final RegExpMatch? heading = _headingPattern.firstMatch(line);
    if (heading != null) {
      flushParagraph();
      blocks.add(
        Block(
          id: nextId(),
          type: _headingLevels[heading.group(1)!.length - 1],
          text: heading.group(2)!,
        ),
      );
      i++;
      continue;
    }

    final RegExpMatch? checkbox = _checkboxPattern.firstMatch(line);
    if (checkbox != null) {
      flushParagraph();
      blocks.add(
        Block(
          id: nextId(),
          type: BlockType.checkboxItem,
          checked: checkbox.group(1)!.toLowerCase() == 'x',
          text: checkbox.group(2)!,
        ),
      );
      i++;
      continue;
    }

    final RegExpMatch? bullet = _bulletPattern.firstMatch(line);
    if (bullet != null) {
      flushParagraph();
      blocks.add(
        Block(
          id: nextId(),
          type: BlockType.bulletListItem,
          text: bullet.group(1)!,
        ),
      );
      i++;
      continue;
    }

    final RegExpMatch? numbered = _numberedPattern.firstMatch(line);
    if (numbered != null) {
      flushParagraph();
      blocks.add(
        Block(
          id: nextId(),
          type: BlockType.numberedListItem,
          text: numbered.group(1)!,
        ),
      );
      i++;
      continue;
    }

    final RegExpMatch? quote = _quotePattern.firstMatch(line);
    if (quote != null) {
      flushParagraph();
      blocks.add(
        Block(id: nextId(), type: BlockType.quote, text: quote.group(1)!),
      );
      i++;
      continue;
    }

    if (trimmed.isEmpty) {
      flushParagraph();
      i++;
      continue;
    }

    paragraphBuffer.add(line);
    i++;
  }
  flushParagraph();

  if (blocks.isEmpty) {
    blocks.add(const Block(id: 'b0', type: BlockType.paragraph));
  }
  return blocks;
}

bool _isTableSeparator(String line) {
  final List<String> cells = line
      .trim()
      .split('|')
      .map((cell) => cell.trim())
      .where((cell) => cell.isNotEmpty)
      .toList();
  return cells.isNotEmpty && cells.every(_tableCellPattern.hasMatch);
}

List<String> _parseTableRow(String line) {
  String trimmed = line.trim();
  if (trimmed.startsWith('|')) trimmed = trimmed.substring(1);
  if (trimmed.endsWith('|')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed.split('|').map((cell) => cell.trim()).toList();
}
