import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../../notes/data/file_system_note_repository.dart';
import '../domain/device_identity.dart';
import '../domain/discovered_peer.dart';
import '../domain/peer_info.dart';
import '../domain/trusted_peer.dart';
import 'pairing_store.dart';
import 'sync_discovery_service.dart';
import 'sync_session.dart';
import 'sync_wire.dart';

/// Ties discovery, pairing and syncing together: listens for incoming
/// connections, dispatches them to pairing or syncing depending on
/// whether a pairing code is currently being shown, and drives outbound
/// pairing/sync attempts against discovered peers.
///
/// [startListening] only opens a plain TCP listener (real dart:io,
/// testable via loopback). [startNetworkDiscovery] layers mDNS
/// broadcast/discovery on top via [SyncDiscoveryService] — that part
/// can't be exercised by `flutter test` (see its doc comment).
class SyncCoordinator {
  SyncCoordinator({
    required this.repository,
    required this.identity,
    required this.pairingStore,
  });

  final FileSystemNoteRepository repository;
  final DeviceIdentity identity;
  final PairingStore pairingStore;

  final SyncDiscoveryService discovery = SyncDiscoveryService();
  ServerSocket? _serverSocket;
  String? _pendingPairingCode;

  int? get listeningPort => _serverSocket?.port;

  Future<int> startListening() async {
    final ServerSocket serverSocket = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      0,
    );
    serverSocket.listen(_handleIncomingConnection);
    _serverSocket = serverSocket;
    return serverSocket.port;
  }

  Future<void> stopListening() async {
    await _serverSocket?.close();
    _serverSocket = null;
  }

  Future<void> startNetworkDiscovery() async {
    final int? port = _serverSocket?.port;
    if (port == null) {
      throw StateError('Call startListening() before startNetworkDiscovery()');
    }
    await discovery.startBroadcasting(deviceName: identity.name, port: port);
    await discovery.startDiscovery();
  }

  Future<void> stopNetworkDiscovery() async {
    await discovery.stopBroadcasting();
    await discovery.stopDiscovery();
  }

  Future<void> dispose() async {
    await stopNetworkDiscovery();
    await stopListening();
  }

  /// Shows a pairing code, accepting exactly one incoming pairing
  /// attempt with a matching code within [validFor]. Returns the code
  /// to display to the user.
  String beginPairingAsResponder({
    Duration validFor = const Duration(minutes: 2),
  }) {
    final String code = _generatePairingCode();
    _pendingPairingCode = code;
    Timer(validFor, () {
      if (_pendingPairingCode == code) _pendingPairingCode = null;
    });
    return code;
  }

  void cancelPairing() => _pendingPairingCode = null;

  /// Connects to [peer] and pairs with it using [code] (the code shown
  /// on the peer's screen). Persists the peer as trusted on success.
  Future<PeerInfo> pairWithPeer(DiscoveredPeer peer, String code) async {
    final Socket socket = await Socket.connect(peer.host, peer.port);
    final SyncSession session = SyncSession(
      repository: repository,
      localIdentity: identity,
    );
    final PeerInfo info = await session.pair(
      MessageChannel(socket),
      code: code,
    );
    await pairingStore.addTrustedPeer(
      TrustedPeer(deviceId: info.deviceId, name: info.name),
    );
    return info;
  }

  /// Connects to an already-trusted [peer] and runs a full sync.
  Future<PeerInfo> syncWithPeer(DiscoveredPeer peer) async {
    final Socket socket = await Socket.connect(peer.host, peer.port);
    final SyncSession session = SyncSession(
      repository: repository,
      localIdentity: identity,
    );
    return session.sync(
      MessageChannel(socket),
      isTrusted: pairingStore.isTrusted,
    );
  }

  void _handleIncomingConnection(Socket socket) {
    final MessageChannel channel = MessageChannel(socket);
    final SyncSession session = SyncSession(
      repository: repository,
      localIdentity: identity,
    );
    final String? code = _pendingPairingCode;

    if (code != null) {
      unawaited(() async {
        try {
          final PeerInfo info = await session.respondToPairing(
            channel,
            expectedCode: code,
          );
          await pairingStore.addTrustedPeer(
            TrustedPeer(deviceId: info.deviceId, name: info.name),
          );
        } catch (_) {
          // Pairing failed (code mismatch, network hiccup, etc.); the
          // peer sees the rejection or the closed connection.
        }
      }());
    } else {
      unawaited(() async {
        try {
          await session.sync(channel, isTrusted: pairingStore.isTrusted);
        } catch (_) {
          // Incoming sync failed (untrusted peer, network hiccup,
          // etc.); the peer sees the closed connection.
        }
      }());
    }
  }

  static String _generatePairingCode() {
    final Random random = Random.secure();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }
}
