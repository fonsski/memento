/// Something that happened on an *incoming* connection — a peer pairing
/// with or syncing against this device — that a UI showing sync status
/// wouldn't otherwise learn about, since `SyncCoordinator` handles those
/// connections in the background rather than in response to a user
/// action here.
sealed class SyncEvent {
  const SyncEvent();
}

/// A peer successfully paired with this device (they knew the code we
/// were showing).
class IncomingPairingAccepted extends SyncEvent {
  const IncomingPairingAccepted(this.peerName);

  final String peerName;
}

/// An incoming pairing attempt failed — wrong code, or the connection
/// dropped mid-handshake.
class IncomingPairingFailed extends SyncEvent {
  const IncomingPairingFailed(this.error);

  final Object error;
}

/// A trusted peer successfully synced against this device.
class IncomingSyncCompleted extends SyncEvent {
  const IncomingSyncCompleted(this.peerName);

  final String peerName;
}

/// An incoming sync attempt failed — an untrusted peer, or a network or
/// file I/O error partway through.
class IncomingSyncFailed extends SyncEvent {
  const IncomingSyncFailed(this.error);

  final Object error;
}
