import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../domain/note_repository.dart';

/// Opens the [DrawingCanvas] dialog and, if the user saves a drawing,
/// rasterizes it and persists it via [repository]. Returns the
/// vault-relative attachment path, or `null` if the user cancelled.
///
/// This is the concrete implementation behind `BlockEditor.onRequestDrawing`.
Future<String?> showDrawingCanvasDialog(
  BuildContext context,
  NoteRepository repository,
) async {
  final Uint8List? bytes = await showDialog<Uint8List>(
    context: context,
    builder: (context) => const DrawingCanvas(),
  );
  if (bytes == null) return null;
  return repository.saveAttachment(bytes);
}

class _Stroke {
  _Stroke({required this.color, required this.width}) : points = [];

  final Color color;
  final double width;
  final List<Offset> points;
}

/// A freehand drawing surface: pen color/width, an eraser, undo, and
/// clear. Pops the dialog with the rasterized PNG bytes on save, or
/// `null` on cancel — it has no knowledge of vaults or attachments,
/// only of pixels (see [showDrawingCanvasDialog] for the save step).
///
/// The eraser is implemented as a wider stroke in the canvas's own
/// background color (white) rather than a true `BlendMode.clear`, since
/// this is simpler and the canvas background never varies.
class DrawingCanvas extends StatefulWidget {
  const DrawingCanvas({super.key});

  static const Size canvasSize = Size(640, 420);
  static const Color backgroundColor = Colors.white;

  static const List<Color> palette = [
    Colors.black,
    Colors.red,
    Colors.orange,
    Colors.green,
    Colors.blue,
    Colors.purple,
  ];

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  final GlobalKey _boundaryKey = GlobalKey();
  final List<_Stroke> _strokes = [];
  Color _color = DrawingCanvas.palette.first;
  double _width = 4;
  bool _eraser = false;

  void _startStroke(Offset point) {
    setState(() {
      _strokes.add(
        _Stroke(
          color: _eraser ? DrawingCanvas.backgroundColor : _color,
          width: _eraser ? _width * 3 : _width,
        )..points.add(point),
      );
    });
  }

  void _extendStroke(Offset point) {
    setState(() => _strokes.last.points.add(point));
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(_strokes.removeLast);
  }

  void _clear() {
    if (_strokes.isEmpty) return;
    setState(_strokes.clear);
  }

  Future<void> _save() async {
    // toImage() asserts that the boundary has no pending paint — tapping
    // Save is itself part of the frame that reconciles the last stroke,
    // so wait for that frame to fully land first.
    await WidgetsBinding.instance.endOfFrame;
    final RenderRepaintBoundary boundary =
        _boundaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (!mounted || bytes == null) return;
    Navigator.of(context).pop(bytes.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        // Scrollable so the fixed-size canvas below never triggers a
        // layout overflow on short windows — the canvas itself is what
        // gets rasterized, so its size can't just shrink to fit.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToolbar(Theme.of(context)),
              const SizedBox(height: 8),
              RepaintBoundary(
                key: _boundaryKey,
                child: Container(
                  width: DrawingCanvas.canvasSize.width,
                  height: DrawingCanvas.canvasSize.height,
                  color: DrawingCanvas.backgroundColor,
                  child: GestureDetector(
                    onPanStart: (details) =>
                        _startStroke(details.localPosition),
                    onPanUpdate: (details) =>
                        _extendStroke(details.localPosition),
                    child: CustomPaint(
                      size: DrawingCanvas.canvasSize,
                      painter: _StrokePainter(_strokes),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Сохранить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    return Row(
      children: [
        for (final Color color in DrawingCanvas.palette)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => setState(() {
                _color = color;
                _eraser = false;
              }),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: !_eraser && _color == color
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Slider(
            value: _width,
            min: 2,
            max: 20,
            onChanged: (value) => setState(() => _width = value),
          ),
        ),
        IconButton(
          tooltip: 'Ластик',
          icon: Icon(
            Icons.auto_fix_normal,
            color: _eraser ? theme.colorScheme.primary : null,
          ),
          onPressed: () => setState(() => _eraser = !_eraser),
        ),
        IconButton(
          tooltip: 'Отменить',
          icon: const Icon(Icons.undo),
          onPressed: _undo,
        ),
        IconButton(
          tooltip: 'Очистить',
          icon: const Icon(Icons.delete_outline),
          onPressed: _clear,
        ),
      ],
    );
  }
}

class _StrokePainter extends CustomPainter {
  _StrokePainter(this.strokes);

  final List<_Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final _Stroke stroke in strokes) {
      final Paint paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        canvas.drawPoints(ui.PointMode.points, stroke.points, paint);
        continue;
      }
      for (int i = 0; i < stroke.points.length - 1; i++) {
        canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) =>
      !identical(oldDelegate.strokes, strokes);
}
