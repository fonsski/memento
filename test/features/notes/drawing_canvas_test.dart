import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/notes/data/file_system_note_repository.dart';
import 'package:memento/features/notes/presentation/drawing_canvas.dart';

/// A minimal valid 2x2 black PNG, used to seed an "existing" attachment
/// on disk directly rather than creating one by driving the dialog —
/// see the tests that reopen an existing drawing.
const List<int> tinyPngBytes = [
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  2,
  0,
  0,
  0,
  2,
  8,
  2,
  0,
  0,
  0,
  253,
  212,
  154,
  115,
  0,
  0,
  0,
  11,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  96,
  64,
  6,
  0,
  0,
  14,
  0,
  1,
  169,
  145,
  115,
  177,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];

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

  Future<bool> fileHasNonWhitePixel(File file) async {
    final Uint8List bytes = await file.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ByteData rgba = (await frame.image.toByteData())!;
    for (int i = 0; i + 2 < rgba.lengthInBytes; i += 4) {
      if (rgba.getUint8(i) != 255 ||
          rgba.getUint8(i + 1) != 255 ||
          rgba.getUint8(i + 2) != 255) {
        return true;
      }
    }
    return false;
  }

  // DrawingCanvas decodes a preloaded background image via a real,
  // unawaited Future kicked off from initState(). If the dialog is
  // popped (e.g. by tapping Save) before that Future resolves, it keeps
  // running abandoned in the runAsync() zone — which was observed to
  // make the test binding hang indefinitely during teardown, waiting for
  // it. Polling for the background to actually be in place before
  // interacting further avoids ever leaving it dangling.
  bool backgroundLoaded(WidgetTester tester) {
    final Finder finder = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.size == DrawingCanvas.canvasSize,
    );
    if (finder.evaluate().isEmpty) return false;
    final CustomPaint customPaint = tester.widget(finder);
    final dynamic painter = customPaint.painter;
    return painter.background != null;
  }

  // Resolves an ImageProvider fully, the way Image.file does when it's
  // actually displayed — used to prime PaintingBinding's cache the same
  // way showing the drawing block in a note would.
  Future<void> resolveImage(ImageProvider provider) {
    final Completer<void> completer = Completer<void>();
    late ImageStreamListener listener;
    final ImageStream stream = provider.resolve(ImageConfiguration.empty);
    listener = ImageStreamListener((image, synchronousCall) {
      stream.removeListener(listener);
      completer.complete();
    });
    stream.addListener(listener);
    return completer.future;
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

  testWidgets(
    'the saved attachment actually contains the drawn stroke, not a blank '
    'canvas',
    (WidgetTester tester) async {
      // Regression test: CustomPainter.shouldRepaint used to compare the
      // strokes list by identity, but strokes are appended to that same
      // list instance in place rather than replacing it — so the
      // comparison always saw "no change" and the canvas never actually
      // repainted after the first (blank) frame, no matter how much was
      // drawn.
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

      // Let the dialog's closing animation (and any overscroll/ripple
      // effects it started) fully settle before decoding the saved file,
      // so no real Timer from those outlives this test.
      await tester.pumpAndSettle();

      bool hasNonWhitePixel = false;
      await tester.runAsync(() async {
        final Uint8List savedBytes = await File(
          '${vaultRoot.path}/$path',
        ).readAsBytes();
        final ui.Codec codec = await ui.instantiateImageCodec(savedBytes);
        final ui.FrameInfo frame = await codec.getNextFrame();
        final ByteData rgba = (await frame.image.toByteData())!;
        for (int i = 0; i + 2 < rgba.lengthInBytes; i += 4) {
          if (rgba.getUint8(i) != 255 ||
              rgba.getUint8(i + 1) != 255 ||
              rgba.getUint8(i + 2) != 255) {
            hasNonWhitePixel = true;
            break;
          }
        }
      });

      expect(hasNonWhitePixel, isTrue);
    },
  );

  testWidgets(
    'reopening an existing drawing preserves it if saved without new edits',
    (WidgetTester tester) async {
      // Regression test: reopening a drawing block always started from a
      // blank canvas, discarding whatever was drawn before — confirmed on
      // a screen recording where an existing drawing reset to white as
      // soon as its dialog was reopened. Seeds the "existing" attachment
      // directly on disk (rather than creating it via a first open/save
      // pass through the dialog) so this only exercises one decode/encode
      // cycle — cycling the dialog open/closed twice in one test was
      // observed to make the test binding hang during teardown.
      final Directory attachmentsDir = Directory(
        '${vaultRoot.path}/attachments',
      )..createSync(recursive: true);
      final String existingAbsolutePath = '${attachmentsDir.path}/existing.png';
      File(existingAbsolutePath).writeAsBytesSync(tinyPngBytes);
      const String existingRelativePath = 'attachments/existing.png';

      final FileSystemNoteRepository repository = FileSystemNoteRepository(
        vaultRoot,
      );
      String? path;

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                path = await showDrawingCanvasDialog(
                  context,
                  repository,
                  existingRelativePath: existingRelativePath,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      bool stillHasContent = false;
      await tester.runAsync(() async {
        await tester.tap(find.text('Open'));
        await pumpUntil(tester, () => backgroundLoaded(tester));
        // Save immediately, without drawing anything new.
        await tester.tap(find.text('Сохранить'));
        await pumpUntil(tester, () => path != null);

        // fileHasNonWhitePixel does real file/decode I/O, which — like
        // the rest of this chain — only resolves inside runAsync().
        stillHasContent = await fileHasNonWhitePixel(
          File('${vaultRoot.path}/$path'),
        );
      });

      expect(path, existingRelativePath);
      expect(stillHasContent, isTrue);
    },
  );

  testWidgets(
    'reopening an existing drawing overwrites the same attachment rather '
    'than creating a new one',
    (WidgetTester tester) async {
      final Directory attachmentsDir = Directory(
        '${vaultRoot.path}/attachments',
      )..createSync(recursive: true);
      final String existingAbsolutePath = '${attachmentsDir.path}/existing.png';
      File(existingAbsolutePath).writeAsBytesSync(tinyPngBytes);
      const String existingRelativePath = 'attachments/existing.png';

      final FileSystemNoteRepository repository = FileSystemNoteRepository(
        vaultRoot,
      );
      String? path;

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                path = await showDrawingCanvasDialog(
                  context,
                  repository,
                  existingRelativePath: existingRelativePath,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        await tester.tap(find.text('Open'));
        await pumpUntil(tester, () => backgroundLoaded(tester));
        await tester.drag(find.byType(CustomPaint).first, const Offset(60, 40));
        await tester.pump();
        await tester.tap(find.text('Сохранить'));
        await pumpUntil(tester, () => path != null);
      });

      expect(path, existingRelativePath);
      expect(attachmentsDir.listSync().whereType<File>().length, 1);
    },
  );

  testWidgets(
    'overwriting an existing drawing evicts it from the image cache so the '
    'note shows the new version',
    (WidgetTester tester) async {
      // Regression test: Image.file (as used to display a drawing block)
      // caches by file path. Since reopening now overwrites the same
      // path instead of creating a new file, the note kept showing
      // whatever had been decoded from that path before — the file on
      // disk was correctly updated, but the displayed image wasn't.
      final Directory attachmentsDir = Directory(
        '${vaultRoot.path}/attachments',
      )..createSync(recursive: true);
      final String existingAbsolutePath = '${attachmentsDir.path}/existing.png';
      final File existingFile = File(existingAbsolutePath)
        ..writeAsBytesSync(tinyPngBytes);
      const String existingRelativePath = 'attachments/existing.png';
      final FileImage fileImage = FileImage(existingFile);

      final FileSystemNoteRepository repository = FileSystemNoteRepository(
        vaultRoot,
      );
      String? path;

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                path = await showDrawingCanvasDialog(
                  context,
                  repository,
                  existingRelativePath: existingRelativePath,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        // Simulate the note having already displayed this drawing once.
        await resolveImage(fileImage);
        expect(
          PaintingBinding.instance.imageCache.containsKey(fileImage),
          isTrue,
        );

        await tester.tap(find.text('Open'));
        await pumpUntil(tester, () => backgroundLoaded(tester));
        await tester.drag(find.byType(CustomPaint).first, const Offset(60, 40));
        await tester.pump();
        await tester.tap(find.text('Сохранить'));
        await pumpUntil(tester, () => path != null);
      });

      expect(path, existingRelativePath);
      expect(
        PaintingBinding.instance.imageCache.containsKey(fileImage),
        isFalse,
      );
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

  testWidgets(
    'clips the paint surface to the canvas so a drag past its edge cannot '
    'draw over the toolbar or dialog buttons',
    (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const DrawingCanvas()));

      final Finder strokePainter = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.size == DrawingCanvas.canvasSize,
      );

      // Ancestor ClipRects also exist elsewhere in the Dialog/Material
      // chrome, so just finding *a* ClipRect ancestor would pass even
      // without ours — check specifically for one sized to the canvas
      // itself, which only the fix under test adds.
      final Iterable<Element> clipRectAncestors = find
          .ancestor(of: strokePainter, matching: find.byType(ClipRect))
          .evaluate();
      final bool hasCanvasSizedClip = clipRectAncestors.any(
        (element) =>
            (element.renderObject! as RenderBox).size ==
            DrawingCanvas.canvasSize,
      );

      expect(hasCanvasSizedClip, isTrue);
    },
  );
}
