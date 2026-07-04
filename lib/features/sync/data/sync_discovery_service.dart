import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

import '../domain/discovered_peer.dart';

/// The mDNS/Bonjour service type Memento instances broadcast and look
/// for on the local network.
const String syncServiceType = '_memento-sync._tcp';

/// Broadcasts this device's sync port on the LAN and/or discovers other
/// Memento instances doing the same, via `bonsoir` (mDNS/Bonjour, NSD).
///
/// This talks to real OS-level network services and plugin platform
/// channels, so it cannot be exercised by `flutter test` — verify it
/// manually against a real second device.
class SyncDiscoveryService {
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  final Map<String, DiscoveredPeer> _peers = {};
  final StreamController<List<DiscoveredPeer>> _peersController =
      StreamController<List<DiscoveredPeer>>.broadcast();

  /// The current set of discovered peers, emitted again on every change.
  Stream<List<DiscoveredPeer>> get peers => _peersController.stream;

  Future<void> startBroadcasting({
    required String deviceName,
    required int port,
  }) async {
    final BonsoirService service = BonsoirService(
      name: deviceName,
      type: syncServiceType,
      port: port,
    );
    final BonsoirBroadcast broadcast = BonsoirBroadcast(service: service);
    await broadcast.initialize();
    await broadcast.start();
    _broadcast = broadcast;
  }

  Future<void> stopBroadcasting() async {
    await _broadcast?.stop();
    _broadcast = null;
  }

  Future<void> startDiscovery() async {
    final BonsoirDiscovery discovery = BonsoirDiscovery(type: syncServiceType);
    await discovery.initialize();
    discovery.eventStream?.listen(_handleEvent);
    await discovery.start();
    _discovery = discovery;
  }

  Future<void> stopDiscovery() async {
    await _discovery?.stop();
    _discovery = null;
    _peers.clear();
  }

  void _handleEvent(BonsoirDiscoveryEvent event) {
    final BonsoirDiscovery? discovery = _discovery;
    if (discovery == null) return;

    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent():
        event.service.resolve(discovery.serviceResolver);
      case BonsoirDiscoveryServiceResolvedEvent():
        final BonsoirService service = event.service;
        final String? host = service.hostAddresses.isNotEmpty
            ? service.hostAddresses.first
            : service.hostname;
        if (host != null) {
          _peers[service.name] = DiscoveredPeer(
            name: service.name,
            host: host,
            port: service.port,
          );
          _peersController.add(_peers.values.toList());
        }
      case BonsoirDiscoveryServiceLostEvent():
        _peers.remove(event.service.name);
        _peersController.add(_peers.values.toList());
      default:
        break;
    }
  }

  Future<void> dispose() async {
    await stopBroadcasting();
    await stopDiscovery();
    await _peersController.close();
  }
}
