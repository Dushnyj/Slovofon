import 'dart:async';
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
import 'package:slovofon/data/mock/stage3_mock_data.dart';
import 'package:slovofon/domain/models/audio_track.dart';
import 'package:slovofon/domain/models/book_version.dart';
import 'package:slovofon/domain/models/chapter.dart';
import 'package:slovofon/features/book_details/book_details_screen.dart';
import 'package:slovofon/features/source_books/source_book_details_screen.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/sources/sources.dart';
import 'package:slovofon/ui/adaptive/slovofon_shell.dart';
import 'package:slovofon/ui/components/book_cover.dart';
import 'package:slovofon/ui/components/chapter_tile.dart';

const _sourceRef = SourceBookRef(sourceId: 'izib', sourceBookId: 'desktop');
const _sourceTitle = 'Путешествие к центру Земли';
const _sourceContentKey = 'desktop-source-details-content';
const _legacyContentKey = 'desktop-legacy-details-content';
const _seedBook = AudioPlaybackBook(
  id: 'desktop-playing',
  versionId: 'desktop-playing-version',
  sourceId: 'izib',
  title: 'Книга в плеере',
  author: 'Автор',
  narrator: 'Чтец',
  sourceName: 'Izib',
  chapters: [
    AudioPlaybackChapter(
      id: 'desktop-playing-chapter',
      index: 0,
      title: 'Первая глава',
      duration: Duration(minutes: 30),
    ),
  ],
);

