import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/sync/data/pairing_store.dart';
import 'package:memento/features/sync/domain/trusted_peer.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late PairingStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('memento_pairing_test');
    store = PairingStore(File(p.join(tempDir.path, 'trusted_peers.json')));
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('starts with no trusted peers', () async {
    expect(await store.loadTrustedPeers(), isEmpty);
    expect(await store.isTrusted('any-id'), isFalse);
  });

  test('adding a peer makes it trusted and persists across loads', () async {
    await store.addTrustedPeer(
      const TrustedPeer(deviceId: 'device-1', name: 'Телефон'),
    );

    expect(await store.isTrusted('device-1'), isTrue);
    final List<TrustedPeer> peers = await store.loadTrustedPeers();
    expect(peers, hasLength(1));
    expect(peers.single.name, 'Телефон');
  });

  test('adding the same peer twice does not duplicate it', () async {
    const TrustedPeer peer = TrustedPeer(deviceId: 'device-1', name: 'Телефон');
    await store.addTrustedPeer(peer);
    await store.addTrustedPeer(peer);

    expect(await store.loadTrustedPeers(), hasLength(1));
  });

  test('removing a trusted peer un-trusts it', () async {
    await store.addTrustedPeer(
      const TrustedPeer(deviceId: 'device-1', name: 'Телефон'),
    );

    await store.removeTrustedPeer('device-1');

    expect(await store.isTrusted('device-1'), isFalse);
    expect(await store.loadTrustedPeers(), isEmpty);
  });
}
