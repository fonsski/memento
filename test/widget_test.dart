import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memento/features/notes/data/file_system_note_repository.dart';
import 'package:memento/main.dart';

void main() {
  late Directory vaultRoot;

  setUp(() async {
    vaultRoot = await Directory.systemTemp.createTemp('memento_app_test');
  });

  tearDown(() async {
    if (vaultRoot.existsSync()) {
      await vaultRoot.delete(recursive: true);
    }
  });

  testWidgets(
    'MementoApp shows the empty-archive placeholder and the note tree',
    (WidgetTester tester) async {
      final FileSystemNoteRepository repository = FileSystemNoteRepository(
        vaultRoot,
      );

      // Real dart:io work (both the seeding call below and the repository
      // load triggered by HomeScreen.initState) needs the real event loop,
      // which testWidgets() otherwise fakes; runAsync() opts back into it.
      await tester.runAsync(() async {
        await repository.createNote('', 'О проекте');
        await tester.pumpWidget(MementoApp(repository: repository));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      expect(find.text('Memento'), findsOneWidget);
      expect(find.text('Место, где мысли остаются навсегда.'), findsOneWidget);
      expect(find.text('О проекте'), findsOneWidget);
    },
  );
}