void main() {
  for (final width in [900.0, 1267.0, 1920.0]) {
    for (final dark in [false, true]) {
      for (final scale in [0.75, 1.0, 2.0, 3.0]) {
        testWidgets('Windows details fit width $width dark $dark text $scale', (
          tester,
        ) async {
          for (final source in [true, false]) {
            await _pumpDetails(
              tester,
              source: source,
              width: width,
              dark: dark,
              scale: scale,
            );
            final content = find.byKey(
              ValueKey(source ? _sourceContentKey : _legacyContentKey),
            );
            expect(content, findsOneWidget);
            expect(
              find.byKey(const ValueKey('desktop-standalone-shell')),
              findsOneWidget,
            );
            expect(
              find.byKey(
                ValueKey(
                  width < 1100
                      ? 'windows-compact-navigation-rail'
                      : 'desktop-navigation-sidebar',
                ),
              ),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('windows-playback-dock')),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('mobile-navigation-bar')),
              findsNothing,
            );
            expect(
              tester
                  .widget<DesktopStandaloneShell>(
                    find.byType(DesktopStandaloneShell),
                  )
                  .selectedIndex,
              source ? 1 : 2,
            );
            final cover = tester.widget<BookCover>(
              find
                  .descendant(of: content, matching: find.byType(BookCover))
                  .first,
            );
            expect(cover.width, inInclusiveRange(100, 220));
            final split = width >= 1920 || (width >= 1267 && scale <= 1);
            expect(
              find.byKey(const ValueKey('desktop-details-split')),
              split ? findsOneWidget : findsNothing,
            );
            expect(
              find.byKey(const ValueKey('desktop-details-stacked')),
              split ? findsNothing : findsOneWidget,
            );
            expect(
              find.descendant(of: content, matching: find.byType(Scrollbar)),
              findsOneWidget,
            );
            expect(
              cover.height,
              closeTo(cover.width * (source ? 1.43 : 1.4), 0.01),
            );
            expect(
              find.descendant(
                of: content,
                matching: find.text(
                  source ? _sourceTitle : activeMockBook.title,
                ),
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);

            // Lay out lower sections too, not only the first viewport.
            final scrollable = find.descendant(
              of: content,
              matching: find.byType(Scrollable),
            );
            expect(scrollable, findsOneWidget);
            await tester.drag(scrollable.first, const Offset(0, -900));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          }
        });
      }
    }
  }

  for (final dark in [false, true]) {
    testWidgets('short Windows details expose identity and play dark $dark', (
      tester,
    ) async {
      for (final source in [true, false]) {
        await _pumpDetails(
          tester,
          source: source,
          width: 1024,
          height: 600,
          dark: dark,
        );
        final content = find.byKey(
          ValueKey(source ? _sourceContentKey : _legacyContentKey),
        );
        final viewport = tester.getRect(content);
        final title = find.descendant(
          of: content,
          matching: find.text(source ? _sourceTitle : activeMockBook.title),
        );
        final narrator = find.descendant(
          of: content,
          matching: find.text(
            source
                ? 'Александр Константинович'
                : '${activeMockBook.narrator} · 15 h 42 min',
          ),
        );
        if (!source) {
          // The fixture remains in its stored canonical format; only the
          // English interface translates duration units, never the narrator.
          expect(activeMockBook.durationLabel, '15 ч 42 мин');
          expect(
            find.text(
              '${activeMockBook.narrator} · ${activeMockBook.durationLabel}',
            ),
            findsNothing,
          );
        }
        final play = find.byKey(
          ValueKey(source ? 'source-details-play' : 'legacy-details-play'),
        );
        for (final essential in [title, narrator, play]) {
          final rect = tester.getRect(essential);
          expect(rect.top, greaterThanOrEqualTo(viewport.top));
          expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
          expect(rect.left, greaterThanOrEqualTo(viewport.left));
          expect(rect.right, lessThanOrEqualTo(viewport.right));
        }
        final artwork = tester.getRect(
          find.byKey(const ValueKey('desktop-details-artwork')),
        );
        expect(artwork.top, greaterThan(tester.getRect(play).bottom));
        expect(artwork.height, lessThan(viewport.height * .5));
        final position = tester
            .state<ScrollableState>(
              find.descendant(of: content, matching: find.byType(Scrollable)),
            )
            .position;
        expect(position.pixels, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }

  testWidgets(
    'details cover responds to height without replacing scroll state',
    (tester) async {
      await _pumpDetails(tester, source: true, width: 1024);
      final content = find.byKey(const ValueKey(_sourceContentKey));
      final scroll = find.descendant(
        of: content,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scroll).position;
      final cover = find.descendant(
        of: content,
        matching: find.byType(BookCover),
      );
      final tallWidth = tester.widget<BookCover>(cover).width;
      tester.view.physicalSize = const Size(1024, 600);
      await tester.pumpAndSettle();
      expect(tester.widget<BookCover>(cover).width, lessThan(tallWidth));
      expect(tester.state<ScrollableState>(scroll).position, same(position));
      expect(position.pixels, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final profile in [
    (TargetPlatform.android, 430.0),
    (TargetPlatform.android, 1440.0),
    (TargetPlatform.windows, 899.0),
  ]) {
    testWidgets(
      'details keep platform chrome at width ${profile.$2} for ${profile.$1}',
      (tester) async {
        for (final source in [true, false]) {
          await _pumpDetails(
            tester,
            source: source,
            platform: profile.$1,
            width: profile.$2,
          );
          final desktop = profile.$1 == TargetPlatform.windows;
          expect(
            find.byType(DesktopStandaloneShell),
            desktop ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const ValueKey(_sourceContentKey)),
            desktop && source ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const ValueKey(_legacyContentKey)),
            desktop && !source ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const ValueKey('windows-compact-navigation-rail')),
            desktop ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const ValueKey('windows-playback-dock')),
            desktop ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const ValueKey('mobile-navigation-bar')),
            !desktop && source ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      },
    );
  }

  testWidgets(
    'wide details use the right edge and separate summary from content',
    (tester) async {
      for (final source in [true, false]) {
        for (final scale in [1.0, 2.0]) {
          await _pumpDetails(tester, source: source, width: 1920, scale: scale);
          final content = find.byKey(
            ValueKey(source ? _sourceContentKey : _legacyContentKey),
          );
          final pageRect = tester.getRect(content);
          final sidebar = tester.getRect(
            find.byKey(const ValueKey('desktop-navigation-sidebar')),
          );
          final summary = tester.getRect(
            find.byKey(const ValueKey('desktop-details-summary')),
          );
          final mainSliver = tester.renderObject<RenderSliver>(
            find.byKey(const ValueKey('desktop-details-main-column')),
          );
          final mainOrigin = MatrixUtils.transformPoint(
            mainSliver.getTransformTo(null),
            Offset.zero,
          );
          final main = Rect.fromLTWH(
            mainOrigin.dx,
            mainOrigin.dy,
            mainSliver.constraints.crossAxisExtent,
            mainSliver.geometry!.paintExtent,
          );
          expect(pageRect.right, closeTo(1920, 0.01));
          expect(pageRect.left, closeTo(sidebar.right + 1, 0.01));
          expect(summary.left, closeTo(pageRect.left + 32, 0.01));
          expect(summary.width, inInclusiveRange(300, 440));
          expect(main.top, closeTo(summary.top, 0.01));
          expect(main.left, closeTo(summary.right + 32, 0.01));
          expect(main.right, closeTo(pageRect.right - 32, 0.01));
          expect(main.width, greaterThan(1000));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    },
  );

  testWidgets(
    'expanded source chapters remain lazy on resize and share one scroll position',
    (tester) async {
      final connector = _DetailsConnector(chapterCount: 500);
      final fixture = await _pumpDetails(
        tester,
        source: true,
        width: 1920,
        connector: connector,
      );
      final content = find.byKey(const ValueKey(_sourceContentKey));
      final scrollable = find.descendant(
        of: content,
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Show 495 more chapters'),
        400,
        scrollable: scrollable,
      );
      await tester.tap(find.text('Show 495 more chapters'));
      await tester.pumpAndSettle();
      expect(find.byType(ChapterTile).evaluate().length, lessThan(35));
      expect(find.text('Глава 500. Начало путешествия'), findsNothing);
      final position = tester.state<ScrollableState>(scrollable).position;
      final searches = connector.searches;
      position.jumpTo(1600);
      await tester.pumpAndSettle();
      expect(find.byType(ChapterTile).evaluate().length, lessThan(35));

      tester.view.physicalSize = const Size(900, 1000);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('desktop-details-stacked')),
        findsOneWidget,
      );
      expect(
        tester.state<ScrollableState>(scrollable).position,
        same(position),
      );
      expect(position.pixels, greaterThan(0));
      expect(find.byType(ChapterTile).evaluate().length, lessThan(35));
      tester.view.physicalSize = const Size(1920, 1000);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('desktop-details-split')),
        findsOneWidget,
      );
      expect(
        tester.state<ScrollableState>(scrollable).position,
        same(position),
      );
      for (var attempt = 0; attempt < 3; attempt++) {
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
      }
      expect(find.text('Collapse chapters'), findsOneWidget);
      expect(find.text('Глава 500. Начало путешествия'), findsOneWidget);
      expect(find.byType(ChapterTile).evaluate().length, lessThan(35));
      expect(connector.searches, searches);
      expect(fixture.router.state.uri.path, '/source');
      expect(tester.takeException(), isNull);
    },
  );

  for (final source in [true, false]) {
    testWidgets(
      'Windows details preserve navigation and seek for source $source',
      (tester) async {
        final fixture = await _pumpDetails(tester, source: source);
        final route = fixture.router.state.uri.path;
        final seek = find.byKey(const ValueKey('desktop-player-seek'));
        final seekRect = tester.getRect(seek);
        await tester.dragFrom(
          Offset(seekRect.left + 20, seekRect.center.dy),
          Offset(seekRect.width * 0.5, 0),
        );
        await tester.pumpAndSettle();
        expect(fixture.router.state.uri.path, route);
        expect(fixture.controller.state.position, greaterThan(Duration.zero));

        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(fixture.router.state.uri.path, '/');
        unawaited(fixture.router.push(route));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('windows-navigation-1')));
        await tester.pumpAndSettle();
        expect(fixture.router.state.uri.path, '/search');
        expect(find.text('Search destination'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final scale in [1.0, 2.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'phone source details actions have 48px targets scale=$scale dark=$dark',
        (tester) async {
          await _pumpDetails(
            tester,
            source: true,
            width: 390,
            height: 1000,
            platform: TargetPlatform.android,
            scale: scale,
            dark: dark,
          );
          for (final name in ['play', 'download', 'favorite', 'share']) {
            final action = find.byKey(ValueKey('source-details-$name'));
            await _revealPhoneDetails(tester, action);
            final bounds = tester.getRect(action);
            expect(bounds.width, greaterThanOrEqualTo(48));
            expect(bounds.height, greaterThanOrEqualTo(48));
            expect(bounds.left, greaterThanOrEqualTo(0));
            expect(bounds.right, lessThanOrEqualTo(390));
          }
          final favorite = find.byKey(
            const ValueKey('source-details-favorite'),
          );
          await _revealPhoneDetails(tester, favorite);
          await tester.tap(favorite);
          await tester.pumpAndSettle();
          expect(find.byTooltip('Remove from favorites'), findsWidgets);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Future<void> _revealPhoneDetails(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find
          .descendant(
            of: find.byType(SourceBookDetailsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
}

Future<({GoRouter router, PlaybackController controller})> _pumpDetails(
  WidgetTester tester, {
  required bool source,
  double width = 1440,
  double height = 1000,
  bool dark = false,
  double scale = 1,
  TargetPlatform platform = TargetPlatform.windows,
  _DetailsConnector? connector,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = PlaybackController(engine: InMemoryAudioEngine());
  addTearDown(controller.dispose);
  await controller.loadBook(_seedBook);
  final storage = _MemoryStorage();
  var theme = (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
    platform: platform,
  );
  if (platform == TargetPlatform.windows) {
    theme = WindowsTheme.from(theme);
  }
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Text('Home destination')),
      ),
      GoRoute(
        path: '/source',
        builder: (context, state) =>
            const SourceBookDetailsScreen(ref: _sourceRef),
      ),
      GoRoute(
        path: '/legacy',
        builder: (context, state) => BookDetailsScreen(book: activeMockBook),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) =>
            const Scaffold(body: Text('Search destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        playbackControllerProvider.overrideWith((ref) => controller),
        downloadStorageProvider.overrideWith((ref) => storage),
        sourceRegistryProvider.overrideWith(
          (ref) => SourceRegistry([connector ?? _DetailsConnector()]),
        ),
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
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(router.push(source ? '/source' : '/legacy'));
  await tester.pumpAndSettle();
  return (router: router, controller: controller);
}

class _MemoryStorage extends FileDownloadStorage {
  _MemoryStorage()
    : super(rootDirectory: Directory('desktop-details-memory-only'));

  final _books = <String, AudioPlaybackBook>{};

  @override
  Future<void> saveBook(AudioPlaybackBook book) => writeMetadata(book);

  @override
  Future<void> writeMetadata(AudioPlaybackBook book) async {
    _books['${book.sourceId}:${book.versionId}'] = book;
  }

  @override
  Future<AudioPlaybackBook?> readMetadataForIds(
    String sourceId,
    String versionId,
  ) async => _books['$sourceId:$versionId'];

  @override
  Future<List<AudioPlaybackBook>> readAllMetadata() async =>
      _books.values.toList();

  @override
  Future<AudioPlaybackBook> offlinePlaybackBook(AudioPlaybackBook book) async =>
      book;
}

/// Exercises SourceCatalogService and the details cache without network or files.
class _DetailsConnector implements SourceConnector {
  _DetailsConnector({this.chapterCount = 6});

  final int chapterCount;
  int searches = 0;

  @override
  String get id => 'izib';
  @override
  String get name => 'Izib';
  @override
  String get host => 'https://izib.uk';
  @override
  String get color => '#2F6FED';
  @override
  SourceCapabilities get capabilities => const SourceCapabilities(
    supportsDetails: true,
    supportsChapters: true,
    supportsDirectAudio: true,
    supportsDownload: true,
    supportsDescription: true,
  );
  @override
  SourceMediaPolicy get mediaPolicy =>
      const SourceMediaPolicy(mediaHosts: {'audio.izib.uk'});
  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async {
    searches++;
    return const [];
  }

  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) async =>
      BookVersionDetails(
        ref: ref,
        version: BookVersion(
          id: 'izib-desktop-version',
          bookId: 'izib-desktop-book',
          sourceId: id,
          sourceBookId: ref.sourceBookId,
          sourceUrl: 'https://izib.uk/art-desktop',
          title: _sourceTitle,
          normalizedTitle: 'путешествие к центру земли',
          authors: const ['Жюль Верн'],
          narrators: const ['Александр Константинович'],
          description:
              'Научная экспедиция отправляется в путешествие к центру Земли.',
          durationMs: const Duration(hours: 12, minutes: 30).inMilliseconds,
          genres: const ['Научная фантастика'],
          publishedYear: 1864,
          isFull: true,
          canStream: true,
          canDownload: true,
          accessType: AccessType.free,
          playbackAccess: PlaybackAccess.streamAndDownload,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
  @override
  Future<List<Chapter>> getChapters(SourceBookRef ref) async => [
    for (var index = 1; index <= chapterCount; index++)
      Chapter(
        id: 'izib-desktop-chapter-$index',
        bookVersionId: 'izib-desktop-version',
        sourceId: id,
        sourceBookId: ref.sourceBookId,
        index: index,
        title: 'Глава $index. Начало путешествия',
        normalizedTitle: 'глава $index начало путешествия',
        durationMs: const Duration(minutes: 30).inMilliseconds,
        streamRef: 'https://audio.izib.uk/desktop/$index.mp3',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
  ];
  @override
  Future<List<AudioTrack>> getAudioTracks(SourceBookRef ref) async => const [];
  @override
  Future<ResolvedMedia> resolveMedia(
    Chapter chapter,
    MediaResolvePurpose purpose,
  ) async => ResolvedMedia(
    sourceId: id,
    sourceBookId: chapter.sourceBookId,
    chapterId: chapter.id,
    mediaSource: AudioMediaSource.url(Uri.parse(chapter.streamRef!)),
    resolvedAt: DateTime(2026),
  );
  @override
  Future<SourceHealth> checkHealth() async =>
      SourceHealth.working(sourceId: id);
}
