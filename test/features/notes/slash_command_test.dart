import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/notes/domain/slash_command.dart';

void main() {
  group('detectSlashTrigger', () {
    test('finds a trigger at the very start of the text', () {
      final SlashTrigger? trigger = detectSlashTrigger('/head', 5);

      expect(trigger, isNotNull);
      expect(trigger!.start, 0);
      expect(trigger.end, 5);
      expect(trigger.query, 'head');
    });

    test('finds a trigger right after typing just "/"', () {
      final SlashTrigger? trigger = detectSlashTrigger('/', 1);

      expect(trigger, isNotNull);
      expect(trigger!.query, isEmpty);
    });

    test('finds a trigger after a newline', () {
      final SlashTrigger? trigger = detectSlashTrigger('текст\n/tab', 10);

      expect(trigger, isNotNull);
      expect(trigger!.start, 6);
      expect(trigger.query, 'tab');
    });

    test('finds a trigger after a space', () {
      final SlashTrigger? trigger = detectSlashTrigger('слово /quo', 10);

      expect(trigger, isNotNull);
      expect(trigger!.query, 'quo');
    });

    test('does not trigger mid-word', () {
      expect(detectSlashTrigger('дробь3/4', 8), isNull);
    });

    test('returns null once whitespace follows the trigger', () {
      expect(detectSlashTrigger('/head ', 6), isNull);
    });

    test('returns null when there is no slash at all', () {
      expect(detectSlashTrigger('просто текст', 5), isNull);
    });

    test('matches the closest slash when several are typed', () {
      final SlashTrigger? trigger = detectSlashTrigger('/one /two', 9);

      expect(trigger, isNotNull);
      expect(trigger!.start, 5);
      expect(trigger.query, 'two');
    });
  });

  group('filterSlashCommands', () {
    test('returns every command for a blank query', () {
      expect(filterSlashCommands('   ').length, slashCommands.length);
    });

    test('filters by label substring, case-insensitively', () {
      final List<SlashCommand> results = filterSlashCommands('ТАБЛИЦ');

      expect(results.map((c) => c.id), ['table']);
    });

    test('filters by keyword', () {
      final List<SlashCommand> results = filterSlashCommands('h2');

      expect(results.map((c) => c.id), ['heading2']);
    });

    test('returns an empty list when nothing matches', () {
      expect(filterSlashCommands('нет такой команды'), isEmpty);
    });
  });
}
