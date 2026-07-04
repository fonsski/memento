import 'dart:io';

import 'package:flutter/gestures.dart';
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

  // Every gesture that (directly or indirectly, via an awaited dialog) ends
  // up calling the real NoteRepository must run inside the *same* runAsync()
  // call as that eventual repository call: an async function resumes in
  // whatever zone it first suspended in, not the zone of whatever later
  // resolves it. Splitting a rename/delete flow's taps across multiple
  // runAsync calls (or partly outside runAsync) leaves the repository
  // call's continuation pinned to testWidgets()'s fake zone, where real
  // dart:io callbacks never fire.
  //
  // How long that real I/O takes varies with machine load, so instead of a
  // fixed delay we poll: pump, check the condition, repeat.
  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    int maxTries = 50,
  }) async {
    const Duration step = Duration(milliseconds: 100);
    for (int i = 0; i < maxTries; i++) {
      await Future<void>.delayed(step);
      // Pump *with* a duration: a bare pump() advances by zero simulated
      // time, so animation-driven tickers (e.g. a dialog's exit
      // transition) never progress even though real time passes. Pump
      // *before* checking: a preceding gesture's setState may not have
      // been applied to the element tree yet, so checking first can
      // wrongly conclude the condition already holds.
      await tester.pump(step);
      if (condition()) return;
    }
    if (!condition()) {
      throw StateError('Condition not met after ${maxTries * 100}ms');
    }
  }

  bool treeLoaded() =>
      find.byType(CircularProgressIndicator).evaluate().isEmpty;

  testWidgets('selecting a note loads its content into the editor', (
    WidgetTester tester,
  ) async {
    final FileSystemNoteRepository repository = FileSystemNoteRepository(
      vaultRoot,
    );

    await tester.runAsync(() async {
      await repository.createNote('', 'О проекте');
      await repository.writeNote('О проекте', 'Содержимое заметки');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: HomeScreen(repository: repository),
        ),
      );
      await pumpUntil(tester, treeLoaded);

      await tester.tap(find.text('О проекте'));
      // Selecting a note triggers its own (separate) content load, which
      // briefly shows another CircularProgressIndicator.
      await pumpUntil(tester, treeLoaded);
    });
    await tester.pump();

    expect(find.text('Место, где мысли остаются навсегда.'), findsNothing);
    expect(find.text('Содержимое заметки'), findsOneWidget);
  });

  testWidgets('autosaves edits to the note after a debounce', (
    WidgetTester tester,
  ) async {
    final FileSystemNoteRepository repository = FileSystemNoteRepository(
      vaultRoot,
    );
    final File file = File('${vaultRoot.path}/Заметка.md');

    await tester.runAsync(() async {
      await repository.createNote('', 'Заметка');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: HomeScreen(repository: repository),
        ),
      );
      await pumpUntil(tester, treeLoaded);

      await tester.tap(find.text('Заметка'));
      await pumpUntil(tester, treeLoaded);

      await tester.enterText(find.byType(TextField), 'новый текст');
      await pumpUntil(tester, () => file.readAsStringSync() == 'новый текст');
    });
    await tester.pump();

    expect(file.readAsStringSync(), 'новый текст');
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
      await pumpUntil(tester, treeLoaded);
    });
    await tester.pump();

    expect(find.text('Memento'), findsOneWidget);
  });

  testWidgets('creates a root note via the header button', (
    WidgetTester tester,
  ) async {
    final FileSystemNoteRepository repository = FileSystemNoteRepository(
      vaultRoot,
    );
    final File noteFile = File('${vaultRoot.path}/Новая идея.md');

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: HomeScreen(repository: repository),
        ),
      );
      await pumpUntil(tester, treeLoaded);

      await tester.tap(find.byIcon(Icons.note_add_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Новая идея');
      await tester.tap(find.text('Сохранить'));
      await pumpUntil(tester, noteFile.existsSync);
      // The reload after the write is a second real round-trip; wait for
      // the tree to actually show it (findsOneWidget, not the still-open
      // dialog's EditableText too).
      await pumpUntil(
        tester,
        () => find.text('Новая идея').evaluate().length == 1,
      );
    });
    await tester.pump();

    expect(
      noteFile.existsSync(),
      isTrue,
      reason: 'the note must actually be written to disk, not just shown',
    );
    expect(find.text('Новая идея'), findsOneWidget);
  });

  testWidgets('renames a note via the context menu', (
    WidgetTester tester,
  ) async {
    final FileSystemNoteRepository repository = FileSystemNoteRepository(
      vaultRoot,
    );
    final File newFile = File('${vaultRoot.path}/Новое имя.md');

    await tester.runAsync(() async {
      await repository.createNote('', 'Старое имя');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: HomeScreen(repository: repository),
        ),
      );
      await pumpUntil(tester, treeLoaded);

      await tester.tap(find.text('Старое имя'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Переименовать'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Новое имя');
      await tester.tap(find.text('Сохранить'));
      await pumpUntil(tester, newFile.existsSync);
      await pumpUntil(
        tester,
        () => find.text('Новое имя').evaluate().length == 1,
      );
    });
    await tester.pump();

    expect(newFile.existsSync(), isTrue);
    expect(File('${vaultRoot.path}/Старое имя.md').existsSync(), isFalse);
    expect(find.text('Новое имя'), findsOneWidget);
    expect(find.text('Старое имя'), findsNothing);
  });

  testWidgets('deletes a note via the context menu after confirmation', (
    WidgetTester tester,
  ) async {
    final FileSystemNoteRepository repository = FileSystemNoteRepository(
      vaultRoot,
    );
    final File noteFile = File('${vaultRoot.path}/Удалить меня.md');

    await tester.runAsync(() async {
      await repository.createNote('', 'Удалить меня');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: HomeScreen(repository: repository),
        ),
      );
      await pumpUntil(tester, treeLoaded);

      await tester.tap(find.text('Удалить меня'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить'));
      await pumpUntil(tester, () => !noteFile.existsSync());
      await pumpUntil(
        tester,
        () => find.text('Удалить меня').evaluate().isEmpty,
      );
    });
    await tester.pump();

    expect(noteFile.existsSync(), isFalse);
    expect(find.text('Удалить меня'), findsNothing);
  });
}
