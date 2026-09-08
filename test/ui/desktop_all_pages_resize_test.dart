import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/app.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/router.dart';
import 'package:slovofon/domain/models/audio_book.dart';
import 'package:slovofon/domain/models/book_version.dart';
import 'package:slovofon/domain/models/chapter.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/features/book_details/saved_book_details_screen.dart';
import 'package:slovofon/features/downloads/downloads_screen.dart';
import 'package:slovofon/features/home/home_screen.dart';
import 'package:slovofon/features/library/library_screen.dart';
import 'package:slovofon/features/search/search_screen.dart';
import 'package:slovofon/features/source_books/source_book_details_screen.dart';
import 'package:slovofon/features/theme_preview/theme_preview_screen.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/library/library_store.dart';
import 'package:slovofon/services/search/search_history_store.dart';
import 'package:slovofon/services/settings/app_settings_store.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/services/updates/update_client.dart';
import 'package:slovofon/services/updates/update_installer.dart';
import 'package:slovofon/services/updates/update_service.dart';
import 'package:slovofon/sources/sources.dart';
import 'package:slovofon/ui/components/book_card.dart';
import 'package:slovofon/ui/components/state_placeholder.dart';

import 'test_search_history_store.dart';

const _sizes = [
  Size(900, 600),
  Size(1024, 600),
  Size(1267, 720),
  Size(1920, 1010),
  Size(768, 480),
];

const _book = AudioPlaybackBook(
  id: 'resize-book',
  versionId: 'resize-version',
  sourceId: 'knigavuhe',
  sourceBookId: 'resize-book',
  title: 'An audiobook for resize regression testing',
  author: 'A genuinely long author name',
  narrator: 'A genuinely long narrator name',
  sourceName: 'Knigavuhe',
  chapters: [
    AudioPlaybackChapter(
      id: 'resize-chapter',
      index: 0,
      title: 'The first chapter',
      duration: Duration(minutes: 20),
    ),
  ],
);

