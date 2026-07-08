import 'dart:async';

import '../../notes/data/file_system_note_repository.dart';
import '../domain/device_identity.dart';
import '../domain/peer_info.dart';
import '../domain/sync_diff.dart';
import '../domain/sync_manifest.dart';
import '../domain/sync_progress.dart';
import '../domain/sync_result.dart';
import 'sync_baseline_store.dart';
import 'sync_manifest_builder.dart';
import 'sync_wire.dart';

/// The peer rejected our pairing code (or we rejected theirs).
class SyncPairingRejectedException implements Exception {
  @override
  String toString() => 'SyncPairingRejectedException: pairing code mismatch';
}

/// The peer connected for a sync but isn't a paired/trusted device.
class SyncUntrustedPeerException implements Exception {
  SyncUntrustedPeerException(this.peerDeviceId);

  final String peerDeviceId;

  @override
  String toString() => 'SyncUntrustedPeerException: $peerDeviceId';
}

/// Drives one conversation over an already-connected [MessageChannel]:
/// either a pairing handshake, or a full manifest-diff-and-transfer sync.
/// Each conversation is a single request/response sequence over one
/// connection — callers open a fresh connection per pairing attempt or
/// sync run.
class SyncSession {
  SyncSession({
    required this.repository,
    required this.localIdentity,
    required this.baselineStore,
  });

  final FileSystemNoteRepository repository;
  final DeviceIdentity localIdentity;
  final SyncBaselineStore baselineStore;

  Future<HelloMessage> _exchangeHello(
    MessageChannel channel,
    StreamIterator<SyncMessage> incoming,
  ) async {
    await channel.send(
      HelloMessage(deviceId: localIdentity.id, deviceName: localIdentity.name),
    );
    return _next<HelloMessage>(incoming);
  }

  /// Pairing initiator: sends [code] (as shown/entered by the user) and
  /// waits for the peer to accept or reject it.
  Future<PeerInfo> pair(MessageChannel channel, {required String code}) async {
    final StreamIterator<SyncMessage> incoming = StreamIterator(
      channel.messages(),
    );
    try {
      final HelloMessage peerHello = await _exchangeHello(channel, incoming);

      await channel.send(PairRequestMessage(code: code));
      final PairResultMessage result = await _next<PairResultMessage>(incoming);

      if (!result.accepted) throw SyncPairingRejectedException();
      return PeerInfo(deviceId: peerHello.deviceId, name: peerHello.deviceName);
    } finally {
      await incoming.cancel();
      await channel.close();
    }
  }

  /// Pairing responder: the side displaying [expectedCode], waiting for
  /// the initiator to send a matching one.
  Future<PeerInfo> respondToPairing(
    MessageChannel channel, {
    required String expectedCode,
  }) async {
    final StreamIterator<SyncMessage> incoming = StreamIterator(
      channel.messages(),
    );
    try {
      final HelloMessage peerHello = await _exchangeHello(channel, incoming);

      final PairRequestMessage request = await _next<PairRequestMessage>(
        incoming,
      );
      final bool accepted = request.code == expectedCode;
      await channel.send(PairResultMessage(accepted: accepted));

      if (!accepted) throw SyncPairingRejectedException();
      return PeerInfo(deviceId: peerHello.deviceId, name: peerHello.deviceName);
    } finally {
      await incoming.cancel();
      await channel.close();
    }
  }

