import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memento/core/theme/app_theme.dart';
import 'package:memento/features/notes/data/file_system_note_repository.dart';
import 'package:memento/features/sync/data/pairing_store.dart';
import 'package:memento/features/sync/data/sync_coordinator.dart';
import 'package:memento/features/sync/domain/device_identity.dart';
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
}
