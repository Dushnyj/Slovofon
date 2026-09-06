import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/data/database/app_database.dart';
import 'package:slovofon/domain/models/app_settings.dart';
import 'package:slovofon/services/settings/app_settings_store.dart';

void main() {
  test('appearance update during hydration preserves saved fields', () async {
    final persistence = _DelayedSettingsStore();
    final store = AppSettingsStore(persistence);
    unawaited(store.load());
    final update = store.setAccentColor('red');
    persistence.loaded.complete(
      const AppSettings(
        themeMode: AppThemeMode.dark,
        languageCode: 'ru',
        textScale: 1.175,
        compactCards: true,
      ),
    );
    await update;
    expect(store.settings.accentColor, 'red');
    expect(store.settings.themeMode, AppThemeMode.dark);
    expect(store.settings.languageCode, 'ru');
    expect(store.settings.textScale, 1.175);
    expect(store.settings.compactCards, isTrue);
    store.dispose();
  });

  test('concurrent appearance updates compose without lost fields', () async {
    final persistence = MemoryAppSettingsPersistenceStore();
    final store = AppSettingsStore(persistence);
    await Future.wait([
      store.setThemeMode(AppThemeMode.dark),
      store.setLanguageCode('ru'),
      store.setAccentColor('green'),
      store.setCompactCards(true),
      store.setTextScale(2),
    ]);
    final saved = (await persistence.load())!;
    expect(saved.themeMode, AppThemeMode.dark);
    expect(saved.languageCode, 'ru');
    expect(saved.accentColor, 'green');
    expect(saved.compactCards, isTrue);
    expect(saved.textScale, 2);
    store.dispose();
  });
  test('AppSettingsStore persists appearance choices', () async {
    final persistence = MemoryAppSettingsPersistenceStore();
    final store = AppSettingsStore(persistence);
    addTearDown(store.dispose);

    await store.load();
    expect(store.settings.languageCode, 'system');
    expect(store.settings.themeMode, AppThemeMode.system);

    await store.setThemeMode(AppThemeMode.dark);
    await store.setLanguageCode('ru');
    await store.setAccentColor('green');
    await store.setTextScale(1.2);
    await store.setCompactCards(true);
    await store.setShowSourceOnCards(false);
    await store.setShowPercentOnCovers(false);
    await store.setAnimationsMode(AppAnimationsMode.reduced);

    final reloaded = AppSettingsStore(persistence);
    addTearDown(reloaded.dispose);
    await reloaded.load();

    expect(reloaded.settings.themeMode, AppThemeMode.dark);
    expect(reloaded.settings.languageCode, 'ru');
    expect(reloaded.settings.accentColor, 'green');
    expect(reloaded.settings.textScale, 1.2);
    expect(reloaded.settings.compactCards, isTrue);
    expect(reloaded.settings.showSourceOnCards, isFalse);
    expect(reloaded.settings.showPercentOnCovers, isFalse);
    expect(reloaded.settings.animationsMode, AppAnimationsMode.reduced);
  });

  for (final scale in [0.75, 1.0, 1.175, 2.0]) {
    test('text scale $scale round-trips through SQLite', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final persistence = DriftAppSettingsPersistenceStore(db);
      final store = AppSettingsStore(persistence);
      addTearDown(store.dispose);
      await store.setTextScale(scale);

      final reloaded = AppSettingsStore(persistence);
      addTearDown(reloaded.dispose);
      await reloaded.load();

      expect(reloaded.settings.textScale, scale);
      expect((await persistence.load())!.textScale, scale);
    });
  }

  for (final sample in <(String, double, double)>[
    ('below range', 0.5, 0.75),
    ('above range', 3, 2),
    ('negative', -1, 0.75),
    ('NaN', double.nan, 1),
    ('positive infinity', double.infinity, 1),
    ('negative infinity', double.negativeInfinity, 1),
  ]) {
    test('text scale setter normalizes ${sample.$1}', () async {
      final persistence = MemoryAppSettingsPersistenceStore();
      final store = AppSettingsStore(persistence);
      addTearDown(store.dispose);
      await store.setTextScale(sample.$2);
      expect(store.settings.textScale, sample.$3);
      expect((await persistence.load())!.textScale, sample.$3);
    });

    test('hydration normalizes ${sample.$1} without saving', () async {
      final persistence = _RecordingSettingsStore(
        AppSettings(
          themeMode: AppThemeMode.amoled,
          languageCode: 'uk',
          accentColor: '#AABBCC',
          textScale: sample.$2,
          compactCards: true,
          showSourceOnCards: false,
          showPercentOnCovers: false,
          animationsMode: AppAnimationsMode.off,
        ),
      );
      final store = AppSettingsStore(persistence);
      addTearDown(store.dispose);
      await store.load();

      expect(store.settings.textScale, sample.$3);
      expect(store.settings.themeMode, AppThemeMode.amoled);
      expect(store.settings.languageCode, 'uk');
      expect(store.settings.accentColor, '#AABBCC');
      expect(store.settings.compactCards, isTrue);
      expect(store.settings.showSourceOnCards, isFalse);
      expect(store.settings.showPercentOnCovers, isFalse);
      expect(store.settings.animationsMode, AppAnimationsMode.off);
      expect(persistence.saveCount, 0);
    });
  }

  test(
    'text scale update awaits hydration and preserves saved fields',
    () async {
      final persistence = _DelayedSettingsStore();
      final store = AppSettingsStore(persistence);
      addTearDown(store.dispose);
      unawaited(store.load());
      final update = store.setTextScale(0.75);
      persistence.loaded.complete(
        const AppSettings(
          themeMode: AppThemeMode.dark,
          languageCode: 'ru',
          accentColor: 'green',
          textScale: 1.2,
          compactCards: true,
        ),
      );
      await update;

      expect(store.settings.textScale, 0.75);
      expect(store.settings.themeMode, AppThemeMode.dark);
      expect(store.settings.languageCode, 'ru');
      expect(store.settings.accentColor, 'green');
      expect(store.settings.compactCards, isTrue);
    },
  );
}

class _RecordingSettingsStore implements AppSettingsPersistenceStore {
  _RecordingSettingsStore(this.settings);

  final AppSettings settings;
  var saveCount = 0;

  @override
  Future<AppSettings?> load() async => settings;

  @override
  Future<void> save(AppSettings settings, {required DateTime updatedAt}) async {
    saveCount++;
  }
}

class _DelayedSettingsStore implements AppSettingsPersistenceStore {
  final loaded = Completer<AppSettings?>();
  @override
  Future<AppSettings?> load() => loaded.future;
  @override
  Future<void> save(
    AppSettings settings, {
    required DateTime updatedAt,
  }) async {}
}
