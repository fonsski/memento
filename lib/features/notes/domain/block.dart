import 'package:flutter/foundation.dart';

/// What a [Block] renders as and how its text (if any) behaves.
enum BlockType {
  paragraph,
  heading1,
  heading2,
  heading3,
  bulletListItem,
  numberedListItem,
  checkboxItem,
  quote,
  codeBlock,
  divider,
  table,
  drawing,
}

/// Block types whose [Block.text] is user-edited prose (as opposed to
/// [BlockType.divider], [BlockType.table] and [BlockType.drawing], which
/// carry their content in other fields).
const Set<BlockType> textBlockTypes = {
  BlockType.paragraph,
  BlockType.heading1,
  BlockType.heading2,
  BlockType.heading3,
  BlockType.bulletListItem,
  BlockType.numberedListItem,
  BlockType.checkboxItem,
  BlockType.quote,
  BlockType.codeBlock,
};

/// One row of a note's block-based document. [id] is a stable identity
/// used for widget keys and focus tracking — it survives edits to the
/// same block (unlike its index, which shifts as blocks are added or
/// removed above it).
@immutable
class Block {
  const Block({
    required this.id,
    required this.type,
    this.text = '',
    this.checked = false,
    this.tableRows = const [],
    this.attachmentPath,
  });

  final String id;
  final BlockType type;

  /// Prose content for [textBlockTypes]; unused otherwise.
  final String text;

  /// Only meaningful for [BlockType.checkboxItem].
  final bool checked;

  /// Only meaningful for [BlockType.table]: each inner list is one row
  /// (first row is the header), each entry one cell's text.
  final List<List<String>> tableRows;

  /// Vault-relative path to the image; only meaningful for
  /// [BlockType.drawing].
  final String? attachmentPath;

  Block copyWith({
    BlockType? type,
    String? text,
    bool? checked,
    List<List<String>>? tableRows,
    String? attachmentPath,
  }) {
    return Block(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      checked: checked ?? this.checked,
      tableRows: tableRows ?? this.tableRows,
      attachmentPath: attachmentPath ?? this.attachmentPath,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Block &&
      other.id == id &&
      other.type == type &&
      other.text == text &&
      other.checked == checked &&
      _tableRowsEqual(other.tableRows, tableRows) &&
      other.attachmentPath == attachmentPath;

  @override
  int get hashCode => Object.hash(
    id,
    type,
    text,
    checked,
    Object.hashAll(tableRows.map((row) => Object.hashAll(row))),
    attachmentPath,
  );

  static bool _tableRowsEqual(List<List<String>> a, List<List<String>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!listEquals(a[i], b[i])) return false;
    }
    return true;
  }

  @override
  String toString() => 'Block($type, id: $id, text: "$text")';
}
