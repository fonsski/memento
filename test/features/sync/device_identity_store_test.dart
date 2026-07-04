import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/sync/data/device_identity_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late DeviceIdentityStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('memento_identity_test');
    store = DeviceIdentityStore(
      File(p.join(tempDir.path, 'device_identity.json')),
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates an identity on first use', () async {
    final identity = await store.loadOrCreate(defaultName: 'Мой ноутбук');

    expect(identity.id, isNotEmpty);
    expect(identity.name, 'Мой ноутбук');
  });

  test('returns the same identity on repeated calls', () async {
    final first = await store.loadOrCreate();
    final second = await store.loadOrCreate();

    expect(second.id, first.id);
    expect(second.name, first.name);
  });

  test('two different stores generate different ids', () async {
    final DeviceIdentityStore other = DeviceIdentityStore(
      File(p.join(tempDir.path, 'other_identity.json')),
    );

    final identityA = await store.loadOrCreate();
    final identityB = await other.loadOrCreate();

    expect(identityA.id, isNot(identityB.id));
  });
}
