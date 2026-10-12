import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/profiles_state.dart';

final profileStoreProvider = Provider<ProfileStore>(
  (ref) => FileProfileStore(),
);

abstract class ProfileStore {
  Future<ProfilesState> load();

  Future<void> save(ProfilesState state);
}

/// Persists profiles as JSON in the app support directory. Writes go to a
/// temporary file first and are renamed into place so a crash never leaves
/// a truncated file behind.
class FileProfileStore implements ProfileStore {
  FileProfileStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  Future<File> _file() async =>
      File('${(await _directory()).path}/profiles.json');

  @override
  Future<ProfilesState> load() async {
    final file = await _file();
    if (!file.existsSync()) return const ProfilesState();
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is Map) {
        return ProfilesState.fromJson(json.cast<String, Object?>());
      }
    } on FormatException {
      await file.copy('${file.path}.corrupt');
    }
    return const ProfilesState();
  }

  @override
  Future<void> save(ProfilesState state) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(state.toJson()), flush: true);
    await tmp.rename(file.path);
  }
}

class MemoryProfileStore implements ProfileStore {
  MemoryProfileStore([this.state = const ProfilesState()]);

  ProfilesState state;

  @override
  Future<ProfilesState> load() async => state;

  @override
  Future<void> save(ProfilesState state) async => this.state = state;
}
