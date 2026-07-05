/// A single quick-insert command offered by the "/" menu.
class SlashCommand {
  const SlashCommand({
    required this.id,
    required this.label,
    required this.keywords,
    this.insertText,
  });

  /// Stable identifier (also used by the presentation layer to pick an
  /// icon, so it doesn't need a Flutter dependency here).
  final String id;

  final String label;

  /// Extra words matched against the query, beyond [label] itself (e.g.
  /// English names for a Russian label).
  final List<String> keywords;

  /// Text that replaces the "/query" trigger when this command is
  /// chosen. `null` for commands that need to do something else first
  /// (currently only the drawing canvas, which opens a dialog and only
  /// then has text to insert) — the caller handles those separately.
  final String? insertText;
}

const List<SlashCommand> slashCommands = [
  SlashCommand(
    id: 'heading1',
    label: 'Заголовок 1',
    keywords: ['h1', 'heading'],
    insertText: '# ',
  ),
  SlashCommand(
    id: 'heading2',
    label: 'Заголовок 2',
    keywords: ['h2', 'heading'],
    insertText: '## ',
  ),
  SlashCommand(
    id: 'heading3',
    label: 'Заголовок 3',
    keywords: ['h3', 'heading'],
    insertText: '### ',
  ),
  SlashCommand(
    id: 'bulletList',
    label: 'Маркированный список',
    keywords: ['bullet', 'list', '-'],
    insertText: '- ',
  ),
  SlashCommand(
    id: 'numberedList',
    label: 'Нумерованный список',
    keywords: ['numbered', 'list', '1'],
    insertText: '1. ',
  ),
  SlashCommand(
    id: 'checkbox',
    label: 'Чекбокс',
    keywords: ['todo', 'checkbox', 'task'],
    insertText: '- [ ] ',
  ),
  SlashCommand(
    id: 'quote',
    label: 'Цитата',
    keywords: ['quote', '>'],
    insertText: '> ',
  ),
  SlashCommand(
    id: 'codeBlock',
    label: 'Блок кода',
    keywords: ['code', '```'],
    insertText: '```\n\n```',
  ),
  SlashCommand(
    id: 'divider',
    label: 'Разделитель',
    keywords: ['divider', 'hr', '---'],
    insertText: '---\n',
  ),
  SlashCommand(
    id: 'table',
    label: 'Таблица',
    keywords: ['table'],
    insertText: '| Колонка 1 | Колонка 2 |\n| --- | --- |\n|  |  |\n',
  ),
  SlashCommand(
    id: 'drawing',
    label: 'Холст для рисования',
    keywords: ['canvas', 'drawing', 'рисунок'],
  ),
];

/// Filters [slashCommands] to those matching [query] (case-insensitive,
/// against the label or keywords). An empty or blank query returns every
/// command.
List<SlashCommand> filterSlashCommands(String query) {
  final String normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return slashCommands;

  return slashCommands
      .where(
        (command) =>
            command.label.toLowerCase().contains(normalized) ||
            command.keywords.any((k) => k.toLowerCase().contains(normalized)),
      )
      .toList();
}

/// Where an active "/" trigger sits in the text: [start] is the index of
/// the `/` itself, [end] is the cursor position (so `text.substring(start,
/// end)` is `/query`), and [query] is the filter text typed after it.
class SlashTrigger {
  const SlashTrigger({
    required this.start,
    required this.end,
    required this.query,
  });

  final int start;
  final int end;
  final String query;
}

/// Looks backward from [cursorOffset] in [text] for an active "/"
/// trigger: a `/` preceded by nothing, a newline, or whitespace (so it
/// starts a word rather than sitting mid-word), followed only by
/// non-whitespace characters up to the cursor. Returns `null` if there's
/// no such trigger — e.g. the cursor has moved past whitespace since the
/// last `/`, so the menu should close.
SlashTrigger? detectSlashTrigger(String text, int cursorOffset) {
  if (cursorOffset < 0 || cursorOffset > text.length) return null;

  for (int i = cursorOffset - 1; i >= 0; i--) {
    final String char = text[i];
    if (char == '/') {
      final bool startsWord =
          i == 0 || const {'\n', ' ', '\t'}.contains(text[i - 1]);
      if (!startsWord) return null;
      return SlashTrigger(
        start: i,
        end: cursorOffset,
        query: text.substring(i + 1, cursorOffset),
      );
    }
    if (char == '\n' || char == ' ' || char == '\t') return null;
  }
  return null;
}
