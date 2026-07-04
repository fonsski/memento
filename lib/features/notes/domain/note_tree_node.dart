import 'package:flutter/foundation.dart';

/// Whether a [NoteTreeNode] is a container for other nodes or a leaf note.
enum NoteTreeNodeType { folder, note }

/// A single row in the notes tree: either a folder (which may hold more
/// nodes) or a note (always a leaf).
@immutable
class NoteTreeNode {
  const NoteTreeNode({
    required this.id,
    required this.title,
    this.type = NoteTreeNodeType.note,
    this.children = const [],
  });

  final String id;
  final String title;
  final NoteTreeNodeType type;
  final List<NoteTreeNode> children;

  bool get isFolder => type == NoteTreeNodeType.folder;
}
