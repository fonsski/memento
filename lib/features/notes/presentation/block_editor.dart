import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/block.dart';
import '../domain/block_parser.dart';
import '../domain/block_serializer.dart';
import '../domain/slash_command.dart';
import 'block_view.dart';
import 'inline_markdown_controller.dart';
import 'slash_command_menu.dart';

const Map<String, BlockType> _blockTypeForCommandId = {
  'heading1': BlockType.heading1,
  'heading2': BlockType.heading2,
  'heading3': BlockType.heading3,
  'bulletList': BlockType.bulletListItem,
  'numberedList': BlockType.numberedListItem,
  'checkbox': BlockType.checkboxItem,
  'quote': BlockType.quote,
  'codeBlock': BlockType.codeBlock,
  'divider': BlockType.divider,
  'table': BlockType.table,
  'drawing': BlockType.drawing,
};

/// A block-based Markdown editor for a single note: parses its content
/// into [Block]s on load, lets each block render/edit itself via
/// [BlockView], and reserializes to Markdown on every change.
///
/// New blocks are added via the "/" menu (typed on a fresh, empty
/// paragraph — see [BlockView] for why splitting/merging blocks
/// mid-typing is out of scope) and removed via each block's own delete
/// button. The document always ends with an empty, ready-to-type
/// paragraph unless it already ends with some other text-bearing block.
class BlockEditor extends StatefulWidget {
  const BlockEditor({
    super.key,
    required this.initialContent,
    required this.onChanged,
    this.onRequestDrawing,
    this.resolveAttachmentPath,
  });

  final String initialContent;
  final ValueChanged<String> onChanged;

  /// Opens the drawing canvas — passed the block's current
  /// `attachmentPath` (`null` for a fresh drawing) so re-editing an
  /// existing one continues from it rather than starting blank — and
  /// returns the vault-relative path of the saved attachment, or `null`
  /// if cancelled. The drawing command is hidden from the "/" menu
  /// entirely while this is `null`.
  final Future<String?> Function(String? existingPath)? onRequestDrawing;

  /// Resolves a `Block.attachmentPath` (vault-relative) to an absolute
  /// on-disk path for display. Required for drawing blocks to render;
  /// see `NoteRepository.resolveAttachmentPath`.
  final String Function(String relativePath)? resolveAttachmentPath;

