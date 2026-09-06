import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/windows_theme.dart';
import 'package:slovofon/features/home/home_screen.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/ui/adaptive/slovofon_shell.dart';
import 'package:slovofon/ui/components/book_card.dart';

const _book = AudioPlaybackBook(
  id: 'home-workspace',
  versionId: 'home-version',
  sourceId: 'knigoblud',
  sourceBookId: 'book',
  title: 'S.T.A.L.K.E.R. Полураспад',
  author: 'Александр Зорич',
  narrator: 'Чайцын Александр (Алекс)',
  sourceName: 'Книгоблуд',
  description:
      'Продолжение истории героев. Настоящее описание книги, а не декоративный текст.',
  chapters: [
    AudioPlaybackChapter(
      id: 'c0',
      index: 0,
      title: 'Возвращение',
      duration: Duration(minutes: 10),
    ),
    AudioPlaybackChapter(
      id: 'c1',
      index: 1,
      title: 'Встреча',
      duration: Duration(minutes: 10),
    ),
    AudioPlaybackChapter(
      id: 'c2',
      index: 2,
      title: 'Путь через Зону',
      duration: Duration(minutes: 10),
    ),
    AudioPlaybackChapter(
      id: 'c3',
      index: 3,
      title: 'Финал',
      duration: Duration(minutes: 10),
    ),
  ],
);

void main() {
  for (final width in [1267.0, 1920.0]) {
    for (final scale in [.9, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets(
          'single-book home uses feature and real chapter rail $width/$scale/$dark',
          (tester) async {
            final controller = await _pump(
              tester,
              width: width,
              scale: scale,
              dark: dark,
            );
            final frame = tester.getRect(
              find.byKey(const ValueKey('desktop-content-frame')),
            );
            expect(frame.right, closeTo(width, 1));
            expect(find.byType(BookCard), findsOneWidget);
            expect(
              find.byKey(const ValueKey('desktop-home-find-next')),
              findsNothing,
            );
            expect(
              find.text(
                'Найдите следующую книгу по названию, автору или чтецу.',
              ),
              findsNothing,
            );
            expect(
              tester
                  .widget<BookCard>(find.byType(BookCard))
                  .desktopPresentation,
              DesktopBookPresentation.feature,
            );
            final feature = tester.getRect(
              find.byKey(const ValueKey('desktop-home-feature')),
            );
            final rail = tester.getRect(
              find.byKey(const ValueKey('desktop-home-chapter-rail')),
            );
            expect(feature.left, closeTo(frame.left + 32, 1));
            if (width == 1920 || scale == .9) {
              expect(rail.left, greaterThan(feature.right));
              expect(rail.right, closeTo(frame.right - 32, 1));
              expect(rail.top, closeTo(feature.top, 1));
            } else {
              expect(rail.top, greaterThan(feature.bottom));
              expect(feature.right, closeTo(frame.right - 32, 1));
            }
            final title = find.descendant(
              of: find.byType(BookCard),
              matching: find.text(_book.title),
            );
            final paragraph = tester.renderObject<RenderParagraph>(title);
            expect(paragraph.textScaler.scale(14), closeTo(14 * scale, .001));
            expect(paragraph.didExceedMaxLines, isFalse);
            if (width == 1920) {
              final controls = tester.getRect(
                find.byKey(const ValueKey('desktop-book-playback-zone')),
              );
              // The feature's controls belong to the information column, not
              // a stretched second row under the cover.
              expect(controls.left, closeTo(tester.getRect(title).left, 1));
            }
            final chapter = find.byKey(const ValueKey('home-chapter-c1'));
            await tester.ensureVisible(chapter);
            await tester.pumpAndSettle();
            await tester.tap(chapter);
            await tester.pumpAndSettle();
            expect(controller.state.chapterIndex, 1);
            expect(controller.state.book!.sourceId, 'knigoblud');
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('home resize preserves book and actions while columns reflow', (
    tester,
  ) async {
    final controller = await _pump(tester, width: 1920, scale: 2, dark: true);
    for (final width in [1267.0, 900.0, 1920.0]) {
      tester.view.physicalSize = Size(width, 1050);
      await tester.pumpAndSettle();
      expect(find.byType(BookCard), findsOneWidget);
      expect(controller.state.book!.versionId, _book.versionId);
      expect(tester.takeException(), isNull);
    }
    final play = find.byKey(const ValueKey('book-card-play-knigoblud-book'));
    await tester.ensureVisible(play);
    await tester.pumpAndSettle();
    await tester.tap(play);
    await tester.pumpAndSettle();
    expect(controller.state.isPlaying, isTrue);
    expect(find.text('player destination'), findsOneWidget);
  });

  testWidgets('empty desktop home uses genuine navigation not fake books', (
    tester,
  ) async {
    await _pump(tester, width: 1920, scale: .9, dark: false, empty: true);
    expect(find.byType(BookCard), findsNothing);
    final prompt = tester.getRect(
      find.byKey(const ValueKey('desktop-home-search-prompt')),
    );
    final shortcuts = tester.getRect(
      find.byKey(const ValueKey('desktop-home-collection-links')),
    );
    expect(shortcuts.left, greaterThan(prompt.right));
    await tester.tap(find.text('Открыть поиск'));
    await tester.pumpAndSettle();
    expect(find.text('search destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<PlaybackController> _pump(
  WidgetTester tester, {
  required double width,
  required double scale,
  required bool dark,
  bool empty = false,
}) async {
  tester.view.physicalSize = Size(width, 1050);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = PlaybackController(engine: InMemoryAudioEngine());
  if (!empty) await controller.loadBook(_book);
  addTearDown(controller.dispose);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const DesktopStandaloneShell(selectedIndex: 0, child: HomeScreen()),
      ),
      GoRoute(
        path: '/player',
        builder: (_, _) => const Scaffold(body: Text('player destination')),
      ),
      GoRoute(
        path: '/search',
        builder: (_, _) => const Scaffold(body: Text('search destination')),
      ),
      GoRoute(
        path: '/library',
        builder: (_, _) => const Scaffold(body: Text('library destination')),
      ),
      GoRoute(
        path: '/downloads',
        builder: (_, _) => const Scaffold(body: Text('downloads destination')),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const Scaffold(body: Text('settings destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playbackControllerProvider.overrideWith((ref) => controller),
        downloadStorageProvider.overrideWith((ref) => _Storage()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('ru'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: WindowsTheme.from(
          (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
            platform: TargetPlatform.windows,
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

class _Storage extends FileDownloadStorage {
  _Storage() : super(rootDirectory: Directory('never-written-home-workspace'));
  @override
  Future<List<AudioPlaybackBook>> readAllMetadata() async => const [];
}
