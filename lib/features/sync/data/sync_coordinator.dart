import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../../notes/data/file_system_note_repository.dart';
import '../domain/device_identity.dart';
import '../domain/discovered_peer.dart';
import '../domain/peer_info.dart';
import '../domain/sync_event.dart';
import '../domain/sync_progress.dart';
import '../domain/sync_result.dart';
import '../domain/trusted_peer.dart';
import 'pairing_store.dart';
import 'sync_baseline_store.dart';
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
    required this.baselineStore,
    this.connectTimeout = const Duration(seconds: 10),
  });

  final FileSystemNoteRepository repository;
  final DeviceIdentity identity;
  final PairingStore pairingStore;
  final SyncBaselineStore baselineStore;

  /// How long [pairWithPeer]/[syncWithPeer] wait for the initial TCP
  /// connection before giving up — without this, a peer that's gone
  /// offline (or a firewall silently dropping packets) hangs on the OS's
  /// own default connect timeout, which is often 30s or more, with no
  /// feedback in the meantime. Overridable (rather than a constant) so
  /// tests can use a short one against a deliberately unreachable
  /// address instead of waiting out the real default.
  final Duration connectTimeout;

  final SyncDiscoveryService discovery = SyncDiscoveryService();
  ServerSocket? _serverSocket;
  String? _pendingPairingCode;

  final StreamController<SyncEvent> _events = StreamController.broadcast();

  /// Outcomes of *incoming* connections (a peer pairing with or syncing
  /// against this device) — the only way a UI can learn about those,
  /// since they're handled in the background rather than in response to
  /// a call the UI itself made. [pairWithPeer] and [syncWithPeer] report
  /// their own outcome directly to their caller instead.
  Stream<SyncEvent> get events => _events.stream;

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
    await discovery.startBroadcasting(
      deviceId: identity.id,
      deviceName: identity.name,
      port: port,
    );
    await discovery.startDiscovery(ownDeviceId: identity.id);
  }

  Future<void> stopNetworkDiscovery() async {
    await discovery.stopBroadcasting();
    await discovery.stopDiscovery();
  }

  Future<void> dispose() async {
    _pairingExpiryTimer?.cancel();
    await stopNetworkDiscovery();
    await stopListening();
    await _events.close();
  }

  Timer? _pairingExpiryTimer;

  /// Shows a pairing code, accepting exactly one incoming pairing
  /// attempt with a matching code within [validFor]. Returns the code
  /// to display to the user.
  String beginPairingAsResponder({
    Duration validFor = const Duration(minutes: 2),
  }) {
    final String code = _generatePairingCode();
    _pendingPairingCode = code;
    _pairingExpiryTimer?.cancel();
    _pairingExpiryTimer = Timer(validFor, () {
      if (_pendingPairingCode == code) _pendingPairingCode = null;
    });
    return code;
  }

  void cancelPairing() {
    _pairingExpiryTimer?.cancel();
    _pendingPairingCode = null;
  }

  /// Connects to [peer] and pairs with it using [code] (the code shown
  /// on the peer's screen). Persists the peer as trusted on success.
  Future<PeerInfo> pairWithPeer(DiscoveredPeer peer, String code) async {
    final Socket socket = await Socket.connect(
      peer.host,
      peer.port,
      timeout: connectTimeout,
    );
    final SyncSession session = SyncSession(
      repository: repository,
      localIdentity: identity,
      baselineStore: baselineStore,
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
  Future<SyncResult> syncWithPeer(
    DiscoveredPeer peer, {
    void Function(SyncProgress progress)? onProgress,
  }) async {
    final Socket socket = await Socket.connect(
      peer.host,
      peer.port,
      timeout: connectTimeout,
    );
    final SyncSession session = SyncSession(
      repository: repository,
      localIdentity: identity,
      baselineStore: baselineStore,
    );
    return session.sync(
      MessageChannel(socket),
      isTrusted: pairingStore.isTrusted,
      onProgress: onProgress,
    );
  }

  void _handleIncomingConnection(Socket socket) {
    final MessageChannel channel = MessageChannel(socket);
    final SyncSession session = SyncSession(
      repository: repository,
      localIdentity: identity,
      baselineStore: baselineStore,
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
          _events.add(IncomingPairingAccepted(info.name));
        } catch (error) {
          // Pairing failed (code mismatch, network hiccup, etc.); the
          // peer sees the rejection or the closed connection, and
          // anything showing sync status locally hears about it too.
          _events.add(IncomingPairingFailed(error));
        }
      }());
    } else {
      unawaited(() async {
        try {
          final SyncResult result = await session.sync(
            channel,
            isTrusted: pairingStore.isTrusted,
          );
          _events.add(
            IncomingSyncCompleted(
              result.peer.name,
              conflictPaths: result.conflictPaths,
            ),
          );
        } catch (error) {
          // Incoming sync failed (untrusted peer, network hiccup, etc.);
          // the peer sees the closed connection, and anything showing
          // sync status locally hears about it too.
          _events.add(IncomingSyncFailed(error));
        }
      }());
    }
  }

  static String _generatePairingCode() {
    final Random random = Random.secure();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }
}
