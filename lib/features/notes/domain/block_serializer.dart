import 'block.dart';

const Set<BlockType> _listTypes = {
  BlockType.bulletListItem,
  BlockType.numberedListItem,
  BlockType.checkboxItem,
};

/// Serializes a block document back to Markdown — the inverse of
/// [parseBlocks (block_parser.dart)]. Consecutive list items of the same
/// type are joined by a single newline (a tight list, as hand-written
/// Markdown normally looks); everything else gets a blank line between,
/// matching normal paragraph spacing.
String serializeBlocks(List<Block> blocks) {
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < blocks.length; i++) {
    if (i > 0) {
      final bool tight =
          _listTypes.contains(blocks[i - 1].type) &&
          blocks[i - 1].type == blocks[i].type;
      buffer.write(tight ? '\n' : '\n\n');
    }
    buffer.write(_serializeBlock(blocks[i]));
  }
  return buffer.toString();
}

String _serializeBlock(Block block) {
  switch (block.type) {
    case BlockType.paragraph:
      return block.text;
    case BlockType.heading1:
      return '# ${block.text}';
    case BlockType.heading2:
      return '## ${block.text}';
    case BlockType.heading3:
      return '### ${block.text}';
    case BlockType.bulletListItem:
      return '- ${block.text}';
    case BlockType.numberedListItem:
      // Every item serializes as "1." — Markdown renderers number a list
      // sequentially regardless of the literal numbers used, so this
      // loses nothing semantically and avoids tracking each item's
      // original position.
      return '1. ${block.text}';
    case BlockType.checkboxItem:
      return '- [${block.checked ? 'x' : ' '}] ${block.text}';
    case BlockType.quote:
      return '> ${block.text}';
    case BlockType.codeBlock:
      return '```\n${block.text}\n```';
    case BlockType.divider:
      return '---';
    case BlockType.table:
      return _serializeTable(block.tableRows);
    case BlockType.drawing:
      return '![Рисунок](${block.attachmentPath ?? ''})';
  }
}

String _serializeTable(List<List<String>> rows) {
  if (rows.isEmpty) return '';
  final String header = _serializeRow(rows.first);
  final String separator =
      '| ${List.filled(rows.first.length, '---').join(' | ')} |';
  final Iterable<String> dataRows = rows.skip(1).map(_serializeRow);
  return [header, separator, ...dataRows].join('\n');
}

String _serializeRow(List<String> cells) => '| ${cells.join(' | ')} |';
