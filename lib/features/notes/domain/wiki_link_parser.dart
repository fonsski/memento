/// Matches `[[Note Title]]` and `[[Note Title|Display text]]`.
final RegExp _wikiLinkPattern = RegExp(r'\[\[([^\]|]+)(?:\|[^\]]+)?\]\]');

/// Extracts the referenced note titles from `[[wiki-link]]`-style
/// references in [content], trimmed, in the order they appear. Duplicate
/// references are kept (callers that need a set can dedupe themselves).
List<String> parseWikiLinks(String content) {
  return _wikiLinkPattern
      .allMatches(content)
      .map((match) => match.group(1)!.trim())
      .where((title) => title.isNotEmpty)
      .toList();
}
