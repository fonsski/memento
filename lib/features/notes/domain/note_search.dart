import 'note_tree_node.dart';

/// Flattens [tree] into just its notes, in depth-first order, skipping
/// folders themselves (only their contents are included).
List<NoteTreeNode> flattenNotes(List<NoteTreeNode> tree) {
  final List<NoteTreeNode> result = [];
  for (final NoteTreeNode node in tree) {
    if (node.isFolder) {
      result.addAll(flattenNotes(node.children));
    } else {
      result.add(node);
    }
  }
  return result;
}

/// Filters [notes] to those whose title contains [query]
/// (case-insensitive), ranked by how early the match starts. An empty or
/// blank query returns [notes] unchanged.
List<NoteTreeNode> searchNotes(List<NoteTreeNode> notes, String query) {
  final String normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return notes;

  final List<NoteTreeNode> matches = notes
      .where((note) => note.title.toLowerCase().contains(normalized))
      .toList();

  int matchIndex(NoteTreeNode note) =>
      note.title.toLowerCase().indexOf(normalized);
  matches.sort((a, b) => matchIndex(a).compareTo(matchIndex(b)));
  return matches;
}
