enum AppThemeMode { system, light, dark, amoled }

enum AppAnimationsMode { full, reduced, off }

class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.languageCode = 'ru',
    this.accentColor = 'default',
    this.textScale = 1,
    this.compactCards = false,
    this.showSourceOnCards = true,
    this.showPercentOnCovers = true,
    this.animationsMode = AppAnimationsMode.full,
  });

  const AppSettings.defaults()
    : themeMode = AppThemeMode.system,
      languageCode = 'ru',
      accentColor = 'default',
      textScale = 1,
      compactCards = false,
      showSourceOnCards = true,
      showPercentOnCovers = true,
      animationsMode = AppAnimationsMode.full;

  final AppThemeMode themeMode;
  final String languageCode;
  final String accentColor;
  final double textScale;
  final bool compactCards;
  final bool showSourceOnCards;
  final bool showPercentOnCovers;
  final AppAnimationsMode animationsMode;
}
