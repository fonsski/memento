import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';

import '../domain/discovered_peer.dart';

/// The mDNS/Bonjour service type Memento instances broadcast and look
/// for on the local network.
const String syncServiceType = '_memento-sync._tcp';

/// The TXT attribute keys a broadcast carries alongside the service.
const String deviceIdAttribute = 'deviceId';
const String deviceNameAttribute = 'deviceName';

/// The unique mDNS service (instance) name for a device. Device *names*
/// alone aren't unique — they default to the hostname, so two instances
/// on one machine (or two same-named laptops) would collide and mDNS
/// would rename or reject the second broadcast. The human-readable name
/// travels in [deviceNameAttribute] instead, and the instance name gets
/// a device-id prefix appended purely for uniqueness.
String serviceNameFor({required String deviceId, required String deviceName}) {
  final String suffix = deviceId.length <= 6
      ? deviceId
      : deviceId.substring(0, 6);
  return '$deviceName-$suffix';
}

/// Converts a *resolved* Bonsoir [service] to a [DiscoveredPeer], or
/// `null` for services that shouldn't be listed:
/// - ones missing a device id (not a Memento peer, or not resolved yet);
/// - this device's own broadcast (mDNS discovery reports it back like
///   any other service; [ownDeviceId] filters it out so the device
///   doesn't list itself as a pairable peer);
/// - ones with no usable address at all.
///
/// Among [BonsoirService.hostAddresses], IPv4 is preferred: the sync
/// TCP listener binds `anyIPv4`, and mDNS resolvers often list an IPv6
/// link-local (`fe80::...`) address first, which would need a scope id
/// to even connect and points at a port nothing listens on. The
/// `.local` hostname is the fallback when no IPv4 address is given.
DiscoveredPeer? discoveredPeerFromService(
  BonsoirService service, {
  required String ownDeviceId,
}) {
  final String? deviceId = service.attributes[deviceIdAttribute];
  if (deviceId == null || deviceId == ownDeviceId) return null;

  final String? host = _selectHost(service.hostAddresses, service.hostname);
  if (host == null) return null;

  return DiscoveredPeer(
    deviceId: deviceId,
    name: service.attributes[deviceNameAttribute] ?? service.name,
    host: host,
    port: service.port,
  );
}

String? _selectHost(List<String> addresses, String? hostname) {
  for (final String address in addresses) {
    if (!address.contains(':')) return address;
  }
  return hostname;
}

/// Broadcasts this device's sync port on the LAN and/or discovers other
/// Memento instances doing the same, via `bonsoir` (mDNS/Bonjour, NSD).
///
/// This talks to real OS-level network services and plugin platform
/// channels, so it cannot be exercised by `flutter test` — verify it
/// manually against a real second device. The pure service-to-peer
/// mapping ([discoveredPeerFromService]) is testable on its own.
class SyncDiscoveryService {
  SyncDiscoveryService({required this.ownDeviceId});

  /// This device's own id, used to filter its own broadcast out of the
  /// results — see [discoveredPeerFromService].
  final String ownDeviceId;

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  final Map<String, DiscoveredPeer> _peers = {};
  final StreamController<List<DiscoveredPeer>> _peersController =
      StreamController<List<DiscoveredPeer>>.broadcast();

  /// The current set of discovered peers, emitted again on every change.
  ///
  /// This is a broadcast stream: it does NOT replay to late subscribers,
  /// so anything building UI from it must seed itself from
  /// [currentPeers] first — otherwise peers discovered before the
  /// subscription (typically all of them, discovery starts at app
  /// launch) are invisible until the next network change.
  Stream<List<DiscoveredPeer>> get peers => _peersController.stream;

  /// The peers discovered so far — the snapshot to pair with [peers].
  List<DiscoveredPeer> get currentPeers => List.unmodifiable(_peers.values);

  Future<void> startBroadcasting({
    required String deviceId,
    required String deviceName,
    required int port,
  }) async {
    final BonsoirService service = BonsoirService(
      name: serviceNameFor(deviceId: deviceId, deviceName: deviceName),
      type: syncServiceType,
      port: port,
      attributes: {
        deviceIdAttribute: deviceId,
        deviceNameAttribute: deviceName,
      },
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
    discovery.eventStream?.listen(handleDiscoveryEvent);
    await discovery.start();
    _discovery = discovery;
  }

  Future<void> stopDiscovery() async {
    await _discovery?.stop();
    _discovery = null;
    _peers.clear();
  }

  /// Visible for testing: the mDNS plumbing that produces these events
  /// needs real platform channels, but the bookkeeping they drive
  /// (which is where the "panel shows nothing" class of bug lives) is
  /// pure and worth covering.
  @visibleForTesting
  void handleDiscoveryEvent(BonsoirDiscoveryEvent event) {
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent():
        // Found services carry no addresses yet; ask the OS to resolve.
        final BonsoirDiscovery? discovery = _discovery;
        if (discovery != null) {
          event.service.resolve(discovery.serviceResolver);
        }
      case BonsoirDiscoveryServiceResolvedEvent():
        final DiscoveredPeer? peer = discoveredPeerFromService(
          event.service,
          ownDeviceId: ownDeviceId,
        );
        if (peer != null) {
          _peers[event.service.name] = peer;
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
