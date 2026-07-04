import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/notes/domain/markdown_tokenizer.dart';

void main() {
  String reconstruct(String text) =>
      tokenizeMarkdown(text).map((t) => t.text).join();

  group('reconstruction', () {
    for (final String sample in [
      'Обычный текст',
      '# Заголовок',
      'Строка1\nСтрока2',
      'Пусто:\n\nтут',
      '- пункт списка',
      '1. пункт списка',
      'Текст с **жирным** и *курсивом* и `кодом`.',
      '',
    ]) {
      test('preserves "$sample" exactly when tokens are joined', () {
        expect(reconstruct(sample), sample);
      });
    }
  });

  group('headings', () {
    test('tokenizes a level-1 heading', () {
      final List<MarkdownToken> tokens = tokenizeMarkdown('# Заголовок');
      expect(tokens, [
        const MarkdownToken('# ', MarkdownSpanKind.marker),
        const MarkdownToken('Заголовок', MarkdownSpanKind.heading1),
      ]);
    });

    test('tokenizes a level-3 heading', () {
      final List<MarkdownToken> tokens = tokenizeMarkdown('### Раздел');
      expect(tokens, [
        const MarkdownToken('### ', MarkdownSpanKind.marker),
        const MarkdownToken('Раздел', MarkdownSpanKind.heading3),
      ]);
    });

    test('does not treat a bare "#word" (no space) as a heading', () {
      final List<MarkdownToken> tokens = tokenizeMarkdown('#тег');
      expect(tokens, [const MarkdownToken('#тег', MarkdownSpanKind.plain)]);
    });
  });

  group('list markers', () {
    test('tokenizes a dash list item', () {
      final List<MarkdownToken> tokens = tokenizeMarkdown('- пункт');
      expect(tokens, [
        const MarkdownToken('- ', MarkdownSpanKind.listMarker),
        const MarkdownToken('пункт', MarkdownSpanKind.plain),
      ]);
    });

    test('tokenizes a numbered list item', () {
      final List<MarkdownToken> tokens = tokenizeMarkdown('2. пункт');
      expect(tokens, [
        const MarkdownToken('2. ', MarkdownSpanKind.listMarker),
        const MarkdownToken('пункт', MarkdownSpanKind.plain),
      ]);
    });
  });

  group('inline styles', () {
    test('tokenizes bold text', () {
      final List<MarkdownToken> tokens = tokenizeMarkdown('**жирный**');
      expect(tokens, [
        const MarkdownToken('**', MarkdownSpanKind.marker),
        const MarkdownToken('жирный', MarkdownSpanKind.bold),
        const MarkdownToken('**', MarkdownSpanKind.marker),
      ]);
    });

    test('tokenizes italic text', () {
      final List<MarkdownToken> tokens = tokenizeMarkdown('*курсив*');
      expect(tokens, [
        const MarkdownToken('*', MarkdownSpanKind.marker),
        const MarkdownToken('курсив', MarkdownSpanKind.italic),
        const MarkdownToken('*', MarkdownSpanKind.marker),
      ]);
    });

    test('tokenizes inline code', () {
      final List<MarkdownToken> tokens = tokenizeMarkdown('`код`');
      expect(tokens, [
        const MarkdownToken('`', MarkdownSpanKind.marker),
        const MarkdownToken('код', MarkdownSpanKind.code),
        const MarkdownToken('`', MarkdownSpanKind.marker),
      ]);
    });

    test('tokenizes plain text around an inline style', () {
      final List<MarkdownToken> tokens = tokenizeMarkdown('до **жир** после');
      expect(tokens, [
        const MarkdownToken('до ', MarkdownSpanKind.plain),
        const MarkdownToken('**', MarkdownSpanKind.marker),
        const MarkdownToken('жир', MarkdownSpanKind.bold),
        const MarkdownToken('**', MarkdownSpanKind.marker),
        const MarkdownToken(' после', MarkdownSpanKind.plain),
      ]);
    });
  });

  test('a blank line contributes only the newline separator', () {
    final List<MarkdownToken> tokens = tokenizeMarkdown('a\n\nb');
    expect(tokens, [
      const MarkdownToken('a', MarkdownSpanKind.plain),
      const MarkdownToken('\n', MarkdownSpanKind.plain),
      const MarkdownToken('\n', MarkdownSpanKind.plain),
      const MarkdownToken('b', MarkdownSpanKind.plain),
    ]);
  });
}
