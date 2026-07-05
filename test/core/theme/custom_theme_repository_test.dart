import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memento/core/theme/custom_theme_repository.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory themesDir;
  late CustomThemeRepository repository;

  setUp(() async {
    themesDir = await Directory.systemTemp.createTemp('memento_themes_test');
    repository = CustomThemeRepository(themesDir);
  });

  tearDown(() async {
    if (themesDir.existsSync()) {
      await themesDir.delete(recursive: true);
    }
  });

  test('returns an empty map when the folder does not exist', () async {
    await themesDir.delete(recursive: true);

    expect(await repository.loadAll(), isEmpty);
  });

  test('returns an empty map for an empty folder', () async {
    expect(await repository.loadAll(), isEmpty);
  });

  test('loads a valid theme, keyed by file name without extension', () async {
    await File(
      p.join(themesDir.path, 'ocean.json'),
    ).writeAsString('{"name": "Океан", "dark": {"accent": "#2E86AB"}}');

    final Map<String, dynamic> themes = await repository.loadAll();

    expect(themes.keys, ['ocean']);
    expect(themes['ocean']!.name, 'Океан');
  });

  test('loads multiple valid themes', () async {
    await File(p.join(themesDir.path, 'a.json')).writeAsString('{"name": "A"}');
    await File(p.join(themesDir.path, 'b.json')).writeAsString('{"name": "B"}');

    final Map<String, dynamic> themes = await repository.loadAll();

    expect(themes.keys.toSet(), {'a', 'b'});
  });

  test('skips files that are not valid JSON', () async {
    await File(
      p.join(themesDir.path, 'broken.json'),
    ).writeAsString('{not valid json');
    await File(
      p.join(themesDir.path, 'ok.json'),
    ).writeAsString('{"name": "OK"}');

    final Map<String, dynamic> themes = await repository.loadAll();

    expect(themes.keys, ['ok']);
  });

  test('skips valid JSON with the wrong shape', () async {
    await File(
      p.join(themesDir.path, 'wrong_shape.json'),
    ).writeAsString('{"light": "not a map"}');
    await File(
      p.join(themesDir.path, 'ok.json'),
    ).writeAsString('{"name": "OK"}');

    final Map<String, dynamic> themes = await repository.loadAll();

    expect(themes.keys, ['ok']);
  });

  test('ignores non-.json files', () async {
    await File(p.join(themesDir.path, 'readme.txt')).writeAsString('hello');

    expect(await repository.loadAll(), isEmpty);
  });
}
