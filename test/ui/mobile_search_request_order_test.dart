import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/features/search/search_screen.dart';
import 'package:slovofon/ui/components/book_card.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/search/search_history_store.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  testWidgets(
    'actual source failures stay visible; Debug statuses separate caps from failures',
    (tester) async {
      final catalog = _StreamingCatalog();
      final fixture = await _pump(
        tester,
        TargetPlatform.android,
        overrideCatalog: catalog,
      );
      await _submit(tester, 'metro');
      fixture.history.pending.single.complete([]);
      const book = BookSearchResult(
        ref: SourceBookRef(sourceId: 'baza_knig', sourceBookId: 'book'),
        sourceName: 'Baza Knig',
        title: 'Metro book',
      );
      const statuses = [
        SearchSourceStatus(
          sourceId: 'knigavuhe',
          participation: SearchSourceParticipation.completed,
        ),
        SearchSourceStatus(
          sourceId: 'knigoblud',
          participation: SearchSourceParticipation.disabled,
        ),
        SearchSourceStatus(
          sourceId: 'baza_knig',
          participation: SearchSourceParticipation.completed,
          matchCount: 1,
          failureKind: SourceErrorKind.accessRestricted,
          failedPage: 2,
        ),
        SearchSourceStatus(
          sourceId: 'akniga',
          participation: SearchSourceParticipation.completed,
          failureKind: SourceErrorKind.network,
          failedPage: 1,
        ),
        SearchSourceStatus(
          sourceId: 'yakniga',
          participation: SearchSourceParticipation.completed,
          paginationLimited: true,
        ),
      ];
      final cursor = _TestContinuation();
      final response = SourceSearchResponse(
        results: const [book],
        sourceStatuses: statuses,
        limitedSourceIds: const {'yakniga'},
        failures: const [
          SourceFailure(
            sourceId: 'baza_knig',
            kind: SourceErrorKind.accessRestricted,
            message: 'internal diagnostic',
          ),
          SourceFailure(
            sourceId: 'akniga',
            kind: SourceErrorKind.network,
            message: 'internal diagnostic',
          ),
        ],
        retryContinuation: cursor,
      );
      catalog.calls.single.completer.complete(response);
      await tester.pumpAndSettle();
      expect(find.text('Metro book'), findsOneWidget);
      final failureNotice = find.byKey(
        const ValueKey('search-source-failures'),
      );
      expect(
        find.descendant(
          of: failureNotice,
          matching: find.text(
            'Unavailable: Akniga\nBaza Knig: Page 2 could not be loaded. '
            'Site returned a verification page instead of results',
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Limits or errors'), findsNothing);
      expect(find.text('Open website'), findsNothing);
      final sourceStatuses = find.byKey(
        const PageStorageKey('search-source-statuses'),
      );
      expect(tester.widget<ExpansionTile>(sourceStatuses).subtitle, isNull);
      final statusesTitle = find.text('Source status');
      await tester.tap(statusesTitle);
      await tester.pumpAndSettle();
      final empty = find.byKey(const ValueKey('search-status-knigavuhe'));
      expect(
        find.descendant(of: empty, matching: find.text('0 results')),
        findsOneWidget,
      );
      expect(find.text('Not searched: disabled in settings'), findsOneWidget);
      final restricted = find.byKey(const ValueKey('search-status-baza_knig'));
      final subtitle = tester.widget<ListTile>(restricted).subtitle! as Text;
      expect(
        subtitle.data,
        '1 result\nPage 2 could not be loaded. '
        'Site returned a verification page instead of results',
      );
      final initialFailure = find.byKey(const ValueKey('search-status-akniga'));
      final initialSubtitle =
          tester.widget<ListTile>(initialFailure).subtitle! as Text;
      expect(initialSubtitle.data, 'Page 1 could not be loaded');
      final limited = find.byKey(const ValueKey('search-status-yakniga'));
      expect(
        (tester.widget<ListTile>(limited).subtitle! as Text).data,
        '0 results\nSearch results are limited',
      );
      expect(find.text('internal diagnostic'), findsNothing);
      final retry = find.byKey(const ValueKey('search-retry'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pump();
      expect(catalog.requests.last.continuation, same(cursor));
      expect(retry, findsNothing);
      catalog.calls.last.completer.complete(response);
      await tester.pumpAndSettle();
      await tester.ensureVisible(statusesTitle);
      await tester.tap(statusesTitle);
      await tester.pumpAndSettle();
      expect(find.text('Metro book'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a source cap alone never renders an error or retry', (
    tester,
  ) async {
    final catalog = _StreamingCatalog();
    final fixture = await _pump(
      tester,
      TargetPlatform.android,
      overrideCatalog: catalog,
    );
    await _submit(tester, 'metro');
    fixture.history.pending.single.complete([]);
    catalog.calls.single.completer.complete(
      const SourceSearchResponse(
        results: [],
        limitedSourceIds: {'yakniga'},
        sourceStatuses: [
          SearchSourceStatus(
            sourceId: 'yakniga',
            participation: SearchSourceParticipation.completed,
            paginationLimited: true,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-source-failures')), findsNothing);
    expect(find.byKey(const ValueKey('search-retry')), findsNothing);
    expect(find.text('Source status'), findsOneWidget);
    expect(find.text('No results'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('playback and download updates only rebuild the matching card', (
    tester,
  ) async {
    final catalog = _StreamingCatalog();
    final playback = _SearchPlaybackFixture();
    final downloads = _EmptyDownloads();
    addTearDown(playback.dispose);
    final fixture = await _pump(
      tester,
      TargetPlatform.android,
      overrideCatalog: catalog,
      overridePlayback: playback,
      overrideDownloads: downloads,
    );
    await _submit(tester, 'metro');
    fixture.history.pending.single.complete([]);
    const playing = BookSearchResult(
      ref: SourceBookRef(sourceId: 'izib', sourceBookId: 'a'),
      sourceName: 'Izib',
      title: 'Playing edition',
    );
    const other = BookSearchResult(
      ref: SourceBookRef(sourceId: 'izib', sourceBookId: 'b'),
      sourceName: 'Izib',
      title: 'Other edition',
    );
    catalog.calls.single.completer.complete(
      const SourceSearchResponse(results: [playing, other]),
    );
    await tester.pumpAndSettle();
    Finder card(String title) => find.byWidgetPredicate(
      (widget) => widget is BookCard && widget.book.title == title,
    );
    final untouched = tester.widget<BookCard>(card(other.title));
    const audioBook = AudioPlaybackBook(
      id: 'a',
      versionId: 'a',
      sourceBookId: 'a',
      sourceId: 'izib',
      title: 'Playing edition',
      author: '',
      narrator: '',
      sourceName: 'Izib',
      chapters: [
        AudioPlaybackChapter(
          id: 'chapter',
          index: 0,
          title: 'Chapter',
          duration: Duration(seconds: 100),
        ),
      ],
    );
    const state = AudioPlaybackState(
      book: audioBook,
      status: AudioPlaybackStatus.playing,
    );
    playback.update(state.copyWith(position: const Duration(seconds: 10)));
    await tester.pump();
    expect(tester.widget<BookCard>(card(playing.title)).book.progress, 0.1);
    expect(tester.widget<BookCard>(card(playing.title)).isCurrentBook, isTrue);
    expect(tester.widget<BookCard>(card(other.title)), same(untouched));
    playback.update(state.copyWith(position: const Duration(seconds: 40)));
    await tester.pump();
    expect(tester.widget<BookCard>(card(playing.title)).book.progress, 0.4);
    expect(tester.widget<BookCard>(card(other.title)), same(untouched));

    final played = tester.widget<BookCard>(card(playing.title));
    final now = DateTime.utc(2026);
    downloads.replaceTasks([
      DownloadTask(
        id: 'download-b',
        bookId: 'b',
        bookVersionId: 'izib-b',
        sourceId: 'izib',
        type: DownloadTaskType.chapter,
        status: DownloadTaskStatus.running,
        progress: 0.3,
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    await tester.pump();
    expect(tester.widget<BookCard>(card(other.title)).downloadProgress, 0.3);
    expect(tester.widget<BookCard>(card(playing.title)), same(played));
  });

  testWidgets(
    'Downloaded only can browse local storage without source requests',
    (tester) async {
      final storage = _EmptyDownloadedStorage();
      final fixture = await _pump(
        tester,
        TargetPlatform.android,
        overrideStorage: storage,
      );
      await tester.tap(find.byKey(const ValueKey('search-options')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('search-only-downloaded')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(storage.scans, 1);
      expect(fixture.catalog.requests, isEmpty);
      expect(fixture.history.pending, isEmpty);
      expect(find.text('No results'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('search starts in all fields and keeps results on paging retry', (
    tester,
  ) async {
    final catalog = _StreamingCatalog();
    final fixture = await _pump(
      tester,
      TargetPlatform.android,
      overrideCatalog: catalog,
    );
    const query = 'Во мрак Андрей Дьяков Кузнецов Сергей Метро 2033';
    await _submit(tester, query);
    fixture.history.pending.single.complete([]);
    await tester.pump();
    final initial = catalog.requests.single;
    expect(initial.query, query);
    expect(initial.effectiveKinds, {
      SearchKind.title,
      SearchKind.author,
      SearchKind.narrator,
      SearchKind.series,
      SearchKind.genre,
    });

    const first = BookSearchResult(
      ref: SourceBookRef(sourceId: 'izib', sourceBookId: 'first'),
      sourceName: 'Izib',
      title: 'First page book',
    );
    const second = BookSearchResult(
      ref: SourceBookRef(sourceId: 'izib', sourceBookId: 'second'),
      sourceName: 'Izib',
      title: 'Second page book',
    );
    final cursor = _TestContinuation();
    catalog.calls.single.completer.complete(
      SourceSearchResponse(results: const [first], continuation: cursor),
    );
    await tester.pumpAndSettle();
    final more = find.byKey(const ValueKey('search-load-more'));
    expect(find.text('Found so far: 1 result'), findsOneWidget);

    await tester.tap(more);
    await tester.pump();
    expect(catalog.requests.last.continuation, same(cursor));
    expect(catalog.requests.last.kinds, initial.kinds);
    expect(find.text(first.title), findsOneWidget);
    catalog.calls.last.completer.completeError(StateError('page unavailable'));
    await tester.pumpAndSettle();
    expect(find.text(first.title), findsOneWidget);
    expect(find.text('Retry loading more results'), findsOneWidget);

    await tester.tap(more);
    await tester.pump();
    expect(catalog.requests.last.continuation, same(cursor));
    expect(fixture.history.pending, hasLength(1));
    catalog.calls.last.completer.complete(
      const SourceSearchResponse(results: [first, second]),
    );
    await tester.pumpAndSettle();
    expect(find.text(first.title), findsOneWidget);
    expect(find.text(second.title), findsOneWidget);
    expect(find.text('2 results'), findsOneWidget);
    expect(more, findsNothing);
  });

  testWidgets('cancelled old future cannot hide a replacement partial', (
    tester,
  ) async {
    final streaming = _StreamingCatalog();
    final fixture = await _pump(
      tester,
      TargetPlatform.windows,
      overrideCatalog: streaming,
    );
    await _submit(tester, 'old query');
    fixture.history.pending[0].complete([]);
    await tester.pump();
    final old = streaming.calls.single;
    await _submit(tester, 'replacement query');
    expect(old.cancellation!.isCancelled, isTrue);
    // The new request starts before its history write, and a late cancelled
    // future must not hide its results.
    old.completer.completeError(const SourceSearchCancelled());
    await tester.pump();
    fixture.history.pending[1].complete([]);
    await tester.pump();
    final replacement = streaming.calls.last;
    const partial = SourceSearchResponse(
      results: [
        BookSearchResult(
          ref: SourceBookRef(sourceId: 'izib', sourceBookId: 'replacement'),
          sourceName: 'Izib',
          title: 'Replacement partial book',
        ),
      ],
    );
    replacement.update!(partial);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(replacement.completer.isCompleted, isFalse);
    expect(find.text('Replacement partial book'), findsOneWidget);
    expect(find.text('Found so far: 1 result'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('search-partial-progress')),
      findsOneWidget,
    );
    replacement.completer.complete(partial);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets(
      'partial results are lazy before final completion on $platform',
      (tester) async {
        final streaming = _StreamingCatalog();
        final fixture = await _pump(
          tester,
          platform,
          overrideCatalog: streaming,
        );
        await _submit(tester, 'query');
        fixture.history.pending.single.complete([]);
        await tester.pump();
        final call = streaming.calls.single;
        final partial = SourceSearchResponse(
          results: List.generate(
            120,
            (i) => BookSearchResult(
              ref: SourceBookRef(sourceId: 'izib', sourceBookId: '$i'),
              sourceName: 'Izib',
              title: 'Partial book $i',
            ),
          ),
          sourceStatuses: const [
            SearchSourceStatus(
              sourceId: 'izib',
              participation: SearchSourceParticipation.searching,
              matchCount: 120,
            ),
          ],
        );
        call.update!(partial);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.byType(BookCard).evaluate().length,
          inInclusiveRange(1, 24),
        );
        expect(
          find.byKey(const ValueKey('search-partial-progress')),
          findsOneWidget,
        );
        expect(call.completer.isCompleted, isFalse);
        final grid = find.byKey(const ValueKey('search-results-grid'));
        final oldGridState = tester.state(grid);
        call.completer.complete(
          SourceSearchResponse(
            results: partial.results,
            continuation: _TestContinuation(),
            sourceStatuses: const [
              SearchSourceStatus(
                sourceId: 'izib',
                participation: SearchSourceParticipation.completed,
                matchCount: 120,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.state(grid), same(oldGridState));
        expect(
          find.byKey(const ValueKey('search-partial-progress')),
          findsNothing,
        );
        expect(
          find.byType(BookCard).evaluate().length,
          inInclusiveRange(1, 24),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'route reset cancels active search and rejects late snapshots on $platform',
      (tester) async {
        final streaming = _StreamingCatalog();
        final fixture = await _pump(
          tester,
          platform,
          overrideCatalog: streaming,
        );
        await _submit(tester, 'query');
        fixture.history.pending.single.complete([]);
        await tester.pump();
        final call = streaming.calls.single;
        fixture.reset.value = 'reset';
        await tester.pumpAndSettle();
        expect(call.cancellation!.isCancelled, isTrue);
        const late = SourceSearchResponse(
          results: [
            BookSearchResult(
              ref: SourceBookRef(sourceId: 'izib', sourceBookId: 'late'),
              sourceName: 'Izib',
              title: 'Obsolete result',
            ),
          ],
        );
        call.update!(late);
        call.completer.complete(late);
        await tester.pumpAndSettle();
        expect(find.text('Obsolete result'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('latest search wins delayed history completion on $platform', (
      tester,
    ) async {
      final fixture = await _pump(tester, platform);
      await _submit(tester, 'older query');
      await _submit(tester, 'newer query');
      expect(fixture.history.pending, hasLength(2));
      expect(fixture.catalog.requests.map((r) => r.query), [
        'older query',
        'newer query',
      ]);
      fixture.history.pending[1].complete([]);
      await tester.pumpAndSettle();
      expect(fixture.catalog.requests.map((r) => r.query), [
        'older query',
        'newer query',
      ]);
      fixture.history.pending[0].complete([]);
      await tester.pumpAndSettle();
      expect(fixture.catalog.requests.map((r) => r.query), [
        'older query',
        'newer query',
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('clearing search invalidates pending history on $platform', (
      tester,
    ) async {
      final fixture = await _pump(tester, platform);
      await _submit(tester, 'older query');
      await _submit(tester, '');
      fixture.history.pending.single.complete([]);
      await tester.pumpAndSettle();
      expect(fixture.catalog.requests.map((r) => r.query), ['older query']);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('route reset invalidates pending history on $platform', (
      tester,
    ) async {
      final fixture = await _pump(tester, platform);
      await _submit(tester, 'older query');
      fixture.reset.value = 'reset search';
      await tester.pumpAndSettle();
      fixture.history.pending.single.complete([]);
      await tester.pumpAndSettle();
      expect(fixture.catalog.requests.map((r) => r.query), ['older query']);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('history write failure does not disable search on $platform', (
      tester,
    ) async {
      final fixture = await _pump(tester, platform);
      await _submit(tester, 'new query');
      fixture.history.pending.single.completeError(
        StateError('Memory fixture history unavailable'),
      );
      await tester.pumpAndSettle();
      expect(fixture.catalog.requests.map((r) => r.query), ['new query']);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _submit(WidgetTester tester, String query) async {
  if (find.byType(TextField).evaluate().isEmpty) {
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byType(TextField), query);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
}

Future<
  ({_DeferredHistory history, _Catalog catalog, ValueNotifier<String> reset})
>
_pump(
  WidgetTester tester,
  TargetPlatform platform, {
  _Catalog? overrideCatalog,
  FileDownloadStorage? overrideStorage,
  PlaybackController? overridePlayback,
  DownloadManager? overrideDownloads,
}) async {
  tester.view.physicalSize = Size(
    platform == TargetPlatform.windows ? 1267 : 390,
    844,
  );
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final history = _DeferredHistory();
  final catalog = overrideCatalog ?? _Catalog();
  final reset = ValueNotifier('');
  addTearDown(reset.dispose);
  final router = GoRouter(
    initialLocation: '/search',
    routes: [
      GoRoute(
        path: '/search',
        builder: (context, state) => Scaffold(
          body: ValueListenableBuilder(
            valueListenable: reset,
            builder: (context, token, _) => SearchScreen(resetToken: token),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        searchHistoryStoreProvider.overrideWith((ref) => history),
        sourceCatalogServiceProvider.overrideWith((ref) => catalog),
        playbackControllerProvider.overrideWith(
          (ref) =>
              overridePlayback ??
              PlaybackController(engine: InMemoryAudioEngine()),
        ),
        playbackProgressSnapshotsProvider.overrideWith((ref) async => []),
        if (overrideStorage != null)
          downloadStorageProvider.overrideWithValue(overrideStorage),
        downloadManagerProvider.overrideWith(
          (ref) => overrideDownloads ?? _EmptyDownloads(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.dark().copyWith(platform: platform),
        locale: const Locale('en'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (history: history, catalog: catalog, reset: reset);
}

class _EmptyDownloadedStorage extends FileDownloadStorage {
  _EmptyDownloadedStorage()
    : super(rootDirectory: Directory('unused-local-search-test'));
  int scans = 0;
  @override
  Future<List<AudioPlaybackBook>> readDownloadedMetadata() async {
    scans++;
    return [];
  }
}

class _SearchPlaybackFixture extends PlaybackController {
  _SearchPlaybackFixture() : super(engine: InMemoryAudioEngine());

  @override
  AudioPlaybackState state = AudioPlaybackState.idle;

  void update(AudioPlaybackState value) {
    state = value;
    notifyListeners();
  }
}

class _DeferredHistory extends SearchHistoryStore {
  final pending = <Completer<List<SearchHistoryEntry>>>[];
  @override
  Future<List<SearchHistoryEntry>> load() async => [];
  @override
  Future<List<SearchHistoryEntry>> record(
    String query,
    SearchKind kind, {
    Set<SearchKind> kinds = const {},
    SearchSort sort = SearchSort.relevance,
  }) {
    final completer = Completer<List<SearchHistoryEntry>>();
    pending.add(completer);
    return completer.future;
  }
}

class _Catalog extends SourceCatalogService {
  _Catalog() : super(registry: SourceRegistry([]));
  final requests = <SearchRequest>[];
  @override
  Future<SourceSearchResponse> search(
    SearchRequest request, {
    void Function(SourceSearchResponse response)? onUpdate,
    SourceSearchCancellation? cancellation,
  }) async {
    requests.add(request);
    return const SourceSearchResponse(results: []);
  }
}

class _EmptyDownloads extends ChangeNotifier implements DownloadManager {
  @override
  List<DownloadTask> tasks = const [];

  @override
  AudioPlaybackBook? bookForTask(String taskId) => null;

  void replaceTasks(List<DownloadTask> newTasks) {
    tasks = newTasks;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StreamingCatalog extends _Catalog {
  final calls =
      <
        ({
          void Function(SourceSearchResponse)? update,
          SourceSearchCancellation? cancellation,
          Completer<SourceSearchResponse> completer,
        })
      >[];
  @override
  Future<SourceSearchResponse> search(
    SearchRequest request, {
    void Function(SourceSearchResponse)? onUpdate,
    SourceSearchCancellation? cancellation,
  }) {
    requests.add(request);
    final completer = Completer<SourceSearchResponse>();
    calls.add((
      update: onUpdate,
      cancellation: cancellation,
      completer: completer,
    ));
    return completer.future;
  }
}

class _TestContinuation implements SourceSearchContinuation {}
