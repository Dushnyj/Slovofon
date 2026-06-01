enum AppThemeMode { system, light, dark, amoled }

enum AppAnimationsMode { full, reduced, off }

class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.languageCode = 'system',
    this.accentColor = 'default',
    this.textScale = 1,
    this.compactCards = false,
    this.showSourceOnCards = true,
    this.showPercentOnCovers = true,
    this.animationsMode = AppAnimationsMode.full,
  });

  const AppSettings.defaults()
    : themeMode = AppThemeMode.system,
      languageCode = 'system',
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

  AppSettings copyWith({
    AppThemeMode? themeMode,
    String? languageCode,
    String? accentColor,
    double? textScale,
    bool? compactCards,
    bool? showSourceOnCards,
    bool? showPercentOnCovers,
    AppAnimationsMode? animationsMode,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      languageCode: languageCode ?? this.languageCode,
      accentColor: accentColor ?? this.accentColor,
      textScale: textScale ?? this.textScale,
      compactCards: compactCards ?? this.compactCards,
      showSourceOnCards: showSourceOnCards ?? this.showSourceOnCards,
      showPercentOnCovers: showPercentOnCovers ?? this.showPercentOnCovers,
      animationsMode: animationsMode ?? this.animationsMode,
    );
  }
}