void main() {
  for (final scale in [.75, 1.0, 2.0]) {
    for (final systemScale in [1.0, 1.5]) {
      for (final compact in [false, true]) {
        _windowsTest(
          'content pages resize without losing state app=$scale system=$systemScale compact=$compact',
          (tester) async {
            final catalog = _ResizeCatalog();
            await _pumpApp(
              tester,
              catalog: catalog,
              scale: scale,
              systemScale: systemScale,
              compact: compact,
            );
            final routes = <(String, Type)>[
              ('/', HomeScreen),
              ('/library', LibraryScreen),
              ('/downloads', DownloadsScreen),
              ('/search?q=Audiobook&run=1&reset=resize', SearchScreen),
              ('/book/${_book.id}', SavedBookDetailsScreen),
              ('/source-book/knigavuhe/resize-book', SourceBookDetailsScreen),
              ('/theme-preview', ThemePreviewScreen),
            ];
            for (final route in routes) {
              tester.view.physicalSize = const Size(1920, 1010);
              appRouter.go(route.$1);
              await _frames(tester);
              final detailRequests = catalog.detailRequests;
              final searchRequests = catalog.searchRequests;
              if (route.$2 == SavedBookDetailsScreen) {
                expect(find.byType(SavedBookDetailsScreen), findsOneWidget);
                expect(
                  find.byKey(const ValueKey('saved-book-not-found')),
                  findsNothing,
                );
                final title = find.byKey(const ValueKey('saved-book-title'));
                expect(title, findsOneWidget);
                expect(tester.widget<Text>(title).data, _book.title);
              }
              if (route.$2 == SearchScreen) {
                expect(
                  find.byType(BookCard).evaluate().length,
                  inInclusiveRange(1, 15),
                  reason: 'Only the visible/cache result rows should mount.',
                );
              }
              for (final size in _sizes) {
                tester.view.physicalSize = size;
                await _frames(tester);
                expect(
                  tester.takeException(),
                  isNull,
                  reason: '${route.$1} $size first viewport',
                );
                expect(appRouter.state.uri.path, Uri.parse(route.$1).path);
                // Inspect lower sections as well as the first viewport.
                await _visitScrollRange(
                  tester,
                  route.$2,
                  expectedBookCount: route.$2 == SearchScreen ? 15 : null,
                );
                expect(
                  tester.takeException(),
                  isNull,
                  reason: '${route.$1} $size lower sections',
                );
                expect(catalog.detailRequests, detailRequests);
                expect(catalog.searchRequests, searchRequests);
                if (route.$2 == SearchScreen) {
                  await _returnToTop(tester, SearchScreen);
                  final queryField = find.descendant(
                    of: find.byType(SearchScreen),
                    matching: find.byType(TextField),
                  );
                  await tester.scrollUntilVisible(
                    queryField,
                    120,
                    scrollable: _contentScrollable(SearchScreen),
                    maxScrolls: 80,
                  );
                  await _frames(tester);
                  expect(queryField, findsOneWidget);
                  expect(
                    tester.widget<TextField>(queryField).controller!.text,
                    'Audiobook',
                  );
                }
              }
            }
          },
        );
      }
    }
  }

  _windowsTest(
    'empty content and pending source/search states survive resize',
    (tester) async {
      final catalog = _ResizeCatalog();
      await _pumpApp(
        tester,
        catalog: catalog,
        empty: true,
        scale: 2,
        systemScale: 1.5,
      );
      for (final route in <(String, Type)>[
        ('/', HomeScreen),
        ('/library', LibraryScreen),
        ('/downloads', DownloadsScreen),
        ('/search', SearchScreen),
      ]) {
        appRouter.go(route.$1);
        await _frames(tester);
        for (final size in _sizes) {
          tester.view.physicalSize = size;
          await _frames(tester);
          await _visitScrollRange(tester, route.$2);
          expect(find.byType(BookCard), findsNothing);
          expect(
            tester.takeException(),
            isNull,
            reason: '${route.$1} $size empty',
          );
        }
      }
      final searchGate = Completer<SourceSearchResponse>();
      catalog.searchGate = searchGate;
      appRouter.go('/search?q=Waiting&run=1&reset=loading');
      await _frames(tester);
      for (final size in _sizes) {
        tester.view.physicalSize = size;
        await _frames(tester);
        await _returnToTop(tester, SearchScreen);
        final loading = find.byWidgetPredicate(
          (widget) => widget is StatePlaceholder && widget.loading,
        );
        await tester.scrollUntilVisible(
          loading,
          200,
          scrollable: _contentScrollable(SearchScreen),
          maxScrolls: 80,
        );
        await _frames(tester);
        expect(loading, findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$size loading search');
      }
      searchGate.completeError(
        StateError('Fixture search is temporarily unavailable'),
      );
      await _frames(tester);
      for (final size in _sizes) {
        tester.view.physicalSize = size;
        await _frames(tester);
        await _returnToTop(tester, SearchScreen);
        final heading = find.byKey(
          const ValueKey('desktop-search-results-heading'),
        );
        await tester.scrollUntilVisible(
          heading,
          200,
          scrollable: _contentScrollable(SearchScreen),
          maxScrolls: 80,
        );
        await _frames(tester);
        final strings = AppStrings.forLocale(const Locale('en'));
        expect(
          find.descendant(
            of: heading,
            matching: find.text(strings.sourceSearchError),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: heading,
            matching: find.text(strings.searchingSources),
          ),
          findsNothing,
        );
        await _visitScrollRange(tester, SearchScreen);
        expect(tester.takeException(), isNull, reason: '$size search failure');
      }
      final detailsGate = Completer<SourceBookSnapshot>();
      catalog.detailsGate = detailsGate;
      appRouter.go('/source-book/knigavuhe/resize-book');
      await _frames(tester);
      for (final size in _sizes) {
        tester.view.physicalSize = size;
        await _frames(tester);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$size loading details');
      }
      detailsGate.complete(_snapshot());
      await _frames(tester);
      await _visitScrollRange(tester, SourceBookDetailsScreen);
      expect(tester.takeException(), isNull);
    },
  );

  _windowsTest(
    'expanded source chapters keep their scroll and route on resize',
    (tester) async {
      final catalog = _ResizeCatalog();
      await _pumpApp(tester, catalog: catalog, scale: 2, systemScale: 1.5);
      appRouter.go('/source-book/knigavuhe/resize-book');
      await _frames(tester);
      await tester.scrollUntilVisible(
        find.text('Show 15 more chapters'),
        400,
        scrollable: _contentScrollable(SourceBookDetailsScreen),
        maxScrolls: 60,
      );
      await _frames(tester);
      await tester.tap(find.text('Show 15 more chapters'));
      await _frames(tester);
      final requests = catalog.detailRequests;
      for (final size in _sizes) {
        tester.view.physicalSize = size;
        await _frames(tester);
        await _visitScrollRange(tester, SourceBookDetailsScreen);
        expect(find.text('Collapse chapters'), findsOneWidget);
        expect(catalog.detailRequests, requests);
        expect(appRouter.state.uri.path, '/source-book/knigavuhe/resize-book');
        expect(
          tester.takeException(),
          isNull,
          reason: '$size expanded chapters',
        );
      }
    },
  );

  _windowsTest('expanded download chapters survive low-height resize', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      catalog: _ResizeCatalog(),
      scale: 2,
      systemScale: 1.5,
    );
    appRouter.go('/downloads');
    await _frames(tester);
    final row = find.byKey(
      const ValueKey('desktop-download-book-knigavuhe:resize-version-1'),
    );
    final title = find.descendant(
      of: row,
      matching: find.text(_sampleBook(1).title),
    );
    await tester.scrollUntilVisible(
      title,
      300,
      scrollable: _contentScrollable(DownloadsScreen),
      maxScrolls: 80,
    );
    await Scrollable.ensureVisible(tester.element(title), alignment: .5);
    await _frames(tester);
    await tester.tap(title);
    await _frames(tester);
    for (final size in _sizes) {
      tester.view.physicalSize = size;
      await _frames(tester);
      final scrollable = _contentScrollable(DownloadsScreen);
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await _frames(tester);
      final lastChapter = find.descendant(
        of: row,
        matching: find.text(_sampleBook(1).chapters.last.title),
      );
      await tester.scrollUntilVisible(
        lastChapter,
        300,
        scrollable: scrollable,
        maxScrolls: 160,
      );
      await _frames(tester);
      expect(lastChapter, findsOneWidget);
      expect(appRouter.state.uri.path, '/downloads');
      expect(tester.takeException(), isNull, reason: '$size download chapters');
    }
  });

  _windowsTest(
    'source error retry remains reachable in a short Windows window',
    (tester) async {
      final catalog = _ResizeCatalog()..failDetails = true;
      await _pumpApp(tester, catalog: catalog, scale: 2, systemScale: 1.5);
      appRouter.go('/source-book/knigavuhe/resize-book');
      await _frames(tester);
      expect(catalog.detailRequests, 1);
      expect(tester.takeException(), isNull);

      for (final size in _sizes) {
        tester.view.physicalSize = size;
        await _frames(tester);
        expect(tester.takeException(), isNull, reason: '$size source error');
        final retry = find.widgetWithText(FilledButton, 'Retry');
        expect(retry, findsOneWidget);
        await Scrollable.ensureVisible(tester.element(retry), alignment: .5);
        await _frames(tester);
        expect(retry.hitTestable(), findsOneWidget);
        final previousRequests = catalog.detailRequests;
        await tester.tap(retry);
        await _frames(tester);
        expect(catalog.detailRequests, previousRequests + 1);
        expect(appRouter.state.uri.path, '/source-book/knigavuhe/resize-book');
        expect(tester.takeException(), isNull);
      }
    },
  );
}

