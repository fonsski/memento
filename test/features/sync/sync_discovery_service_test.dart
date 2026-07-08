import 'package:bonsoir/bonsoir.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/sync/data/sync_discovery_service.dart';
import 'package:memento/features/sync/domain/discovered_peer.dart';

// SyncDiscoveryService itself talks to real mDNS via platform channels
// and can't run under flutter test (see its doc comment) — these cover
// the pure service-to-peer mapping it dispatches resolved services
// through, which is where the discovery bugs found in live testing
// lived: listing one's own broadcast as a peer, and picking an IPv6
// link-local address the IPv4-only listener can never be reached on.
void main() {
  BonsoirService service({
    Map<String, String> attributes = const {},
    List<String> hostAddresses = const [],
    String? hostname,
    String name = 'fon-linux-abc123',
    int port = 41163,
  }) {
    return BonsoirService(
      name: name,
      type: syncServiceType,
      port: port,
      hostAddresses: hostAddresses,
      hostname: hostname,
      attributes: attributes,
    );
  }

  group('discoveredPeerFromService', () {
    test('maps a resolved peer, preferring its IPv4 address', () {
      final DiscoveredPeer? peer = discoveredPeerFromService(
        service(
          attributes: {'deviceId': 'peer-id', 'deviceName': 'Ноутбук'},
          hostAddresses: ['fe80::2007:500f:1af6:6156', '192.168.1.10'],
          hostname: 'fon-linux.local',
        ),
        ownDeviceId: 'my-id',
      );

      expect(peer, isNotNull);
      expect(peer!.deviceId, 'peer-id');
      expect(peer.name, 'Ноутбук');
      expect(peer.host, '192.168.1.10');
      expect(peer.port, 41163);
    });

    test('filters out this device\'s own broadcast', () {
      final DiscoveredPeer? peer = discoveredPeerFromService(
        service(
          attributes: {'deviceId': 'my-id', 'deviceName': 'Ноутбук'},
          hostAddresses: ['192.168.1.10'],
        ),
        ownDeviceId: 'my-id',
      );

      expect(peer, isNull);
    });

    test('ignores services without a device id attribute', () {
      final DiscoveredPeer? peer = discoveredPeerFromService(
        service(hostAddresses: ['192.168.1.10']),
        ownDeviceId: 'my-id',
      );

      expect(peer, isNull);
    });

    test(
      'falls back to the .local hostname when only IPv6 addresses are given',
      () {
        final DiscoveredPeer? peer = discoveredPeerFromService(
          service(
            attributes: {'deviceId': 'peer-id'},
            hostAddresses: ['fe80::2007:500f:1af6:6156'],
            hostname: 'fon-linux.local',
          ),
          ownDeviceId: 'my-id',
        );

        expect(peer, isNotNull);
        expect(peer!.host, 'fon-linux.local');
      },
    );

    test('returns null when there is no usable address at all', () {
      final DiscoveredPeer? peer = discoveredPeerFromService(
        service(attributes: {'deviceId': 'peer-id'}),
        ownDeviceId: 'my-id',
      );

      expect(peer, isNull);
    });

    test(
      'falls back to the service name when no display name attribute is set',
      () {
        final DiscoveredPeer? peer = discoveredPeerFromService(
          service(
            attributes: {'deviceId': 'peer-id'},
            hostAddresses: ['192.168.1.10'],
            name: 'fon-linux-abc123',
          ),
          ownDeviceId: 'my-id',
        );

        expect(peer!.name, 'fon-linux-abc123');
      },
    );
  });

  group('serviceNameFor', () {
    test('appends a device-id prefix so equal device names stay unique', () {
      final String a = serviceNameFor(
        deviceId: 'aaaaaa1111',
        deviceName: 'fon-linux',
      );
      final String b = serviceNameFor(
        deviceId: 'bbbbbb2222',
        deviceName: 'fon-linux',
      );

      expect(a, isNot(b));
      expect(a, startsWith('fon-linux-'));
    });

    test('handles device ids shorter than the prefix length', () {
      expect(serviceNameFor(deviceId: 'ab', deviceName: 'x'), 'x-ab');
    });
  });

  group('handleDiscoveryEvent bookkeeping', () {
    test('a resolved service lands in currentPeers even with no subscriber, '
        'so a late-opened panel can seed itself', () {
      final SyncDiscoveryService discovery = SyncDiscoveryService(
        ownDeviceId: 'my-id',
      );

      discovery.handleDiscoveryEvent(
        BonsoirDiscoveryServiceResolvedEvent(
          service: service(
            attributes: {'deviceId': 'peer-id', 'deviceName': 'Ноутбук'},
            hostAddresses: ['192.168.1.10'],
          ),
        ),
      );

      expect(discovery.currentPeers, hasLength(1));
      expect(discovery.currentPeers.single.deviceId, 'peer-id');
    });

    test('a lost service is removed from currentPeers', () {
      final SyncDiscoveryService discovery = SyncDiscoveryService(
        ownDeviceId: 'my-id',
      );
      final BonsoirService resolved = service(
        attributes: {'deviceId': 'peer-id'},
        hostAddresses: ['192.168.1.10'],
      );

      discovery.handleDiscoveryEvent(
        BonsoirDiscoveryServiceResolvedEvent(service: resolved),
      );
      discovery.handleDiscoveryEvent(
        BonsoirDiscoveryServiceLostEvent(service: resolved),
      );

      expect(discovery.currentPeers, isEmpty);
    });

    test('this device\'s own broadcast never enters currentPeers', () {
      final SyncDiscoveryService discovery = SyncDiscoveryService(
        ownDeviceId: 'my-id',
      );

      discovery.handleDiscoveryEvent(
        BonsoirDiscoveryServiceResolvedEvent(
          service: service(
            attributes: {'deviceId': 'my-id'},
            hostAddresses: ['192.168.1.10'],
          ),
        ),
      );

      expect(discovery.currentPeers, isEmpty);
    });

    test('changes are also emitted on the peers stream', () async {
      final SyncDiscoveryService discovery = SyncDiscoveryService(
        ownDeviceId: 'my-id',
      );
      final Future<List<DiscoveredPeer>> firstEmission = discovery.peers.first;

      discovery.handleDiscoveryEvent(
        BonsoirDiscoveryServiceResolvedEvent(
          service: service(
            attributes: {'deviceId': 'peer-id'},
            hostAddresses: ['192.168.1.10'],
          ),
        ),
      );

      expect(await firstEmission, hasLength(1));
    });
  });
}
