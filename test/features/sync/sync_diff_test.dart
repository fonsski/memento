import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/sync/domain/sync_diff.dart';
import 'package:memento/features/sync/domain/sync_manifest.dart';

void main() {
  final DateTime t0 = DateTime(2026);
  final DateTime t1 = t0.add(const Duration(minutes: 1));

  ManifestEntry entry(String path, DateTime modifiedAt, String hash) {
    return ManifestEntry(path: path, modifiedAt: modifiedAt, contentHash: hash);
  }

  test('a path only on the remote side is pulled', () {
    const SyncManifest local = SyncManifest({});
    final SyncManifest remote = SyncManifest({'a': entry('a', t0, 'hash-a')});

    final List<SyncAction> actions = diffManifests(local, remote);

    expect(actions, [
      const SyncAction(path: 'a', kind: SyncActionKind.pull, conflict: false),
    ]);
  });

  test('a path only on the local side is pushed', () {
    final SyncManifest local = SyncManifest({'a': entry('a', t0, 'hash-a')});
    const SyncManifest remote = SyncManifest({});

    final List<SyncAction> actions = diffManifests(local, remote);

    expect(actions, [
      const SyncAction(path: 'a', kind: SyncActionKind.push, conflict: false),
    ]);
  });

  test('identical content on both sides is a no-op', () {
    final SyncManifest local = SyncManifest({'a': entry('a', t0, 'same')});
    final SyncManifest remote = SyncManifest({'a': entry('a', t1, 'same')});

    expect(diffManifests(local, remote), isEmpty);
  });

  test('newer local content wins and is flagged as a conflict', () {
    final SyncManifest local = SyncManifest({'a': entry('a', t1, 'new')});
    final SyncManifest remote = SyncManifest({'a': entry('a', t0, 'old')});

    final List<SyncAction> actions = diffManifests(local, remote);

    expect(actions, [
      const SyncAction(path: 'a', kind: SyncActionKind.push, conflict: true),
    ]);
  });

  test('newer remote content wins and is flagged as a conflict', () {
    final SyncManifest local = SyncManifest({'a': entry('a', t0, 'old')});
    final SyncManifest remote = SyncManifest({'a': entry('a', t1, 'new')});

    final List<SyncAction> actions = diffManifests(local, remote);

    expect(actions, [
      const SyncAction(path: 'a', kind: SyncActionKind.pull, conflict: true),
    ]);
  });

  test('an exact tie deterministically prefers the remote side', () {
    final SyncManifest local = SyncManifest({'a': entry('a', t0, 'local')});
    final SyncManifest remote = SyncManifest({'a': entry('a', t0, 'remote')});

    final List<SyncAction> actions = diffManifests(local, remote);

    expect(actions.single.kind, SyncActionKind.pull);
    expect(actions.single.conflict, isTrue);
  });

  test('multiple paths are returned sorted by path', () {
    final SyncManifest local = SyncManifest({
      'z': entry('z', t0, 'z-hash'),
      'a': entry('a', t0, 'a-hash'),
    });
    const SyncManifest remote = SyncManifest({});

    final List<SyncAction> actions = diffManifests(local, remote);

    expect(actions.map((a) => a.path).toList(), ['a', 'z']);
  });

  test('two empty manifests produce no actions', () {
    expect(
      diffManifests(const SyncManifest({}), const SyncManifest({})),
      isEmpty,
    );
  });

  group('with a baseline', () {
    test('a path deleted locally since the baseline produces no action, '
        'rather than being pulled back', () {
      const SyncManifest local = SyncManifest({});
      final SyncManifest remote = SyncManifest({'a': entry('a', t0, 'h')});
      final SyncManifest baseline = SyncManifest({'a': entry('a', t0, 'h')});

      expect(diffManifests(local, remote, baseline: baseline), isEmpty);
    });

    test(
      'a path new on the remote (never in the baseline) is still pulled',
      () {
        const SyncManifest local = SyncManifest({});
        final SyncManifest remote = SyncManifest({'a': entry('a', t0, 'h')});
        const SyncManifest baseline = SyncManifest({});

        final List<SyncAction> actions = diffManifests(
          local,
          remote,
          baseline: baseline,
        );

        expect(actions, [
          const SyncAction(
            path: 'a',
            kind: SyncActionKind.pull,
            conflict: false,
          ),
        ]);
      },
    );

    test('a path deleted remotely since the baseline, untouched locally, '
        'is deleted locally', () {
      final SyncManifest local = SyncManifest({'a': entry('a', t0, 'h')});
      const SyncManifest remote = SyncManifest({});
      final SyncManifest baseline = SyncManifest({'a': entry('a', t0, 'h')});

      final List<SyncAction> actions = diffManifests(
        local,
        remote,
        baseline: baseline,
      );

      expect(actions, [
        const SyncAction(
          path: 'a',
          kind: SyncActionKind.deleteLocal,
          conflict: false,
        ),
      ]);
    });

    test('a path edited locally after the peer deleted it keeps the edit '
        'and pushes it, rather than deleting it', () {
      final SyncManifest local = SyncManifest({'a': entry('a', t1, 'new')});
      const SyncManifest remote = SyncManifest({});
      final SyncManifest baseline = SyncManifest({'a': entry('a', t0, 'old')});

      final List<SyncAction> actions = diffManifests(
        local,
        remote,
        baseline: baseline,
      );

      expect(actions, [
        const SyncAction(path: 'a', kind: SyncActionKind.push, conflict: false),
      ]);
    });

    test('a path new locally (never in the baseline) is still pushed', () {
      final SyncManifest local = SyncManifest({'a': entry('a', t0, 'h')});
      const SyncManifest remote = SyncManifest({});
      const SyncManifest baseline = SyncManifest({});

      final List<SyncAction> actions = diffManifests(
        local,
        remote,
        baseline: baseline,
      );

      expect(actions, [
        const SyncAction(path: 'a', kind: SyncActionKind.push, conflict: false),
      ]);
    });

    test('without a baseline, one-sided paths are always treated as new', () {
      const SyncManifest local = SyncManifest({});
      final SyncManifest remote = SyncManifest({'a': entry('a', t0, 'h')});

      final List<SyncAction> actions = diffManifests(local, remote);

      expect(actions, [
        const SyncAction(path: 'a', kind: SyncActionKind.pull, conflict: false),
      ]);
    });
  });
}
