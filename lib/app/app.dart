import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/app_settings.dart';
import '../core/platform/app_device_profile.dart';
import '../services/deep_links/app_deep_links.dart';
import '../services/deep_links/slovofon_deep_link.dart';
import '../services/settings/app_settings_store.dart';
import '../services/updates/update_prompt.dart';
import '../ui/adaptive/desktop_layout.dart';
import '../ui/adaptive/television_layout.dart';
import '../ui/adaptive/windows_playback_shortcuts.dart';
import '../ui/components/playback_error_listener.dart';
import 'localization/app_strings.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/app_text_scaler.dart';
import 'theme/windows_theme.dart';
import 'theme/television_theme.dart';

class SlovofonApp extends ConsumerStatefulWidget {
  const SlovofonApp({
    this.deepLinks = const NoopAppDeepLinkSource(),
    super.key,
  });

  final AppDeepLinkSource deepLinks;

  @override
  ConsumerState<SlovofonApp> createState() => _SlovofonAppState();
}

class _SlovofonAppState extends ConsumerState<SlovofonApp> {
  StreamSubscription<Uri>? _deepLinkSubscription;

  @override
  void initState() {
    super.initState();
    _listenForDeepLinks();
  }

  @override
  void didUpdateWidget(covariant SlovofonApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deepLinks != widget.deepLinks) {
      unawaited(_deepLinkSubscription?.cancel());
      _listenForDeepLinks();
    }
  }

  @override
  void dispose() {
    unawaited(_deepLinkSubscription?.cancel());
    super.dispose();
  }

  void _listenForDeepLinks() {
    unawaited(_handleInitialDeepLink(widget.deepLinks));
    _deepLinkSubscription = widget.deepLinks.links.listen(
      _openDeepLink,
      onError: _reportDeepLinkError,
    );
  }

  Future<void> _handleInitialDeepLink(AppDeepLinkSource source) async {
    try {
      final uri = await source.getInitialLink();
      if (mounted && uri != null) {
        _openDeepLink(uri);
      }
    } catch (error, stackTrace) {
      _reportDeepLinkError(error, stackTrace);
    }
  }

  void _openDeepLink(Uri uri) {
    final location = sourceBookLocationFromDeepLink(uri);
    if (location == null) {
      return;
    }
    if (mounted) {
      appRouter.go(location);
    }
  }

  void _reportDeepLinkError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'slovofon deep links',
        context: ErrorDescription('while handling app link'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appSettings = ref.watch(appSettingsStoreProvider).settings;
    final television = ref.watch(appDeviceProfileProvider).isTelevision;
    final accent = _accentColor(appSettings.accentColor);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => context.strings.appTitle,
      routerConfig: appRouter,
      locale: _localeFor(appSettings.languageCode),
      themeMode: _themeModeFor(appSettings.themeMode),
      theme: AppTheme.light(accent: accent),
      darkTheme: AppTheme.dark(
        accent: accent,
        amoled: appSettings.themeMode == AppThemeMode.amoled,
      ),
      highContrastTheme: AppTheme.light(accent: accent, highContrast: true),
      highContrastDarkTheme: AppTheme.dark(
        accent: accent,
        highContrast: true,
        amoled: appSettings.themeMode == AppThemeMode.amoled,
      ),
      builder: (context, child) {
        final routeChild = PlaybackErrorListener(
          child: child ?? const SizedBox.shrink(),
        );
        return UpdateStartupGate(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations:
                  MediaQuery.disableAnimationsOf(context) ||
                  ((DesktopLayout.isActive(context) || television) &&
                      appSettings.animationsMode != AppAnimationsMode.full),
              textScaler: AppTextScaler(
                MediaQuery.textScalerOf(context),
                appSettings.textScale,
              ),
            ),
            child: DesktopPreferences(
              compactCards: appSettings.compactCards,
              showSourceOnCards: appSettings.showSourceOnCards,
              showPercentOnCovers: appSettings.showPercentOnCovers,
              child: television
                  ? TelevisionLayout(
                      enabled: true,
                      child: Theme(
                        data: TelevisionTheme.from(Theme.of(context)),
                        child: TelevisionViewport(child: routeChild),
                      ),
                    )
                  : DesktopLayout.isActive(context)
                  ? Theme(
                      data: WindowsTheme.from(Theme.of(context)),
                      child: WindowsPlaybackShortcuts(child: routeChild),
                    )
                  : routeChild,
            ),
          ),
        );
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppStrings.supportedLocales,
    );
  }
}

Locale? _localeFor(String languageCode) {
  if (languageCode == 'system') {
    return null;
  }
  return Locale(languageCode);
}

ThemeMode _themeModeFor(AppThemeMode mode) {
  return switch (mode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark || AppThemeMode.amoled => ThemeMode.dark,
  };
}

Color _accentColor(String id) {
  if (id.startsWith('custom:#')) {
    final hex = id.substring('custom:#'.length);
    if (RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)) {
      return Color(0xFF000000 | int.parse(hex, radix: 16));
    }
  }
  return switch (id) {
    'green' => const Color(0xFF1F7A4D),
    'teal' => const Color(0xFF0F766E),
    'red' => const Color(0xFFB42318),
    'gold' => const Color(0xFF8A5B00),
    _ => const Color(0xFF516AA4),
  };
}
