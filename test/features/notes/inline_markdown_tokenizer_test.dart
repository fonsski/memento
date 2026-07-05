import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/notes/domain/inline_markdown_tokenizer.dart';

void main() {
  test('plain text with no markers is a single plain token', () {
    final List<InlineToken> tokens = tokenizeInlineMarkdown('просто текст');

    expect(tokens, [const InlineToken('просто текст', InlineSpanKind.plain)]);
  });

  test('tokenizes bold text with dimmable markers', () {
    final List<InlineToken> tokens = tokenizeInlineMarkdown('**жирный**');

    expect(tokens, [
      const InlineToken('**', InlineSpanKind.marker),
      const InlineToken('жирный', InlineSpanKind.bold),
      const InlineToken('**', InlineSpanKind.marker),
    ]);
  });

  test('tokenizes italic text with dimmable markers', () {
    final List<InlineToken> tokens = tokenizeInlineMarkdown('*курсив*');

    expect(tokens, [
      const InlineToken('*', InlineSpanKind.marker),
      const InlineToken('курсив', InlineSpanKind.italic),
      const InlineToken('*', InlineSpanKind.marker),
    ]);
  });

  test('tokenizes inline code with dimmable markers', () {
    final List<InlineToken> tokens = tokenizeInlineMarkdown('`код`');

    expect(tokens, [
      const InlineToken('`', InlineSpanKind.marker),
      const InlineToken('код', InlineSpanKind.code),
      const InlineToken('`', InlineSpanKind.marker),
    ]);
  });

  test('tokenizes plain text around a marker', () {
    final List<InlineToken> tokens = tokenizeInlineMarkdown('до **жир** после');

    expect(tokens, [
      const InlineToken('до ', InlineSpanKind.plain),
      const InlineToken('**', InlineSpanKind.marker),
      const InlineToken('жир', InlineSpanKind.bold),
      const InlineToken('**', InlineSpanKind.marker),
      const InlineToken(' после', InlineSpanKind.plain),
    ]);
  });

  test('does not treat "#" or "-" specially — that is the block\'s job', () {
    final List<InlineToken> tokens = tokenizeInlineMarkdown('# не заголовок');

    expect(tokens, [const InlineToken('# не заголовок', InlineSpanKind.plain)]);
  });

  test('preserves newlines within multi-line text as plain tokens', () {
    final List<InlineToken> tokens = tokenizeInlineMarkdown(
      'строка 1\nстрока 2',
    );

    expect(tokens, [
      const InlineToken('строка 1', InlineSpanKind.plain),
      const InlineToken('\n', InlineSpanKind.plain),
      const InlineToken('строка 2', InlineSpanKind.plain),
    ]);
  });

  test('joining every token reproduces the original text', () {
    const String source = '**жир** и *курсив* и `код`\nвторая строка';

    final String joined = tokenizeInlineMarkdown(
      source,
    ).map((t) => t.text).join();

    expect(joined, source);
  });
}