void _windowsTest(
  String description,
  Future<void> Function(WidgetTester) body,
) => testWidgets(
  description,
  body,
  variant: TargetPlatformVariant.only(TargetPlatform.windows),
);

Future<void> _frames(WidgetTester tester) async {
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Finder _contentScrollable(Type pageType) => find
    .descendant(
      of: find.byType(pageType),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    )
    .last;

Future<void> _visitScrollRange(
  WidgetTester tester,
  Type pageType, {
  int? expectedBookCount,
}) async {
  final scrollable = _contentScrollable(pageType);
  expect(scrollable, findsOneWidget);
  var position = tester.state<ScrollableState>(scrollable).position;
  position.jumpTo(0);
  await tester.pump();
  _expectScrollLayout(tester, pageType, position, 'return to top');
  final seenBooks = <String>{};
  void collectBooks() {
    seenBooks.addAll(
      tester
          .widgetList<BookCard>(
            find.descendant(
              of: find.byType(pageType),
              matching: find.byType(BookCard),
            ),
          )
          .map((card) => card.book.id),
    );
  }

  collectBooks();
  var visits = 0;
  while (position.pixels < position.maxScrollExtent && visits < 400) {
    final step = (position.viewportDimension * .8).clamp(48.0, 800.0);
    position.jumpTo(
      (position.pixels + step).clamp(0, position.maxScrollExtent),
    );
    await tester.pump();
    _expectScrollLayout(tester, pageType, position, 'scroll visit $visits');
    collectBooks();
    position = tester.state<ScrollableState>(scrollable).position;
    visits++;
  }
  expect(visits, lessThan(400), reason: '$pageType scroll extent converges');
  if (expectedBookCount != null) {
    expect(
      seenBooks,
      hasLength(expectedBookCount),
      reason: 'Every lazy result remains reachable after resize.',
    );
  }
}

void _expectScrollLayout(
  WidgetTester tester,
  Type pageType,
  ScrollPosition position,
  String reason,
) {
  expect(
    tester.takeException(),
    isNull,
    reason: '$pageType $reason at ${position.pixels}',
  );
}

Future<void> _returnToTop(WidgetTester tester, Type pageType) async {
  tester
      .state<ScrollableState>(_contentScrollable(pageType))
      .position
      .jumpTo(0);
  // ListView may have disposed controls while we checked lower sections. The
  // next layout must recreate them before querying their widget/controller.
  await _frames(tester);
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required _ResizeCatalog catalog,
  double scale = 1,
  double systemScale = 1,
  bool compact = false,
  bool empty = false,
}) async {
  tester.view.physicalSize = _sizes.first;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = systemScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final settings = AppSettingsStore(MemoryAppSettingsPersistenceStore());
  await settings.setLanguageCode('en');
  await settings.setTextScale(scale);
  await settings.setCompactCards(compact);
  final controller = PlaybackController(engine: InMemoryAudioEngine());
  if (!empty) await controller.loadBook(_book);
  final library = LibraryStore(MemoryLibraryPersistenceStore());
  await library.load();
  if (!empty) {
    for (var index = 0; index < 15; index++) {
      await library.toggleFavorite(_audioBook(index));
    }
  }
  final storage = _MemoryStorage();
  if (!empty) {
    // The production /book route resolves real metadata, never demo IDs.
    await storage.writeMetadata(_book);
  }
  final manager = _ResizeManager(storage, empty ? 0 : 15);
  appRouter.go('/');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsStoreProvider.overrideWith((ref) => settings),
        playbackControllerProvider.overrideWith((ref) {
          ref.onDispose(controller.dispose);
          return controller;
        }),
        libraryStoreProvider.overrideWith((ref) => library),
        searchHistoryStoreProvider.overrideWithValue(
          MemorySearchHistoryStore(),
        ),
        downloadStorageProvider.overrideWithValue(storage),
        downloadManagerProvider.overrideWith((ref) => manager),
        sourceRegistryProvider.overrideWithValue(SourceRegistry([])),
        sourceCatalogServiceProvider.overrideWithValue(catalog),
        updateServiceProvider.overrideWithValue(
          UpdateService(
            client: const UpdateClient(),
            installer: PlatformUpdateInstaller(),
            runtimePlatform: UpdateRuntimePlatform.unsupported,
          ),
        ),
      ],
      child: const SlovofonApp(),
    ),
  );
  await _frames(tester);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _ResizeCatalog extends SourceCatalogService {
  _ResizeCatalog() : super(registry: SourceRegistry([]));

  bool failDetails = false;
  int detailRequests = 0;
  int searchRequests = 0;
  Completer<SourceSearchResponse>? searchGate;
  Completer<SourceBookSnapshot>? detailsGate;

  @override
  Future<SourceSearchResponse> search(
    SearchRequest request, {
    void Function(SourceSearchResponse response)? onUpdate,
    SourceSearchCancellation? cancellation,
  }) async {
    searchRequests++;
    if (searchGate case final gate?) return gate.future;
    return SourceSearchResponse(
      results: [
        for (var index = 0; index < 15; index++)
          BookSearchResult(
            ref: SourceBookRef(
              sourceId: 'knigavuhe',
              sourceBookId: 'resize-book-$index',
            ),
            sourceName: _book.sourceName,
            title: _audioBook(index).title,
            author: _book.author,
            narrator: _book.narrator,
            duration: const Duration(minutes: 400),
            accessType: AccessType.free,
          ),
      ],
    );
  }

  @override
  Future<List<BookSearchResult>> findOtherNarrations(
    SourceBookSnapshot snapshot, {
    int limit = 12,
  }) async => const [];

  @override
  Future<SourceBookSnapshot> loadBook(
    SourceBookRef ref, {
    bool forceRefresh = false,
    MediaResolvePurpose purpose = MediaResolvePurpose.playback,
  }) async {
    detailRequests++;
    if (failDetails) {
      throw StateError('Fixture details temporarily unavailable');
    }
    if (detailsGate case final gate?) return gate.future;
    return _snapshot();
  }
}

