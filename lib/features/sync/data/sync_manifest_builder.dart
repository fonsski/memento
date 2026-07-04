import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../notes/data/file_system_note_repository.dart';
import '../../notes/domain/note_search.dart';
import '../../notes/domain/note_tree_node.dart';
import '../domain/sync_manifest.dart';

/// Builds a [SyncManifest] by reading every note in [repository]'s vault.
Future<SyncManifest> buildSyncManifest(
  FileSystemNoteRepository repository,
) async {
  final List<NoteTreeNode> tree = await repository.loadTree();
  final Map<String, ManifestEntry> entries = {};

  for (final NoteTreeNode note in flattenNotes(tree)) {
    final String content = await repository.readNote(note.id);
    final DateTime modifiedAt = await repository.noteModifiedAt(note.id);
    entries[note.id] = ManifestEntry(
      path: note.id,
      modifiedAt: modifiedAt,
      contentHash: sha256.convert(utf8.encode(content)).toString(),
    );
  }

  return SyncManifest(entries);
}
