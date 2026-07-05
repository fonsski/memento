import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists which theme the user has selected, as a plain text file in
/// the app's support directory — mirrors `VaultSettings`' approach for
/// the same reason: one string setting doesn't need a database.
class ThemeSettings {
  const ThemeSettings(this._file);

  final File _file;

  static Future<ThemeSettings> create() async {
    final Directory supportDir = await getApplicationSupportDirectory();
    return ThemeSettings(File(p.join(supportDir.path, 'theme_id.txt')));
  }

  /// The id (file name without extension) of the previously selected
  /// custom theme, or `null` if the built-in theme is selected — either
  /// because the user chose it, or because nothing's been chosen yet.
  Future<String?> readThemeId() async {
    if (!_file.existsSync()) return null;
    final String content = (await _file.readAsString()).trim();
    return content.isEmpty ? null : content;
  }

  /// Saves the selected theme id, or clears the setting (falling back to
  /// the built-in theme) when [id] is `null`.
  Future<void> writeThemeId(String? id) async {
    if (id == null) {
      if (_file.existsSync()) await _file.delete();
      return;
    }
    await _file.parent.create(recursive: true);
    await _file.writeAsString(id);
  }
}
