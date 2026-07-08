import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/memento_colors.dart';
import '../domain/block.dart';

/// Renders one [Block] according to its type. The text field for
/// text-bearing blocks uses an externally-owned [controller]/[focusNode]
/// (owned by `BlockEditor`, keyed by the block's id) so they survive
/// this widget being rebuilt with a new [block] value.
///
/// Headings/list items/checkboxes/quotes are single-line fields: Enter
/// reliably fires [onSubmitted] on those (via the field's IME "done"
/// action) without needing to intercept/undo a newline insertion.
/// Paragraphs and code blocks are multi-line instead, so Enter inserts a
/// newline within the block — appropriate for prose that wraps and code
/// that has real line breaks, and it sidesteps needing to fight
/// [TextField]'s own default Enter handling to split a block mid-typing.
/// Splitting/merging blocks in the middle of typing is out of scope for
/// this version; blocks are added via the "/" menu on a fresh empty
/// paragraph and removed via [onDelete].
class BlockView extends StatelessWidget {
  const BlockView({
    super.key,
    required this.block,
    this.controller,
    this.focusNode,
    this.listIndex,
    required this.onSubmitted,
    required this.onDelete,
    this.onToggleChecked,
    this.onCellChanged,
    this.onEditDrawing,
    this.onAddRow,
    this.onRemoveRow,
    this.onAddColumn,
    this.onRemoveColumn,
    this.resolveAttachmentPath,
    this.attachmentVersion = 0,
  });

  final Block block;

  /// Required for every [textBlockTypes] block; unused otherwise.
  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// 1-based display number for [BlockType.numberedListItem]; unused
  /// otherwise.
  final int? listIndex;

  /// Fires on Enter for single-line block types (see class docs).
  final VoidCallback onSubmitted;

  final VoidCallback onDelete;

  /// Required for [BlockType.checkboxItem].
  final ValueChanged<bool>? onToggleChecked;

  /// Required for [BlockType.table].
  final void Function(int row, int column, String value)? onCellChanged;

  /// Required for [BlockType.drawing].
  final VoidCallback? onEditDrawing;

  /// Table row/column controls; all required for [BlockType.table].
  final VoidCallback? onAddRow;
  final VoidCallback? onRemoveRow;
  final VoidCallback? onAddColumn;
  final VoidCallback? onRemoveColumn;

  /// Resolves [Block.attachmentPath] (vault-relative) to an absolute
  /// on-disk path; required for [BlockType.drawing] to render.
  final String Function(String relativePath)? resolveAttachmentPath;

  /// Bumped by `BlockEditor` each time this drawing is re-saved, so its
  /// `Image` gets a new widget identity and re-reads the file even
  /// though `attachmentPath` (and thus the plain file path) is
  /// unchanged — otherwise the already-mounted `Image` keeps whatever
  /// it last resolved, since evicting the path from `ImageCache` only
  /// affects images resolved *after* the evict.
  final int attachmentVersion;

