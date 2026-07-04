import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/notes/data/vault_settings.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late VaultSettings settings;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('memento_settings_test');
    settings = VaultSettings(File(p.join(tempDir.path, 'vault_path.txt')));
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('returns null when nothing has been saved yet', () async {
    expect(await settings.readVaultPath(), isNull);
  });

  test('reads back a saved path', () async {
    await settings.writeVaultPath('/home/user/MyVault');

    expect(await settings.readVaultPath(), '/home/user/MyVault');
  });

  test('overwrites a previously saved path', () async {
    await settings.writeVaultPath('/first/path');
    await settings.writeVaultPath('/second/path');

    expect(await settings.readVaultPath(), '/second/path');
  });

  test('creates the parent directory if it does not exist', () async {
    final VaultSettings nested = VaultSettings(
      File(p.join(tempDir.path, 'nested', 'dir', 'vault_path.txt')),
    );

    await nested.writeVaultPath('/some/path');

    expect(await nested.readVaultPath(), '/some/path');
  });
}
