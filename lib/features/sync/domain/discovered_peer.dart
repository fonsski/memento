/// A peer device found on the local network via mDNS, not yet paired.
class DiscoveredPeer {
  const DiscoveredPeer({
    required this.deviceId,
    required this.name,
    required this.host,
    required this.port,
  });

  final String deviceId;
  final String name;
  final String host;
  final int port;
}
