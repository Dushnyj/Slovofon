import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/database/app_database.dart';

const defaultSourceIds = [
  'izib',
  'akniga',
  'yakniga',
  'knigavuhe',
  'knigoblud',
  'baza_knig',
];

final sourceSettingsStoreProvider = ChangeNotifierProvider<SourceSettingsStore>(
  (ref) {
    return SourceSettingsStore(MemorySourceSettingsPersistenceStore())..load();
  },
);

class SourceSettingsStore extends ChangeNotifier {
  SourceSettingsStore(this._persistence, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _settings = {
      for (final id in defaultSourceIds)
        id: SourceSettings(sourceId: id, updatedAt: _clock()),
    };
  }

  final SourceSettingsPersistenceStore _persistence;
  final DateTime Function() _clock;
  late Map<String, SourceSettings> _settings;
  Future<void>? _loadFuture;

  List<SourceSettings> get settings {
    return [for (final id in defaultSourceIds) _settings[id]!];
  }

  Set<String> get enabledSearchSourceIds {
    return {
      for (final setting in settings)
        if (setting.isEnabled && setting.useInGlobalSearch) setting.sourceId,
    };
  }

  bool isEnabled(String sourceId) {
    return _settings[sourceId]?.isEnabled ?? true;
  }

  SourceSettings? settingsFor(String sourceId) => _settings[sourceId];

  Future<void> load() {
    return _loadFuture ??= _load();
  }

  Future<void> setSourceEnabled(String sourceId, bool enabled) async {
    await load();
    final current =
        _settings[sourceId] ??
        SourceSettings(sourceId: sourceId, updatedAt: _clock());
    final next = current.copyWith(isEnabled: enabled, updatedAt: _clock());
    _settings[sourceId] = next;
    await _persistence.save(next);
    notifyListeners();
  }

  Future<void> setEnabledSources(Set<String> sourceIds) async {
    await load();
    final enabledIds = sourceIds.isEmpty ? {defaultSourceIds.first} : sourceIds;
    for (final setting in settings) {
      final enabled = enabledIds.contains(setting.sourceId);
      final next = setting.copyWith(isEnabled: enabled, updatedAt: _clock());
      _settings[setting.sourceId] = next;
      await _persistence.save(next);
    }
    notifyListeners();
  }

  Future<void> setMediaPermissions(
    String sourceId, {
    bool? allowStreaming,
    bool? allowDownload,
  }) async {
    await load();
    if (allowStreaming == null && allowDownload == null) {
      return;
    }
    final current =
        _settings[sourceId] ??
        SourceSettings(sourceId: sourceId, updatedAt: _clock());
    final next = current.copyWith(
      allowStreaming: allowStreaming,
      allowDownload: allowDownload,
      updatedAt: _clock(),
    );
    _settings[sourceId] = next;
    await _persistence.save(next);
    notifyListeners();
  }

  Future<void> _load() async {
    final loaded = await _persistence.load();
    _settings = {
      // Keep explicitly stored preferences even for a source not present in the
      // current built-in registry. Absence still uses the permissive default.
      ...loaded,
      for (final id in defaultSourceIds)
        id: loaded[id] ?? SourceSettings(sourceId: id, updatedAt: _clock()),
    };
    notifyListeners();
  }
}

class SourceSettings {
  const SourceSettings({
    required this.sourceId,
    required this.updatedAt,
    this.isEnabled = true,
    this.priority = 0,
    this.useInGlobalSearch = true,
    this.allowStreaming = true,
    this.allowDownload = true,
  });

  final String sourceId;
  final bool isEnabled;
  final int priority;
  final bool useInGlobalSearch;
  final bool allowStreaming;
  final bool allowDownload;
  final DateTime updatedAt;

  SourceSettings copyWith({
    bool? isEnabled,
    int? priority,
    bool? useInGlobalSearch,
    bool? allowStreaming,
    bool? allowDownload,
    DateTime? updatedAt,
  }) {
    return SourceSettings(
      sourceId: sourceId,
      isEnabled: isEnabled ?? this.isEnabled,
      priority: priority ?? this.priority,
      useInGlobalSearch: useInGlobalSearch ?? this.useInGlobalSearch,
      allowStreaming: allowStreaming ?? this.allowStreaming,
      allowDownload: allowDownload ?? this.allowDownload,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

abstract interface class SourceSettingsPersistenceStore {
  Future<Map<String, SourceSettings>> load();

  Future<void> save(SourceSettings settings);
}

class MemorySourceSettingsPersistenceStore
    implements SourceSettingsPersistenceStore {
  final _settings = <String, SourceSettings>{};

  @override
  Future<Map<String, SourceSettings>> load() async {
    return Map.unmodifiable(_settings);
  }

  @override
  Future<void> save(SourceSettings settings) async {
    _settings[settings.sourceId] = settings;
  }
}

class DriftSourceSettingsPersistenceStore
    implements SourceSettingsPersistenceStore {
  DriftSourceSettingsPersistenceStore(this._db);

  final AppDatabase _db;

  @override
  Future<Map<String, SourceSettings>> load() async {
    final rows = await _db.select(_db.sourceSettingsRows).get();
    return {
      for (final row in rows)
        row.sourceId: SourceSettings(
          sourceId: row.sourceId,
          isEnabled: row.isEnabled,
          priority: row.priority,
          useInGlobalSearch: row.useInGlobalSearch,
          allowStreaming: row.allowStreaming,
          allowDownload: row.allowDownload,
          updatedAt: row.updatedAt,
        ),
    };
  }

  @override
  Future<void> save(SourceSettings settings) async {
    await _db
        .into(_db.sourceSettingsRows)
        .insertOnConflictUpdate(
          SourceSettingsRowsCompanion(
            sourceId: Value(settings.sourceId),
            isEnabled: Value(settings.isEnabled),
            priority: Value(settings.priority),
            useInGlobalSearch: Value(settings.useInGlobalSearch),
            allowStreaming: Value(settings.allowStreaming),
            allowDownload: Value(settings.allowDownload),
            updatedAt: Value(settings.updatedAt),
          ),
        );
  }
}
