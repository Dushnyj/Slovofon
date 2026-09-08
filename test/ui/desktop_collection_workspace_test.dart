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
import 'package:slovofon/domain/models/audio_book.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/features/downloads/downloads_screen.dart';
import 'package:slovofon/features/library/library_screen.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_persistence.dart';
import 'package:slovofon/services/bookmarks/bookmark_store.dart';
import 'package:slovofon/services/library/library_metadata.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/library/library_store.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/sources/sources.dart';
import 'package:slovofon/ui/adaptive/desktop_layout.dart';
import 'package:slovofon/ui/adaptive/slovofon_shell.dart';
import 'package:slovofon/ui/components/book_card.dart';
import 'package:slovofon/ui/components/book_cover.dart';
import 'package:slovofon/ui/components/responsive_tile_grid.dart';

void main() {
  testWidgets('all eight library shelves show real distinct membership', (
    tester,
  ) async {
    final fixture = await _pump(tester, shelfFixture: true);
    for (final entry in const {
      'All': 5,
      'Listening': 1,
      'Favorites': 1,
      'Later': 1,
      'Downloaded': 1,
      'Finished': 1,
      'Bookmarks': 1,
      'History': 2,
    }.entries) {
      final tab = find.widgetWithText(ChoiceChip, entry.key);
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pumpAndSettle();
      if (entry.key == 'Bookmarks') {
        expect(find.text('Shelf bookmark · 0:01'), findsOneWidget);
        expect(find.byType(BookCard), findsNothing);
      } else {
        expect(
          find.byType(BookCard),
          findsNWidgets(entry.value),
          reason: entry.key,
        );
      }
      expect(tester.takeException(), isNull, reason: entry.key);
    }
    await fixture.library.toggleLater(_libraryBook(1));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Later'));
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.forLocale(const Locale('en')).emptyLaterShelf),
      findsOneWidget,
    );
    expect(find.byType(BookCard), findsNothing);
    expect(fixture.library.favorites, hasLength(1));
  });
  for (final width in [900.0, 1267.0, 1920.0]) {
    for (final dark in [false, true]) {
      for (final scale in [.75, 1.0, 2.0, 3.0]) {
        testWidgets('collection fills width $width dark $dark scale $scale', (
          tester,
        ) async {
          for (final downloads in [false, true]) {
            final fixture = await _pump(
              tester,
              downloads: downloads,
              width: width,
              dark: dark,
              scale: scale,
            );
            await _revealFirstRow(tester, downloads: downloads);
            _expectRowsFillWidth(tester, fixture, downloads: downloads);
            final row = downloads
                ? _downloadRow(0)
                : find.byType(BookCard).first;
            final title = find.descendant(
              of: row,
              matching: find.text(_book(0).title),
            );
            expect(title, findsOneWidget);
            final paragraph = tester.renderObject<RenderParagraph>(title);
            expect(paragraph.textScaler.scale(14), closeTo(14 * scale, .01));
            expect(paragraph.didExceedMaxLines, isFalse);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          }
        });
      }
    }
  }

  for (final width in [900.0, 1024.0]) {
    for (final dark in [false, true]) {
      testWidgets('short downloads prioritize transfer at $width dark $dark', (
        tester,
      ) async {
        for (final scale in [1.0, 2.0]) {
          final fixture = await _pump(
            tester,
            downloads: true,
            width: width,
            height: 600,
            scale: scale,
            dark: dark,
            realShell: true,
            statuses: [DownloadTaskStatus.running],
          );
          await fixture.controller.loadBook(_book(0));
          await tester.pumpAndSettle();
          final row = _downloadRow(0);
          final transfer = find.byKey(
            const ValueKey('desktop-download-transfer-knigoblud:version-0'),
          );
          if (scale > 1) {
            await tester.scrollUntilVisible(
              transfer,
              180,
              scrollable: find
                  .descendant(
                    of: find.byKey(const PageStorageKey('downloads-scroll')),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await tester.pumpAndSettle();
          }
          expect(
            find.byKey(
              const ValueKey('desktop-download-compact-knigoblud:version-0'),
            ),
            findsOneWidget,
          );
          final metadata = find.byKey(
            const ValueKey('desktop-download-metadata-knigoblud:version-0'),
          );
          final title = find.byKey(
            const ValueKey('desktop-download-title-knigoblud:version-0'),
          );
          expect(
            tester.getRect(title).bottom,
            lessThan(tester.getRect(transfer).top),
          );
          expect(
            tester.getRect(transfer).bottom,
            lessThan(tester.getRect(metadata).top),
          );
          final pause = find.descendant(
            of: transfer,
            matching: find.byTooltip('Pause download'),
          );
          final cancel = find.descendant(
            of: transfer,
            matching: find.byTooltip('Cancel download'),
          );
          expect(pause, findsOneWidget);
          expect(cancel, findsOneWidget);
          if (scale == 1) {
            final content = tester.getRect(find.byType(DownloadsScreen));
            for (final action in [pause, cancel]) {
              final rect = tester.getRect(action);
              expect(rect.top, greaterThanOrEqualTo(content.top));
              expect(rect.bottom, lessThanOrEqualTo(content.bottom));
            }
          }
          // Bibliographic facts remain accessible from book details; the
          // transfer row keeps only narrator/source/duration/progress.
          expect(
            find.descendant(of: row, matching: find.text(_book(0).author)),
            findsNothing,
          );
          expect(
            find.descendant(of: row, matching: find.text(_book(0).narrator)),
            findsOneWidget,
          );
          await tester.tap(pause);
          await tester.pumpAndSettle();
          expect(
            fixture.manager.actions.where(
              (action) => action.startsWith('pause:'),
            ),
            hasLength(3),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });
    }
  }

  testWidgets(
    'empty desktop downloads offer search instead of zero dashboard',
    (tester) async {
      final fixture = await _pump(
        tester,
        downloads: true,
        width: 1024,
        height: 600,
        count: 0,
        realShell: true,
      );
      expect(
        find.byKey(const ValueKey('desktop-download-summary')),
        findsNothing,
      );
      final strings = AppStrings.forLocale(const Locale('en'));
      expect(find.text(strings.booksCount(0)), findsNothing);
      expect(find.text(strings.emptyDownloadsMessage), findsOneWidget);
      final action = find.byKey(
        const ValueKey('desktop-downloads-empty-search'),
      );
      final viewport = tester.getRect(find.byType(DownloadsScreen));
      expect(tester.getRect(action).bottom, lessThanOrEqualTo(viewport.bottom));
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(fixture.router.state.uri.path, '/search');
      expect(find.text('Search destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final count in [3, 12]) {
    testWidgets('$count books keep full-width rows instead of a sparse grid', (
      tester,
    ) async {
      for (final downloads in [false, true]) {
        final fixture = await _pump(tester, downloads: downloads, count: count);
        if (!downloads) {
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey('desktop-library-count')),
                )
                .data,
            AppStrings.forLocale(const Locale('en')).booksCount(count),
          );
        }
        await _revealFirstRow(tester, downloads: downloads);
        _expectRowsFillWidth(tester, fixture, downloads: downloads);
        expect(find.byType(ResponsiveTileGrid), findsNothing);
        expect(
          find.byType(downloads ? ExpansionTile : BookCard).evaluate().length,
          inInclusiveRange(1, count),
        );
        // A lazy collection no longer mounts every item simultaneously. Visit
        // every identity and retain the full-width geometry assertions there.
        for (var index = 0; index < count; index++) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pump();
          final row = downloads
              ? _downloadRow(index)
              : find.byWidgetPredicate(
                  (widget) =>
                      widget is BookCard &&
                      widget.book.title == _book(index).title,
                );
          await tester.scrollUntilVisible(
            row,
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(row, findsOneWidget);
          _expectRowsFillWidth(tester, fixture, downloads: downloads);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }

  testWidgets(
    'download summary counts books, excludes canceled, updates live',
    (tester) async {
      final fixture = await _pump(
        tester,
        downloads: true,
        statuses: [
          DownloadTaskStatus.running,
          DownloadTaskStatus.paused,
          DownloadTaskStatus.queued,
          DownloadTaskStatus.failed,
          DownloadTaskStatus.completed,
          DownloadTaskStatus.canceled,
        ],
      );
      _expectSummary(tester, active: 2, queued: 1, failed: 1, completed: 1);
      // Sections below the viewport are intentionally built lazily. Inspect
      // every expected book rather than requiring all sections to stay mounted.
      for (var index = 0; index < 5; index++) {
        await tester.scrollUntilVisible(
          _downloadRow(index),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(_downloadRow(index), findsOneWidget);
      }
      expect(_downloadRow(5), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('desktop-download-summary')),
        -500,
        scrollable: find.byType(Scrollable).first,
      );
      fixture.manager.setStatus(0, DownloadTaskStatus.completed);
      fixture.manager.setStatus(3, DownloadTaskStatus.queued);
      await tester.pumpAndSettle();
      _expectSummary(tester, active: 1, queued: 2, failed: 0, completed: 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'library keeps live count, shelves, favorite and playback actions',
    (tester) async {
      final fixture = await _pump(tester, count: 2);
      await fixture.controller.loadBook(_book(0));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('book-card-play-knigoblud-book-0')),
      );
      await tester.tap(
        find.byKey(const ValueKey('book-card-play-knigoblud-book-0')),
      );
      await tester.pumpAndSettle();
      expect(fixture.controller.state.isPlaying, isTrue);
      await tester.tap(
        find.byKey(const ValueKey('book-card-play-knigoblud-book-0')),
      );
      await tester.pumpAndSettle();
      expect(fixture.controller.state.isPlaying, isFalse);
      await tester.tap(
        find.byKey(const ValueKey('book-card-favorite-knigoblud-book-0')),
      );
      await tester.pumpAndSettle();
      expect(fixture.library.favorites, hasLength(1));
      // The active book remains in History/All even after removing Favorites.
      expect(find.byType(BookCard), findsNWidgets(2));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('desktop-library-count')))
            .data,
        AppStrings.forLocale(const Locale('en')).booksCount(2),
      );
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Favorites'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Favorites'));
      await tester.pumpAndSettle();
      expect(find.byType(BookCard), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('download actions and expanded chapters keep their targets', (
    tester,
  ) async {
    final fixture = await _pump(
      tester,
      downloads: true,
      statuses: [DownloadTaskStatus.running],
    );
    var row = _downloadRow(0);
    await tester.tap(
      find.descendant(of: row, matching: find.byTooltip('Pause download')),
    );
    await tester.pumpAndSettle();
    expect(
      fixture.manager.actions.where((action) => action.startsWith('pause:')),
      hasLength(3),
    );

    fixture.manager.setStatus(0, DownloadTaskStatus.paused);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: row, matching: find.byTooltip('Resume download')),
    );
    await tester.pumpAndSettle();
    expect(
      fixture.manager.actions.where((action) => action.startsWith('resume:')),
      hasLength(3),
    );
    expect(fixture.manager.actions, contains('missing:version-0'));

    fixture.manager.setStatus(0, DownloadTaskStatus.failed);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: row, matching: find.byTooltip('Retry')),
    );
    await tester.pumpAndSettle();
    expect(
      fixture.manager.actions.where((action) => action.startsWith('retry:')),
      hasLength(3),
    );

    fixture.manager.setStatus(0, DownloadTaskStatus.completed);
    await fixture.controller.loadBook(_book(0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: row, matching: find.byTooltip('Play')),
    );
    await tester.pumpAndSettle();
    expect(fixture.controller.state.isPlaying, isTrue);

    final expansion = find.descendant(
      of: row,
      matching: find.byType(ExpansionTile),
    );
    await tester.tap(
      find.descendant(of: expansion, matching: find.text(_book(0).title)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Глава 2. Продолжение путешествия'), findsOneWidget);
    await tester.ensureVisible(find.text('Глава 2. Продолжение путешествия'));
    await tester.tap(find.text('Глава 2. Продолжение путешествия'));
    await tester.pumpAndSettle();
    expect(fixture.controller.state.chapterIndex, 1);
    expect(find.text('Глава 2. Продолжение путешествия'), findsOneWidget);

    row = _downloadRow(0);
    final transfer = find.byKey(
      const ValueKey('desktop-download-transfer-knigoblud:version-0'),
    );
    await tester.ensureVisible(transfer);
    await tester.tap(
      find.descendant(
        of: transfer,
        matching: find.byTooltip('Delete downloaded'),
      ),
    );
    await tester.pumpAndSettle();
    expect(fixture.manager.actions, contains('delete:version-0'));
    expect(tester.takeException(), isNull);
  });

  for (final compact in [false, true]) {
    testWidgets('download workspace honors card settings compact $compact', (
      tester,
    ) async {
      final fixture = await _pump(
        tester,
        downloads: true,
        compact: compact,
        source: false,
        percent: false,
      );
      await fixture.controller.loadBook(
        _book(0),
        position: const Duration(minutes: 6),
      );
      await tester.pumpAndSettle();
      final cover = tester.widget<BookCover>(find.byType(BookCover).first);
      expect(cover.width, compact ? 72 : 88);
      expect(cover.showProgressPercent, isFalse);
      expect(find.text('Knigoblud'), findsNothing);
      expect(
        find.byKey(
          const ValueKey('desktop-download-listening-knigoblud:version-0'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final profile in [
    (TargetPlatform.android, 390.0),
    (TargetPlatform.android, 1440.0),
    (TargetPlatform.windows, 899.0),
  ]) {
    testWidgets('collection workspace follows platform for $profile', (
      tester,
    ) async {
      for (final downloads in [false, true]) {
        final fixture = await _pump(
          tester,
          downloads: downloads,
          platform: profile.$1,
          width: profile.$2,
        );
        final desktop = profile.$1 == TargetPlatform.windows;
        expect(find.byType(ResponsiveTileGrid), findsNothing);
        if (downloads) {
          expect(
            find.descendant(
              of: find.byKey(const PageStorageKey('downloads-scroll')),
              matching: find.byType(SliverList),
            ),
            findsOneWidget,
            reason: 'One lazy list owns all section offsets during resize.',
          );
        } else {
          expect(find.byType(SliverResponsiveTileGrid), findsOneWidget);
          expect(
            tester
                .widget<SliverResponsiveTileGrid>(
                  find.byType(SliverResponsiveTileGrid),
                )
                .singleColumn,
            desktop,
          );
        }
        expect(
          find.byKey(const ValueKey('desktop-library-rows')),
          desktop && !downloads ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const ValueKey('desktop-download-summary')),
          desktop && downloads ? findsOneWidget : findsNothing,
        );
        if (desktop) {
          await _revealFirstRow(tester, downloads: downloads);
          _expectRowsFillWidth(tester, fixture, downloads: downloads);
        }
        expect(
          _downloadRow(0),
          desktop && downloads ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}

Finder _downloadRow(int index) =>
    find.byKey(ValueKey('desktop-download-book-knigoblud:version-$index'));

Future<void> _revealFirstRow(
  WidgetTester tester, {
  required bool downloads,
}) async {
  await tester.scrollUntilVisible(
    downloads ? _downloadRow(0) : find.byType(BookCard).first,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void _expectRowsFillWidth(
  WidgetTester tester,
  _Fixture fixture, {
  required bool downloads,
}) {
  final rows = downloads
      ? find.byWidgetPredicate(
          (widget) =>
              widget is Card &&
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'desktop-download-book-',
              ),
        )
      : find.byType(BookCard);
  expect(rows, findsWidgets);
  final padding = fixture.width < 900 ? 16 : 32;
  for (final element in rows.evaluate()) {
    final bounds = tester.getRect(
      find.byElementPredicate((value) => value == element),
    );
    expect(bounds.left, closeTo(fixture.sidebarWidth + padding, .01));
    expect(bounds.right, closeTo(fixture.width - padding, .01));
  }
}

void _expectSummary(
  WidgetTester tester, {
  required int active,
  required int queued,
  required int failed,
  required int completed,
}) {
  for (final item in [
    ('active', active),
    ('queued', queued),
    ('failed', failed),
    ('completed', completed),
  ]) {
    final text = tester.widget<Text>(
      find.byKey(ValueKey('desktop-download-count-${item.$1}')),
    );
    expect(text.textSpan!.toPlainText(), endsWith('  ${item.$2}'));
  }
}

Future<_Fixture> _pump(
  WidgetTester tester, {
  bool downloads = false,
  double width = 1920,
  double height = 1050,
  double scale = 1,
  bool dark = false,
  int count = 1,
  TargetPlatform platform = TargetPlatform.windows,
  List<DownloadTaskStatus>? statuses,
  bool compact = false,
  bool source = true,
  bool percent = true,
  bool realShell = false,
  bool shelfFixture = false,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final desktop = platform == TargetPlatform.windows;
  final sidebarWidth = desktop ? (scale > 1 ? 320.0 : 244.0) : 0.0;
  final controller = PlaybackController(engine: InMemoryAudioEngine());
  addTearDown(controller.dispose);
  final library = LibraryStore(MemoryLibraryPersistenceStore());
  final bookmarks = BookmarkStore(MemoryBookmarkPersistence());
  await bookmarks.load();
  for (var index = 0; index < count; index++) {
    await library.toggleFavorite(_libraryBook(index));
  }
  if (shelfFixture) {
    await library.toggleLater(_libraryBook(1));
    await bookmarks.add(
      book: _book(4),
      chapterId: _book(4).chapters.first.id,
      positionMs: 1000,
      title: 'Shelf bookmark',
    );
  }
  final manager = _MemoryManager(
    statuses ?? List.filled(count, DownloadTaskStatus.completed),
  );
  var theme = (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
    platform: platform,
  );
  if (desktop) theme = WindowsTheme.from(theme);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => realShell
            ? const DesktopStandaloneShell(
                selectedIndex: 3,
                child: DownloadsScreen(),
              )
            : Scaffold(
                body: Row(
                  children: [
                    SizedBox(width: sidebarWidth),
                    Expanded(
                      child: downloads
                          ? const DownloadsScreen()
                          : const LibraryScreen(),
                    ),
                  ],
                ),
              ),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) =>
            const Scaffold(body: Text('Search destination')),
      ),
      GoRoute(
        path: '/source-book/:sourceId/:sourceBookId',
        builder: (context, state) =>
            Scaffold(body: Text('Details ${state.pathParameters}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        playbackControllerProvider.overrideWith((ref) => controller),
        libraryStoreProvider.overrideWith((ref) => library),
        bookmarkStoreProvider.overrideWith((ref) => bookmarks),
        if (shelfFixture) ...[
          libraryPlaybackBooksProvider.overrideWith(
            (ref) async => [for (var i = 0; i < 5; i++) _book(i)],
          ),
          playbackProgressSnapshotsProvider.overrideWith(
            (ref) async => [
              for (final i in [2, 3])
                PlaybackProgressSnapshot(
                  bookId: _book(i).id,
                  bookVersionId: _book(i).versionId,
                  currentChapterId: _book(i).chapters.first.id,
                  currentPositionMs: 1000,
                  maxReachedGlobalPositionMs: 1000,
                  totalDurationMs: 10000,
                  listenedDurationMs: 1000,
                  percent: i == 3 ? 100 : 10,
                  isFinished: i == 3,
                  lastPlayedAt: DateTime(2026, 9, 6),
                ),
            ],
          ),
        ],
        downloadManagerProvider.overrideWith((ref) => manager),
        downloadStorageProvider.overrideWith((ref) => _MemoryStorage()),
        sourceRegistryProvider.overrideWith((ref) => SourceRegistry([])),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: theme,
        locale: const Locale('en'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: DesktopPreferences(
            compactCards: compact,
            showSourceOnCards: source,
            showPercentOnCovers: percent,
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Fixture(width, sidebarWidth, controller, library, manager, router);
}

class _Fixture {
  const _Fixture(
    this.width,
    this.sidebarWidth,
    this.controller,
    this.library,
    this.manager,
    this.router,
  );
  final double width;
  final double sidebarWidth;
  final PlaybackController controller;
  final LibraryStore library;
  final _MemoryManager manager;
  final GoRouter router;
}

AudioPlaybackBook _book(int index) => AudioPlaybackBook(
  id: 'book-$index',
  versionId: 'version-$index',
  sourceId: 'knigoblud',
  sourceBookId: 'book-$index',
  title: 'Путешествие к центру Земли $index',
  author: 'Жюль Верн',
  narrator: 'Александр Константинович',
  sourceName: 'Knigoblud',
  chapters: [
    for (var chapter = 1; chapter <= 3; chapter++)
      AudioPlaybackChapter(
        id: 'chapter-$index-$chapter',
        index: chapter,
        title: 'Глава $chapter. Продолжение путешествия',
        duration: const Duration(minutes: 12),
      ),
  ],
);

AudioBook _libraryBook(int index) {
  final book = _book(index);
  return AudioBook(
    id: book.id,
    sourceBookId: book.sourceBookId,
    title: book.title,
    author: book.author,
    narrator: book.narrator,
    sourceId: book.sourceId,
    sourceName: book.sourceName,
    durationLabel: '36 мин',
    chapterCount: 3,
    progress: .43,
    access: BookAccess.free,
  );
}

class _MemoryStorage extends FileDownloadStorage {
  _MemoryStorage()
    : super(rootDirectory: Directory('unused-desktop-collection-storage'));
  @override
  Future<List<AudioPlaybackBook>> readAllMetadata() async => const [];
}

class _MemoryManager extends DownloadManager {
  _MemoryManager(this.statuses)
    : super(
        client: DefaultDownloadClient(),
        storage: _MemoryStorage(),
        persistence: MemoryDownloadPersistenceStore(),
      );
  final List<DownloadTaskStatus> statuses;
  final actions = <String>[];
  void setStatus(int index, DownloadTaskStatus status) {
    statuses[index] = status;
    notifyListeners();
  }

  @override
  List<DownloadTask> get tasks => [
    for (var index = 0; index < statuses.length; index++)
      for (final chapter in _book(index).chapters)
        DownloadTask(
          id: 'task-$index-${chapter.index}',
          bookId: 'book-$index',
          bookVersionId: 'version-$index',
          chapterId: chapter.id,
          sourceId: 'knigoblud',
          type: DownloadTaskType.chapter,
          status: statuses[index],
          progress: statuses[index] == DownloadTaskStatus.completed ? 1 : .5,
          downloadedBytes: 1024 * 1024,
          totalBytes: 2 * 1024 * 1024,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
  ];
  @override
  AudioPlaybackBook bookForTask(String taskId) =>
      _book(int.parse(taskId.split('-')[1]));
  @override
  Future<void> pause(String taskId) async {
    actions.add('pause:$taskId');
  }

  @override
  Future<void> resumeChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) async {
    actions.add('resume:${chapter.id}');
  }

  @override
  Future<void> retryChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) async {
    actions.add('retry:${chapter.id}');
  }

  @override
  Future<List<DownloadTask>> enqueueMissingChapters(
    AudioPlaybackBook book,
  ) async {
    actions.add('missing:${book.versionId}');
    return [];
  }

  @override
  Future<void> cancelAndDeleteBook(AudioPlaybackBook book) async {
    actions.add('delete:${book.versionId}');
  }
}
