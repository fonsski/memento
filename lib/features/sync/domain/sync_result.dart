import 'peer_info.dart';

/// The outcome of a completed sync: who it was with, and which note
/// paths (if any) had a genuine content conflict — both sides had
/// changed the note since the last sync, so this device's older content
/// was preserved as a `.conflict-<timestamp>` copy rather than silently
/// discarded when the peer's newer version was written in its place.
///
/// Only conflicts *this device* resolved locally are listed here — when
/// this device's content wins instead, the peer is the one preserving
/// its own losing copy, and reports that in its own [SyncResult].
class SyncResult {
  const SyncResult({required this.peer, required this.conflictPaths});

  final PeerInfo peer;
  final List<String> conflictPaths;
}
