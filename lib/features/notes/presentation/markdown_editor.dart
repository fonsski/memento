import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_typography.dart';
import '../domain/slash_command.dart';
import 'markdown_syntax_controller.dart';
import 'slash_command_menu.dart';

/// A Markdown editor for a single note: a centered column set in the
/// editor's serif prose style, with WYSIWYG-lite syntax highlighting
/// (dimmed markers, styled headings/bold/italic/code) via
/// [MarkdownSyntaxController], and a "/" quick-insert menu for common
/// blocks.
///
/// The column is a *fraction* of the available width (not a fixed size),
/// so it reads as a spacious page rather than a cramped form field on
/// wide windows, while still capping out at [maxWidth] so lines don't
/// become uncomfortably long on very wide ones.
///
/// Callers should give this widget a key derived from the note's identity
/// (e.g. `ValueKey(note.id)`) so switching notes creates a fresh editor
/// instance instead of reusing a stale [TextEditingController].
class MarkdownEditor extends StatefulWidget {
  const MarkdownEditor({
    super.key,
    required this.initialContent,
    required this.onChanged,
    this.onInsertDrawing,
  });

  final String initialContent;
  final ValueChanged<String> onChanged;

  /// Called when the user picks "Холст для рисования" from the "/" menu;
  /// should return the Markdown to insert (typically an image
  /// reference to a freshly-saved drawing), or `null` if cancelled. The
  /// drawing command is hidden from the menu entirely while this is
  /// `null` (e.g. before the caller can persist an attachment).
  final Future<String?> Function()? onInsertDrawing;

  static const double maxWidth = 900;
  static const double widthFraction = 0.85;
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 48,
    vertical: 64,
  );

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late final MarkdownSyntaxController _controller = MarkdownSyntaxController(
    text: widget.initialContent,
  );

  static const double _bodyFontSize = 16;
  static const double _bodyLineHeightFactor = 1.7;
  static const double _bodyLineHeight = _bodyFontSize * _bodyLineHeightFactor;

  SlashTrigger? _trigger;
  List<SlashCommand> _matches = const [];
  int _highlightedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final TextEditingValue value = _controller.value;
    final SlashTrigger? trigger = detectSlashTrigger(
      value.text,
      value.selection.baseOffset,
    );

    if (trigger == null) {
      if (_trigger != null) setState(() => _trigger = null);
      return;
    }

    final List<SlashCommand> matches = filterSlashCommands(trigger.query)
        .where(
          (command) =>
              command.insertText != null || widget.onInsertDrawing != null,
        )
        .toList();
    setState(() {
      _trigger = trigger;
      _matches = matches;
      _highlightedIndex = 0;
    });
  }

  void _moveHighlight(int delta) {
    if (_matches.isEmpty) return;
    setState(() {
      _highlightedIndex = (_highlightedIndex + delta) % _matches.length;
      if (_highlightedIndex < 0) _highlightedIndex += _matches.length;
    });
  }

  Future<void> _applyCommand(SlashCommand command) async {
    final SlashTrigger trigger = _trigger!;
    setState(() => _trigger = null);

    final String? insertText =
        command.insertText ?? await widget.onInsertDrawing?.call();
    if (insertText == null || !mounted) return;

    final String text = _controller.text;
    // The trigger's range may be stale if something else edited the text
    // while awaiting onInsertDrawing (e.g. autosave doesn't, but a
    // future collaborative edit might) — bail rather than corrupt it.
    if (trigger.end > text.length) return;

    final String newText = text.replaceRange(
      trigger.start,
      trigger.end,
      insertText,
    );
    final int newCursor = trigger.start + insertText.length;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    widget.onChanged(newText);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (_trigger == null || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveHighlight(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveHighlight(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_matches.isNotEmpty) {
        unawaited(_applyCommand(_matches[_highlightedIndex]));
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => _trigger = null);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.onSurface;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double columnWidth =
            (constraints.maxWidth * MarkdownEditor.widthFraction)
                .clamp(0, MarkdownEditor.maxWidth)
                .toDouble();

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: columnWidth),
            child: Focus(
              onKeyEvent: _handleKeyEvent,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: MarkdownEditor.padding,
                    child: TextField(
                      controller: _controller,
                      onChanged: widget.onChanged,
                      maxLines: null,
                      decoration: const InputDecoration(
                        // The app theme sets an explicit OutlineInputBorder
                        // as both enabledBorder and focusedBorder; setting
                        // only `border: InputBorder.none` doesn't suppress
                        // those (Flutter falls back to the theme's named
                        // borders when enabledBorder/focusedBorder aren't
                        // set locally), so every state needs to be nulled
                        // out here too.
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        isCollapsed: true,
                      ),
                      style: AppEditorTextStyles.body(color),
                      cursorColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (_trigger != null) _buildMenu(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Positions the menu below the line the trigger is on. This only
  /// tracks *which line* (via a newline count, not a full text layout),
  /// so it lands in the right vertical neighborhood rather than exactly
  /// under the "/" horizontally — a deliberate, much simpler trade-off
  /// than measuring the real caret position via the field's RenderEditable.
  Widget _buildMenu() {
    final SlashTrigger trigger = _trigger!;
    final int line = '\n'
        .allMatches(_controller.text.substring(0, trigger.start))
        .length;
    final double top =
        MarkdownEditor.padding.top + (line + 1) * _bodyLineHeight;

    return Positioned(
      top: top,
      left: MarkdownEditor.padding.left,
      child: SlashCommandMenu(
        commands: _matches,
        highlightedIndex: _highlightedIndex,
        onSelect: (command) => unawaited(_applyCommand(command)),
      ),
    );
  }
}