  /// Runs a full sync with an already-paired peer: exchanges manifests,
  /// then pushes/pulls/deletes notes per [diffManifests] (against this
  /// peer's baseline from the last successful sync, so offline deletions
  /// don't resurrect), applying a `.conflict-<timestamp>` copy before
  /// overwriting the losing side of a genuine conflict — reported back
  /// via [SyncResult.conflictPaths], since a silent copy on disk is easy
  /// to never notice. [isTrusted] is checked against the peer's
  /// announced id before any vault data is exchanged. On success, saves
  /// the post-sync vault state as the new baseline for this peer.
  ///
  /// [onProgress], if given, is called once the total is known (with
  /// `completed: 0`) and again after every individual push/pull/deletion
  /// — a plain "syncing…" label doesn't say much for a sync moving more
  /// than a note or two.
  Future<SyncResult> sync(
    MessageChannel channel, {
    required Future<bool> Function(String peerDeviceId) isTrusted,
    void Function(SyncProgress progress)? onProgress,
  }) async {
    final StreamIterator<SyncMessage> incoming = StreamIterator(
      channel.messages(),
    );
    try {
      final HelloMessage peerHello = await _exchangeHello(channel, incoming);

      if (!await isTrusted(peerHello.deviceId)) {
        throw SyncUntrustedPeerException(peerHello.deviceId);
      }

      final SyncManifest localManifest = await buildSyncManifest(repository);
      await channel.send(ManifestMessage(manifest: localManifest));
      final ManifestMessage remoteManifestMessage =
          await _next<ManifestMessage>(incoming);

      final SyncManifest? baseline = await baselineStore.loadBaseline(
        peerHello.deviceId,
      );
      final List<SyncAction> actions = diffManifests(
        localManifest,
        remoteManifestMessage.manifest,
        baseline: baseline,
      );
      final List<SyncAction> pushes = [
        for (final SyncAction action in actions)
          if (action.kind == SyncActionKind.push) action,
      ];
      final List<SyncAction> pulls = [
        for (final SyncAction action in actions)
          if (action.kind == SyncActionKind.pull) action,
      ];
      final List<SyncAction> deletions = [
        for (final SyncAction action in actions)
          if (action.kind == SyncActionKind.deleteLocal) action,
      ];

      final int total = pushes.length + pulls.length + deletions.length;
      int completedCount = 0;
      void reportProgress() {
        onProgress?.call(SyncProgress(completed: completedCount, total: total));
      }

      reportProgress();

      for (final SyncAction action in pushes) {
        final String content = await repository.readNote(action.path);
        await channel.send(
          FileContentMessage(path: action.path, content: content),
        );
        completedCount++;
        reportProgress();
      }

      final Map<String, SyncAction> pullsByPath = {
        for (final SyncAction action in pulls) action.path: action,
      };
      final List<String> conflictPaths = [];
      for (int i = 0; i < pulls.length; i++) {
        final FileContentMessage message = await _next<FileContentMessage>(
          incoming,
        );
        // A path we didn't plan to pull would mean the two sides'
        // diffs disagree (diverged baselines); don't apply content this
        // side decided it didn't want.
        final SyncAction? action = pullsByPath[message.path];
        if (action != null) {
          await _applyPull(action, message.content);
          if (action.conflict) conflictPaths.add(action.path);
        }
        completedCount++;
        reportProgress();
      }

      for (final SyncAction action in deletions) {
        await repository.delete(action.path);
        completedCount++;
        reportProgress();
      }

      // The baseline must be recorded on both sides or on neither: it's
      // what lets the next diff treat a missing path as "deleted on the
      // peer", so a baseline recorded by only one side (this side
      // finished, the peer failed mid-apply) would make the next sync
      // delete notes the peer never actually received. Exchanging done
      // markers first means each side saves only once the other has
      // fully applied too.
      final SyncManifest finalManifest = await buildSyncManifest(repository);
      await channel.send(SyncDoneMessage());
      await _next<SyncDoneMessage>(incoming);
      await baselineStore.saveBaseline(peerHello.deviceId, finalManifest);

      return SyncResult(
        peer: PeerInfo(
          deviceId: peerHello.deviceId,
          name: peerHello.deviceName,
        ),
        conflictPaths: conflictPaths,
      );
    } finally {
      await incoming.cancel();
      await channel.close();
    }
  }

  Future<void> _applyPull(SyncAction action, String remoteContent) async {
    if (action.conflict) {
      final String losingContent = await repository.readNote(action.path);
      await repository.writeNote(
        '${action.path} (конфликт $_conflictSuffix)',
        losingContent,
      );
    }
    await repository.writeNote(action.path, remoteContent);
  }

  String get _conflictSuffix {
    final DateTime now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  Future<T> _next<T extends SyncMessage>(
    StreamIterator<SyncMessage> incoming,
  ) async {
    if (!await incoming.moveNext()) {
      throw StateError('Sync connection closed unexpectedly');
    }
    return incoming.current as T;
  }
}
