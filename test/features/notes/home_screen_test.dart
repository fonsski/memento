import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memento/core/theme/app_theme.dart';
import 'package:memento/features/notes/data/file_system_note_repository.dart';
import 'package:memento/features/notes/presentation/home_screen.dart';

void main() {
  late Directory vaultRoot;

  setUp(() async {
    vaultRoot = await Directory.systemTemp.createTemp('memento_home_test');
  });

  tearDown(() async {
    if (vaultRoot.existsSync()) {
      await vaultRoot.delete(recursive: true);
    }
  });

  testWidgets('selecting a note replaces the empty-state content', (
    WidgetTester tester,
  ) async {
    final FileSystemNoteRepository repository = FileSystemNoteRepository(
      vaultRoot,
    );

    // Real dart:io work needs the real event loop, which testWidgets()
    // otherwise fakes; runAsync() opts back into it.
    await tester.runAsync(() async {
      await repository.createNote('', 'О проекте');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: HomeScreen(repository: repository),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.text('О проекте'), findsOneWidget);

    await tester.tap(find.text('О проекте'));
    await tester.pumpAndSettle();

    expect(find.text('Место, где мысли остаются навсегда.'), findsNothing);
    expect(find.text('О проекте'), findsWidgets);
  });

  testWidgets('shows an empty tree for a freshly created vault', (
    WidgetTester tester,
  ) async {
    final FileSystemNoteRepository repository = FileSystemNoteRepository(
      vaultRoot,
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: HomeScreen(repository: repository),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.text('Memento'), findsOneWidget);
  });
}
