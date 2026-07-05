import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/slash_command.dart';

/// The "/" quick-insert popup: a compact list of matching commands.
/// Purely presentational — where it's positioned and how keyboard input
/// reaches it is the caller's responsibility (the menu itself never
/// takes focus, so the editor keeps it while the user keeps typing).
class SlashCommandMenu extends StatelessWidget {
  const SlashCommandMenu({
    super.key,
    required this.commands,
    required this.highlightedIndex,
    required this.onSelect,
  });

  final List<SlashCommand> commands;
  final int highlightedIndex;
  final ValueChanged<SlashCommand> onSelect;

  static const double width = 260;
  static const double maxHeight = 280;

  static const Map<String, IconData> _icons = {
    'heading1': Icons.title,
    'heading2': Icons.title,
    'heading3': Icons.title,
    'bulletList': Icons.format_list_bulleted,
    'numberedList': Icons.format_list_numbered,
    'checkbox': Icons.check_box_outlined,
    'quote': Icons.format_quote,
    'codeBlock': Icons.code,
    'divider': Icons.horizontal_rule,
    'table': Icons.table_chart_outlined,
    'drawing': Icons.brush_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: width,
          maxHeight: maxHeight,
        ),
        child: commands.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Ничего не найдено',
                  style: theme.textTheme.bodySmall,
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: commands.length,
                itemBuilder: (context, index) {
                  final SlashCommand command = commands[index];
                  return ListTile(
                    dense: true,
                    selected: index == highlightedIndex,
                    leading: Icon(
                      _icons[command.id] ?? Icons.article_outlined,
                      size: 18,
                    ),
                    title: Text(command.label),
                    onTap: () => onSelect(command),
                  );
                },
              ),
      ),
    );
  }
}
