import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/notes/domain/note_search.dart';
import 'package:memento/features/notes/domain/note_tree_node.dart';

void main() {
  const List<NoteTreeNode> tree = [
    NoteTreeNode(
      id: 'archive',
      title: 'Архив',
      type: NoteTreeNodeType.folder,
      children: [
        NoteTreeNode(id: 'archive/memory', title: 'Заметки о памяти'),
        NoteTreeNode(
          id: 'archive/history',
          title: 'История',
          type: NoteTreeNodeType.folder,
          children: [NoteTreeNode(id: 'archive/history/2025', title: '2025')],
        ),
      ],
    ),
    NoteTreeNode(id: 'readme', title: 'О проекте'),
  ];

  group('flattenNotes', () {
    test('collects only notes, skipping folders, depth-first', () {
      expect(flattenNotes(tree).map((n) => n.id).toList(), [
        'archive/memory',
        'archive/history/2025',
        'readme',
      ]);
    });

    test('returns an empty list for an empty tree', () {
      expect(flattenNotes(const []), isEmpty);
    });
  });

  group('searchNotes', () {
    final List<NoteTreeNode> notes = flattenNotes(tree);

    test('returns all notes for a blank query', () {
      expect(searchNotes(notes, '   '), notes);
    });

    test('filters case-insensitively by title substring', () {
      final List<NoteTreeNode> results = searchNotes(notes, 'ПАМЯТИ');
      expect(results.map((n) => n.id).toList(), ['archive/memory']);
    });

    test('ranks earlier matches first', () {
      final List<NoteTreeNode> results = searchNotes(notes, 'о');
      // "О проекте" matches at index 0; "Заметки о памяти" matches later.
      expect(results.first.id, 'readme');
    });

    test('returns an empty list when nothing matches', () {
      expect(searchNotes(notes, 'нет такого'), isEmpty);
    });
  });
}
