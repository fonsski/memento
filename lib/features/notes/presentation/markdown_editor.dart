import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import 'markdown_syntax_controller.dart';

/// A Markdown editor for a single note: a centered, book-width column set
/// in the editor's serif prose style, with WYSIWYG-lite syntax
/// highlighting (dimmed markers, styled headings/bold/italic/code) via
/// [MarkdownSyntaxController].
///
/// Callers should give this widget a key derived from the note's identity
/// (e.g. `ValueKey(note.id)`) so switching notes creates a fresh editor
/// instance instead of reusing a stale [TextEditingController].
class MarkdownEditor extends StatefulWidget {
  const MarkdownEditor({
    super.key,
    required this.initialContent,
    required this.onChanged,
  });

  final String initialContent;
  final ValueChanged<String> onChanged;

  static const double maxWidth = 720;

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late final MarkdownSyntaxController _controller = MarkdownSyntaxController(
    text: widget.initialContent,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.onSurface;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: MarkdownEditor.maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: TextField(
            controller: _controller,
            onChanged: widget.onChanged,
            maxLines: null,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
            ),
            style: AppEditorTextStyles.body(color),
            cursorColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