final _fixtureBooks = <int, AudioPlaybackBook>{};

AudioPlaybackBook _sampleBook(int index) =>
    _fixtureBooks.putIfAbsent(index, () => _makeSampleBook(index));

AudioPlaybackBook _makeSampleBook(int index) => AudioPlaybackBook(
  id: 'resize-book-$index',
  versionId: 'resize-version-$index',
  sourceId: 'knigavuhe',
  sourceBookId: 'resize-book-$index',
  title: 'Audiobook $index: A journey across distant countries and libraries',
  author: _book.author,
  narrator: _book.narrator,
  sourceName: _book.sourceName,
  description:
      'A long description of the journey, with enough text to exercise '
      'wrapping and the expanded book summary in a short desktop window.',
  chapters: [
    for (var chapter = 0; chapter < 20; chapter++)
      AudioPlaybackChapter(
        id: 'resize-$index-chapter-$chapter',
        index: chapter,
        title: 'Chapter ${chapter + 1}: A journey through the great library',
        duration: const Duration(minutes: 20),
      ),
  ],
);

AudioBook _audioBook(int index) {
  final book = _sampleBook(index);
  return AudioBook(
    id: book.id,
    sourceBookId: book.sourceBookId,
    title: book.title,
    author: book.author,
    narrator: book.narrator,
    sourceId: book.sourceId,
    sourceName: book.sourceName,
    durationLabel: '6 h 40 min',
    chapterCount: 20,
    progress: .42,
    access: BookAccess.free,
  );
}

