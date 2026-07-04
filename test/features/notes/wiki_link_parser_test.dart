import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/notes/domain/wiki_link_parser.dart';

void main() {
  test('extracts a simple wiki-link', () {
    expect(parseWikiLinks('See [[Архив]] for details.'), ['Архив']);
  });

  test('extracts the title from a piped display-text link', () {
    expect(parseWikiLinks('See [[Архив|тут]] for details.'), ['Архив']);
  });

  test('extracts multiple links in order', () {
    expect(parseWikiLinks('[[A]] then [[B]] then [[C]]'), ['A', 'B', 'C']);
  });

  test('trims whitespace inside the brackets', () {
    expect(parseWikiLinks('[[  Архив  ]]'), ['Архив']);
  });

  test('returns an empty list when there are no links', () {
    expect(parseWikiLinks('Обычный текст без ссылок.'), isEmpty);
  });

  test('ignores an empty [[]] link', () {
    expect(parseWikiLinks('Пустая ссылка [[]] тут.'), isEmpty);
  });
}
