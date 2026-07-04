import 'package:flutter/material.dart';

import '../../../core/theme/memento_colors.dart';
import '../domain/note_tree_node.dart';
import 'note_tree_context_menu.dart';

/// A single row of the notes tree: indent guide, expand chevron (folders
/// only), folder/note icon, and label. Purely presentational — expand and
/// selection state live in the parent [NoteTree]; right-clicking shows the
/// context menu and reports the chosen action via [onAction].
class NoteTreeItem extends StatelessWidget {
  const NoteTreeItem({
    super.key,
    required this.node,
    required this.depth,
    required this.expanded,
    required this.selected,
    required this.onTap,
    required this.onAction,
  });

  final NoteTreeNode node;
  final int depth;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<NoteTreeAction> onAction;

  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    final NoteTreeAction? action = await showNoteTreeContextMenu(
      context: context,
      position: position,
      node: node,
    );
    if (action != null) {
      onAction(action);
    }
  }

  static const double rowHeight = 36;
  static const double indentPerLevel = 16;
  static const double _basePadding = 12;
  static const Duration _chevronDuration = Duration(milliseconds: 150);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MementoColors colors = theme.extension<MementoColors>()!;
    final Color iconColor = theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        onSecondaryTapUp: (TapUpDetails details) =>
            _showContextMenu(context, details.globalPosition),
        child: Container(
          height: rowHeight,
          padding: EdgeInsets.only(
            left: _basePadding + depth * indentPerLevel,
            right: _basePadding,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.selectedBackground : null,
            border: selected
                ? Border(
                    left: BorderSide(color: colors.selectedBorder, width: 2),
                  )
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                child: node.isFolder
                    ? AnimatedRotation(
                        turns: expanded ? 0.25 : 0,
                        duration: _chevronDuration,
                        curve: Curves.easeInOut,
                        child: Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: iconColor,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 4),
              Icon(
                node.isFolder
                    ? Icons.folder_outlined
                    : Icons.description_outlined,
                size: 16,
                color: iconColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.title,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
