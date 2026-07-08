import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/sync/data/sync_baseline_store.dart';
import 'package:memento/features/sync/domain/sync_manifest.dart';

void main() {
  late Directory tempDir;
  late SyncBaselineStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('memento_baseline_test');
    store = SyncBaselineStore(tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('starts with no baseline for a peer', () async {
    expect(await store.loadBaseline('device-1'), isNull);
  });

  test('saving a baseline makes it loadable, entries intact', () async {
    final SyncManifest manifest = SyncManifest({
      'note': ManifestEntry(
        path: 'note',
        modifiedAt: DateTime.utc(2026, 1, 1, 12),
        contentHash: 'abc123',
      ),
    });

    await store.saveBaseline('device-1', manifest);
    final SyncManifest? loaded = await store.loadBaseline('device-1');

    expect(loaded, isNotNull);
    expect(loaded!.entries.keys, ['note']);
    expect(loaded.entries['note']!.contentHash, 'abc123');
    expect(loaded.entries['note']!.modifiedAt, DateTime.utc(2026, 1, 1, 12));
  });

  test('baselines for different peers are independent', () async {
    await store.saveBaseline('device-1', const SyncManifest({}));
    expect(await store.loadBaseline('device-2'), isNull);
  });

  test(
    'saving again for the same peer replaces the previous baseline',
    () async {
      await store.saveBaseline(
        'device-1',
        SyncManifest({
          'a': ManifestEntry(
            path: 'a',
            modifiedAt: DateTime.utc(2026),
            contentHash: 'h1',
          ),
        }),
      );
      await store.saveBaseline(
        'device-1',
        SyncManifest({
          'b': ManifestEntry(
            path: 'b',
            modifiedAt: DateTime.utc(2026),
            contentHash: 'h2',
          ),
        }),
      );

      final SyncManifest? loaded = await store.loadBaseline('device-1');
      expect(loaded!.entries.keys, ['b']);
    },
  );

  test('clearing a baseline removes it', () async {
    await store.saveBaseline('device-1', const SyncManifest({}));
    await store.clearBaseline('device-1');

    expect(await store.loadBaseline('device-1'), isNull);
  });

  test('clearing a never-saved baseline is harmless', () async {
    await store.clearBaseline('device-1');
    expect(await store.loadBaseline('device-1'), isNull);
  });
}
