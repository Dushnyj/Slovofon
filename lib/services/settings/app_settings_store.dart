import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/database/app_database.dart';
import '../../domain/models/app_settings.dart';

final appSettingsStoreProvider = ChangeNotifierProvider<AppSettingsStore>((
  ref,
) {
  return AppSettingsStore(MemoryAppSettingsPersistenceStore())..load();
});

class AppSettingsStore extends ChangeNotifier {
  AppSettingsStore(this._persistence, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const settingsId = 'app';

  final AppSettingsPersistenceStore _persistence;
  final DateTime Function() _clock;
  AppSettings _settings = const AppSettings.defaults();
  Future<void>? _loadFuture;
  Future<void> _updates = Future<void>.value();
  bool _disposed = false;

  AppSettings get settings => _settings;

  Future<void> load() {
    final pending = _loadFuture;
    if (pending != null) return pending;
    final loading = _load();
    _loadFuture = loading;
    // Keep the error visible to this caller, but allow a later retry to read
    // saved settings instead of permanently reusing a failed hydration future.
    loading.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {
        if (identical(_loadFuture, loading)) _loadFuture = null;
      },
    );
    return loading;
  }

  Future<void> setThemeMode(AppThemeMode themeMode) {
    return _update((current) => current.copyWith(themeMode: themeMode));
  }

  Future<void> setLanguageCode(String languageCode) {
    return _update((current) => current.copyWith(languageCode: languageCode));
  }

  Future<void> setAccentColor(String accentColor) {
    return _update((current) => current.copyWith(accentColor: accentColor));
  }

  Future<void> setTextScale(double textScale) {
    return _update(
      (current) => current.copyWith(
        textScale: AppSettings.normalizeTextScale(textScale),
      ),
    );
  }

  Future<void> setCompactCards(bool compactCards) {
    return _update((current) => current.copyWith(compactCards: compactCards));
  }

  Future<void> setShowSourceOnCards(bool showSourceOnCards) {
    return _update(
      (current) => current.copyWith(showSourceOnCards: showSourceOnCards),
    );
  }

  Future<void> setShowPercentOnCovers(bool showPercentOnCovers) {
    return _update(
      (current) => current.copyWith(showPercentOnCovers: showPercentOnCovers),
    );
  }

  Future<void> setAnimationsMode(AppAnimationsMode animationsMode) {
    return _update(
      (current) => current.copyWith(animationsMode: animationsMode),
    );
  }

  Future<void> _load() async {
    final saved = await _persistence.load() ?? const AppSettings.defaults();
    _settings = saved.copyWith(
      textScale: AppSettings.normalizeTextScale(saved.textScale),
    );
    if (!_disposed) notifyListeners();
  }

  Future<void> _update(AppSettings Function(AppSettings) transform) {
    final update = _updates.then((_) async {
      await load();
      final settings = transform(_settings);
      await _persistence.save(settings, updatedAt: _clock());
      _settings = settings;
      if (!_disposed) notifyListeners();
    });
    _updates = update.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return update;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

abstract interface class AppSettingsPersistenceStore {
  Future<AppSettings?> load();

  Future<void> save(AppSettings settings, {required DateTime updatedAt});
}

class MemoryAppSettingsPersistenceStore implements AppSettingsPersistenceStore {
  AppSettings? _settings;

  @override
  Future<AppSettings?> load() async => _settings;

  @override
  Future<void> save(AppSettings settings, {required DateTime updatedAt}) async {
    _settings = settings;
  }
}

class DriftAppSettingsPersistenceStore implements AppSettingsPersistenceStore {
  DriftAppSettingsPersistenceStore(this._db);

  final AppDatabase _db;

  @override
  Future<AppSettings?> load() async {
    final row =
        await (_db.select(_db.appSettingsRows)
              ..where((table) => table.id.equals(AppSettingsStore.settingsId)))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }

    return AppSettings(
      themeMode: _themeModeFromStorage(row.themeMode),
      languageCode: row.languageCode,
      accentColor: row.accentColor,
      textScale: row.textScale,
      compactCards: row.compactCards,
      showSourceOnCards: row.showSourceOnCards,
      showPercentOnCovers: row.showPercentOnCovers,
      animationsMode: _animationsModeFromStorage(row.animationsMode),
    );
  }

  @override
  Future<void> save(AppSettings settings, {required DateTime updatedAt}) async {
    await _db
        .into(_db.appSettingsRows)
        .insertOnConflictUpdate(
          AppSettingsRowsCompanion(
            id: const Value(AppSettingsStore.settingsId),
            themeMode: Value(settings.themeMode.name),
            languageCode: Value(settings.languageCode),
            accentColor: Value(settings.accentColor),
            textScale: Value(settings.textScale),
            compactCards: Value(settings.compactCards),
            showSourceOnCards: Value(settings.showSourceOnCards),
            showPercentOnCovers: Value(settings.showPercentOnCovers),
            animationsMode: Value(settings.animationsMode.name),
            updatedAt: Value(updatedAt),
          ),
        );
  }
}

AppThemeMode _themeModeFromStorage(String value) {
  return AppThemeMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => AppThemeMode.system,
  );
}

AppAnimationsMode _animationsModeFromStorage(String value) {
  return AppAnimationsMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => AppAnimationsMode.full,
  );
}
