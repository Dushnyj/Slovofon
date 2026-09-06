import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_color_tokens.dart';
import 'package:slovofon/app/theme/app_theme.dart';
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

void main() {
  for (final size in [const Size(393, 852), const Size(800, 1280)]) {
    for (final mode in ['light', 'dark', 'amoled']) {
      for (final accent in [const Color(0xFF7C3AED), const Color(0xFFCA8A04)]) {
        testWidgets('Player metadata link contrast $size $mode $accent', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final controller = PlaybackController(engine: InMemoryAudioEngine());
          addTearDown(controller.dispose);
          await controller.loadBook(
            const AudioPlaybackBook(
              id: 'metadata-contrast-book',
              versionId: 'metadata-contrast-version',
              sourceId: 'izib',
              sourceName: 'Изибук',
              title: 'Белые ночи',
              author: 'Федор Достоевский',
              narrator: 'Василий Дахненко',
              chapters: [
                AudioPlaybackChapter(
                  id: 'chapter-1',
                  index: 0,
                  title: 'Ночь первая',
                  duration: Duration(minutes: 12),
                ),
              ],
            ),
            autoPlay: false,
          );
          final manager = DownloadManager(
            client: _NoNetworkClient(),
            storage: FileDownloadStorage(
              rootDirectory: Directory('unused-player-metadata-contrast'),
            ),
            persistence: MemoryDownloadPersistenceStore(),
          );
          final router = GoRouter(
            initialLocation: '/player',
            routes: [
              GoRoute(
                path: '/player',
                builder: (_, _) => const FullPlayerScreen(),
              ),
              GoRoute(
                path: '/scoped-search',
                builder: (_, _) =>
                    const Scaffold(body: Text('Search destination')),
              ),
            ],
          );
          addTearDown(router.dispose);
          final theme =
              (mode == 'light'
                      ? AppTheme.light(accent: accent)
                      : AppTheme.dark(accent: accent, amoled: mode == 'amoled'))
                  .copyWith(platform: TargetPlatform.android);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                playbackControllerProvider.overrideWith((ref) => controller),
                downloadManagerProvider.overrideWith((ref) => manager),
              ],
              child: MaterialApp.router(
                theme: theme,
                routerConfig: router,
                locale: const Locale('ru'),
                supportedLocales: AppStrings.supportedLocales,
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final link = find.byKey(
            const ValueKey('mobile-player-meta-author-Федор Достоевский'),
          );
          await tester.ensureVisible(link);
          await tester.pumpAndSettle();
          final button = tester.widget<TextButton>(link);
          final label = button.child! as Text;
          expect(
            label.style!.color,
            isNull,
            reason: 'Text must inherit the state foreground',
          );
          expect(label.style!.decoration, TextDecoration.underline);
          for (final states in <Set<WidgetState>>[
            {},
            {WidgetState.hovered},
            {WidgetState.focused},
            {WidgetState.pressed},
          ]) {
            final foreground = button.style!.foregroundColor!.resolve(states)!;
            final background = Color.alphaBlend(
              button.style!.backgroundColor!.resolve(states)!,
              theme.scaffoldBackgroundColor,
            );
            expect(
              AppColorTokens.contrastRatio(foreground, background),
              greaterThanOrEqualTo(4.5),
              reason: '$states',
            );
          }
          await tester.tap(link);
          await tester.pumpAndSettle();
          // An imperative push need not update the platform URL provider.
          // Inspect the actually displayed destination route instead.
          final destination = find.text('Search destination');
          expect(destination, findsOneWidget);
          final uri = GoRouterState.of(tester.element(destination)).uri;
          expect(uri.path, '/scoped-search');
          expect(uri.queryParameters['q'], 'Федор Достоевский');
          expect(uri.queryParameters['kind'], 'author');
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

class _NoNetworkClient implements DownloadClient {
  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async =>
      throw StateError('Metadata contrast fixture does not access media');
}
