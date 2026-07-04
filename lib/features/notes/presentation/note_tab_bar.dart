import 'package:flutter/material.dart';

import '../../../core/theme/memento_colors.dart';
import '../domain/note_tree_node.dart';

/// Underline-style tab bar for the notes currently open in the editor.
/// Purely presentational — which notes are open and which is active is
/// owned by the caller.
class NoteTabBar extends StatelessWidget {
  const NoteTabBar({
    super.key,
    required this.openNotes,
    required this.activeId,
    required this.onSelect,
    required this.onClose,
  });

  final List<NoteTreeNode> openNotes;
  final String? activeId;
  final ValueChanged<NoteTreeNode> onSelect;
  final ValueChanged<NoteTreeNode> onClose;

  static const double height = 36;

  @override
  Widget build(BuildContext context) {
    if (openNotes.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final NoteTreeNode note in openNotes)
            _NoteTab(
              note: note,
              active: note.id == activeId,
              onTap: () => onSelect(note),
              onClose: () => onClose(note),
            ),
        ],
      ),
    );
  }
}

class _NoteTab extends StatelessWidget {
  const _NoteTab({
    required this.note,
    required this.active,
    required this.onTap,
    required this.onClose,
  });

  final NoteTreeNode note;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClose;

  static const double _maxLabelWidth = 160;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MementoColors colors = theme.extension<MementoColors>()!;
    final Color mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? colors.selectedBorder : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxLabelWidth),
                child: Text(
                  note.title,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: active ? null : mutedColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: onClose,
                child: Icon(Icons.close, size: 14, color: mutedColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
