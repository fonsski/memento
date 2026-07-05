import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'custom_theme.dart';

/// Loads user-authored theme JSON files from the app's themes folder
/// (`<application support dir>/themes/*.json`) — no vault or repository
/// involved, since themes are app configuration, not note content.
class CustomThemeRepository {
  const CustomThemeRepository(this.themesDirectory);

  /// Directory where user theme JSON files live; exposed so the UI can
  /// point users to it (e.g. "open folder").
  final Directory themesDirectory;

  static Future<CustomThemeRepository> create() async {
    final Directory supportDir = await getApplicationSupportDirectory();
    return CustomThemeRepository(Directory(p.join(supportDir.path, 'themes')));
  }

  /// Loads every valid theme file in [themesDirectory], keyed by file
  /// name (without extension) so a theme can be referenced stably even
  /// if its display name changes. This folder is user-edited, so a file
  /// that isn't valid JSON or doesn't parse as a theme is skipped rather
  /// than failing the whole list.
  Future<Map<String, CustomThemeDefinition>> loadAll() async {
    if (!themesDirectory.existsSync()) return {};

    final Map<String, CustomThemeDefinition> themes = {};
    final List<FileSystemEntity> entries = await themesDirectory
        .list()
        .toList();
    for (final FileSystemEntity entity in entries) {
      if (entity is! File || p.extension(entity.path) != '.json') continue;
      try {
        final Object? decoded = jsonDecode(await entity.readAsString());
        if (decoded is Map<String, dynamic>) {
          final String id = p.basenameWithoutExtension(entity.path);
          themes[id] = CustomThemeDefinition.fromJson(decoded);
        }
      } catch (_) {
        // Not valid JSON, or valid JSON with the wrong shape (e.g. "light"
        // isn't a map) — skip this one file, keep the rest of the folder.
      }
    }
    return themes;
  }
}
