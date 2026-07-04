import 'sync_manifest.dart';

/// Which side should send its content for a given path.
enum SyncActionKind {
  /// The local side's content should be sent to the peer.
  push,

  /// The peer's content should be written locally.
  pull,
}

/// One path that needs to sync, from the local side's perspective.
class SyncAction {
  const SyncAction({
    required this.path,
    required this.kind,
    required this.conflict,
  });

  final String path;
  final SyncActionKind kind;

  /// True when this overwrites existing, differing content on the
  /// losing side — that side should preserve its current content as a
  /// `.conflict-<timestamp>` copy before applying the change.
  final bool conflict;

  @override
  bool operator ==(Object other) =>
      other is SyncAction &&
      other.path == path &&
      other.kind == kind &&
      other.conflict == conflict;

  @override
  int get hashCode => Object.hash(path, kind, conflict);

  @override
  String toString() => 'SyncAction($path, $kind, conflict: $conflict)';
}

/// Compares [local] against [remote] and decides, for every path that
/// differs, which side's content should win.
///
/// This is last-write-wins by modification time: a path present on only
/// one side is copied to the other; a path present on both with the same
/// content hash is left alone; otherwise the more recently modified side
/// wins (ties go to the remote side, arbitrarily but deterministically).
///
/// Known limitation: without a persisted baseline from the previous sync,
/// a path missing from one side can't be told apart from "new since last
/// sync" vs. "deleted on the other side" — it is always treated as new
/// and copied over, so a deletion made offline on one device can
/// resurrect the note when it next syncs.
List<SyncAction> diffManifests(SyncManifest local, SyncManifest remote) {
  final Set<String> allPaths = {...local.entries.keys, ...remote.entries.keys};
  final List<SyncAction> actions = [];

  for (final String path in allPaths) {
    final ManifestEntry? localEntry = local.entries[path];
    final ManifestEntry? remoteEntry = remote.entries[path];

    if (localEntry == null) {
      actions.add(
        SyncAction(path: path, kind: SyncActionKind.pull, conflict: false),
      );
      continue;
    }
    if (remoteEntry == null) {
      actions.add(
        SyncAction(path: path, kind: SyncActionKind.push, conflict: false),
      );
      continue;
    }
    if (localEntry.contentHash == remoteEntry.contentHash) {
      continue;
    }

    final bool localIsNewer = localEntry.modifiedAt.isAfter(
      remoteEntry.modifiedAt,
    );
    actions.add(
      SyncAction(
        path: path,
        kind: localIsNewer ? SyncActionKind.push : SyncActionKind.pull,
        conflict: true,
      ),
    );
  }

  actions.sort((a, b) => a.path.compareTo(b.path));
  return actions;
}
