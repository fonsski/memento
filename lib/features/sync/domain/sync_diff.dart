import 'sync_manifest.dart';

/// Which side should send its content for a given path — or, for
/// [deleteLocal], that nothing needs sending at all.
enum SyncActionKind {
  /// The local side's content should be sent to the peer.
  push,

  /// The peer's content should be written locally.
  pull,

  /// Neither side has content to exchange for this path — it should be
  /// removed locally to honor a deletion the peer made since the last
  /// sync. Applied purely from local state (this device's manifest,
  /// the peer's manifest, and the local baseline for that peer); no
  /// wire message is needed; see [diffManifests]'s doc comment.
  deleteLocal,
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
/// [baseline] — the vault's manifest as of the last successful sync with
/// this specific peer, or `null` if they've never synced — is what tells
/// "new since last sync" apart from "deleted on the other side" for a
/// path missing from one side:
/// - Missing locally, present remotely, and in [baseline]: deleted here
///   since the last sync — nothing to push, and pulling it back would
///   resurrect a deletion made on purpose, so no action is produced at
///   all. The peer reaches the same conclusion independently, from its
///   own manifests and its own copy of this baseline, and deletes its
///   side too — no wire message is needed to tell it to.
/// - Present locally, missing remotely, and in [baseline] with an
///   unchanged hash: the peer deleted it and this side hasn't touched it
///   since, so it's safe to honor that deletion — [SyncActionKind.deleteLocal].
/// - Present locally, missing remotely, but changed since [baseline] (or
///   never in it): either genuinely new locally, or edited here after the
///   peer's deletion — either way the edit wins and gets pushed.
/// - Without a [baseline] at all (first sync with a peer), every
///   one-sided path is treated as new, matching the pre-baseline
///   behavior — there's nothing to compare a deletion against yet.
List<SyncAction> diffManifests(
  SyncManifest local,
  SyncManifest remote, {
  SyncManifest? baseline,
}) {
  final Set<String> allPaths = {...local.entries.keys, ...remote.entries.keys};
  final List<SyncAction> actions = [];

  for (final String path in allPaths) {
    final ManifestEntry? localEntry = local.entries[path];
    final ManifestEntry? remoteEntry = remote.entries[path];
    final ManifestEntry? baselineEntry = baseline?.entries[path];

    if (localEntry == null) {
      if (remoteEntry != null && baselineEntry != null) {
        continue;
      }
      actions.add(
        SyncAction(path: path, kind: SyncActionKind.pull, conflict: false),
      );
      continue;
    }
    if (remoteEntry == null) {
      if (baselineEntry != null &&
          localEntry.contentHash == baselineEntry.contentHash) {
        actions.add(
          SyncAction(
            path: path,
            kind: SyncActionKind.deleteLocal,
            conflict: false,
          ),
        );
        continue;
      }
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
