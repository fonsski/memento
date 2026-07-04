import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/memento_colors.dart';
import '../domain/note_repository.dart';
import '../domain/note_tree_node.dart';
import 'note_tree.dart';

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
            child: SafeArea(child: _buildSidebarContent(theme)),
          ),
          Expanded(child: _ContentArea(selectedNote: _selectedNote)),
        ],
      ),
    );
  }

  Widget _buildSidebarContent(ThemeData theme) {
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
    );
  }
}

class _ContentArea extends StatelessWidget {
  const _ContentArea({required this.selectedNote});

  final NoteTreeNode? selectedNote;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final NoteTreeNode? note = selectedNote;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: note == null
            ? Column(
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
              )
            : Text(note.title, style: textTheme.headlineMedium),
      ),
    );
  }
}
