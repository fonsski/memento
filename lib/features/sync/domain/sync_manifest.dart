/// A note's state as seen by one device, for comparing against a peer's
/// manifest.
class ManifestEntry {
  const ManifestEntry({
    required this.path,
    required this.modifiedAt,
    required this.contentHash,
  });

  final String path;
  final DateTime modifiedAt;

  /// A fingerprint of the note's content (not the content itself, to
  /// keep manifest exchange lightweight) — differs iff the content does.
  final String contentHash;
}

/// A snapshot of every note in a vault, keyed by path, exchanged between
/// peers to figure out what needs to sync.
class SyncManifest {
  const SyncManifest(this.entries);

  final Map<String, ManifestEntry> entries;
}
