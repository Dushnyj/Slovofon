import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/television_theme.dart';
import 'package:slovofon/app/theme/windows_theme.dart';
import 'package:slovofon/features/player/full_player_screen.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/ui/adaptive/television_layout.dart';
import 'package:slovofon/ui/adaptive/television_shell.dart';
import 'package:slovofon/ui/components/mini_player_bar.dart';
import 'package:slovofon/ui/components/seek_interval_icon.dart';
import 'package:slovofon/ui/icons/app_icons.dart';

void main() {
  for (final dark in [false, true]) {
    for (final profile in [
      (
        name: 'phone controls',
        width: 390.0,
        height: 844.0,
        windows: false,
        television: false,
        full: false,
      ),
      (
        name: 'phone full',
        width: 390.0,
        height: 844.0,
        windows: false,
        television: false,
        full: true,
      ),
      (
        name: 'tablet dock',
        width: 1280.0,
        height: 800.0,
        windows: false,
        television: false,
        full: false,
      ),
      (
        name: 'tablet full',
        width: 1280.0,
        height: 800.0,
        windows: false,
        television: false,
        full: true,
      ),
      (
        name: 'Windows dock',
        width: 1920.0,
        height: 1080.0,
        windows: true,
        television: false,
        full: false,
      ),
      (
        name: 'Windows full',
        width: 1920.0,
        height: 1080.0,
        windows: true,
        television: false,
        full: true,
      ),
      (
        name: 'TV dock',
        width: 960.0,
        height: 540.0,
        windows: false,
        television: true,
        full: false,
      ),
      (
        name: 'TV full',
        width: 960.0,
        height: 540.0,
        windows: false,
        television: true,
        full: true,
      ),
    ]) {
      testWidgets(
        '${profile.name} uses shared directional 15s vectors dark=$dark',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(profile.width, profile.height);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final controller = PlaybackController(engine: InMemoryAudioEngine());
          await controller.loadBook(
            _book,
            position: const Duration(seconds: 60),
          );
          final manager = DownloadManager(
            client: _NoNetworkClient(),
            storage: FileDownloadStorage(
              rootDirectory: Directory('unused-seek-consumer-fixture'),
            ),
            persistence: MemoryDownloadPersistenceStore(),
          );
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) {
                  if (profile.full) return const FullPlayerScreen();
                  if (profile.television) {
                    return TelevisionShell(
                      selectedIndex: 0,
                      onSelected: (_) {},
                      child: const SizedBox.expand(),
                    );
                  }
                  return Scaffold(
                    body: Column(
                      children: [
                        const Expanded(child: SizedBox()),
                        if (profile.width < 900)
                          const MiniPlayerControlsBar()
                        else
                          const DesktopMiniPlayerBar(),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
          addTearDown(router.dispose);
          var theme = (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
            platform: profile.windows
                ? TargetPlatform.windows
                : TargetPlatform.android,
          );
          if (profile.windows) theme = WindowsTheme.from(theme);
          if (profile.television) theme = TelevisionTheme.from(theme);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                playbackControllerProvider.overrideWith((ref) {
                  ref.onDispose(controller.dispose);
                  return controller;
                }),
                downloadManagerProvider.overrideWith((ref) {
                  ref.onDispose(manager.dispose);
                  return manager;
                }),
              ],
              child: MaterialApp.router(
                theme: theme,
                routerConfig: router,
                locale: const Locale('en'),
                supportedLocales: AppStrings.supportedLocales,
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                builder: (context, child) => TelevisionLayout(
                  enabled: profile.television,
                  child: profile.television
                      ? TelevisionViewport(child: child!)
                      : child!,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final shared = find.byType(SeekIntervalIcon);
          expect(shared, findsNWidgets(2));
          expect(
            tester
                .widgetList<SeekIntervalIcon>(shared)
                .map((icon) => icon.forward),
            containsAll([false, true]),
          );
          for (final icon
              in tester
                  .widgetList<AppIcon>(find.byType(AppIcon))
                  .where(
                    (icon) =>
                        icon.asset == AppIconAssets.playerRewind15 ||
                        icon.asset == AppIconAssets.playerForward15,
                  )) {
            expect(
              find.ancestor(of: find.byWidget(icon), matching: shared),
              findsOneWidget,
            );
          }
          // Test the real buttons, not a reconstruction of their dispatch logic.
          for (final forward in [false, true]) {
            final graphic = find.byWidgetPredicate(
              (widget) =>
                  widget is SeekIntervalIcon && widget.forward == forward,
            );
            final button = find.ancestor(
              of: graphic,
              matching: find.byType(IconButton),
            );
            expect(button, findsOneWidget);
            final strings = AppStrings.of(tester.element(button));
            expect(
              tester.widget<IconButton>(button).tooltip,
              forward ? strings.forward15 : strings.rewind15,
            );
            await tester.ensureVisible(button);
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(
              controller.state.position,
              Duration(seconds: forward ? 60 : 45),
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

const _book = AudioPlaybackBook(
  id: 'seek-consumer-book',
  versionId: 'seek-consumer-version',
  sourceId: 'akniga',
  sourceName: 'Akniga',
  title: 'White nights',
  author: 'Fyodor Dostoevsky',
  narrator: 'Narrator',
  chapters: [
    AudioPlaybackChapter(
      id: 'one',
      index: 0,
      title: 'Chapter one',
      duration: Duration(minutes: 20),
    ),
  ],
);

class _NoNetworkClient implements DownloadClient {
  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async => throw StateError('Seek consumer test never downloads media');
}
