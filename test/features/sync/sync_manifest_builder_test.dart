import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/notes/data/file_system_note_repository.dart';
import 'package:memento/features/sync/data/sync_manifest_builder.dart';
import 'package:memento/features/sync/domain/sync_manifest.dart';

void main() {
  late Directory vaultRoot;
  late FileSystemNoteRepository repository;

  setUp(() async {
    vaultRoot = await Directory.systemTemp.createTemp('memento_manifest_test');
    repository = FileSystemNoteRepository(vaultRoot);
  });

  tearDown(() async {
    if (vaultRoot.existsSync()) {
      await vaultRoot.delete(recursive: true);
    }
  });

  test('includes an entry for every note', () async {
    await repository.createNote('', 'Первая');
    await repository.createNote('', 'Вторая');

    final SyncManifest manifest = await buildSyncManifest(repository);

    expect(manifest.entries.keys.toSet(), {'Первая', 'Вторая'});
  });

  test('two notes with different content have different hashes', () async {
    await repository.createNote('', 'Первая');
    await repository.createNote('', 'Вторая');
    await repository.writeNote('Первая', 'содержимое А');
    await repository.writeNote('Вторая', 'содержимое Б');

    final SyncManifest manifest = await buildSyncManifest(repository);

    expect(
      manifest.entries['Первая']!.contentHash,
      isNot(manifest.entries['Вторая']!.contentHash),
    );
  });

  test('the same content produces the same hash', () async {
    await repository.createNote('', 'Первая');
    await repository.createNote('', 'Вторая');
    await repository.writeNote('Первая', 'одинаковый текст');
    await repository.writeNote('Вторая', 'одинаковый текст');

    final SyncManifest manifest = await buildSyncManifest(repository);

    expect(
      manifest.entries['Первая']!.contentHash,
      manifest.entries['Вторая']!.contentHash,
    );
  });

  test('records the note\'s on-disk modification time', () async {
    await repository.createNote('', 'Заметка');
    final DateTime before = DateTime.now().subtract(const Duration(seconds: 1));

    final SyncManifest manifest = await buildSyncManifest(repository);

    expect(manifest.entries['Заметка']!.modifiedAt.isAfter(before), isTrue);
  });

  test('returns an empty manifest for an empty vault', () async {
    final SyncManifest manifest = await buildSyncManifest(repository);

    expect(manifest.entries, isEmpty);
  });
}
