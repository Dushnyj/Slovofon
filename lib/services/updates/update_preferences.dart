import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class SkippedUpdate {
  const SkippedUpdate({required this.version, required this.build});

  factory SkippedUpdate.fromJson(Map<String, Object?> json) {
    return SkippedUpdate(
      version: json['version']?.toString() ?? '',
      build: json['build'] is int ? json['build'] as int : null,
    );
  }

  final String version;
  final int? build;

  Map<String, Object?> toJson() => {'version': version, 'build': build};

  bool matches({required String version, required int? build}) {
    return this.version == version && this.build == build;
  }
}

abstract interface class UpdatePreferencesStore {
  Future<SkippedUpdate?> loadSkippedUpdate();

  Future<void> saveSkippedUpdate(SkippedUpdate update);
}

class MemoryUpdatePreferencesStore implements UpdatePreferencesStore {
  SkippedUpdate? _skippedUpdate;

  @override
  Future<SkippedUpdate?> loadSkippedUpdate() async => _skippedUpdate;

  @override
  Future<void> saveSkippedUpdate(SkippedUpdate update) async {
    _skippedUpdate = update;
  }
}

class FileUpdatePreferencesStore implements UpdatePreferencesStore {
  FileUpdatePreferencesStore._(this._file);

  static Future<FileUpdatePreferencesStore> create() async {
    final directory = await getApplicationSupportDirectory();
    return FileUpdatePreferencesStore._(
      File('${directory.path}${Platform.pathSeparator}update_preferences.json'),
    );
  }

  final File _file;

  @override
  Future<SkippedUpdate?> loadSkippedUpdate() async {
    if (!await _file.exists()) {
      return null;
    }
    try {
      final raw = jsonDecode(await _file.readAsString());
      if (raw is Map) {
        return SkippedUpdate.fromJson(Map<String, Object?>.from(raw));
      }
    } on Object {
      return null;
    }
    return null;
  }

  @override
  Future<void> saveSkippedUpdate(SkippedUpdate update) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(update.toJson()));
  }
}

class LazyFileUpdatePreferencesStore implements UpdatePreferencesStore {
  Future<FileUpdatePreferencesStore>? _storeFuture;

  Future<FileUpdatePreferencesStore> get _store {
    return _storeFuture ??= FileUpdatePreferencesStore.create();
  }

  @override
  Future<SkippedUpdate?> loadSkippedUpdate() async {
    return (await _store).loadSkippedUpdate();
  }

  @override
  Future<void> saveSkippedUpdate(SkippedUpdate update) async {
    return (await _store).saveSkippedUpdate(update);
  }
}