SourceBookSnapshot _snapshot() {
  final book = _sampleBook(0);
  final now = DateTime(2026);
  return SourceBookSnapshot(
    details: BookVersionDetails(
      ref: const SourceBookRef(
        sourceId: 'knigavuhe',
        sourceBookId: 'resize-book',
      ),
      version: BookVersion(
        id: book.versionId,
        bookId: book.id,
        sourceId: book.sourceId,
        sourceBookId: 'resize-book',
        title: book.title,
        normalizedTitle: book.title.toLowerCase(),
        authors: [book.author],
        narrators: [book.narrator],
        description: book.description,
        isFull: true,
        canStream: true,
        canDownload: true,
        accessType: AccessType.free,
        playbackAccess: PlaybackAccess.streamAndDownload,
        createdAt: now,
        updatedAt: now,
      ),
    ),
    chapters: [
      for (final chapter in book.chapters)
        Chapter(
          id: chapter.id,
          bookVersionId: book.versionId,
          sourceId: book.sourceId,
          sourceBookId: 'resize-book',
          index: chapter.index,
          title: chapter.title,
          normalizedTitle: chapter.title.toLowerCase(),
          durationMs: chapter.duration.inMilliseconds,
          createdAt: now,
          updatedAt: now,
        ),
    ],
    audioBook: _audioBook(0),
    playbackBook: book,
  );
}

