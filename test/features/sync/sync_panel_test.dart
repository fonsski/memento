import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memento/core/theme/app_theme.dart';
import 'package:memento/features/notes/data/file_system_note_repository.dart';
import 'package:memento/features/sync/data/pairing_store.dart';
import 'package:memento/features/sync/data/sync_baseline_store.dart';
import 'package:memento/features/sync/data/sync_coordinator.dart';
import 'package:memento/features/sync/data/sync_discovery_service.dart';
import 'package:memento/features/sync/domain/device_identity.dart';
import 'package:memento/features/sync/domain/discovered_peer.dart';
import 'package:memento/features/sync/domain/trusted_peer.dart';
import 'package:memento/features/sync/presentation/sync_panel.dart';
import 'package:path/path.dart' as p;

Future<SyncCoordinator> _setUpCoordinator(
  List<Directory> tempDirs,
  String deviceId,
  String deviceName,
) async {
  final Directory vaultRoot = await Directory.systemTemp.createTemp(
    'memento_syncpanel_$deviceId',
  );
  final Directory settingsDir = await Directory.systemTemp.createTemp(
    'memento_syncpanel_settings_$deviceId',
  );
  tempDirs.addAll([vaultRoot, settingsDir]);
  final SyncCoordinator coordinator = SyncCoordinator(
    repository: FileSystemNoteRepository(vaultRoot),
    identity: DeviceIdentity(id: deviceId, name: deviceName),
    pairingStore: PairingStore(File(p.join(settingsDir.path, 'peers.json'))),
    baselineStore: SyncBaselineStore(
      Directory(p.join(settingsDir.path, 'sync_baselines')),
    ),
  );
  await coordinator.startListening();
  return coordinator;
}

