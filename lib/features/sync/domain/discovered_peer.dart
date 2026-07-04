/// A peer device found on the local network via mDNS, not yet paired.
class DiscoveredPeer {
  const DiscoveredPeer({
    required this.name,
    required this.host,
    required this.port,
  });

  final String name;
  final String host;
  final int port;
}
