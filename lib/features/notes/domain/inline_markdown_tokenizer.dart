/// What role a chunk of tokenized inline text plays, so the renderer
/// can style it (dim a marker, bold/italicize, monospace).
enum InlineSpanKind { plain, marker, bold, italic, code }

/// A contiguous run of [text] that should all be styled as [kind].
class InlineToken {
  const InlineToken(this.text, this.kind);

  final String text;
  final InlineSpanKind kind;

  @override
  bool operator ==(Object other) =>
      other is InlineToken && other.text == text && other.kind == kind;

  @override
  int get hashCode => Object.hash(text, kind);

  @override
  String toString() => 'InlineToken($kind, "$text")';
}

final RegExp _inlinePattern = RegExp(
  r'(\*\*[^*\n]+\*\*|\*[^*\n]+\*|`[^`\n]+`)',
);

/// Tokenizes a single block's prose for `**bold**`, `*italic*` and
/// `` `code` `` — nothing block-level (headings, list markers, quote
/// prefixes) is recognized here, since the block model already carries
/// that as [Block.type] rather than as literal characters in
/// [Block.text]. Newlines within a multi-line block (e.g. a paragraph)
/// are preserved as their own plain tokens.
List<InlineToken> tokenizeInlineMarkdown(String text) {
  final List<String> lines = text.split('\n');
  final List<InlineToken> tokens = [];

  for (int i = 0; i < lines.length; i++) {
    tokens.addAll(_tokenizeLine(lines[i]));
    if (i != lines.length - 1) {
      tokens.add(const InlineToken('\n', InlineSpanKind.plain));
    }
  }
  return tokens;
}

List<InlineToken> _tokenizeLine(String line) {
  final List<InlineToken> tokens = [];
  int cursor = 0;

  for (final RegExpMatch match in _inlinePattern.allMatches(line)) {
    if (match.start > cursor) {
      tokens.add(
        InlineToken(line.substring(cursor, match.start), InlineSpanKind.plain),
      );
    }

    final String token = match.group(0)!;
    if (token.startsWith('**')) {
      tokens.add(const InlineToken('**', InlineSpanKind.marker));
      tokens.add(
        InlineToken(token.substring(2, token.length - 2), InlineSpanKind.bold),
      );
      tokens.add(const InlineToken('**', InlineSpanKind.marker));
    } else if (token.startsWith('`')) {
      tokens.add(const InlineToken('`', InlineSpanKind.marker));
      tokens.add(
        InlineToken(token.substring(1, token.length - 1), InlineSpanKind.code),
      );
      tokens.add(const InlineToken('`', InlineSpanKind.marker));
    } else {
      tokens.add(const InlineToken('*', InlineSpanKind.marker));
      tokens.add(
        InlineToken(
          token.substring(1, token.length - 1),
          InlineSpanKind.italic,
        ),
      );
      tokens.add(const InlineToken('*', InlineSpanKind.marker));
    }
    cursor = match.end;
  }

  if (cursor < line.length) {
    tokens.add(InlineToken(line.substring(cursor), InlineSpanKind.plain));
  }
  return tokens;
}
