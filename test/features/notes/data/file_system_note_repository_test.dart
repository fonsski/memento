import 'dart:io';
import 'dart:typed_data';

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

  test('noteModifiedAt reflects the last write', () async {
    await repository.createNote('', 'Заметка');
    final DateTime before = DateTime.now().subtract(const Duration(seconds: 1));

    await repository.writeNote('Заметка', 'обновлено');

    final DateTime modifiedAt = await repository.noteModifiedAt('Заметка');
    expect(modifiedAt.isAfter(before), isTrue);
  });

  test('createNote creates an empty .md file and returns its path', () async {
    final String path = await repository.createNote('', 'Идея');

    expect(path, 'Идея');
    expect(File(p.join(vaultRoot.path, 'Идея.md')).existsSync(), isTrue);
  });

  test('createNote inside a parent folder nests the path', () async {
    await Directory(p.join(vaultRoot.path, 'folder')).create();

    final String path = await repository.createNote('folder', 'Идея');

    expect(path, 'folder/Идея');
    expect(
      File(p.join(vaultRoot.path, 'folder', 'Идея.md')).existsSync(),
      isTrue,
    );
  });

  test('createNote throws if a note with that title already exists', () async {
    await repository.createNote('', 'Идея');

    expect(() => repository.createNote('', 'Идея'), throwsA(anything));
  });

  test(
    'createFolder creates an empty directory and returns its path',
    () async {
      final String path = await repository.createFolder('', 'Архив');

      expect(path, 'Архив');
      expect(Directory(p.join(vaultRoot.path, 'Архив')).existsSync(), isTrue);
    },
  );

  test('rename renames a note file in place', () async {
    await repository.createNote('', 'Старое');

    final String newPath = await repository.rename('Старое', 'Новое');

    expect(newPath, 'Новое');
    expect(File(p.join(vaultRoot.path, 'Старое.md')).existsSync(), isFalse);
    expect(File(p.join(vaultRoot.path, 'Новое.md')).existsSync(), isTrue);
  });

  test('rename renames a folder in place', () async {
    await repository.createFolder('', 'Старое');

    final String newPath = await repository.rename('Старое', 'Новое');

    expect(newPath, 'Новое');
    expect(Directory(p.join(vaultRoot.path, 'Старое')).existsSync(), isFalse);
    expect(Directory(p.join(vaultRoot.path, 'Новое')).existsSync(), isTrue);
  });

  test('delete removes a note file', () async {
    await repository.createNote('', 'Заметка');

    await repository.delete('Заметка');

    expect(File(p.join(vaultRoot.path, 'Заметка.md')).existsSync(), isFalse);
  });

  test('delete removes a folder and its contents', () async {
    await repository.createFolder('', 'Папка');
    await repository.createNote('Папка', 'Внутри');

    await repository.delete('Папка');

    expect(Directory(p.join(vaultRoot.path, 'Папка')).existsSync(), isFalse);
  });

  group('saveAttachment', () {
    test('writes the bytes under a vault-root attachments/ folder', () async {
      final Uint8List bytes = Uint8List.fromList([1, 2, 3, 4]);

      final String path = await repository.saveAttachment(bytes);

      expect(path, startsWith('attachments/'));
      expect(path, endsWith('.png'));
      final File file = File(p.join(vaultRoot.path, path));
      expect(file.existsSync(), isTrue);
      expect(file.readAsBytesSync(), bytes);
    });

    test('uses the given extension', () async {
      final String path = await repository.saveAttachment(
        Uint8List.fromList([1]),
        extension: 'jpg',
      );

      expect(path, endsWith('.jpg'));
    });

    test('gives each attachment a distinct file name', () async {
      final String first = await repository.saveAttachment(
        Uint8List.fromList([1]),
      );
      final String second = await repository.saveAttachment(
        Uint8List.fromList([2]),
      );

      expect(first, isNot(second));
    });
  });
}
