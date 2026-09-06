import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/windows_theme.dart';
import 'package:slovofon/domain/models/audio_book.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/ui/adaptive/desktop_layout.dart';
import 'package:slovofon/ui/adaptive/slovofon_shell.dart';
import 'package:slovofon/ui/components/book_card.dart';
import 'package:slovofon/ui/components/book_cover.dart';
import 'package:slovofon/ui/components/source_badge.dart';

const _book = AudioBook(
  id: 'test',
  sourceBookId: 'test',
  title: 'Очень длинное название аудиокниги для проверки библиотеки',
  author: 'Первый автор, Второй автор',
  narrator: 'Первый чтец, Второй чтец',
  sourceId: 'izib',
  sourceName: 'Изибук',
  durationLabel: '12 ч 30 мин',
  chapterCount: 35,
  progress: .43,
  access: BookAccess.free,
  year: 2026,
  ratingValue: 4.8,
  seriesTitle: 'Длинное название литературного цикла',
);

void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.5, 2.6]) {
      testWidgets('Windows card actions/settings dark=$dark scale=$scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1200, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var play = 0;
        var favorite = 0;
        var download = 0;
        var open = 0;
        Widget app({
          bool compact = false,
          bool source = true,
          bool percent = true,
        }) => MaterialApp(
          theme: WindowsTheme.from(
            (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
              platform: TargetPlatform.windows,
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 430,
                child: DesktopPreferences(
                  compactCards: compact,
                  showSourceOnCards: source,
                  showPercentOnCovers: percent,
                  child: BookCard(
                    book: _book,
                    onTap: () => open++,
                    onPlay: () => play++,
                    onFavoritePressed: () => favorite++,
                    onDownloadPressed: () => download++,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(app());
        expect(tester.takeException(), isNull);
        expect(find.byType(SourceBadge), findsOneWidget);
        expect(find.text('43%'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('book-card-play-izib-test')),
        );
        await tester.tap(
          find.byKey(const ValueKey('book-card-favorite-izib-test')),
        );
        await tester.tap(
          find.byKey(const ValueKey('book-card-download-izib-test')),
        );
        expect([play, favorite, download, open], [1, 1, 1, 0]);
        await tester.tap(find.text(_book.title));
        expect(open, 1);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer();
        await mouse.moveTo(tester.getCenter(find.byType(BookCard)));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await mouse.removePointer();
        await tester.pumpWidget(
          app(compact: true, source: false, percent: false),
        );
        await tester.pump();
        expect(find.byType(SourceBadge), findsNothing);
        expect(find.text('43%'), findsNothing);
        expect(tester.widget<BookCover>(find.byType(BookCover)).width, 76);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final profile in [
    (TargetPlatform.windows, 900.0, 2.6),
    (TargetPlatform.windows, 1440.0, 1.0),
    (TargetPlatform.android, 1440.0, 1.0),
    (TargetPlatform.windows, 899.0, 1.0),
  ]) {
    testWidgets('shell navigation and platform boundary $profile', (
      tester,
    ) async {
      tester.view.physicalSize = Size(profile.$2, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final player = PlaybackController(engine: InMemoryAudioEngine());
      addTearDown(player.dispose);
      final router = GoRouter(
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) =>
                SlovofonShell(navigationShell: shell),
            branches: [
              for (final path in [
                '/',
                '/search',
                '/library',
                '/downloads',
                '/settings',
              ])
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: path,
                      builder: (context, state) => Text('route:$path'),
                    ),
                  ],
                ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [playbackControllerProvider.overrideWith((ref) => player)],
          child: MaterialApp.router(
            routerConfig: router,
            theme: WindowsTheme.from(
              AppTheme.light(),
            ).copyWith(platform: profile.$1),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(profile.$3),
                disableAnimations: true,
              ),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final desktop = profile.$1 == TargetPlatform.windows;
      expect(
        find.byKey(const ValueKey('windows-navigation-0')),
        desktop ? findsOneWidget : findsNothing,
      );
      if (desktop) {
        final compact = profile.$2 < 1100;
        final navigation = find.byKey(
          ValueKey(
            compact
                ? 'windows-compact-navigation-rail'
                : 'desktop-navigation-sidebar',
          ),
        );
        expect(navigation, findsOneWidget);
        expect(find.text('Slovofon'), compact ? findsNothing : findsOneWidget);
        if (compact) {
          expect(tester.getSize(navigation).width, 80);
          expect(
            find.byKey(const ValueKey('mobile-navigation-bar')),
            findsNothing,
          );
        }
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(find.text('route:/library'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('windows-navigation-4')),
        );
        await tester.tap(find.byKey(const ValueKey('windows-navigation-4')));
        await tester.pumpAndSettle();
        expect(find.text('route:/settings'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
