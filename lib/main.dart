import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/notes/data/file_system_note_repository.dart';
import 'features/notes/data/vault_settings.dart';
import 'features/notes/domain/note_repository.dart';
import 'features/notes/presentation/home_screen.dart';
import 'features/sync/data/device_identity_store.dart';
import 'features/sync/data/pairing_store.dart';
import 'features/sync/data/sync_coordinator.dart';
import 'features/sync/domain/device_identity.dart';

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
  SyncCoordinator? _syncCoordinator;
  DeviceIdentity? _identity;
  PairingStore? _pairingStore;

  @override
  void initState() {
    super.initState();
    unawaited(_setUpSync(widget.repository));
  }

  /// Sets up P2P sync for [repository]. Failures here (e.g. no
  /// path_provider/network plugin available on this platform) are
  /// swallowed — sync is an optional feature, not something that should
  /// take the whole app down if it can't start; the sync button just
  /// stays disabled.
  Future<void> _setUpSync(FileSystemNoteRepository repository) async {
    try {
      final DeviceIdentity identity =
          _identity ??
          await (await DeviceIdentityStore.create()).loadOrCreate();
      final PairingStore pairingStore =
          _pairingStore ?? await PairingStore.create();
      final SyncCoordinator coordinator = SyncCoordinator(
        repository: repository,
        identity: identity,
        pairingStore: pairingStore,
      );
      await coordinator.startListening();
      await coordinator.startNetworkDiscovery();

      if (!mounted) {
        await coordinator.dispose();
        return;
      }
      setState(() {
        _identity = identity;
        _pairingStore = pairingStore;
        _syncCoordinator = coordinator;
      });
    } catch (_) {
      // Sync stays unavailable; nothing else in the app depends on it.
    }
  }

  Future<void> _changeVault(String newPath) async {
    final VaultSettings settings = await VaultSettings.create();
    await settings.writeVaultPath(newPath);

    final SyncCoordinator? oldCoordinator = _syncCoordinator;
    final FileSystemNoteRepository newRepository = FileSystemNoteRepository(
      Directory(newPath),
    );
    setState(() {
      _repository = newRepository;
      _vaultPath = newPath;
      _syncCoordinator = null;
    });

    await oldCoordinator?.dispose();
    await _setUpSync(newRepository);
  }

  @override
  void dispose() {
    unawaited(_syncCoordinator?.dispose());
    super.dispose();
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
        syncCoordinator: _syncCoordinator,
      ),
    );
  }
}
