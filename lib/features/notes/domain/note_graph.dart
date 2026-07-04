import 'note_repository.dart';
import 'note_search.dart';
import 'note_tree_node.dart';
import 'wiki_link_parser.dart';

/// A note in the knowledge graph.
class GraphNode {
  const GraphNode({required this.id, required this.title});

  final String id;
  final String title;
}

/// An (undirected, deduplicated) connection between two notes.
class GraphEdge {
  const GraphEdge({required this.fromId, required this.toId});

  final String fromId;
  final String toId;
}

/// The notes vault as a graph of `[[wiki-link]]` connections.
class NoteGraph {
  const NoteGraph({required this.nodes, required this.edges});

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  /// Number of edges touching the node [nodeId], used to size nodes by
  /// how connected they are.
  int connectionCount(String nodeId) {
    return edges
        .where((edge) => edge.fromId == nodeId || edge.toId == nodeId)
        .length;
  }
}

/// Reads every note in [tree] and links them by their `[[wiki-link]]`
/// references, matched case-insensitively against note titles. Links to a
/// title with no matching note, and self-links, are dropped; a link
/// appearing in both directions (or repeated) collapses to one edge.
Future<NoteGraph> buildNoteGraph(
  NoteRepository repository,
  List<NoteTreeNode> tree,
) async {
  final List<NoteTreeNode> notes = flattenNotes(tree);
  final Map<String, String> titleToId = {
    for (final NoteTreeNode note in notes) note.title.toLowerCase(): note.id,
  };
  final List<GraphNode> nodes = [
    for (final NoteTreeNode note in notes)
      GraphNode(id: note.id, title: note.title),
  ];

  final Set<String> seenPairs = {};
  final List<GraphEdge> edges = [];
  for (final NoteTreeNode note in notes) {
    final String content = await repository.readNote(note.id);
    for (final String link in parseWikiLinks(content)) {
      final String? targetId = titleToId[link.toLowerCase()];
      if (targetId == null || targetId == note.id) continue;

      final List<String> pair = [note.id, targetId]..sort();
      if (seenPairs.add(pair.join('|'))) {
        edges.add(GraphEdge(fromId: note.id, toId: targetId));
      }
    }
  }

  return NoteGraph(nodes: nodes, edges: edges);
}
