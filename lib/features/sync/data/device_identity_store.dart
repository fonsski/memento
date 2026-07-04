import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/device_identity.dart';

/// Persists this device's [DeviceIdentity] as a small JSON file in the
/// app's support directory, generating one on first use.
class DeviceIdentityStore {
  const DeviceIdentityStore(this._file);

  final File _file;

  static Future<DeviceIdentityStore> create() async {
    final Directory supportDir = await getApplicationSupportDirectory();
    return DeviceIdentityStore(
      File(p.join(supportDir.path, 'device_identity.json')),
    );
  }

  /// Returns the previously generated identity, or generates and
  /// persists a new one (named [defaultName], falling back to the
  /// host's network name) if none exists yet.
  Future<DeviceIdentity> loadOrCreate({String? defaultName}) async {
    if (_file.existsSync()) {
      final Map<String, dynamic> json =
          jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      return DeviceIdentity(
        id: json['id'] as String,
        name: json['name'] as String,
      );
    }

    final DeviceIdentity identity = DeviceIdentity(
      id: _generateId(),
      name: defaultName ?? Platform.localHostname,
    );
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
      jsonEncode({'id': identity.id, 'name': identity.name}),
    );
    return identity;
  }

  static String _generateId() {
    final Random random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