class _ResizeManager extends DownloadManager {
  _ResizeManager(FileDownloadStorage storage, this.count)
    : super(
        client: _NoNetworkDownloadClient(),
        storage: storage,
        persistence: MemoryDownloadPersistenceStore(),
      );
  final int count;
  @override
  List<DownloadTask> get tasks => _fixtureTasks;

  late final List<DownloadTask> _fixtureTasks = [
    for (var index = 0; index < count; index++)
      for (final chapter in _sampleBook(index).chapters)
        DownloadTask(
          id: 'resize-task-$index-${chapter.index}',
          bookId: 'resize-book-$index',
          bookVersionId: 'resize-version-$index',
          chapterId: chapter.id,
          sourceId: 'knigavuhe',
          type: DownloadTaskType.chapter,
          status: [
            DownloadTaskStatus.completed,
            DownloadTaskStatus.running,
            DownloadTaskStatus.paused,
            DownloadTaskStatus.queued,
            DownloadTaskStatus.failed,
          ][index % 5],
          progress: index % 5 == 0 ? 1 : .5,
          downloadedBytes: index % 5 == 0 ? 2048 : 1024,
          totalBytes: 2048,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
  ];
  @override
  AudioPlaybackBook bookForTask(String taskId) =>
      _sampleBook(int.parse(taskId.split('-')[2]));
}

class _NoNetworkDownloadClient implements DownloadClient {
  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async => throw StateError('Resize tests must not download media');
}

/// All persistence accessed by these pages stays in memory. The nominal root
/// is never created; no download, installation, or external launch is invoked.
class _MemoryStorage extends FileDownloadStorage {
  _MemoryStorage()
    : super(rootDirectory: Directory('unused-resize-test-storage'));

  @override
  Future<List<AudioPlaybackBook>> readAllMetadata() async =>
      List.unmodifiable(_metadata.values);

  final _metadata = <String, AudioPlaybackBook>{};
  @override
  Future<void> saveBook(AudioPlaybackBook book) => writeMetadata(book);
  @override
  Future<void> writeMetadata(AudioPlaybackBook book) async {
    _metadata['${book.sourceId}:${book.versionId}'] = book;
  }

  @override
  Future<AudioPlaybackBook?> readMetadataForIds(
    String sourceId,
    String versionId,
  ) async => _metadata['$sourceId:$versionId'];
  @override
  Future<AudioPlaybackBook> offlinePlaybackBook(AudioPlaybackBook book) async =>
      book;

  @override
  Future<CardCacheStats> cardCacheStats() async =>
      const CardCacheStats(bytes: 0, bookCount: 0);
}
