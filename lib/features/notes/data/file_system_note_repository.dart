import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/note_repository.dart';
import '../domain/note_tree_node.dart';

/// Stores the vault as a plain directory tree on disk: folders are
/// directories, notes are `.md` files, and a note's title is its file
/// name without the extension. Node ids/paths always use `/` as the
/// separator, regardless of platform.
class FileSystemNoteRepository implements NoteRepository {
  FileSystemNoteRepository(this.vaultRoot);

  final Directory vaultRoot;

  static const String noteExtension = '.md';

  @override
  Future<List<NoteTreeNode>> loadTree() async {
    if (!vaultRoot.existsSync()) {
      await vaultRoot.create(recursive: true);
    }
    return _listDirectory(vaultRoot);
  }

  Future<List<NoteTreeNode>> _listDirectory(Directory directory) async {
    final List<FileSystemEntity> entries = await directory.list().toList();
    final List<NoteTreeNode> folders = [];
    final List<NoteTreeNode> notes = [];

    for (final FileSystemEntity entity in entries) {
      if (entity is Directory) {
        folders.add(
          NoteTreeNode(
            id: _relativePath(entity),
            title: p.basename(entity.path),
            type: NoteTreeNodeType.folder,
            children: await _listDirectory(entity),
          ),
        );
      } else if (entity is File && p.extension(entity.path) == noteExtension) {
        notes.add(
          NoteTreeNode(
            id: p.posix.withoutExtension(_relativePath(entity)),
            title: p.basenameWithoutExtension(entity.path),
          ),
        );
      }
    }

    int byTitle(NoteTreeNode a, NoteTreeNode b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase());
    folders.sort(byTitle);
    notes.sort(byTitle);
    return [...folders, ...notes];
  }

  /// Vault-relative path for [entity], always `/`-separated.
  String _relativePath(FileSystemEntity entity) {
    return p.relative(entity.path, from: vaultRoot.path).replaceAll(r'\', '/');
  }

  @override
  Future<String> readNote(String path) {
    return File(_absoluteNotePath(path)).readAsString();
  }

  @override
  Future<void> writeNote(String path, String content) {
    return File(_absoluteNotePath(path)).writeAsString(content);
  }

  /// Absolute on-disk path of the `.md` file backing note [path].
  String _absoluteNotePath(String path) {
    return '${p.joinAll([vaultRoot.path, ...path.split('/')])}$noteExtension';
  }

  @override
  Future<String> createNote(String parentPath, String title) =>
      throw UnimplementedError();

  @override
  Future<String> createFolder(String parentPath, String title) =>
      throw UnimplementedError();

  @override
  Future<String> rename(String path, String newTitle) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String path) => throw UnimplementedError();
}
