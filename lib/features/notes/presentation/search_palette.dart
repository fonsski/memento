import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/note_search.dart';
import '../domain/note_tree_node.dart';

/// Shows the search palette over [notes] and resolves to the chosen note,
/// or `null` if dismissed without a choice.
Future<NoteTreeNode?> showSearchPalette(
  BuildContext context,
  List<NoteTreeNode> notes,
) {
  return showDialog<NoteTreeNode>(
    context: context,
    builder: (BuildContext context) => SearchPalette(notes: notes),
  );
}

/// A Ctrl/Cmd+K-style overlay: a search field over a live-filtered list of
/// notes, navigable with the arrow keys and Enter, dismissed with Escape.
class SearchPalette extends StatefulWidget {
  const SearchPalette({super.key, required this.notes});

  final List<NoteTreeNode> notes;

  static const double maxWidth = 560;
  static const double maxResultsHeight = 320;

  @override
  State<SearchPalette> createState() => _SearchPaletteState();
}

class _SearchPaletteState extends State<SearchPalette> {
  final TextEditingController _controller = TextEditingController();
  late List<NoteTreeNode> _results = widget.notes;
  int _highlightedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleQueryChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    setState(() {
      _results = searchNotes(widget.notes, _controller.text);
      _highlightedIndex = 0;
    });
  }

  void _moveHighlight(int delta) {
    if (_results.isEmpty) return;
    setState(() {
      _highlightedIndex = (_highlightedIndex + delta) % _results.length;
      if (_highlightedIndex < 0) _highlightedIndex += _results.length;
    });
  }

  void _select(NoteTreeNode note) {
    Navigator.of(context).pop(note);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

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
      if (_results.isNotEmpty) _select(_results[_highlightedIndex]);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 96),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: SearchPalette.maxWidth),
          child: Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.large),
            child: Focus(
              onKeyEvent: _handleKeyEvent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Поиск заметок…',
                      ),
                    ),
                  ),
                  Divider(height: 1, color: theme.dividerColor),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: SearchPalette.maxResultsHeight,
                    ),
                    child: _results.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Ничего не найдено',
                              style: theme.textTheme.bodySmall,
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final NoteTreeNode note = _results[index];
                              return ListTile(
                                dense: true,
                                selected: index == _highlightedIndex,
                                title: Text(note.title),
                                onTap: () => _select(note),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
