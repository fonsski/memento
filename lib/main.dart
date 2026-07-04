import 'dart:io';

import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/notes/data/file_system_note_repository.dart';
import 'features/notes/data/vault_settings.dart';
import 'features/notes/domain/note_repository.dart';
import 'features/notes/presentation/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final FileSystemNoteRepository repository =
      await createDefaultNoteRepository();
  runApp(MementoApp(repository: repository));
}

class MementoApp extends StatefulWidget {
  const MementoApp({super.key, required this.repository});

  final FileSystemNoteRepository repository;

  @override
  State<MementoApp> createState() => _MementoAppState();
}

class _MementoAppState extends State<MementoApp> {
  late NoteRepository _repository = widget.repository;
  late String _vaultPath = widget.repository.vaultRoot.path;

  Future<void> _changeVault(String newPath) async {
    final VaultSettings settings = await VaultSettings.create();
    await settings.writeVaultPath(newPath);
    setState(() {
      _repository = FileSystemNoteRepository(Directory(newPath));
      _vaultPath = newPath;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memento',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      // Keyed by the vault path so switching vaults remounts HomeScreen
      // fresh (new tree, no leftover tabs from the previous vault).
      home: HomeScreen(
        key: ValueKey(_vaultPath),
        repository: _repository,
        vaultPath: _vaultPath,
        onChangeVault: _changeVault,
      ),
    );
  }
}
