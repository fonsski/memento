/// A peer device the user has paired with, trusted for future syncs
/// without re-confirming a pairing code.
class TrustedPeer {
  const TrustedPeer({required this.deviceId, required this.name});

  final String deviceId;
  final String name;
}
