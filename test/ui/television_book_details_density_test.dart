import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/television_theme.dart';
import 'package:slovofon/data/mock/stage3_mock_data.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/features/book_details/saved_book_details_screen.dart';
import 'package:slovofon/features/source_books/source_book_details_screen.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
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
import 'package:slovofon/ui/adaptive/desktop_book_details_layout.dart';
import 'package:slovofon/ui/adaptive/television_layout.dart';
import 'package:slovofon/ui/components/download_action_button.dart';

void main() {
  for (final dpr in [2.0, 4.0]) {
    for (final scale in [.75, 1.0, 2.0]) {
      for (final height in [360.0, 420.0]) {
        testWidgets(
          'TV details chapters visible at 818x$height DPR=$dpr text=$scale',
          (tester) async {
            await _pumpLayout(tester, height: height, dpr: dpr, scale: scale);
            final panel = find.byKey(
              const ValueKey('television-details-panel'),
            );
            final first = find.byKey(const ValueKey('density-chapter-0'));
            expect(
              find.byKey(const ValueKey('television-details-split')),
              findsOneWidget,
            );
            final chapterRect = tester.getRect(first);
            expect(tester.getRect(panel).contains(chapterRect.topLeft), isTrue);
            expect(
              tester.getRect(panel).contains(chapterRect.bottomRight),
              isTrue,
            );
            expect(find.text('Information body'), findsNothing);
            expect(
              MediaQuery.textScalerOf(tester.element(first)).scale(14),
              closeTo(14 * scale, .001),
            );
            expect(MediaQuery.devicePixelRatioOf(tester.element(first)), dpr);
            final summaryScroll = tester
                .widget<SingleChildScrollView>(
                  find.byKey(
                    const ValueKey('television-details-summary-scroll'),
                  ),
                )
                .controller!;
            summaryScroll.jumpTo(summaryScroll.position.maxScrollExtent);
            await tester.pumpAndSettle();
            expect(
              tester.getRect(first),
              chapterRect,
              reason: 'Profile scrolling must not move the chapter viewport',
            );
            await tester.tap(
              find.byKey(const ValueKey('television-details-tab-1')),
            );
            await tester.pumpAndSettle();
            expect(find.text('Information body'), findsOneWidget);
            expect(first, findsNothing);
            await tester.tap(
              find.byKey(const ValueKey('television-details-tab-0')),
            );
            await tester.pumpAndSettle();
            expect(tester.getRect(first), chapterRect);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final rtl in [false, true]) {
    testWidgets('TV details compact split follows reading order RTL=$rtl', (
      tester,
    ) async {
      await _pumpLayout(tester, rtl: rtl);
      final summary = tester.getRect(
        find.byKey(const ValueKey('desktop-details-summary')),
      );
      final panel = tester.getRect(
        find.byKey(const ValueKey('television-details-panel')),
      );
      expect(
        rtl ? summary.left - panel.right : panel.left - summary.right,
        closeTo(12, .01),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('TV chapter tab transfers D-pad focus into the chapter list', (
    tester,
  ) async {
    await _pumpLayout(tester);
    final tab = find.byKey(const ValueKey('television-details-tab-0'));
    final first = find.byKey(const ValueKey('density-chapter-0'));
    final label = find.descendant(of: tab, matching: find.byType(Text));
    Focus.of(tester.element(label)).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusWithin(tester.element(first)), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      _focusWithin(
        tester.element(find.byKey(const ValueKey('density-chapter-1'))),
      ),
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(_focusWithin(tester.element(first)), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(_focusWithin(tester.element(tab)), isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('TV details tabs preserve focus contrast dark=$dark', (
      tester,
    ) async {
      await _pumpLayout(tester, dark: dark);
      for (var i = 0; i < 2; i++) {
        final tab = find.byKey(ValueKey('television-details-tab-$i'));
        final style = tester.widget<TextButton>(tab).style!;
        for (final states in [
          <WidgetState>{},
          {WidgetState.focused},
        ]) {
          final foreground = style.foregroundColor!.resolve(states)!;
          final background = style.backgroundColor!.resolve(states)!;
          final values = [
            foreground.computeLuminance(),
            background.computeLuminance(),
          ]..sort();
          expect(
            (values.last + .05) / (values.first + .05),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final source in [false, true]) {
    testWidgets(
      'TV ${source ? 'source' : 'saved'} details expose chapters, Later, download and removal',
      (tester) async {
        final fixture = await _pumpDetails(tester, source: source);
        final prefix = source ? 'source-details' : 'saved-book';
        final first = find.byKey(ValueKey('$prefix-chapter-0'));
        final panel = tester.getRect(
          find.byKey(const ValueKey('television-details-panel')),
        );
        final chapter = tester.getRect(first);
        expect(panel.contains(chapter.topLeft), isTrue);
        expect(panel.contains(chapter.bottomRight), isTrue);
        final artwork = tester.getSize(
          find.byKey(const ValueKey('television-details-artwork')),
        );
        expect(artwork.width, inInclusiveRange(64, 80));
        final play = find.byKey(ValueKey('$prefix-play'));
        expect(tester.getSize(play), const Size.square(40));
        expect(tester.widget<IconButton>(play).tooltip, isNotEmpty);
        final actionKeys = [
          '$prefix-play',
          '$prefix-download',
          '$prefix-favorite',
          '$prefix-later',
          if (source) '$prefix-share',
        ];
        final rowTop = tester.getRect(play).center.dy;
        for (final key in actionKeys) {
          expect(
            tester.getRect(find.byKey(ValueKey(key))).center.dy,
            closeTo(rowTop, .01),
            reason: 'Compact TV actions must remain on one row: $key',
          );
        }
        final book = source
            ? fixture.snapshot.audioBook
            : libraryCardBook(fixture.book);
        final later = find.byKey(ValueKey('$prefix-later'));
        await tester.ensureVisible(later);
        await tester.pumpAndSettle();
        await tester.tap(later);
        await tester.pumpAndSettle();
        expect(fixture.library.isLater(book), isTrue);
        await tester.tap(later);
        await tester.pumpAndSettle();
        expect(fixture.library.isLater(book), isFalse);
        final favorite = find.byKey(ValueKey('$prefix-favorite'));
        await tester.ensureVisible(favorite);
        await tester.pumpAndSettle();
        await tester.tap(favorite);
        await tester.pumpAndSettle();
        expect(fixture.library.isFavorite(book), isTrue);
        final download = find.byKey(ValueKey('$prefix-download'));
        await tester.ensureVisible(download);
        await tester.pumpAndSettle();
        await tester.tap(download);
        await tester.pumpAndSettle();
        expect(fixture.downloads.enqueued, 1);
        final playback = source ? fixture.snapshot.playbackBook : fixture.book;
        fixture.downloads.complete(playback);
        await tester.pumpAndSettle();
        final summary = find.byKey(const ValueKey('desktop-details-summary'));
        final control = tester.widget<DownloadActionButton>(
          find.descendant(
            of: summary,
            matching: find.byType(DownloadActionButton),
          ),
        );
        expect(control.state, BookCardDownloadState.downloaded);
        await tester.tap(download);
        await tester.pumpAndSettle();
        expect(fixture.downloads.deleted, 1);
        await tester.tap(
          find.byKey(const ValueKey('television-details-tab-1')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            ValueKey(
              source ? 'tv-source-details-url' : 'saved-book-description',
            ),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

bool _focusWithin(Element ancestor) {
  var result = false;
  FocusManager.instance.primaryFocus?.context?.visitAncestorElements((element) {
    if (element == ancestor) result = true;
    return !result;
  });
  return result;
}

Future<void> _pumpLayout(
  WidgetTester tester, {
  double height = 360,
  double dpr = 2,
  double scale = 1,
  bool rtl = false,
  bool dark = true,
}) async {
  tester.view.physicalSize = Size(818, height) * dpr;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: TelevisionTheme.from(dark ? AppTheme.dark() : AppTheme.light()),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            navigationMode: NavigationMode.directional,
          ),
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: TelevisionLayout(
              enabled: true,
              child: Scaffold(
                body: DesktopBookDetailsLayout(
                  summary: Column(
                    children: [
                      Text(
                        'Мастер и Маргарита',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (var i = 0; i < 30; i++) Text('Факт о книге $i'),
                    ],
                  ),
                  contentSlivers: const [],
                  televisionTabs: [
                    TelevisionBookDetailsTab(
                      title: 'Главы',
                      slivers: [
                        SliverList.builder(
                          itemCount: 25,
                          itemBuilder: (context, index) => TextButton(
                            key: ValueKey('density-chapter-$index'),
                            onPressed: () {},
                            child: Text('Глава ${index + 1}'),
                          ),
                        ),
                      ],
                    ),
                    const TelevisionBookDetailsTab(
                      title: 'Информация',
                      slivers: [
                        SliverToBoxAdapter(child: Text('Information body')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<
  ({
    LibraryStore library,
    _RecordingDownloads downloads,
    AudioPlaybackBook book,
    SourceBookSnapshot snapshot,
  })
>
_pumpDetails(WidgetTester tester, {required bool source}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final library = LibraryStore(MemoryLibraryPersistenceStore());
  await library.load();
  final book = AudioPlaybackBook(
    id: 'saved-density-book',
    versionId: 'saved-density-version',
    sourceId: 'izib',
    sourceName: 'Изибук',
    title: 'Белые ночи',
    author: 'Фёдор Достоевский',
    narrator: 'Василий Дахненко',
    description: 'Настоящее описание сохранённой аудиокниги.',
    chapters: [
      for (var i = 0; i < 12; i++)
        AudioPlaybackChapter(
          id: 'density-$i',
          index: i,
          title: 'Глава ${i + 1}',
          duration: const Duration(minutes: 12),
        ),
    ],
  );
  final controller = PlaybackController(engine: InMemoryAudioEngine());
  await controller.loadBook(book, autoPlay: false);
  addTearDown(controller.dispose);
  final storage = _MemoryStorage();
  final downloads = _RecordingDownloads(storage);
  final catalog = SourceCatalogService(
    registry: SourceRegistry([MockSourceConnector.yakniga()]),
  );
  final snapshot = await catalog.loadBook(
    SourceBookRef(
      sourceId: activeMockBook.sourceId,
      sourceBookId: activeMockBook.id,
    ),
  );
  final router = GoRouter(
    initialLocation: '/details',
    routes: [
      GoRoute(
        path: '/details',
        builder: (_, _) => source
            ? SourceBookDetailsScreen(ref: snapshot.details.ref)
            : const SavedBookDetailsScreen(bookId: 'saved-density-book'),
      ),
      for (final path in [
        '/',
        '/player',
        '/search',
        '/library',
        '/downloads',
        '/settings',
      ])
        GoRoute(
          path: path,
          builder: (_, _) => const Scaffold(body: Text('Destination')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        libraryStoreProvider.overrideWith((ref) => library),
        playbackControllerProvider.overrideWith((ref) => controller),
        downloadManagerProvider.overrideWith((ref) => downloads),
        downloadStorageProvider.overrideWithValue(storage),
        libraryPlaybackBooksProvider.overrideWith((ref) async => [book]),
        sourceCatalogServiceProvider.overrideWithValue(catalog),
      ],
      child: MaterialApp.router(
        theme: TelevisionTheme.from(
          AppTheme.dark(),
        ).copyWith(platform: TargetPlatform.android),
        routerConfig: router,
        locale: const Locale('ru'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            navigationMode: NavigationMode.directional,
            disableAnimations: true,
          ),
          child: TelevisionLayout(
            enabled: true,
            child: TelevisionViewport(child: child!),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (
    library: library,
    downloads: downloads,
    book: book,
    snapshot: snapshot,
  );
}

class _RecordingDownloads extends DownloadManager {
  _RecordingDownloads(FileDownloadStorage storage)
    : super(
        client: _NoNetworkClient(),
        storage: storage,
        persistence: MemoryDownloadPersistenceStore(),
      );
  int enqueued = 0;
  int deleted = 0;
  final _completed = <DownloadTask>[];
  AudioPlaybackBook? _book;
  @override
  List<DownloadTask> get tasks => List.unmodifiable(_completed);
  @override
  AudioPlaybackBook? bookForTask(String taskId) => _book;
  @override
  Future<List<DownloadTask>> enqueueMissingChapters(
    AudioPlaybackBook book,
  ) async {
    enqueued++;
    return [];
  }

  @override
  Future<void> cancelAndDeleteBook(AudioPlaybackBook book) async {
    deleted++;
    _completed.clear();
    notifyListeners();
  }

  void complete(AudioPlaybackBook book) {
    _book = book;
    _completed.addAll([
      for (final chapter in book.chapters)
        DownloadTask(
          id: 'download-${chapter.id}',
          bookId: book.id,
          bookVersionId: book.versionId,
          chapterId: chapter.id,
          sourceId: book.sourceId,
          type: DownloadTaskType.chapter,
          status: DownloadTaskStatus.completed,
          progress: 1,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
    ]);
    notifyListeners();
  }
}

class _NoNetworkClient implements DownloadClient {
  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async => throw StateError('Details widget test does not access media');
}

class _MemoryStorage extends FileDownloadStorage {
  _MemoryStorage() : super(rootDirectory: Directory('unused-tv-density-test'));
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