  static const double maxWidth = 900;
  static const double widthFraction = 0.85;
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 48,
    vertical: 64,
  );

  @override
  State<BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends State<BlockEditor> {
  late List<Block> _blocks = _ensureTrailingParagraph(
    parseBlocks(widget.initialContent),
  );
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  int _idCounter = 0;

  String? _activeSlashBlockId;
  List<SlashCommand> _slashMatches = const [];
  int _slashHighlighted = 0;

  @override
  void initState() {
    super.initState();
    for (final Block block in _blocks) {
      _ensureControllerFor(block);
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    for (final FocusNode node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  String _newBlockId() => 'new-${_idCounter++}';

  void _ensureControllerFor(Block block) {
    if (!textBlockTypes.contains(block.type)) return;
    if (_controllers.containsKey(block.id)) return;
    final InlineMarkdownController controller = InlineMarkdownController(
      text: block.text,
    );
    controller.addListener(() => _handleBlockTextChanged(block.id));
    _controllers[block.id] = controller;
    _focusNodes[block.id] = FocusNode();
  }

  /// The document always needs a text-bearing block at the end to type
  /// into — if it's empty, or ends with a divider/table/drawing (none
  /// of which offer that), append a fresh empty paragraph.
  List<Block> _ensureTrailingParagraph(List<Block> blocks) {
    if (blocks.isEmpty || !textBlockTypes.contains(blocks.last.type)) {
      return [...blocks, Block(id: _newBlockId(), type: BlockType.paragraph)];
    }
    return blocks;
  }

  void _emitChange() => widget.onChanged(serializeBlocks(_blocks));

  void _handleBlockTextChanged(String blockId) {
    final int index = _blocks.indexWhere((b) => b.id == blockId);
    if (index == -1) return;
    final Block block = _blocks[index];
    final String newText = _controllers[blockId]!.text;

    // Paragraphs are the only multi-line block whose Enter key should
    // start a new block rather than a literal line break (code blocks
    // need real newlines for multi-line code). Since an ancestor
    // Focus.onKeyEvent can't reliably out-race EditableText's own Enter
    // handling, we let the newline land in the text field and react to
    // it here instead: split the block at the newline and move the rest
    // into a fresh paragraph below.
    if (block.type == BlockType.paragraph && newText.contains('\n')) {
      final int splitAt = newText.indexOf('\n');
      _splitParagraphBlock(
        blockId,
        before: newText.substring(0, splitAt),
        after: newText.substring(splitAt + 1),
      );
      return;
    }

    setState(() => _blocks[index] = block.copyWith(text: newText));
    _emitChange();

    // Only an empty paragraph turning into "/query" is a trigger — see
    // class docs for why this doesn't support mid-text triggers.
    if (block.type == BlockType.paragraph && newText.startsWith('/')) {
      final List<SlashCommand> matches =
          filterSlashCommands(newText.substring(1))
              .where(
                (c) => c.insertText != null || widget.onRequestDrawing != null,
              )
              .toList();
      setState(() {
        _activeSlashBlockId = blockId;
        _slashMatches = matches;
        _slashHighlighted = 0;
      });
    } else if (_activeSlashBlockId == blockId) {
      setState(() => _activeSlashBlockId = null);
    }
  }

  void _moveSlashHighlight(int delta) {
    if (_slashMatches.isEmpty) return;
    setState(() {
      _slashHighlighted = (_slashHighlighted + delta) % _slashMatches.length;
      if (_slashHighlighted < 0) _slashHighlighted += _slashMatches.length;
    });
  }

  Future<void> _applySlashCommand(String blockId, SlashCommand command) async {
    final BlockType? newType = _blockTypeForCommandId[command.id];
    final int index = _blocks.indexWhere((b) => b.id == blockId);
    if (newType == null || index == -1) return;

    setState(() {
      _activeSlashBlockId = null;
      Block updated = _blocks[index].copyWith(type: newType, text: '');
      if (newType == BlockType.table) {
        updated = updated.copyWith(
          tableRows: [
            ['', ''],
            ['', ''],
          ],
        );
      }
      _blocks[index] = updated;
      _blocks = _ensureTrailingParagraph(_blocks);
      for (final Block block in _blocks) {
        _ensureControllerFor(block);
      }
    });
    _controllers[blockId]?.text = '';
    _emitChange();

    if (newType == BlockType.drawing) {
      await _handleEditDrawing(blockId);
    } else if (textBlockTypes.contains(newType)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes[blockId]?.requestFocus();
      });
    }
  }

  /// Splits a paragraph block in two at the point where the user pressed
  /// Enter: [before] stays in the existing block, [after] moves into a
  /// new paragraph inserted right after it, which then takes focus.
  void _splitParagraphBlock(
    String blockId, {
    required String before,
    required String after,
  }) {
    final int index = _blocks.indexWhere((b) => b.id == blockId);
    if (index == -1) return;
    final String newId = _newBlockId();
    final Block newBlock = Block(
      id: newId,
      type: BlockType.paragraph,
      text: after,
    );

    setState(() {
      _blocks[index] = _blocks[index].copyWith(text: before);
      _controllers[blockId]!.value = TextEditingValue(
        text: before,
        selection: TextSelection.collapsed(offset: before.length),
      );
      _blocks = [..._blocks]..insert(index + 1, newBlock);
      _ensureControllerFor(newBlock);
    });
    _emitChange();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[newId]?.requestFocus();
    });
  }

  void _handleSubmitted(String blockId) {
    final int index = _blocks.indexWhere((b) => b.id == blockId);
    if (index == -1) return;
    final String newId = _newBlockId();
    final Block newBlock = Block(id: newId, type: BlockType.paragraph);

    setState(() {
      _blocks = [..._blocks]..insert(index + 1, newBlock);
      _ensureControllerFor(newBlock);
    });
    _emitChange();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[newId]?.requestFocus();
    });
  }

  void _deleteBlock(String blockId) {
    final int index = _blocks.indexWhere((b) => b.id == blockId);
    if (index == -1) return;

    setState(() {
      _blocks = [..._blocks]..removeAt(index);
      _blocks = _ensureTrailingParagraph(_blocks);
      for (final Block block in _blocks) {
        _ensureControllerFor(block);
      }
      if (_activeSlashBlockId == blockId) _activeSlashBlockId = null;
    });
    _emitChange();
  }

  void _handleToggleChecked(String blockId, bool value) {
    final int index = _blocks.indexWhere((b) => b.id == blockId);
    if (index == -1) return;
    setState(() => _blocks[index] = _blocks[index].copyWith(checked: value));
    _emitChange();
  }

  void _handleCellChanged(String blockId, int row, int column, String value) {
    final int index = _blocks.indexWhere((b) => b.id == blockId);
    if (index == -1) return;
    final List<List<String>> rows = [
      for (final List<String> r in _blocks[index].tableRows) [...r],
    ];
    rows[row][column] = value;
    setState(() => _blocks[index] = _blocks[index].copyWith(tableRows: rows));
    _emitChange();
  }

  void _addTableRow(String blockId) {
    final int index = _blocks.indexWhere((b) => b.id == blockId);
    if (index == -1) return;
    final Block block = _blocks[index];
    final int columnCount = block.tableRows.isEmpty
        ? 2
        : block.tableRows.first.length;
    final List<List<String>> rows = [
      ...block.tableRows,
      List<String>.filled(columnCount, ''),
    ];
    setState(() => _blocks[index] = block.copyWith(tableRows: rows));
    _emitChange();
  }

  void _removeTableRow(String blockId) {
    final int index = _blocks.indexWhere((b) => b.id == blockId);
    if (index == -1) return;
    final Block block = _blocks[index];
    if (block.tableRows.length <= 1) return;
    final List<List<String>> rows = [...block.tableRows]..removeLast();
    setState(() => _blocks[index] = block.copyWith(tableRows: rows));
    _emitChange();
  }

  void _addTableColumn(String blockId) {
    final int index = _blocks.indexWhere((b) => b.id == blockId);
    if (index == -1) return;
    final Block block = _blocks[index];
    final List<List<String>> rows = [
      for (final List<String> row in block.tableRows) [...row, ''],
    ];
    setState(() => _blocks[index] = block.copyWith(tableRows: rows));
    _emitChange();
  }

  void _removeTableColumn(String blockId) {
    final int index = _blocks.indexWhere((b) => b.id == blockId);
    if (index == -1) return;
    final Block block = _blocks[index];
    if (block.tableRows.isEmpty || block.tableRows.first.length <= 1) return;
    final List<List<String>> rows = [
      for (final List<String> row in block.tableRows)
        row.sublist(0, row.length - 1),
    ];
    setState(() => _blocks[index] = block.copyWith(tableRows: rows));
    _emitChange();
  }

  Future<void> _handleEditDrawing(String blockId) async {
    final Future<String?> Function(String?)? request = widget.onRequestDrawing;
    if (request == null) return;

    final int existingIndex = _blocks.indexWhere((b) => b.id == blockId);
    if (existingIndex == -1) return;
    final String? path = await request(_blocks[existingIndex].attachmentPath);
    if (!mounted || path == null) return;

    final int index = _blocks.indexWhere((b) => b.id == blockId);
    if (index == -1) return;
    setState(
      () => _blocks[index] = _blocks[index].copyWith(attachmentPath: path),
    );
    _emitChange();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (_activeSlashBlockId == null || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveSlashHighlight(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSlashHighlight(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_slashMatches.isNotEmpty) {
        unawaited(
          _applySlashCommand(
            _activeSlashBlockId!,
            _slashMatches[_slashHighlighted],
          ),
        );
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => _activeSlashBlockId = null);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double columnWidth =
            (constraints.maxWidth * BlockEditor.widthFraction)
                .clamp(0, BlockEditor.maxWidth)
                .toDouble();

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: columnWidth),
            child: Focus(
              onKeyEvent: _handleKeyEvent,
              child: ListView(
                padding: BlockEditor.padding,
                children: _buildRows(),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildRows() {
    final List<Widget> rows = [];
    int numberedIndex = 0;

    for (final Block block in _blocks) {
      numberedIndex = block.type == BlockType.numberedListItem
          ? numberedIndex + 1
          : 0;

      rows.add(
        BlockView(
          key: ValueKey(block.id),
          block: block,
          controller: _controllers[block.id],
          focusNode: _focusNodes[block.id],
          listIndex: block.type == BlockType.numberedListItem
              ? numberedIndex
              : null,
          onSubmitted: () => _handleSubmitted(block.id),
          onDelete: () => _deleteBlock(block.id),
          onToggleChecked: (value) => _handleToggleChecked(block.id, value),
          onCellChanged: (row, column, value) =>
              _handleCellChanged(block.id, row, column, value),
          onEditDrawing: () => unawaited(_handleEditDrawing(block.id)),
          resolveAttachmentPath: widget.resolveAttachmentPath,
          onAddRow: () => _addTableRow(block.id),
          onRemoveRow: () => _removeTableRow(block.id),
          onAddColumn: () => _addTableColumn(block.id),
          onRemoveColumn: () => _removeTableColumn(block.id),
        ),
      );

      if (_activeSlashBlockId == block.id) {
        rows.add(
          SlashCommandMenu(
            commands: _slashMatches,
            highlightedIndex: _slashHighlighted,
            onSelect: (command) =>
                unawaited(_applySlashCommand(block.id, command)),
          ),
        );
      }
    }
    return rows;
  }
}
