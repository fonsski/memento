import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/memento_colors.dart';
import '../domain/note_graph.dart';
import '../domain/note_repository.dart';
import '../domain/note_search.dart';
import '../domain/note_tree_node.dart';
import 'graph_view.dart';
import 'markdown_editor.dart';
import 'note_tab_bar.dart';
import 'note_tree.dart';
import 'note_tree_context_menu.dart';
import 'note_tree_dialogs.dart';
import 'search_palette.dart';

/// App shell: a fixed-width sidebar tree next to open-note tabs and the
/// main content area.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});

  final NoteRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double _sidebarWidth = 260;

  List<NoteTreeNode>? _tree;
  Object? _loadError;
  List<NoteTreeNode> _openNotes = [];
  String? _activeNoteId;
  bool _showGraph = false;
  NoteGraph? _graph;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTree());
  }

  Future<void> _loadTree() async {
    try {
      final List<NoteTreeNode> tree = await widget.repository.loadTree();
      if (mounted) setState(() => _tree = tree);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  void _openNote(NoteTreeNode note) {
    setState(() {
      if (!_openNotes.any((n) => n.id == note.id)) {
        _openNotes = [..._openNotes, note];
      }
      _activeNoteId = note.id;
    });
  }

  void _closeNote(NoteTreeNode note) {
    final int index = _openNotes.indexWhere((n) => n.id == note.id);
    if (index == -1) return;
    setState(() {
      _openNotes = [..._openNotes]..removeAt(index);
      if (_activeNoteId != note.id) return;
      if (_openNotes.isEmpty) {
        _activeNoteId = null;
      } else {
        final int neighbor = index < _openNotes.length
            ? index
            : _openNotes.length - 1;
        _activeNoteId = _openNotes[neighbor].id;
      }
    });
  }

  Future<void> _handleNodeAction(NoteTreeNode node, NoteTreeAction action) {
    switch (action) {
      case NoteTreeAction.newNote:
        return _createNote(node.id);
      case NoteTreeAction.newFolder:
        return _createFolder(node.id);
      case NoteTreeAction.rename:
        return _rename(node);
      case NoteTreeAction.delete:
        return _delete(node);
    }
  }

  Future<void> _createNote(String parentPath) async {
    final String? title = await promptForTitle(
      context,
      dialogTitle: 'Новая заметка',
    );
    if (title == null || !mounted) return;
    await _runMutation(() => widget.repository.createNote(parentPath, title));
  }

  Future<void> _createFolder(String parentPath) async {
    final String? title = await promptForTitle(
      context,
      dialogTitle: 'Новая папка',
    );
    if (title == null || !mounted) return;
    await _runMutation(() => widget.repository.createFolder(parentPath, title));
  }

  Future<void> _rename(NoteTreeNode node) async {
    final String? title = await promptForTitle(
      context,
      dialogTitle: 'Переименовать',
      initialValue: node.title,
    );
    if (title == null || title == node.title || !mounted) return;
    await _runMutation(() async {
      final String newPath = await widget.repository.rename(node.id, title);
      final int index = _openNotes.indexWhere((n) => n.id == node.id);
      if (index != -1 && mounted) {
        setState(() {
          _openNotes = [..._openNotes];
          _openNotes[index] = NoteTreeNode(id: newPath, title: title);
          if (_activeNoteId == node.id) _activeNoteId = newPath;
        });
      }
    });
  }

  Future<void> _delete(NoteTreeNode node) async {
    final bool confirmed = await confirmDelete(context, node.title);
    if (!confirmed || !mounted) return;
    await _runMutation(() async {
      await widget.repository.delete(node.id);
      if (_openNotes.any((n) => n.id == node.id) && mounted) {
        _closeNote(node);
      }
    });
  }

  Future<void> _toggleGraph() async {
    if (_showGraph) {
      setState(() => _showGraph = false);
      return;
    }
    setState(() {
      _showGraph = true;
      _graph = null;
    });
    final NoteGraph graph = await buildNoteGraph(
      widget.repository,
      _tree ?? [],
    );
    if (mounted) setState(() => _graph = graph);
  }

  void _handleGraphNodeTap(GraphNode node) {
    setState(() => _showGraph = false);
    _openNote(NoteTreeNode(id: node.id, title: node.title));
  }

  Future<void> _showSearch() async {
    final List<NoteTreeNode>? tree = _tree;
    if (tree == null) return;
    final NoteTreeNode? selected = await showSearchPalette(
      context,
      flattenNotes(tree),
    );
    if (selected != null) _openNote(selected);
  }

  /// Runs a repository mutation, reloading the tree on success and
  /// surfacing a snackbar on failure (e.g. a duplicate title).
  Future<void> _runMutation(Future<void> Function() action) async {
    try {
      await action();
      await _loadTree();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось выполнить: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MementoColors colors = theme.extension<MementoColors>()!;

    return CallbackShortcuts(
      bindings: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
            _showSearch,
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK):
            _showSearch,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(
            children: [
              Container(
                width: _sidebarWidth,
                decoration: BoxDecoration(
                  color: colors.navPanel,
                  border: Border(right: BorderSide(color: theme.dividerColor)),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      _SidebarHeader(
                        graphActive: _showGraph,
                        onToggleGraph: _toggleGraph,
                        onSearch: _showSearch,
                        onNewNote: () => _createNote(''),
                        onNewFolder: () => _createFolder(''),
                      ),
                      Expanded(child: _buildTreeArea(theme)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _showGraph
                    ? _buildGraphArea(theme)
                    : Column(
                        children: [
                          NoteTabBar(
                            openNotes: _openNotes,
                            activeId: _activeNoteId,
                            onSelect: (note) =>
                                setState(() => _activeNoteId = note.id),
                            onClose: _closeNote,
                          ),
                          if (_openNotes.isNotEmpty)
                            Divider(height: 1, color: theme.dividerColor),
                          Expanded(
                            child: _ContentArea(
                              repository: widget.repository,
                              openNotes: _openNotes,
                              activeNoteId: _activeNoteId,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTreeArea(ThemeData theme) {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Не удалось загрузить заметки',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final List<NoteTreeNode>? tree = _tree;
    if (tree == null) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return NoteTree(
      nodes: tree,
      onNoteSelected: _openNote,
      onNodeAction: _handleNodeAction,
    );
  }

  Widget _buildGraphArea(ThemeData theme) {
    final NoteGraph? graph = _graph;
    if (graph == null) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return GraphView(graph: graph, onNodeTap: _handleGraphNodeTap);
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.graphActive,
    required this.onToggleGraph,
    required this.onSearch,
    required this.onNewNote,
    required this.onNewFolder,
  });

  final bool graphActive;
  final VoidCallback onToggleGraph;
  final VoidCallback onSearch;
  final VoidCallback onNewNote;
  final VoidCallback onNewFolder;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(
              Icons.hub_outlined,
              size: 18,
              color: graphActive ? theme.colorScheme.primary : null,
            ),
            tooltip: 'Граф связей',
            onPressed: onToggleGraph,
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 18),
            tooltip: 'Поиск (Ctrl+K)',
            onPressed: onSearch,
          ),
          IconButton(
            icon: const Icon(Icons.note_add_outlined, size: 18),
            tooltip: 'Новая заметка',
            onPressed: onNewNote,
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined, size: 18),
            tooltip: 'Новая папка',
            onPressed: onNewFolder,
          ),
        ],
      ),
    );
  }
}

class _ContentArea extends StatelessWidget {
  const _ContentArea({
    required this.repository,
    required this.openNotes,
    required this.activeNoteId,
  });

  final NoteRepository repository;
  final List<NoteTreeNode> openNotes;
  final String? activeNoteId;

  @override
  Widget build(BuildContext context) {
    if (openNotes.isEmpty) {
      return const _EmptyArchiveMessage();
    }

    final int activeIndex = openNotes.indexWhere(
      (note) => note.id == activeNoteId,
    );

    // All open notes' editors stay mounted (via IndexedStack) so switching
    // tabs doesn't lose in-flight, not-yet-autosaved edits or reload from
    // disk unnecessarily.
    return IndexedStack(
      index: activeIndex < 0 ? 0 : activeIndex,
      children: [
        for (final NoteTreeNode note in openNotes)
          _NoteEditorLoader(
            key: ValueKey(note.id),
            repository: repository,
            note: note,
          ),
      ],
    );
  }
}

class _EmptyArchiveMessage extends StatelessWidget {
  const _EmptyArchiveMessage();

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Memento', style: textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Место, где мысли остаются навсегда.',
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Loads a note's content, then hands it to a [MarkdownEditor] and
/// autosaves edits after a short pause in typing.
class _NoteEditorLoader extends StatefulWidget {
  const _NoteEditorLoader({
    super.key,
    required this.repository,
    required this.note,
  });

  final NoteRepository repository;
  final NoteTreeNode note;

  static const Duration autosaveDebounce = Duration(milliseconds: 500);

  @override
  State<_NoteEditorLoader> createState() => _NoteEditorLoaderState();
}

class _NoteEditorLoaderState extends State<_NoteEditorLoader> {
  String? _content;
  Timer? _autosaveTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final String content = await widget.repository.readNote(widget.note.id);
    if (mounted) setState(() => _content = content);
  }

  void _handleChanged(String value) {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_NoteEditorLoader.autosaveDebounce, () {
      unawaited(widget.repository.writeNote(widget.note.id, value));
    });
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? content = _content;
    if (content == null) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return MarkdownEditor(initialContent: content, onChanged: _handleChanged);
  }
}
