import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/notes/data/file_system_note_repository.dart';
import 'package:memento/features/sync/data/sync_baseline_store.dart';
import 'package:memento/features/sync/data/sync_session.dart';
import 'package:memento/features/sync/data/sync_wire.dart';
import 'package:memento/features/sync/domain/device_identity.dart';
import 'package:memento/features/sync/domain/peer_info.dart';
import 'package:memento/features/sync/domain/sync_result.dart';

/// Connects two [MessageChannel]s over a real TCP loopback connection.
Future<(MessageChannel, MessageChannel, ServerSocket)> _connectPair() async {
  final ServerSocket serverSocket = await ServerSocket.bind(
    InternetAddress.loopbackIPv4,
    0,
  );
  final Future<Socket> acceptFuture = serverSocket.first;
  final Socket clientSocket = await Socket.connect(
    InternetAddress.loopbackIPv4,
    serverSocket.port,
  );
  final Socket serverSideSocket = await acceptFuture;
  return (
    MessageChannel(clientSocket),
    MessageChannel(serverSideSocket),
    serverSocket,
  );
}

void main() {
  late Directory vaultA;
  late Directory vaultB;
  late Directory baselineDirA;
  late Directory baselineDirB;
  late SyncBaselineStore baselineStoreA;
  late SyncBaselineStore baselineStoreB;

  setUp(() async {
    vaultA = await Directory.systemTemp.createTemp('memento_sync_a');
    vaultB = await Directory.systemTemp.createTemp('memento_sync_b');
    baselineDirA = await Directory.systemTemp.createTemp(
      'memento_sync_baseline_a',
    );
    baselineDirB = await Directory.systemTemp.createTemp(
      'memento_sync_baseline_b',
    );
    baselineStoreA = SyncBaselineStore(baselineDirA);
    baselineStoreB = SyncBaselineStore(baselineDirB);
  });

  tearDown(() async {
    if (vaultA.existsSync()) await vaultA.delete(recursive: true);
    if (vaultB.existsSync()) await vaultB.delete(recursive: true);
    if (baselineDirA.existsSync()) await baselineDirA.delete(recursive: true);
    if (baselineDirB.existsSync()) await baselineDirB.delete(recursive: true);
  });

  group('pairing', () {
    test('succeeds when the codes match', () async {
      final (client, server, serverSocket) = await _connectPair();
      final SyncSession sessionA = SyncSession(
        repository: FileSystemNoteRepository(vaultA),
        localIdentity: const DeviceIdentity(id: 'device-a', name: 'A'),
        baselineStore: baselineStoreA,
      );
      final SyncSession sessionB = SyncSession(
        repository: FileSystemNoteRepository(vaultB),
        localIdentity: const DeviceIdentity(id: 'device-b', name: 'B'),
        baselineStore: baselineStoreB,
      );

      final List<PeerInfo> results = await Future.wait([
        sessionA.pair(client, code: '123456'),
        sessionB.respondToPairing(server, expectedCode: '123456'),
      ]);

      expect(results[0].deviceId, 'device-b');
      expect(results[1].deviceId, 'device-a');

      await serverSocket.close();
    });

    test('fails when the codes do not match', () async {
      final (client, server, serverSocket) = await _connectPair();
      final SyncSession sessionA = SyncSession(
        repository: FileSystemNoteRepository(vaultA),
        localIdentity: const DeviceIdentity(id: 'device-a', name: 'A'),
        baselineStore: baselineStoreA,
      );
      final SyncSession sessionB = SyncSession(
        repository: FileSystemNoteRepository(vaultB),
        localIdentity: const DeviceIdentity(id: 'device-b', name: 'B'),
        baselineStore: baselineStoreB,
      );

      final List<Object> results = await Future.wait([
        sessionA
            .pair(client, code: 'wrong')
            .then<Object>((v) => v, onError: (Object e) => e),
        sessionB
            .respondToPairing(server, expectedCode: '123456')
            .then<Object>((v) => v, onError: (Object e) => e),
      ]);

      expect(results[0], isA<SyncPairingRejectedException>());
      expect(results[1], isA<SyncPairingRejectedException>());

      await serverSocket.close();
    });
  });

  group('sync', () {
    test('rejects a peer that is not trusted', () async {
      final (client, server, serverSocket) = await _connectPair();
      final SyncSession sessionA = SyncSession(
        repository: FileSystemNoteRepository(vaultA),
        localIdentity: const DeviceIdentity(id: 'device-a', name: 'A'),
        baselineStore: baselineStoreA,
      );
      final SyncSession sessionB = SyncSession(
        repository: FileSystemNoteRepository(vaultB),
        localIdentity: const DeviceIdentity(id: 'device-b', name: 'B'),
        baselineStore: baselineStoreB,
      );

      final List<Object> results = await Future.wait([
        sessionA
            .sync(client, isTrusted: (_) async => true)
            .then<Object>((v) => v, onError: (Object e) => e),
        sessionB
            .sync(server, isTrusted: (_) async => false)
            .then<Object>((v) => v, onError: (Object e) => e),
      ]);

      expect(results[1], isA<SyncUntrustedPeerException>());

      await serverSocket.close();
    });

    test('copies a note that only exists on one side to the other', () async {
      final FileSystemNoteRepository repoA = FileSystemNoteRepository(vaultA);
      final FileSystemNoteRepository repoB = FileSystemNoteRepository(vaultB);
      await repoA.createNote('', 'Новая заметка');
      await repoA.writeNote('Новая заметка', 'привет из А');

      final (client, server, serverSocket) = await _connectPair();
      final SyncSession sessionA = SyncSession(
        repository: repoA,
        localIdentity: const DeviceIdentity(id: 'device-a', name: 'A'),
        baselineStore: baselineStoreA,
      );
      final SyncSession sessionB = SyncSession(
        repository: repoB,
        localIdentity: const DeviceIdentity(id: 'device-b', name: 'B'),
        baselineStore: baselineStoreB,
      );

      await Future.wait([
        sessionA.sync(client, isTrusted: (_) async => true),
        sessionB.sync(server, isTrusted: (_) async => true),
      ]);

      expect(await repoB.readNote('Новая заметка'), 'привет из А');

      await serverSocket.close();
    });

    test(
      'the newer side wins and the older side keeps a conflict copy',
      () async {
        final FileSystemNoteRepository repoA = FileSystemNoteRepository(vaultA);
        final FileSystemNoteRepository repoB = FileSystemNoteRepository(vaultB);
        await repoA.createNote('', 'Заметка');
        await repoB.createNote('', 'Заметка');
        await repoB.writeNote('Заметка', 'старая версия (Б)');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await repoA.writeNote('Заметка', 'новая версия (А)');

        final (client, server, serverSocket) = await _connectPair();
        final SyncSession sessionA = SyncSession(
          repository: repoA,
          localIdentity: const DeviceIdentity(id: 'device-a', name: 'A'),
          baselineStore: baselineStoreA,
        );
        final SyncSession sessionB = SyncSession(
          repository: repoB,
          localIdentity: const DeviceIdentity(id: 'device-b', name: 'B'),
          baselineStore: baselineStoreB,
        );

        final List<SyncResult> results = await Future.wait([
          sessionA.sync(client, isTrusted: (_) async => true),
          sessionB.sync(server, isTrusted: (_) async => true),
        ]);

        expect(await repoB.readNote('Заметка'), 'новая версия (А)');
        final List<FileSystemEntity> bFiles = await vaultB.list().toList();
        final bool hasConflictCopy = bFiles.any(
          (f) => f.path.contains('конфликт'),
        );
        expect(hasConflictCopy, isTrue);

        // A's content won (pushed), so A itself preserved nothing; B is
        // the side that lost and kept a conflict copy of its own content.
        expect(results[0].conflictPaths, isEmpty);
        expect(results[1].conflictPaths, ['Заметка']);

        await serverSocket.close();
      },
    );

    test(
      'does nothing for a note with identical content on both sides',
      () async {
        final FileSystemNoteRepository repoA = FileSystemNoteRepository(vaultA);
        final FileSystemNoteRepository repoB = FileSystemNoteRepository(vaultB);
        await repoA.createNote('', 'Заметка');
        await repoB.createNote('', 'Заметка');
        await repoA.writeNote('Заметка', 'одинаковый текст');
        await repoB.writeNote('Заметка', 'одинаковый текст');

        final (client, server, serverSocket) = await _connectPair();
        final SyncSession sessionA = SyncSession(
          repository: repoA,
          localIdentity: const DeviceIdentity(id: 'device-a', name: 'A'),
          baselineStore: baselineStoreA,
        );
        final SyncSession sessionB = SyncSession(
          repository: repoB,
          localIdentity: const DeviceIdentity(id: 'device-b', name: 'B'),
          baselineStore: baselineStoreB,
        );

        await Future.wait([
          sessionA.sync(client, isTrusted: (_) async => true),
          sessionB.sync(server, isTrusted: (_) async => true),
        ]);

        final List<FileSystemEntity> bFiles = await vaultB.list().toList();
        expect(bFiles, hasLength(1));

        await serverSocket.close();
      },
    );

    test('a note deleted after a prior sync is deleted on the peer too, not '
        'resurrected', () async {
      // Regression test for the sync baseline: without one, a path
      // missing from one side always looks "new" to the other, so a
      // deletion made offline would come back the next time it syncs.
      final FileSystemNoteRepository repoA = FileSystemNoteRepository(vaultA);
      final FileSystemNoteRepository repoB = FileSystemNoteRepository(vaultB);
      await repoA.createNote('', 'Заметка');
      await repoA.writeNote('Заметка', 'текст');

      Future<void> runSync() async {
        final (client, server, serverSocket) = await _connectPair();
        final SyncSession sessionA = SyncSession(
          repository: repoA,
          localIdentity: const DeviceIdentity(id: 'device-a', name: 'A'),
          baselineStore: baselineStoreA,
        );
        final SyncSession sessionB = SyncSession(
          repository: repoB,
          localIdentity: const DeviceIdentity(id: 'device-b', name: 'B'),
          baselineStore: baselineStoreB,
        );
        await Future.wait([
          sessionA.sync(client, isTrusted: (_) async => true),
          sessionB.sync(server, isTrusted: (_) async => true),
        ]);
        await serverSocket.close();
      }

      // First sync: B picks up the note from A, and both sides record
      // a baseline that includes it.
      await runSync();
      expect(await repoB.readNote('Заметка'), 'текст');

      // A deletes its copy after that baseline was recorded.
      await repoA.delete('Заметка');

      // Second sync: B still has the note, but both sides' baselines
      // know it existed before, so it's deleted on B too instead of
      // being pulled back onto A.
      await runSync();

      expect(await repoA.loadTree(), isEmpty);
      expect(await repoB.loadTree(), isEmpty);
    });
  });
}
