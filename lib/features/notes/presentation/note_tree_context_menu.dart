import 'package:flutter/material.dart';

import '../domain/note_tree_node.dart';

/// Actions offered by a tree row's right-click context menu.
enum NoteTreeAction { newNote, newFolder, rename, delete }

/// Shows the context menu for [node] at [position] (global coordinates,
/// e.g. from a [TapUpDetails.globalPosition]) and returns the chosen
/// action, or `null` if the menu was dismissed without a choice.
Future<NoteTreeAction?> showNoteTreeContextMenu({
  required BuildContext context,
  required Offset position,
  required NoteTreeNode node,
}) {
  final RenderBox overlay =
      Overlay.of(context).context.findRenderObject()! as RenderBox;

  return showMenu<NoteTreeAction>(
    context: context,
    position: RelativeRect.fromRect(
      position & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      if (node.isFolder) ...[
        const PopupMenuItem(
          value: NoteTreeAction.newNote,
          child: Text('Новая заметка'),
        ),
        const PopupMenuItem(
          value: NoteTreeAction.newFolder,
          child: Text('Новая папка'),
        ),
        const PopupMenuDivider(),
      ],
      const PopupMenuItem(
        value: NoteTreeAction.rename,
        child: Text('Переименовать'),
      ),
      const PopupMenuItem(value: NoteTreeAction.delete, child: Text('Удалить')),
    ],
  );
}
