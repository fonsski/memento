import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/memento_colors.dart';
import '../domain/note_repository.dart';
import '../domain/note_tree_node.dart';
import 'markdown_editor.dart';
import 'note_tree.dart';
import 'note_tree_context_menu.dart';
import 'note_tree_dialogs.dart';

/// App shell: a fixed-width sidebar tree next to the main content area.
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
  NoteTreeNode? _selectedNote;

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
      if (_selectedNote?.id == node.id && mounted) {
        setState(() => _selectedNote = NoteTreeNode(id: newPath, title: title));
      }
    });
  }

  Future<void> _delete(NoteTreeNode node) async {
    final bool confirmed = await confirmDelete(context, node.title);
    if (!confirmed || !mounted) return;
    await _runMutation(() async {
      await widget.repository.delete(node.id);
      if (_selectedNote?.id == node.id && mounted) {
        setState(() => _selectedNote = null);
      }
    });
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

    return Scaffold(
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
                    onNewNote: () => _createNote(''),
                    onNewFolder: () => _createFolder(''),
                  ),
                  Expanded(child: _buildTreeArea(theme)),
                ],
              ),
            ),
          ),
          Expanded(
            child: _ContentArea(
              repository: widget.repository,
              selectedNote: _selectedNote,
            ),
          ),
        ],
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
      onNoteSelected: (node) => setState(() => _selectedNote = node),
      onNodeAction: _handleNodeAction,
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.onNewNote, required this.onNewFolder});

  final VoidCallback onNewNote;
  final VoidCallback onNewFolder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
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
  const _ContentArea({required this.repository, required this.selectedNote});

  final NoteRepository repository;
  final NoteTreeNode? selectedNote;

  @override
  Widget build(BuildContext context) {
    final NoteTreeNode? note = selectedNote;
    if (note == null) {
      return const _EmptyArchiveMessage();
    }
    // Keyed by the note's path so switching notes starts a fresh loader
    // and editor instead of reusing stale content/controller state.
    return _NoteEditorLoader(
      key: ValueKey(note.id),
      repository: repository,
      note: note,
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
