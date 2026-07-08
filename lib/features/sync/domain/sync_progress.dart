/// How far a sync has gotten: [completed] note transfers/deletions done
/// so far out of [total] planned for this sync (pushes + pulls +
/// deletions combined). Reported via `SyncSession.sync`'s `onProgress`
/// callback so a UI showing a bare "syncing…" label can show something
/// more concrete for syncs involving more than a note or two.
class SyncProgress {
  const SyncProgress({required this.completed, required this.total});

  final int completed;
  final int total;
}
