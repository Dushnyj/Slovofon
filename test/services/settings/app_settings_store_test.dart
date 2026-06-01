import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/app_settings.dart';
import 'package:slovofon/services/settings/app_settings_store.dart';

void main() {
  test('AppSettingsStore persists appearance choices', () async {
    final persistence = MemoryAppSettingsPersistenceStore();
    final store = AppSettingsStore(persistence);

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
}
