import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists the user's chosen vault location as a plain text file in the
/// app's support directory — no database or extra plugin needed for a
/// single string setting.
class VaultSettings {
  const VaultSettings(this._file);

  final File _file;

  static Future<VaultSettings> create() async {
    final Directory supportDir = await getApplicationSupportDirectory();
    return VaultSettings(File(p.join(supportDir.path, 'vault_path.txt')));
  }

  /// The previously saved vault path, or `null` if none has been set yet.
  Future<String?> readVaultPath() async {
    if (!_file.existsSync()) return null;
    final String content = (await _file.readAsString()).trim();
    return content.isEmpty ? null : content;
  }

  Future<void> writeVaultPath(String path) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(path);
  }
}