  static const Set<BlockType> _singleLineTypes = {
    BlockType.heading1,
    BlockType.heading2,
    BlockType.heading3,
    BlockType.bulletListItem,
    BlockType.numberedListItem,
    BlockType.checkboxItem,
    BlockType.quote,
  };

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case BlockType.divider:
        return _DividerRow(onDelete: onDelete);
      case BlockType.table:
        return _TableBlock(
          block: block,
          onCellChanged: onCellChanged,
          onDelete: onDelete,
          onAddRow: onAddRow,
          onRemoveRow: onRemoveRow,
          onAddColumn: onAddColumn,
          onRemoveColumn: onRemoveColumn,
        );
      case BlockType.drawing:
        return _DrawingBlock(
          block: block,
          onEditDrawing: onEditDrawing,
          onDelete: onDelete,
          resolveAttachmentPath: resolveAttachmentPath,
          attachmentVersion: attachmentVersion,
        );
      default:
        return _buildTextRow(context);
    }
  }

  Widget _buildTextRow(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = theme.colorScheme.onSurface;
    final bool singleLine = _singleLineTypes.contains(block.type);
    final TextStyle style = _styleFor(theme, color);
    final Widget? prefix = _prefixFor(theme, style);

    Widget field = TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: singleLine ? 1 : null,
      onSubmitted: singleLine ? (_) => onSubmitted() : null,
      decoration: const InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        isCollapsed: true,
      ),
      style: style,
      cursorColor: theme.colorScheme.primary,
    );

    if (block.type == BlockType.codeBlock) {
      field = Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.extension<MementoColors>()!.navPanel,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: field,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (prefix != null)
            Padding(padding: const EdgeInsets.only(right: 8), child: prefix),
          Expanded(child: field),
          _DeleteButton(onDelete: onDelete),
        ],
      ),
    );
  }

  TextStyle _styleFor(ThemeData theme, Color color) {
    switch (block.type) {
      case BlockType.heading1:
        return AppEditorTextStyles.heading1(color);
      case BlockType.heading2:
        return AppEditorTextStyles.heading2(color);
      case BlockType.heading3:
        return AppEditorTextStyles.heading3(color);
      case BlockType.codeBlock:
        return AppCodeTextStyle.code(color);
      case BlockType.checkboxItem:
        return AppEditorTextStyles.body(color).copyWith(
          decoration: block.checked ? TextDecoration.lineThrough : null,
          color: block.checked ? color.withValues(alpha: 0.5) : color,
        );
      default:
        return AppEditorTextStyles.body(color);
    }
  }

  Widget? _prefixFor(ThemeData theme, TextStyle style) {
    switch (block.type) {
      case BlockType.bulletListItem:
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('•', style: style),
        );
      case BlockType.numberedListItem:
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('${listIndex ?? 1}.', style: style),
        );
      case BlockType.checkboxItem:
        return Checkbox(
          value: block.checked,
          onChanged: (value) => onToggleChecked?.call(value ?? false),
        );
      case BlockType.quote:
        return Container(
          width: 3,
          margin: const EdgeInsets.only(top: 2),
          constraints: const BoxConstraints(minHeight: 20),
          color: theme.dividerColor,
        );
      default:
        return null;
    }
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete_outline, size: 14),
      tooltip: 'Удалить блок',
      onPressed: onDelete,
      style: const ButtonStyle(
        padding: WidgetStatePropertyAll(EdgeInsets.all(2)),
        minimumSize: WidgetStatePropertyAll(Size(24, 24)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _DividerRow extends StatelessWidget {
  const _DividerRow({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        _DeleteButton(onDelete: onDelete),
      ],
    );
  }
}

class _TableBlock extends StatelessWidget {
  const _TableBlock({
    required this.block,
    required this.onCellChanged,
    required this.onDelete,
    required this.onAddRow,
    required this.onRemoveRow,
    required this.onAddColumn,
    required this.onRemoveColumn,
  });

  final Block block;
  final void Function(int row, int column, String value)? onCellChanged;
  final VoidCallback onDelete;
  final VoidCallback? onAddRow;
  final VoidCallback? onRemoveRow;
  final VoidCallback? onAddColumn;
  final VoidCallback? onRemoveColumn;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TableToolButton(
                icon: Icons.playlist_add,
                tooltip: 'Добавить строку',
                onPressed: onAddRow,
              ),
              _TableToolButton(
                icon: Icons.playlist_remove,
                tooltip: 'Удалить строку',
                onPressed: onRemoveRow,
              ),
              const SizedBox(width: 8),
              _TableToolButton(
                icon: Icons.view_column_outlined,
                tooltip: 'Добавить столбец',
                onPressed: onAddColumn,
              ),
              _TableToolButton(
                icon: Icons.view_column,
                tooltip: 'Удалить столбец',
                onPressed: onRemoveColumn,
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Table(
                  border: TableBorder.all(color: theme.dividerColor),
                  children: [
                    for (int row = 0; row < block.tableRows.length; row++)
                      TableRow(
                        children: [
                          for (
                            int col = 0;
                            col < block.tableRows[row].length;
                            col++
                          )
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: TextField(
                                controller: TextEditingController(
                                  text: block.tableRows[row][col],
                                ),
                                onChanged: (value) =>
                                    onCellChanged?.call(row, col, value),
                                style: AppEditorTextStyles.body(
                                  theme.colorScheme.onSurface,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              _DeleteButton(onDelete: onDelete),
            ],
          ),
        ],
      ),
    );
  }
}

class _TableToolButton extends StatelessWidget {
  const _TableToolButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      style: const ButtonStyle(
        padding: WidgetStatePropertyAll(EdgeInsets.all(4)),
        minimumSize: WidgetStatePropertyAll(Size(28, 28)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _DrawingBlock extends StatelessWidget {
  const _DrawingBlock({
    required this.block,
    required this.onEditDrawing,
    required this.onDelete,
    required this.resolveAttachmentPath,
    required this.attachmentVersion,
  });

  final Block block;
  final VoidCallback? onEditDrawing;
  final VoidCallback onDelete;
  final String Function(String relativePath)? resolveAttachmentPath;
  final int attachmentVersion;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? relativePath = block.attachmentPath;
    // block.attachmentPath is vault-relative (see NoteRepository); it
    // must be resolved to an absolute path before File() can find it —
    // a bare relative path resolves against the process's working
    // directory, not the vault, and would never load.
    final String? path = relativePath == null
        ? null
        : resolveAttachmentPath?.call(relativePath);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onEditDrawing,
              child: Container(
                constraints: const BoxConstraints(minHeight: 120),
                decoration: BoxDecoration(
                  color: theme.extension<MementoColors>()!.navPanel,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(color: theme.dividerColor),
                ),
                alignment: Alignment.center,
                child: path == null
                    ? Text(
                        'Нажмите, чтобы нарисовать',
                        style: theme.textTheme.bodySmall,
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.small),
                        child: Image.file(
                          File(path),
                          // See attachmentVersion's doc comment: without
                          // this, re-saving the same file in place
                          // wouldn't refresh an already-mounted Image.
                          key: ValueKey('$path#$attachmentVersion'),
                          errorBuilder: (context, error, stackTrace) => Text(
                            'Не удалось загрузить рисунок',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          _DeleteButton(onDelete: onDelete),
        ],
      ),
    );
  }
}
