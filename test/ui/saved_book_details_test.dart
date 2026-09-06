import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/windows_theme.dart';
import 'package:slovofon/domain/models/audio_book.dart';
import 'package:slovofon/features/book_details/saved_book_details_screen.dart';
import 'package:slovofon/features/source_books/source_book_details_screen.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_persistence.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/library/library_metadata.dart';
import 'package:slovofon/services/library/library_store.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  final strings = AppStrings.forLocale(const Locale('en'));

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets(
      'saved details show requested real identity and play correct book on $platform',
      (tester) async {
        final target = _book('target');
        final fixture = await _pump(
          tester,
          books: [_book('unrelated'), target],
          platform: platform,
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('saved-book-title')))
              .data,
          'Real title target',
        );
        expect(find.text('Real narrator target'), findsOneWidget);
        expect(find.text('Description target'), findsOneWidget);
        expect(find.text('Real title unrelated'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('saved-book-play')));
        await tester.pumpAndSettle();
        expect(fixture.storage.resolved, ['target']);
        expect(fixture.controller.state.book?.id, 'target');
        expect(fixture.controller.state.isPlaying, isTrue);
        expect(find.text('Real player route'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'missing saved ID never falls back to first metadata or current book',
    (tester) async {
      await _pump(tester, books: [_book('other')], current: _book('current'));
      expect(
        find.byKey(const ValueKey('saved-book-not-found')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('saved-book-title')), findsNothing);
      expect(find.byKey(const ValueKey('saved-book-play')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('saved-book-search')));
      await tester.pumpAndSettle();
      expect(find.text('Search route'), findsOneWidget);
    },
  );

  testWidgets(
    'current playback can supply exact saved book before metadata resolves',
    (tester) async {
      final pending = Completer<List<AudioPlaybackBook>>();
      await _pump(
        tester,
        current: _book('target'),
        metadata: () => pending.future,
        settle: false,
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('saved-book-title')), findsOneWidget);
      expect(find.byKey(const ValueKey('saved-book-loading')), findsNothing);
      pending.complete([]);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('loading does not prematurely claim book not found', (
    tester,
  ) async {
    final pending = Completer<List<AudioPlaybackBook>>();
    await _pump(tester, metadata: () => pending.future, settle: false);
    expect(find.byKey(const ValueKey('saved-book-loading')), findsOneWidget);
    expect(find.byKey(const ValueKey('saved-book-not-found')), findsNothing);
    pending.complete([_book('target')]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('saved-book-title')), findsOneWidget);
  });

  testWidgets(
    'metadata failure has a working retry instead of a mock fallback',
    (tester) async {
      var calls = 0;
      await _pump(
        tester,
        metadata: () async {
          if (++calls == 1) throw StateError('Synthetic metadata read failure');
          return [_book('target')];
        },
      );
      expect(find.byKey(const ValueKey('saved-book-error')), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, strings.retry));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byKey(const ValueKey('saved-book-title')), findsOneWidget);
    },
  );

  testWidgets(
    'favorite-only details expose real fields and honest unavailable media',
    (tester) async {
      final book = _card('target');
      final fixture = await _pump(tester, favorites: [book]);
      expect(find.text(book.title), findsOneWidget);
      expect(find.text(book.narrator), findsOneWidget);
      expect(find.byKey(const ValueKey('saved-book-play')), findsNothing);
      expect(
        find.byKey(const ValueKey('saved-book-media-unavailable')),
        findsOneWidget,
      );
      expect(fixture.library.isFavorite(book), isTrue);
      await tester.tap(find.byKey(const ValueKey('saved-book-favorite')));
      await tester.pumpAndSettle();
      expect(fixture.library.isFavorite(book), isFalse);
      expect(
        find.byKey(const ValueKey('saved-book-not-found')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'source-linked favorite reuses exact SourceBookRef instead of mock metadata',
    (tester) async {
      await _pump(
        tester,
        favorites: [_card('target', sourceBookId: 'real-source-id')],
      );
      final screen = tester.widget<SourceBookDetailsScreen>(
        find.byType(SourceBookDetailsScreen),
      );
      expect(screen.ref.sourceId, 'fixture');
      expect(screen.ref.sourceBookId, 'real-source-id');
      expect(find.byKey(const ValueKey('saved-book-title')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ambiguous unqualified IDs cannot select another source', (
    tester,
  ) async {
    await _pump(
      tester,
      books: [
        _book('target'),
        _book('target', source: 'second-source'),
      ],
    );
    expect(find.byKey(const ValueKey('saved-book-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('saved-book-play')), findsNothing);
  });

  testWidgets(
    'chapter tap selects the requested real chapter and not current book',
    (tester) async {
      final fixture = await _pump(
        tester,
        books: [_book('target')],
        current: _book('other'),
      );
      final chapter = find.byKey(const ValueKey('saved-book-chapter-1'));
      await tester.scrollUntilVisible(
        chapter,
        200,
        scrollable: find
            .descendant(
              of: find.byKey(
                const ValueKey('saved-book-layout-fixture:target'),
              ),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(chapter);
      await tester.pumpAndSettle();
      expect(fixture.controller.state.book?.id, 'target');
      expect(fixture.controller.state.chapterIndex, 1);
      expect(fixture.controller.state.position, Duration.zero);
      expect(fixture.controller.state.isPlaying, isTrue);
    },
  );

  testWidgets('play resumes saved chapter and position', (tester) async {
    final fixture = await _pump(
      tester,
      books: [_book('target')],
      progress: [
        PlaybackProgressSnapshot(
          bookId: 'target',
          bookVersionId: 'version-target',
          currentChapterId: 'target-chapter-1',
          currentPositionMs: 42000,
          maxReachedGlobalPositionMs: 642000,
          totalDurationMs: 1200000,
          listenedDurationMs: 642000,
          percent: .535,
          isFinished: false,
          lastPlayedAt: DateTime(2026),
        ),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('saved-book-play')));
    await tester.pumpAndSettle();
    expect(fixture.controller.state.chapterIndex, 1);
    expect(fixture.controller.state.position, const Duration(seconds: 42));
  });

  testWidgets(
    'playing the same current book preserves position and does not pause',
    (tester) async {
      final fixture = await _pump(tester, current: _book('target'));
      await fixture.controller.seek(const Duration(seconds: 60));
      await fixture.controller.play();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saved-book-play')));
      await tester.pumpAndSettle();
      expect(fixture.controller.state.position, const Duration(seconds: 60));
      expect(fixture.controller.state.isPlaying, isTrue);
      expect(fixture.storage.resolved, isEmpty);
    },
  );

  testWidgets(
    'offline resolver failure is visible and retry resolves requested book',
    (tester) async {
      final storage = _Storage()..fail = true;
      final fixture = await _pump(
        tester,
        books: [_book('target')],
        storage: storage,
      );
      await tester.tap(find.byKey(const ValueKey('saved-book-play')));
      await tester.pumpAndSettle();
      expect(find.text(strings.savedBookPlaybackError), findsOneWidget);
      expect(fixture.controller.state.book, isNull);
      expect(find.text('Real player route'), findsNothing);
      storage.fail = false;
      await tester.tap(find.byKey(const ValueKey('saved-book-play')));
      await tester.pumpAndSettle();
      expect(fixture.controller.state.book?.id, 'target');
    },
  );

  testWidgets(
    'offline overlay supplies playable files absent from durable metadata',
    (tester) async {
      final storage = _Storage()..overlay = _book('target');
      final fixture = await _pump(
        tester,
        books: [_book('target', media: false)],
        storage: storage,
      );
      await tester.tap(find.byKey(const ValueKey('saved-book-play')));
      await tester.pumpAndSettle();
      expect(storage.resolved, ['target']);
      expect(
        fixture.controller.state.currentChapter?.mediaSource?.type,
        AudioMediaSourceType.file,
      );
      expect(fixture.controller.state.isPlaying, isTrue);
      expect(find.text('Real player route'), findsOneWidget);
    },
  );

  testWidgets(
    'chapter metadata without playable audio gives an explicit error',
    (tester) async {
      final fixture = await _pump(
        tester,
        books: [_book('target', media: false)],
      );
      await tester.tap(find.byKey(const ValueKey('saved-book-play')));
      await tester.pumpAndSettle();
      expect(find.text(strings.savedBookMediaUnavailable), findsOneWidget);
      expect(fixture.controller.state.book, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'leaving identity while offline resolution waits cannot start stale book',
    (tester) async {
      final pending = Completer<AudioPlaybackBook>();
      final storage = _Storage()..pending = pending;
      final fixture = await _pump(
        tester,
        books: [_book('target'), _book('second')],
        storage: storage,
      );
      await tester.tap(find.byKey(const ValueKey('saved-book-play')));
      await tester.pump();
      fixture.router.go('/book/second');
      await tester.pumpAndSettle();
      pending.complete(_book('target'));
      await tester.pumpAndSettle();
      expect(fixture.controller.state.book, isNull);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('saved-book-title')))
            .data,
        'Real title second',
      );
    },
  );
}

AudioPlaybackBook _book(
  String id, {
  String source = 'fixture',
  bool media = true,
}) => AudioPlaybackBook(
  id: id,
  versionId: 'version-$id',
  sourceId: source,
  sourceName: 'Fixture source',
  title: 'Real title $id',
  author: 'Real author $id',
  narrator: 'Real narrator $id',
  description: 'Description $id',
  chapters: [
    for (var i = 0; i < 2; i++)
      AudioPlaybackChapter(
        id: '$id-chapter-$i',
        index: i,
        title: '$id actual chapter $i',
        duration: const Duration(minutes: 10),
        mediaSource: media
            ? AudioMediaSource.file('/synthetic/$id/$i.mp3')
            : null,
      ),
  ],
);

AudioBook _card(String id, {String? sourceBookId}) => AudioBook(
  id: id,
  sourceBookId: sourceBookId,
  title: 'Favorite title $id',
  author: 'Favorite author $id',
  narrator: 'Favorite narrator $id',
  sourceId: 'fixture',
  sourceName: 'Fixture source',
  durationLabel: '10:00',
  chapterCount: 0,
  progress: 0,
  access: BookAccess.unknown,
);

Future<
  ({
    PlaybackController controller,
    GoRouter router,
    LibraryStore library,
    _Storage storage,
  })
>
_pump(
  WidgetTester tester, {
  List<AudioPlaybackBook> books = const [],
  List<AudioBook> favorites = const [],
  List<PlaybackProgressSnapshot> progress = const [],
  AudioPlaybackBook? current,
  Future<List<AudioPlaybackBook>> Function()? metadata,
  _Storage? storage,
  TargetPlatform platform = TargetPlatform.windows,
  bool settle = true,
}) async {
  tester.view.physicalSize = platform == TargetPlatform.windows
      ? const Size(1267, 900)
      : const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = PlaybackController(engine: InMemoryAudioEngine());
  addTearDown(controller.dispose);
  if (current != null) await controller.loadBook(current);
  final library = LibraryStore(MemoryLibraryPersistenceStore());
  await library.load();
  for (final book in favorites) {
    await library.toggleFavorite(book);
  }
  final memory = storage ?? _Storage();
  final downloads = DownloadManager(
    client: _NoNetwork(),
    storage: memory,
    persistence: MemoryDownloadPersistenceStore(),
  );
  final router = GoRouter(
    initialLocation: '/book/target',
    routes: [
      GoRoute(
        path: '/book/:bookId',
        builder: (_, state) =>
            SavedBookDetailsScreen(bookId: state.pathParameters['bookId']!),
      ),
      GoRoute(
        path: '/player',
        builder: (_, _) => const Scaffold(body: Text('Real player route')),
      ),
      GoRoute(
        path: '/search',
        builder: (_, _) => const Scaffold(body: Text('Search route')),
      ),
      for (final path in ['/', '/library', '/downloads', '/settings'])
        GoRoute(
          path: path,
          builder: (_, _) => const Scaffold(body: Text('Other route')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playbackControllerProvider.overrideWithValue(controller),
        libraryStoreProvider.overrideWith((ref) => library),
        libraryPlaybackBooksProvider.overrideWith(
          (ref) => metadata?.call() ?? Future.value(books),
        ),
        playbackProgressSnapshotsProvider.overrideWith((ref) async => progress),
        downloadStorageProvider.overrideWithValue(memory),
        downloadManagerProvider.overrideWith((ref) => downloads),
        sourceCatalogServiceProvider.overrideWithValue(
          SourceCatalogService(registry: SourceRegistry([])),
        ),
      ],
      child: MaterialApp.router(
        theme:
            (platform == TargetPlatform.windows
                    ? WindowsTheme.from(AppTheme.dark())
                    : AppTheme.dark())
                .copyWith(platform: platform),
        routerConfig: router,
        locale: const Locale('en'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return (
    controller: controller,
    router: router,
    library: library,
    storage: memory,
  );
}

class _Storage extends FileDownloadStorage {
  _Storage() : super(rootDirectory: Directory('unused-saved-details-fixture'));
  bool fail = false;
  Completer<AudioPlaybackBook>? pending;
  AudioPlaybackBook? overlay;
  final resolved = <String>[];
  @override
  Future<List<AudioPlaybackBook>> readAllMetadata() async => [];
  @override
  Future<AudioPlaybackBook> offlinePlaybackBook(AudioPlaybackBook book) async {
    resolved.add(book.id);
    if (fail) throw StateError('Synthetic offline resolver failure');
    final wait = pending;
    if (wait != null) return wait.future;
    return overlay ?? book;
  }
}

class _NoNetwork implements DownloadClient {
  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async => throw StateError('No network in saved details tests');
}
