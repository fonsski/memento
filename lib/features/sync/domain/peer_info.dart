/// Identity of the peer at the other end of a sync connection, as it
/// introduced itself.
class PeerInfo {
  const PeerInfo({required this.deviceId, required this.name});

  final String deviceId;
  final String name;
}
