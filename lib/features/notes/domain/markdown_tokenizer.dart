/// What role a chunk of tokenized Markdown text plays, so the renderer
/// can style it (dim a marker, render a heading, etc).
enum MarkdownSpanKind {
  plain,
  marker,
  listMarker,
  heading1,
  heading2,
  heading3,
  heading4,
  bold,
  italic,
  code,
}

/// A contiguous run of [text] that should all be styled as [kind].
class MarkdownToken {
  const MarkdownToken(this.text, this.kind);

  final String text;
  final MarkdownSpanKind kind;

  @override
  bool operator ==(Object other) =>
      other is MarkdownToken && other.text == text && other.kind == kind;

  @override
  int get hashCode => Object.hash(text, kind);

  @override
  String toString() => 'MarkdownToken($kind, "$text")';
}

final RegExp _headingPattern = RegExp(r'^(#{1,4})(\s+)(.*)$');
final RegExp _listMarkerPattern = RegExp(r'^(\s*)([-*+]|\d+\.)(\s+)(.*)$');
final RegExp _inlinePattern = RegExp(
  r'(\*\*[^*\n]+\*\*|\*[^*\n]+\*|`[^`\n]+`)',
);

const List<MarkdownSpanKind> _headingKinds = [
  MarkdownSpanKind.heading1,
  MarkdownSpanKind.heading2,
  MarkdownSpanKind.heading3,
  MarkdownSpanKind.heading4,
];

/// Splits Markdown [text] into styled tokens, line by line: headings and
/// list markers are recognized at the start of a line, `**bold**`,
/// `*italic*` and `` `code` `` are recognized anywhere within a line's
/// remaining text. Newlines are preserved as plain tokens.
List<MarkdownToken> tokenizeMarkdown(String text) {
  final List<String> lines = text.split('\n');
  final List<MarkdownToken> tokens = [];

  for (int i = 0; i < lines.length; i++) {
    tokens.addAll(_tokenizeLine(lines[i]));
    if (i != lines.length - 1) {
      tokens.add(const MarkdownToken('\n', MarkdownSpanKind.plain));
    }
  }
  return tokens;
}

List<MarkdownToken> _tokenizeLine(String line) {
  final RegExpMatch? heading = _headingPattern.firstMatch(line);
  if (heading != null) {
    final String hashes = heading.group(1)!;
    final MarkdownSpanKind kind = _headingKinds[hashes.length - 1];
    return [
      MarkdownToken(hashes + heading.group(2)!, MarkdownSpanKind.marker),
      ..._tokenizeInline(heading.group(3)!, kind),
    ];
  }

  final RegExpMatch? list = _listMarkerPattern.firstMatch(line);
  if (list != null) {
    final String indent = list.group(1)!;
    return [
      if (indent.isNotEmpty) MarkdownToken(indent, MarkdownSpanKind.plain),
      MarkdownToken(
        list.group(2)! + list.group(3)!,
        MarkdownSpanKind.listMarker,
      ),
      ..._tokenizeInline(list.group(4)!, MarkdownSpanKind.plain),
    ];
  }

  return _tokenizeInline(line, MarkdownSpanKind.plain);
}

List<MarkdownToken> _tokenizeInline(String text, MarkdownSpanKind baseKind) {
  final List<MarkdownToken> tokens = [];
  int cursor = 0;

  for (final RegExpMatch match in _inlinePattern.allMatches(text)) {
    if (match.start > cursor) {
      tokens.add(MarkdownToken(text.substring(cursor, match.start), baseKind));
    }

    final String token = match.group(0)!;
    if (token.startsWith('**')) {
      tokens.add(const MarkdownToken('**', MarkdownSpanKind.marker));
      tokens.add(
        MarkdownToken(
          token.substring(2, token.length - 2),
          MarkdownSpanKind.bold,
        ),
      );
      tokens.add(const MarkdownToken('**', MarkdownSpanKind.marker));
    } else if (token.startsWith('`')) {
      tokens.add(const MarkdownToken('`', MarkdownSpanKind.marker));
      tokens.add(
        MarkdownToken(
          token.substring(1, token.length - 1),
          MarkdownSpanKind.code,
        ),
      );
      tokens.add(const MarkdownToken('`', MarkdownSpanKind.marker));
    } else {
      tokens.add(const MarkdownToken('*', MarkdownSpanKind.marker));
      tokens.add(
        MarkdownToken(
          token.substring(1, token.length - 1),
          MarkdownSpanKind.italic,
        ),
      );
      tokens.add(const MarkdownToken('*', MarkdownSpanKind.marker));
    }
    cursor = match.end;
  }

  if (cursor < text.length) {
    tokens.add(MarkdownToken(text.substring(cursor), baseKind));
  }
  return tokens;
}
