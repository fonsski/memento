import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/note_repository.dart';
import '../domain/note_tree_node.dart';
import 'vault_settings.dart';

/// The vault the user previously chose (see [VaultSettings]), or a
/// `Memento` folder inside the platform's application-documents
/// directory if none has been chosen yet.
Future<FileSystemNoteRepository> createDefaultNoteRepository() async {
  final VaultSettings settings = await VaultSettings.create();
  final String? savedPath = await settings.readVaultPath();
  if (savedPath != null) {
    return FileSystemNoteRepository(Directory(savedPath));
  }

  final Directory documents = await getApplicationDocumentsDirectory();
  return FileSystemNoteRepository(Directory(p.join(documents.path, 'Memento')));
}

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

  /// Last-modified time of the `.md` file backing note [path], used by
  /// sync's last-write-wins comparisons.
  Future<DateTime> noteModifiedAt(String path) async {
    final FileStat stat = await File(_absoluteNotePath(path)).stat();
    return stat.modified;
  }

  /// Absolute on-disk path of the `.md` file backing note [path].
  String _absoluteNotePath(String path) {
    return '${p.joinAll([vaultRoot.path, ...path.split('/')])}$noteExtension';
  }

  @override
  Future<String> createNote(String parentPath, String title) async {
    final String path = _childPath(parentPath, title);
    await File(_absoluteNotePath(path)).create(exclusive: true);
    return path;
  }

  @override
  Future<String> createFolder(String parentPath, String title) async {
    final String path = _childPath(parentPath, title);
    await Directory(_absoluteFolderPath(path)).create();
    return path;
  }

  @override
  Future<String> rename(String path, String newTitle) async {
    final String newPath = _childPath(_parentPath(path), newTitle);
    if (await Directory(_absoluteFolderPath(path)).exists()) {
      await Directory(
        _absoluteFolderPath(path),
      ).rename(_absoluteFolderPath(newPath));
    } else {
      await File(_absoluteNotePath(path)).rename(_absoluteNotePath(newPath));
    }
    return newPath;
  }

  @override
  Future<void> delete(String path) async {
    final Directory folder = Directory(_absoluteFolderPath(path));
    if (await folder.exists()) {
      await folder.delete(recursive: true);
    } else {
      await File(_absoluteNotePath(path)).delete();
    }
  }

  /// Absolute on-disk path of the folder at vault-relative [path].
  String _absoluteFolderPath(String path) {
    return p.joinAll([vaultRoot.path, ...path.split('/')]);
  }

  /// Vault-relative path of [title] inside the folder at [parentPath]
  /// (empty string for the vault root).
  String _childPath(String parentPath, String title) {
    return parentPath.isEmpty ? title : '$parentPath/$title';
  }

  /// Vault-relative path of the folder containing [path] (empty string
  /// if [path] is already at the vault root).
  String _parentPath(String path) {
    final String dir = p.posix.dirname(path);
    return dir == '.' ? '' : dir;
  }

  static final Random _random = Random();

  @override
  Future<String> saveAttachment(
    Uint8List bytes, {
    String extension = 'png',
  }) async {
    final Directory attachmentsDir = Directory(
      p.join(vaultRoot.path, 'attachments'),
    );
    await attachmentsDir.create(recursive: true);

    final String fileName =
        '${DateTime.now().millisecondsSinceEpoch}-${_random.nextInt(1 << 32)}.$extension';
    await File(p.join(attachmentsDir.path, fileName)).writeAsBytes(bytes);
    return 'attachments/$fileName';
  }
}
