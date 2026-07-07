import 'dart:typed_data';

import 'note_tree_node.dart';

/// Persists and reads the notes vault. Every node is addressed by its
/// `path` (relative to the vault root, `/`-separated, no leading slash).
abstract class NoteRepository {
  /// Loads the full folder/note tree, sorted folders-then-notes,
  /// alphabetically within each group.
  Future<List<NoteTreeNode>> loadTree();

  /// Reads the raw Markdown content of the note at [path].
  Future<String> readNote(String path);

  /// Overwrites the Markdown content of the note at [path].
  Future<void> writeNote(String path, String content);

  /// Creates an empty note named [title] inside the folder at
  /// [parentPath] (empty string for the vault root). Returns the new
  /// note's path.
  Future<String> createNote(String parentPath, String title);

  /// Creates an empty folder named [title] inside the folder at
  /// [parentPath] (empty string for the vault root). Returns the new
  /// folder's path.
  Future<String> createFolder(String parentPath, String title);

  /// Renames the note or folder at [path] to [newTitle], keeping it in
  /// the same parent folder. Returns the new path.
  Future<String> rename(String path, String newTitle);

  /// Deletes the note or folder at [path] (folders are removed with all
  /// of their contents).
  Future<void> delete(String path);

  /// Saves [bytes] as a new attachment (e.g. a rasterized drawing) in a
  /// shared vault-root `attachments/` folder — vault-root-relative
  /// paths (rather than relative to each note) match how tools like
  /// Obsidian resolve attachment links, and sidestep computing a
  /// relative path from a possibly-nested note back to a shared folder.
  /// Returns the vault-relative path to embed in Markdown (e.g.
  /// `attachments/1700000000000-4213.png`).
  Future<String> saveAttachment(Uint8List bytes, {String extension = 'png'});

  /// Resolves a vault-relative attachment path (as returned by
  /// [saveAttachment], e.g. from `Block.attachmentPath`) to an absolute
  /// on-disk path suitable for reading the file directly (e.g. via
  /// `File`/`Image.file`) — a relative path alone would resolve against
  /// the process's working directory, not the vault, and load nothing.
  String resolveAttachmentPath(String relativePath);
}
