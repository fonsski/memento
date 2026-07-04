/// This device's identity for P2P pairing: a stable random id (so peers
/// can recognize it across reconnects) and a human-readable name shown
/// during pairing.
class DeviceIdentity {
  const DeviceIdentity({required this.id, required this.name});

  final String id;
  final String name;
}
