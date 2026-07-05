import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memento/core/theme/theme_settings.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late ThemeSettings settings;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('memento_theme_settings');
    settings = ThemeSettings(File(p.join(tempDir.path, 'theme_id.txt')));
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('returns null when nothing has been saved yet', () async {
    expect(await settings.readThemeId(), isNull);
  });

  test('reads back a saved theme id', () async {
    await settings.writeThemeId('ocean');

    expect(await settings.readThemeId(), 'ocean');
  });

  test('writing null clears a previously saved id', () async {
    await settings.writeThemeId('ocean');
    await settings.writeThemeId(null);

    expect(await settings.readThemeId(), isNull);
  });
}