void main() {
  final List<Directory> tempDirs = [];

  tearDown(() async {
    for (final Directory dir in tempDirs) {
      if (dir.existsSync()) await dir.delete(recursive: true);
    }
    tempDirs.clear();
  });

  Widget wrap(WidgetBuilder builder) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Builder(builder: builder),
    );
  }

  // testWidgets() wraps the *entire* test body in a fake async zone, so
  // every real dart:io call — not just pumpWidget — needs runAsync():
  // creating the coordinator/its temp vault/its TCP listener, and
  // disposing it again at the end (closing the ServerSocket apparently
  // leaves something in the fake zone's pending-timer queue otherwise,
  // which the test framework then waits on forever).
  testWidgets('shows a message when no devices are known', (
    WidgetTester tester,
  ) async {
    late SyncCoordinator coordinator;

    await tester.runAsync(() async {
      coordinator = await _setUpCoordinator(tempDirs, 'a', 'Ноутбук');
      await tester.pumpWidget(
        wrap((context) => SyncPanel(coordinator: coordinator)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.text('Пока ничего не найдено рядом'), findsOneWidget);

    await tester.runAsync(() => coordinator.dispose());
  });

  testWidgets('shows a 6-digit pairing code when requested', (
    WidgetTester tester,
  ) async {
    late SyncCoordinator coordinator;

    await tester.runAsync(() async {
      coordinator = await _setUpCoordinator(tempDirs, 'a', 'Ноутбук');
      await tester.pumpWidget(
        wrap((context) => SyncPanel(coordinator: coordinator)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    await tester.tap(find.text('Показать код для сопряжения'));
    await tester.pump();

    expect(find.textContaining(RegExp(r'^\d{6}$')), findsOneWidget);

    await tester.runAsync(() => coordinator.dispose());
  });

  testWidgets('shows a peer that was discovered before the panel was opened', (
    WidgetTester tester,
  ) async {
    // Regression test: discovery runs from app launch and its stream
    // doesn't replay, so peers found before the panel opened (i.e.
    // usually all of them) never appeared — leaving no device list
    // and nowhere to enter a pairing code.
    late SyncCoordinator coordinator;

    await tester.runAsync(() async {
      coordinator = await _setUpCoordinator(tempDirs, 'a', 'Ноутбук');
      // Simulate a peer resolved by mDNS before the panel exists.
      coordinator.discovery.handleDiscoveryEvent(
        BonsoirDiscoveryServiceResolvedEvent(
          service: BonsoirService(
            name: 'fon-linux-bbbbbb',
            type: syncServiceType,
            port: 12345,
            hostAddresses: const ['192.168.1.20'],
            attributes: const {'deviceId': 'b', 'deviceName': 'Телефон'},
          ),
        ),
      );
      await tester.pumpWidget(
        wrap((context) => SyncPanel(coordinator: coordinator)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.text('Телефон'), findsOneWidget);
    expect(find.text('Сопряжить'), findsOneWidget);

    await tester.runAsync(() => coordinator.dispose());
  });

  testWidgets('shows a trusted-but-offline device without a sync button', (
    WidgetTester tester,
  ) async {
    late SyncCoordinator coordinator;

    await tester.runAsync(() async {
      coordinator = await _setUpCoordinator(tempDirs, 'a', 'Ноутбук');
      await coordinator.pairingStore.addTrustedPeer(
        const TrustedPeer(deviceId: 'b', name: 'Телефон'),
      );
      await tester.pumpWidget(
        wrap((context) => SyncPanel(coordinator: coordinator)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.text('Телефон'), findsOneWidget);
    final TextButton button = tester.widget(
      find.widgetWithText(TextButton, 'Синхронизировать'),
    );
    expect(button.onPressed, isNull);

    await tester.runAsync(() => coordinator.dispose());
  });

  testWidgets('shows a status message when a peer pairs with this device', (
    WidgetTester tester,
  ) async {
    // Regression test: incoming connections used to be handled
    // entirely silently — a peer pairing with this device left no
    // trace in an already-open panel.
    late SyncCoordinator coordinator;
    late SyncCoordinator peerCoordinator;
    late String code;

    await tester.runAsync(() async {
      coordinator = await _setUpCoordinator(tempDirs, 'a', 'Ноутбук');
      peerCoordinator = await _setUpCoordinator(tempDirs, 'b', 'Телефон');
      await tester.pumpWidget(
        wrap((context) => SyncPanel(coordinator: coordinator)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    await tester.tap(find.text('Показать код для сопряжения'));
    await tester.pump();
    code = tester.widget<Text>(find.textContaining(RegExp(r'^\d{6}$'))).data!;

    await tester.runAsync(() async {
      final DiscoveredPeer peer = DiscoveredPeer(
        deviceId: 'a',
        name: 'Ноутбук',
        host: '127.0.0.1',
        port: coordinator.listeningPort!,
      );
      await peerCoordinator.pairWithPeer(peer, code);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.textContaining('Сопряжено с'), findsOneWidget);

    await tester.runAsync(() async {
      await coordinator.dispose();
      await peerCoordinator.dispose();
    });
  });

  testWidgets('shows a conflict message when an incoming sync produces one', (
    WidgetTester tester,
  ) async {
    // Regression test: a conflict was previously only visible as an
    // unannounced ".conflict-<timestamp>" file sitting in the tree.
    late SyncCoordinator coordinator;
    late SyncCoordinator peerCoordinator;

    await tester.runAsync(() async {
      coordinator = await _setUpCoordinator(tempDirs, 'a', 'Ноутбук');
      peerCoordinator = await _setUpCoordinator(tempDirs, 'b', 'Телефон');
      await coordinator.pairingStore.addTrustedPeer(
        const TrustedPeer(deviceId: 'b', name: 'Телефон'),
      );
      await peerCoordinator.pairingStore.addTrustedPeer(
        const TrustedPeer(deviceId: 'a', name: 'Ноутбук'),
      );

      // A's copy is older, so when B syncs against A, A is the side
      // that loses and preserves a conflict copy of its own content.
      await coordinator.repository.createNote('', 'Заметка');
      await peerCoordinator.repository.createNote('', 'Заметка');
      await coordinator.repository.writeNote('Заметка', 'старая версия (А)');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await peerCoordinator.repository.writeNote('Заметка', 'новая версия (Б)');

      await tester.pumpWidget(
        wrap((context) => SyncPanel(coordinator: coordinator)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    await tester.runAsync(() async {
      final DiscoveredPeer peer = DiscoveredPeer(
        deviceId: 'a',
        name: 'Ноутбук',
        host: '127.0.0.1',
        port: coordinator.listeningPort!,
      );
      // B connects out to A, so A (this panel's coordinator) is the one
      // receiving an incoming sync.
      await peerCoordinator.syncWithPeer(peer);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.textContaining('Конфликт'), findsOneWidget);

    await tester.runAsync(() async {
      await coordinator.dispose();
      await peerCoordinator.dispose();
    });
  });
}
