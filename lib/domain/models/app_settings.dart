enum AppThemeMode { system, light, dark, amoled }

enum AppAnimationsMode { full, reduced, off }

class AppSettings {
  static const minTextScale = 0.75;
  static const maxTextScale = 2.0;
  static const defaultTextScale = 1.0;
  static const textScaleStep = 0.05;

  /// Keeps persisted preferences and UI controls within the same safe range.
  /// Valid values are not rounded so existing preferences retain their size.
  static double normalizeTextScale(double value) {
    if (!value.isFinite) return defaultTextScale;
    return value.clamp(minTextScale, maxTextScale);
  }

  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.languageCode = 'system',
    this.accentColor = 'default',
    this.textScale = defaultTextScale,
    this.compactCards = false,
    this.showSourceOnCards = true,
    this.showPercentOnCovers = true,
    this.animationsMode = AppAnimationsMode.full,
  });

  const AppSettings.defaults()
    : themeMode = AppThemeMode.system,
      languageCode = 'system',
      accentColor = 'default',
      textScale = defaultTextScale,
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
