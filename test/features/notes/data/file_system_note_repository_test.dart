import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/notes/data/file_system_note_repository.dart';
import 'package:memento/features/notes/domain/note_tree_node.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory vaultRoot;
  late FileSystemNoteRepository repository;

  setUp(() async {
    vaultRoot = await Directory.systemTemp.createTemp('memento_vault_test');
    repository = FileSystemNoteRepository(vaultRoot);
  });

  tearDown(() async {
    if (vaultRoot.existsSync()) {
      await vaultRoot.delete(recursive: true);
    }
  });

  test('creates the vault directory if it does not exist yet', () async {
    await vaultRoot.delete(recursive: true);

    final List<NoteTreeNode> tree = await repository.loadTree();

    expect(vaultRoot.existsSync(), isTrue);
    expect(tree, isEmpty);
  });

  test(
    'lists folders before notes, alphabetically within each group',
    () async {
      await File(p.join(vaultRoot.path, 'b.md')).create();
      await File(p.join(vaultRoot.path, 'a.md')).create();
      await Directory(p.join(vaultRoot.path, 'zeta')).create();
      await Directory(p.join(vaultRoot.path, 'alpha')).create();

      final List<NoteTreeNode> tree = await repository.loadTree();

      expect(tree.map((node) => node.title).toList(), [
        'alpha',
        'zeta',
        'a',
        'b',
      ]);
      expect(tree[0].isFolder, isTrue);
      expect(tree[2].isFolder, isFalse);
    },
  );

  test('ignores non-.md files and nests subfolders with / ids', () async {
    await File(p.join(vaultRoot.path, 'ignore.txt')).create();
    final Directory sub = await Directory(
      p.join(vaultRoot.path, 'folder'),
    ).create();
    await File(p.join(sub.path, 'nested.md')).create();

    final List<NoteTreeNode> tree = await repository.loadTree();

    expect(tree.length, 1);
    expect(tree.single.id, 'folder');
    expect(tree.single.children.single.id, 'folder/nested');
    expect(tree.single.children.single.title, 'nested');
  });

  test('reads back the content written for a note', () async {
    final Directory sub = await Directory(
      p.join(vaultRoot.path, 'folder'),
    ).create();
    await File(p.join(sub.path, 'nested.md')).writeAsString('placeholder');

    await repository.writeNote('folder/nested', '# Hello, Memento');

    expect(await repository.readNote('folder/nested'), '# Hello, Memento');
  });
}
