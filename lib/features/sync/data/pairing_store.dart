import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/trusted_peer.dart';

/// Persists the set of peer devices the user has paired with, as a JSON
/// file in the app's support directory.
class PairingStore {
  const PairingStore(this._file);

  final File _file;

  static Future<PairingStore> create() async {
    final Directory supportDir = await getApplicationSupportDirectory();
    return PairingStore(File(p.join(supportDir.path, 'trusted_peers.json')));
  }

  Future<List<TrustedPeer>> loadTrustedPeers() async {
    if (!_file.existsSync()) return [];
    final List<dynamic> list =
        jsonDecode(await _file.readAsString()) as List<dynamic>;
    return [
      for (final dynamic item in list)
        TrustedPeer(
          deviceId: (item as Map<String, dynamic>)['deviceId'] as String,
          name: item['name'] as String,
        ),
    ];
  }

  Future<bool> isTrusted(String deviceId) async {
    final List<TrustedPeer> peers = await loadTrustedPeers();
    return peers.any((peer) => peer.deviceId == deviceId);
  }

  Future<void> addTrustedPeer(TrustedPeer peer) async {
    final List<TrustedPeer> peers = await loadTrustedPeers();
    if (peers.any((existing) => existing.deviceId == peer.deviceId)) return;
    await _save([...peers, peer]);
  }

  Future<void> removeTrustedPeer(String deviceId) async {
    final List<TrustedPeer> peers = await loadTrustedPeers();
    peers.removeWhere((peer) => peer.deviceId == deviceId);
    await _save(peers);
  }

  Future<void> _save(List<TrustedPeer> peers) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
      jsonEncode([
        for (final TrustedPeer peer in peers)
          {'deviceId': peer.deviceId, 'name': peer.name},
      ]),
    );
  }
}
