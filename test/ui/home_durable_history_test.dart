import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/features/home/home_screen.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_persistence.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/library/library_metadata.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/sources/sources.dart';
import 'package:slovofon/ui/components/book_card.dart';

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets(
      'durable home history remains playable after card cache removal $platform',
      (tester) async {
        tester.view.physicalSize = platform == TargetPlatform.windows
            ? const Size(1267, 820)
            : const Size(430, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final engine = InMemoryAudioEngine();
        final controller = PlaybackController(engine: engine);
        addTearDown(controller.dispose);
        addTearDown(engine.dispose);
        final catalog = _Catalog();
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: HomeScreen()),
            ),
            GoRoute(
              path: '/player',
              builder: (_, _) =>
                  const Scaffold(body: Text('Player destination')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              playbackControllerProvider.overrideWith((ref) => controller),
              downloadStorageProvider.overrideWith((ref) => _EmptyCache()),
              libraryMetadataPersistenceProvider.overrideWith(
                (ref) => _DurableMetadata(),
              ),
              sourceCatalogServiceProvider.overrideWith((ref) => catalog),
              playbackProgressSnapshotsProvider.overrideWith(
                (ref) async => [_progress],
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              locale: const Locale('en'),
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: AppTheme.light().copyWith(platform: platform),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BookCard), findsOneWidget);
        expect(find.text('Durable history book'), findsOneWidget);
        expect(
          tester.widget<BookCard>(find.byType(BookCard)).book.progress,
          closeTo(1 / 3, .001),
        );
        expect(
          catalog.refreshes,
          0,
          reason: 'Showing history must not fetch remote media.',
        );
        final play = find.byKey(
          ValueKey('book-card-play-${_book.sourceId}-${_book.sourceBookId}'),
        );
        expect(play, findsOneWidget);
        await tester.ensureVisible(play);
        await tester.pumpAndSettle();
        await tester.tap(play);
        await tester.pumpAndSettle();
        expect(catalog.refreshes, 1);
        expect(controller.state.book!.versionId, _book.versionId);
        expect(controller.state.position, const Duration(seconds: 20));
        expect(controller.state.isPlaying, isTrue);
        expect(find.text('Player destination'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _EmptyCache extends FileDownloadStorage {
  _EmptyCache() : super(rootDirectory: Directory('never-written-home-durable'));
  @override
  Future<List<AudioPlaybackBook>> readAllMetadata() async => [];
  @override
  Future<AudioPlaybackBook> offlinePlaybackBook(AudioPlaybackBook book) async =>
      book;
}

class _DurableMetadata implements LibraryMetadataPersistence {
  @override
  Future<List<AudioPlaybackBook>> loadPlaybackBooks({
    Set<String>? versionIds,
  }) async =>
      versionIds == null || versionIds.contains(_book.versionId) ? [_book] : [];
  @override
  Future<void> savePlaybackBook(AudioPlaybackBook book) async {}
}

class _Catalog extends SourceCatalogService {
  _Catalog() : super(registry: SourceRegistry(const []));
  int refreshes = 0;
  @override
  Future<AudioPlaybackBook> refreshBookForPlayback(
    AudioPlaybackBook book,
  ) async {
    refreshes++;
    return book.copyWith(
      chapters: [
        book.chapters.single.copyWith(
          mediaSource: AudioMediaSource.url(
            Uri.parse('https://fixture.test/chapter.mp3'),
          ),
        ),
      ],
    );
  }
}

const _book = AudioPlaybackBook(
  id: 'source-book',
  versionId: 'source-version',
  sourceId: 'source',
  sourceBookId: 'ref',
  title: 'Durable history book',
  author: 'Author',
  narrator: 'Narrator',
  sourceName: 'Source',
  chapters: [
    AudioPlaybackChapter(
      id: 'chapter',
      index: 0,
      title: 'Chapter',
      duration: Duration(minutes: 1),
    ),
  ],
);
final _progress = PlaybackProgressSnapshot(
  bookId: _book.id,
  bookVersionId: _book.versionId,
  currentChapterId: 'chapter',
  currentPositionMs: 20000,
  maxReachedGlobalPositionMs: 20000,
  totalDurationMs: 60000,
  listenedDurationMs: 20000,
  percent: 100 / 3,
  isFinished: false,
  lastPlayedAt: DateTime(2026),
);
