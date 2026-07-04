import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/note_tree_node.dart';
import 'note_tree_item.dart';

/// Sidebar tree of folders and notes. Manages which folders are expanded
/// and which node is selected; each [NoteTreeItem] is purely presentational.
class NoteTree extends StatefulWidget {
  const NoteTree({super.key, required this.nodes, this.onNoteSelected});

  final List<NoteTreeNode> nodes;
  final ValueChanged<NoteTreeNode>? onNoteSelected;

  @override
  State<NoteTree> createState() => _NoteTreeState();
}

class _NoteTreeState extends State<NoteTree> {
  final Set<String> _expandedIds = {};
  String? _selectedId;

  void _handleTap(NoteTreeNode node) {
    setState(() {
      if (node.isFolder) {
        if (_expandedIds.contains(node.id)) {
          _expandedIds.remove(node.id);
        } else {
          _expandedIds.add(node.id);
        }
      }
      _selectedId = node.id;
    });
    if (!node.isFolder) {
      widget.onNoteSelected?.call(node);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: _buildRows(widget.nodes, 0),
    );
  }

  List<Widget> _buildRows(List<NoteTreeNode> nodes, int depth) {
    return [for (final NoteTreeNode node in nodes) _buildRow(node, depth)];
  }

  Widget _buildRow(NoteTreeNode node, int depth) {
    final bool expanded = _expandedIds.contains(node.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NoteTreeItem(
          node: node,
          depth: depth,
          expanded: expanded,
          selected: node.id == _selectedId,
          onTap: () => _handleTap(node),
        ),
        if (node.isFolder)
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
            child: expanded
                ? _StaggeredChildren(
                    children: _buildRows(node.children, depth + 1),
                  )
                : const SizedBox(width: double.infinity),
          ),
      ],
    );
  }
}

/// Fades and slides its children in with a small cascading delay, capped
/// so long lists don't take longer to reveal than a single glance allows.
class _StaggeredChildren extends StatelessWidget {
  const _StaggeredChildren({required this.children});

  final List<Widget> children;

  static const int _maxStaggeredIndex = 5;
  static const Duration _stepDelay = Duration(milliseconds: 20);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < children.length; i++)
          _StaggeredFadeIn(
            delay:
                _stepDelay * (i > _maxStaggeredIndex ? _maxStaggeredIndex : i),
            child: children[i],
          ),
      ],
    );
  }
}

class _StaggeredFadeIn extends StatefulWidget {
  const _StaggeredFadeIn({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<_StaggeredFadeIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _visible = true);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      offset: _visible ? Offset.zero : const Offset(0, -0.08),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _visible ? 1 : 0,
        child: widget.child,
      ),
    );
  }
}
