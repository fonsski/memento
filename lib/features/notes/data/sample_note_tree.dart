import '../domain/note_tree_node.dart';

/// Placeholder tree content for developing and testing the sidebar tree
/// before the local storage layer exists. Replace with a real repository
/// once notes are persisted on disk.
const List<NoteTreeNode> sampleNoteTree = [
  NoteTreeNode(
    id: 'archive',
    title: 'Архив',
    type: NoteTreeNodeType.folder,
    children: [
      NoteTreeNode(id: 'archive/1', title: 'Заметки о памяти'),
      NoteTreeNode(id: 'archive/2', title: 'Черновик философии'),
      NoteTreeNode(
        id: 'archive/history',
        title: 'История',
        type: NoteTreeNodeType.folder,
        children: [
          NoteTreeNode(id: 'archive/history/1', title: '2024 год'),
          NoteTreeNode(id: 'archive/history/2', title: '2025 год'),
        ],
      ),
    ],
  ),
  NoteTreeNode(
    id: 'inbox',
    title: 'Входящие',
    type: NoteTreeNodeType.folder,
    children: [NoteTreeNode(id: 'inbox/1', title: 'Быстрая мысль')],
  ),
  NoteTreeNode(id: 'readme', title: 'О проекте'),
];
