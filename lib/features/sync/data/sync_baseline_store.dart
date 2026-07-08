import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/sync_manifest.dart';

/// Persists, per peer, the vault's [SyncManifest] as it stood right after
/// the last successful sync with that peer — the "baseline" [diffManifests
/// (sync_diff.dart)] needs to tell "new since last sync" apart from
/// "deleted on the other side" (without one, a path missing from either
/// side is always assumed new, so an offline deletion resurrects the note
/// the next time it syncs).
class SyncBaselineStore {
  const SyncBaselineStore(this._directory);

  final Directory _directory;

  static Future<SyncBaselineStore> create() async {
    final Directory supportDir = await getApplicationSupportDirectory();
    return SyncBaselineStore(
      Directory(p.join(supportDir.path, 'sync_baselines')),
    );
  }

  File _fileFor(String peerDeviceId) =>
      File(p.join(_directory.path, '$peerDeviceId.json'));

  /// The manifest as of the last successful sync with [peerDeviceId], or
  /// `null` if they've never synced (or the record was cleared).
  Future<SyncManifest?> loadBaseline(String peerDeviceId) async {
    final File file = _fileFor(peerDeviceId);
    if (!file.existsSync()) return null;
    return SyncManifest.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  Future<void> saveBaseline(String peerDeviceId, SyncManifest manifest) async {
    await _directory.create(recursive: true);
    await _fileFor(peerDeviceId).writeAsString(jsonEncode(manifest.toJson()));
  }

  /// Clears the baseline for [peerDeviceId] — e.g. when unpairing, so a
  /// future re-pair doesn't treat stale local state as "last synced".
  Future<void> clearBaseline(String peerDeviceId) async {
    final File file = _fileFor(peerDeviceId);
    if (file.existsSync()) await file.delete();
  }
}
