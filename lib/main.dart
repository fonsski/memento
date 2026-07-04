import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/notes/data/file_system_note_repository.dart';
import 'features/notes/domain/note_repository.dart';
import 'features/notes/presentation/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final NoteRepository repository = await createDefaultNoteRepository();
  runApp(MementoApp(repository: repository));
}

class MementoApp extends StatelessWidget {
  const MementoApp({super.key, required this.repository});

  final NoteRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memento',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: HomeScreen(repository: repository),
    );
  }
}
