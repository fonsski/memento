import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/notes/data/file_system_note_repository.dart';
import 'package:memento/features/notes/presentation/drawing_canvas.dart';

void main() {
  late Directory vaultRoot;

  setUp(() async {
    vaultRoot = await Directory.systemTemp.createTemp('memento_drawing_test');
  });

  tearDown(() async {
    if (vaultRoot.existsSync()) {
      await vaultRoot.delete(recursive: true);
    }
  });

  // See home_screen_test.dart for why the whole gesture-to-real-I/O chain
  // must run inside a single runAsync() call, and why pumpAndSettle() is
  // avoided in favor of polling.
  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    int maxTries = 50,
  }) async {
    const Duration step = Duration(milliseconds: 100);
    for (int i = 0; i < maxTries; i++) {
      await Future<void>.delayed(step);
      await tester.pump(step);
      if (condition()) return;
    }
    if (!condition()) {
      throw StateError('Condition not met after ${maxTries * 100}ms');
    }
  }

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('cancel returns null and saves nothing', (
    WidgetTester tester,
  ) async {
    String? result = 'unset';
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showDrawingCanvasDialog(
                context,
                FileSystemNoteRepository(vaultRoot),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(Directory('${vaultRoot.path}/attachments').existsSync(), isFalse);
  });

  testWidgets(
    'drawing a stroke and saving persists an attachment and returns its path',
    (WidgetTester tester) async {
      String? path;
      final FileSystemNoteRepository repository = FileSystemNoteRepository(
        vaultRoot,
      );

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                path = await showDrawingCanvasDialog(context, repository);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        await tester.tap(find.text('Open'));
        await pumpUntil(
          tester,
          () => find.byType(DrawingCanvas).evaluate().isNotEmpty,
        );

        await tester.drag(find.byType(CustomPaint).first, const Offset(60, 40));
        await tester.pump();

        await tester.tap(find.text('Сохранить'));
        await pumpUntil(tester, () => path != null);
      });

      expect(path, isNotNull);
      expect(path, startsWith('attachments/'));
      expect(File('${vaultRoot.path}/$path').existsSync(), isTrue);
    },
  );

  testWidgets('still draws when the dialog is short enough to need scrolling', (
    WidgetTester tester,
  ) async {
    // Regression test: a GestureDetector's pan recognizer nested inside
    // a scrollable can lose the gesture arena to the ancestor's own
    // vertical drag recognizer once there's actually room to scroll.
    // The default test viewport is large enough that the dialog never
    // needs to scroll, so that conflict never triggered there — shrink
    // it here to force the SingleChildScrollView to engage.
    tester.view.physicalSize = const Size(500, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    String? path;
    final FileSystemNoteRepository repository = FileSystemNoteRepository(
      vaultRoot,
    );

    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              path = await showDrawingCanvasDialog(context, repository);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      await tester.tap(find.text('Open'));
      await pumpUntil(
        tester,
        () => find.byType(DrawingCanvas).evaluate().isNotEmpty,
      );

      await tester.drag(find.byType(CustomPaint).first, const Offset(60, 40));
      await tester.pump();

      await tester.ensureVisible(find.text('Сохранить'));
      await tester.pump();
      await tester.tap(find.text('Сохранить'));
      await pumpUntil(tester, () => path != null);
    });

    expect(path, isNotNull);
    expect(File('${vaultRoot.path}/$path').existsSync(), isTrue);
  });

  testWidgets('selecting a palette color highlights only that swatch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(const DrawingCanvas()));

    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color == Colors.red,
      ),
    );
    await tester.pump();

    final Container redSwatch = tester.widget(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color == Colors.red,
      ),
    );
    final BoxDecoration decoration = redSwatch.decoration! as BoxDecoration;
    expect((decoration.border as Border).top.color, isNot(Colors.transparent));
  });

  testWidgets('toggling the eraser highlights its icon button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(const DrawingCanvas()));

    Icon eraserIcon() => tester.widget(
      find.descendant(
        of: find.byTooltip('Ластик'),
        matching: find.byType(Icon),
      ),
    );

    expect(eraserIcon().color, isNull);

    await tester.tap(find.byTooltip('Ластик'));
    await tester.pump();

    expect(eraserIcon().color, isNotNull);
  });

  testWidgets('undo and clear are harmless with no strokes yet', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(const DrawingCanvas()));

    await tester.tap(find.byTooltip('Отменить'));
    await tester.tap(find.byTooltip('Очистить'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
