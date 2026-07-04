import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/notes/data/file_system_note_repository.dart';
import 'package:memento/features/sync/data/pairing_store.dart';
import 'package:memento/features/sync/data/sync_coordinator.dart';
import 'package:memento/features/sync/data/sync_session.dart';
import 'package:memento/features/sync/domain/device_identity.dart';
import 'package:memento/features/sync/domain/discovered_peer.dart';
import 'package:memento/features/sync/domain/peer_info.dart';
import 'package:memento/features/sync/domain/trusted_peer.dart';
import 'package:path/path.dart' as p;

/// Sets up a coordinator with its own temp vault + pairing store, only
/// starting its plain TCP listener (never mDNS, which needs real plugin
/// platform channels flutter test can't provide).
Future<(SyncCoordinator, Directory)> _setUpCoordinator(
  String deviceId,
  String deviceName,
) async {
  final Directory vaultRoot = await Directory.systemTemp.createTemp(
    'memento_coordinator_$deviceId',
  );
  final Directory settingsDir = await Directory.systemTemp.createTemp(
    'memento_coordinator_settings_$deviceId',
  );
  final SyncCoordinator coordinator = SyncCoordinator(
    repository: FileSystemNoteRepository(vaultRoot),
    identity: DeviceIdentity(id: deviceId, name: deviceName),
    pairingStore: PairingStore(File(p.join(settingsDir.path, 'peers.json'))),
  );
  await coordinator.startListening();
  return (coordinator, vaultRoot);
}

void main() {
  final List<Directory> tempDirs = [];

  tearDown(() async {
    for (final Directory dir in tempDirs) {
      if (dir.existsSync()) await dir.delete(recursive: true);
    }
    tempDirs.clear();
  });

  test('pairing over loopback trusts the peer on both sides', () async {
    final (coordinatorA, vaultA) = await _setUpCoordinator('a', 'Ноутбук');
    final (coordinatorB, vaultB) = await _setUpCoordinator('b', 'Телефон');
    tempDirs.addAll([vaultA, vaultB]);

    final String code = coordinatorB.beginPairingAsResponder();
    final DiscoveredPeer peerB = DiscoveredPeer(
      deviceId: 'b',
      name: 'Телефон',
      host: '127.0.0.1',
      port: coordinatorB.listeningPort!,
    );

    final PeerInfo info = await coordinatorA.pairWithPeer(peerB, code);

    expect(info.deviceId, 'b');
    expect(await coordinatorA.pairingStore.isTrusted('b'), isTrue);
    // Give the responder's fire-and-forget handler a moment to persist
    // trust on its side too.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(await coordinatorB.pairingStore.isTrusted('a'), isTrue);

    await coordinatorA.dispose();
    await coordinatorB.dispose();
  });

  test('pairing with the wrong code throws and trusts nobody', () async {
    final (coordinatorA, vaultA) = await _setUpCoordinator('a', 'Ноутбук');
    final (coordinatorB, vaultB) = await _setUpCoordinator('b', 'Телефон');
    tempDirs.addAll([vaultA, vaultB]);

    coordinatorB.beginPairingAsResponder();
    final DiscoveredPeer peerB = DiscoveredPeer(
      deviceId: 'b',
      name: 'Телефон',
      host: '127.0.0.1',
      port: coordinatorB.listeningPort!,
    );

    await expectLater(
      coordinatorA.pairWithPeer(peerB, 'wrong-code'),
      throwsA(isA<SyncPairingRejectedException>()),
    );
    expect(await coordinatorA.pairingStore.isTrusted('b'), isFalse);

    await coordinatorA.dispose();
    await coordinatorB.dispose();
  });

  test('syncing with a paired peer transfers notes both ways', () async {
    final (coordinatorA, vaultA) = await _setUpCoordinator('a', 'Ноутбук');
    final (coordinatorB, vaultB) = await _setUpCoordinator('b', 'Телефон');
    tempDirs.addAll([vaultA, vaultB]);

    await coordinatorA.pairingStore.addTrustedPeer(
      const TrustedPeer(deviceId: 'b', name: 'Телефон'),
    );
    await coordinatorB.pairingStore.addTrustedPeer(
      const TrustedPeer(deviceId: 'a', name: 'Ноутбук'),
    );

    final FileSystemNoteRepository repoA = coordinatorA.repository;
    await repoA.createNote('', 'Из А');
    await repoA.writeNote('Из А', 'содержимое из А');

    final DiscoveredPeer peerB = DiscoveredPeer(
      deviceId: 'b',
      name: 'Телефон',
      host: '127.0.0.1',
      port: coordinatorB.listeningPort!,
    );
    await coordinatorA.syncWithPeer(peerB);
    // The responder side applies its half of the sync asynchronously;
    // give it a moment to finish writing.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final FileSystemNoteRepository repoB = coordinatorB.repository;
    expect(await repoB.readNote('Из А'), 'содержимое из А');

    await coordinatorA.dispose();
    await coordinatorB.dispose();
  });

  test('syncing rejects a peer that was never paired', () async {
    final (coordinatorA, vaultA) = await _setUpCoordinator('a', 'Ноутбук');
    final (coordinatorB, vaultB) = await _setUpCoordinator('b', 'Телефон');
    tempDirs.addAll([vaultA, vaultB]);

    final DiscoveredPeer peerB = DiscoveredPeer(
      deviceId: 'b',
      name: 'Телефон',
      host: '127.0.0.1',
      port: coordinatorB.listeningPort!,
    );

    await expectLater(
      coordinatorA.syncWithPeer(peerB),
      throwsA(isA<SyncUntrustedPeerException>()),
    );

    await coordinatorA.dispose();
    await coordinatorB.dispose();
  });
}
