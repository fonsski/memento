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

  /// Shared by the wire protocol (sending a manifest to a peer) and the
  /// sync baseline store (persisting one locally as the record of a
  /// peer's last-synced state).
  Map<String, dynamic> toJson() => {
    'entries': [
      for (final ManifestEntry entry in entries.values)
        {
          'path': entry.path,
          'modifiedAt': entry.modifiedAt.toIso8601String(),
          'contentHash': entry.contentHash,
        },
    ],
  };

  static SyncManifest fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawEntries = json['entries'] as List<dynamic>;
    return SyncManifest({
      for (final dynamic raw in rawEntries)
        (raw as Map<String, dynamic>)['path'] as String: ManifestEntry(
          path: raw['path'] as String,
          modifiedAt: DateTime.parse(raw['modifiedAt'] as String),
          contentHash: raw['contentHash'] as String,
        ),
    });
  }
}
