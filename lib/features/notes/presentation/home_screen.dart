import 'package:flutter/material.dart';

import '../../../core/theme/memento_colors.dart';
import '../data/sample_note_tree.dart';
import '../domain/note_tree_node.dart';
import 'note_tree.dart';

/// App shell: a fixed-width sidebar tree next to the main content area.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double _sidebarWidth = 260;

  NoteTreeNode? _selectedNote;

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
              child: NoteTree(
                nodes: sampleNoteTree,
                onNoteSelected: (node) => setState(() => _selectedNote = node),
              ),
            ),
          ),
          Expanded(child: _ContentArea(selectedNote: _selectedNote)),
        ],
      ),
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
