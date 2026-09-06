import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/app.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/router.dart';
import 'package:slovofon/core/platform/app_device_profile.dart';
import 'package:slovofon/domain/models/app_settings.dart';
import 'package:slovofon/domain/models/book_version.dart';
import 'package:slovofon/domain/models/chapter.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/features/book_details/saved_book_details_screen.dart';
import 'package:slovofon/features/downloads/downloads_screen.dart';
import 'package:slovofon/features/home/home_screen.dart';
import 'package:slovofon/features/library/library_screen.dart';
import 'package:slovofon/features/player/full_player_screen.dart';
import 'package:slovofon/features/search/search_screen.dart';
import 'package:slovofon/features/settings/settings_screen.dart';
import 'package:slovofon/features/source_books/source_book_details_screen.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/bookmarks/bookmark_store.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/library/library_metadata.dart';
import 'package:slovofon/services/library/library_store.dart';
import 'package:slovofon/services/search/search_history_store.dart';
import 'package:slovofon/services/settings/app_settings_store.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/services/updates/update_client.dart';
import 'package:slovofon/services/updates/update_installer.dart';
import 'package:slovofon/services/updates/update_service.dart';
import 'package:slovofon/sources/sources.dart';
import 'package:slovofon/ui/adaptive/desktop_layout.dart';
import 'package:slovofon/ui/adaptive/slovofon_shell.dart';
import 'package:slovofon/ui/adaptive/television_layout.dart';
import 'package:slovofon/ui/adaptive/television_shell.dart';
import 'package:slovofon/ui/components/book_card.dart';
import 'package:slovofon/ui/components/filter_picker_sheet.dart';
import 'package:slovofon/ui/components/mini_player_bar.dart';
import 'package:slovofon/ui/components/television_book_card.dart';

import 'test_search_history_store.dart';

// Production app/router/screens, not screenshots and not native-device tests.
// All content is synthetic and all I/O-facing services are memory fixtures.
// Dimensions are logical dp; DPR 2 must not enable television or Windows UI.
const _sizes = [
  Size(600, 960),
  Size(800, 1280),
  Size(1024, 768),
  Size(1280, 800),
  Size(480, 800), // Android split-screen / narrow resizable activity.
];
final _android = TargetPlatformVariant.only(TargetPlatform.android);
final _strings = AppStrings.forLocale(const Locale('ru'));
final _stamp = DateTime(2026, 9, 7);
final _book = AudioPlaybackBook(
  id: 'tablet-classic',
  versionId: 'tablet-classic-version',
  sourceId: 'izib',
  sourceBookId: 'tablet-classic',
  sourceName: 'Изибук',
  title: 'Белые ночи. Сентиментальный роман из воспоминаний мечтателя',
  author: 'Фёдор Михайлович Достоевский',
  narrator: 'Василий Дахненко',
  description:
      'Петербургская повесть о встрече мечтателя и Настеньки. '
      'Воспоминания о четырёх ночах и одном утре.',
  genre: 'Русская классика',
  chapters: [
    for (var index = 0; index < 4; index++)
      AudioPlaybackChapter(
        id: 'tablet-chapter-$index',
        index: index,
        title: 'Ночь ${index + 1}. Встречи на набережной Петербурга',
        duration: const Duration(minutes: 30),
      ),
  ],
);

void main() {
  for (final size in _sizes) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets(
          'Android tablet $size text=$scale dark=$dark real screen matrix',
          (tester) async {
            final downloads = await _pumpApp(
              tester,
              size: size,
              scale: scale,
              dark: dark,
            );
            _expectTouchShell(tester, size: size, scale: scale, dark: dark);
            expect(find.byType(HomeScreen), findsOneWidget);
            expect(find.byType(BookCard), findsWidgets);

            await _navigate(tester, size, 1, '/search');
            expect(find.byType(SearchScreen), findsOneWidget);
            final search = find.byType(TextField);
            await _reveal(tester, search);
            await tester.enterText(search, 'Белые ночи');
            await tester.testTextInput.receiveAction(TextInputAction.search);
            await tester.pumpAndSettle();
            expect(find.byType(BookCard), findsWidgets);
            _expectClean(tester, 'populated search');

            await _navigate(tester, size, 2, '/library');
            expect(find.byType(LibraryScreen), findsOneWidget);
            expect(find.byType(BookCard), findsWidgets);
            final shelf = find.byKey(const ValueKey('library-shelf-picker'));
            await _reveal(tester, shelf);
            await tester.tap(shelf);
            await tester.pumpAndSettle();
            expect(find.byType(BottomSheet), findsOneWidget);
            expect(find.byType(Dialog), findsNothing);
            final favorite = find.descendant(
              of: find.byType(BottomSheet),
              matching: find.text(_strings.favorites),
            );
            await _reveal(tester, favorite);
            await tester.tap(favorite);
            await tester.pumpAndSettle();
            final applyShelf = find.byKey(
              const ValueKey('library-shelf-apply'),
            );
            await _reveal(tester, applyShelf);
            await tester.tap(applyShelf);
            await tester.pumpAndSettle();
            expect(find.byType(BottomSheet), findsNothing);
            expect(find.byType(BookCard), findsWidgets);
            _expectClean(tester, 'library favorite filter');

            await _navigate(tester, size, 3, '/downloads');
            expect(find.byType(DownloadsScreen), findsOneWidget);
            final actions = find.byKey(
              const ValueKey('mobile-download-actions-tablet-classic-version'),
            );
            final pause = find.descendant(
              of: actions,
              matching: find.byTooltip(_strings.pauseDownload),
            );
            await _reveal(tester, pause);
            expect(
              tester.getSize(pause).shortestSide,
              greaterThanOrEqualTo(48),
            );
            await tester.tap(pause);
            await tester.pumpAndSettle();
            expect(downloads.paused, ['tablet-download']);
            _expectClean(tester, 'downloads pause action');

            await _navigate(tester, size, 4, '/settings');
            expect(find.byType(SettingsScreen), findsOneWidget);
            final appearance = find.text(_strings.appearance);
            await _reveal(tester, appearance);
            await tester.tap(appearance);
            await tester.pumpAndSettle();
            expect(find.byType(BottomSheet), findsOneWidget);
            expect(find.byType(FilterPickerSheet), findsOneWidget);
            expect(find.byType(Dialog), findsNothing);
            final slider = find.byKey(
              const ValueKey('appearance-text-scale-slider'),
            );
            await _reveal(tester, slider);
            expect(tester.widget<Slider>(slider).value, scale);
            _expectClean(tester, 'touch appearance sheet');
            Navigator.of(tester.element(slider)).pop();
            await tester.pumpAndSettle();

            appRouter.go('/book/${_book.id}');
            await tester.pumpAndSettle();
            expect(find.byType(SavedBookDetailsScreen), findsOneWidget);
            expect(find.text(_book.title), findsWidgets);
            _expectNoTv(tester);
            _expectClean(tester, 'saved book details');

            appRouter.go('/source-book/izib/${_book.sourceBookId}');
            await tester.pumpAndSettle();
            expect(find.byType(SourceBookDetailsScreen), findsOneWidget);
            final download = find.byKey(
              const ValueKey('source-details-download'),
            );
            // At 200% text in a narrow split-screen, the long book header
            // exceeds the viewport/cache extent. Reach the lazily built
            // actions with touch scrolling, not a finder before they exist.
            final detailsScroll = find.descendant(
              of: find.byType(SourceBookDetailsScreen),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
              ),
            );
            expect(detailsScroll, findsOneWidget);
            await tester.scrollUntilVisible(
              download,
              180,
              scrollable: detailsScroll,
              maxScrolls: 20,
            );
            await _reveal(tester, download);
            expect(
              tester.getSize(download).shortestSide,
              greaterThanOrEqualTo(48),
            );
            _expectNoTv(tester);
            _expectClean(tester, 'source book details');

            appRouter.go('/player');
            await tester.pumpAndSettle();
            expect(find.byType(FullPlayerScreen), findsOneWidget);
            final source = find.byKey(
              const ValueKey('mobile-full-player-source'),
            );
            await _reveal(tester, source);
            _expectNoTv(tester);
            expect(
              find.byKey(const ValueKey('windows-player-book-panel')),
              findsNothing,
            );
            _expectClean(tester, 'touch player overview');
            for (var index = 1; index < 4; index++) {
              final pages = find.byType(TabBarView);
              await tester.drag(
                pages,
                Offset(-tester.getSize(pages).width * .8, 0),
              );
              await tester.pumpAndSettle();
              expect(tester.widget<TabBarView>(pages).controller!.index, index);
              _expectClean(tester, 'touch player page $index');
            }
          },
          variant: _android,
        );
      }
    }
  }

  testWidgets(
    'Android tablet resize keeps search state and switches touch navigation only',
    (tester) async {
      await _pumpApp(tester, size: _sizes.first, scale: 2, dark: true);
      await _navigate(tester, _sizes.first, 1, '/search');
      await tester.enterText(find.byType(TextField), 'Белые ночи');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      for (final size in [
        _sizes[1],
        _sizes[3],
        _sizes[2],
        _sizes.last,
        _sizes.first,
      ]) {
        tester.view.physicalSize = size * 2;
        await tester.pumpAndSettle();
        _expectTouchShell(tester, size: size, scale: 2, dark: true);
        expect(appRouter.state.uri.path, '/search');
        expect(find.byType(BookCard), findsWidgets);
        final controller = ProviderScope.containerOf(
          tester.element(find.byType(SlovofonShell)),
        ).read(playbackControllerProvider);
        expect(controller.state.book?.versionId, _book.versionId);
        expect(controller.state.position, const Duration(minutes: 4));
        _expectClean(tester, 'resize $size');
      }
    },
    variant: _android,
  );
}

void _expectNoTv(WidgetTester tester) {
  expect(find.byType(TelevisionShell), findsNothing);
  expect(find.byType(TelevisionStandaloneShell), findsNothing);
  expect(find.byType(TelevisionViewport), findsNothing);
  expect(find.byType(TelevisionBookCard), findsNothing);
  expect(
    find.byKey(const ValueKey('windows-shell-shortcut-focus')),
    findsNothing,
  );
  expect(
    find.byKey(const ValueKey('windows-compact-navigation-rail')),
    findsNothing,
  );
}

void _expectTouchShell(
  WidgetTester tester, {
  required Size size,
  required double scale,
  required bool dark,
}) {
  _expectNoTv(tester);
  final context = tester.element(find.byType(SlovofonShell));
  expect(TelevisionLayout.isActive(context), isFalse);
  expect(DesktopLayout.isActive(context), isFalse);
  expect(MediaQuery.sizeOf(context), size);
  expect(MediaQuery.devicePixelRatioOf(context), 2);
  expect(MediaQuery.textScalerOf(context).scale(16), 16 * scale);
  expect(
    Theme.of(context).brightness,
    dark ? Brightness.dark : Brightness.light,
  );
  expect(
    find.byType(SlovofonBottomNavigationBar),
    size.width < 900 ? findsOneWidget : findsNothing,
  );
  expect(
    find.byType(DesktopMiniPlayerBar),
    size.width >= 900 ? findsOneWidget : findsNothing,
  );
  _expectClean(tester, 'touch shell $size');
}

void _expectClean(WidgetTester tester, String phase) =>
    expect(tester.takeException(), isNull, reason: phase);

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  final center = tester.getCenter(finder);
  final viewport = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect((Offset.zero & viewport).contains(center), isTrue);
}

Future<void> _navigate(
  WidgetTester tester,
  Size size,
  int index,
  String route,
) async {
  final target = find.byKey(
    ValueKey('${size.width >= 900 ? 'wide' : 'mobile'}-navigation-item-$index'),
  );
  await _reveal(tester, target);
  expect(tester.getSize(target).shortestSide, greaterThanOrEqualTo(48));
  await tester.tap(target);
  await tester.pumpAndSettle();
  expect(appRouter.state.uri.path, route);
  _expectClean(tester, 'navigate $route');
}

Future<_Downloads> _pumpApp(
  WidgetTester tester, {
  required Size size,
  required double scale,
  required bool dark,
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = size * 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final settings = AppSettingsStore(MemoryAppSettingsPersistenceStore());
  await settings.load();
  await settings.setLanguageCode('ru');
  await settings.setTextScale(scale);
  await settings.setThemeMode(dark ? AppThemeMode.dark : AppThemeMode.light);
  final library = LibraryStore(MemoryLibraryPersistenceStore());
  await library.load();
  await library.toggleFavorite(libraryCardBook(_book));
  final bookmarks = BookmarkStore(MemoryBookmarkPersistence());
  await bookmarks.load();
  await bookmarks.add(
    book: _book,
    chapterId: _book.chapters.first.id,
    positionMs: 120000,
  );
  final controller = PlaybackController(engine: InMemoryAudioEngine());
  await controller.loadBook(
    _book,
    position: const Duration(minutes: 4),
    autoPlay: false,
  );
  final downloads = _Downloads();
  final history = MemorySearchHistoryStore();
  await history.record('Белые ночи', SearchKind.title);
  appRouter.go('/');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDeviceProfileProvider.overrideWithValue(
          const AppDeviceProfile(isTelevision: false, hasTouchscreen: true),
        ),
        appSettingsStoreProvider.overrideWith((ref) => settings),
        libraryStoreProvider.overrideWith((ref) => library),
        bookmarkStoreProvider.overrideWith((ref) => bookmarks),
        playbackControllerProvider.overrideWith((ref) {
          ref.onDispose(controller.dispose);
          return controller;
        }),
        playbackProgressSnapshotsProvider.overrideWith((ref) async => []),
        libraryPlaybackBooksProvider.overrideWith((ref) async => [_book]),
        downloadManagerProvider.overrideWith((ref) => downloads),
        downloadStorageProvider.overrideWith((ref) => _MemoryStorage()),
        searchHistoryStoreProvider.overrideWith((ref) => history),
        sourceRegistryProvider.overrideWith((ref) => SourceRegistry([])),
        sourceCatalogServiceProvider.overrideWithValue(_Catalog()),
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
  await tester.pumpAndSettle();
  return downloads;
}

class _Downloads extends ChangeNotifier implements DownloadManager {
  final paused = <String>[];
  @override
  List<DownloadTask> get tasks => [
    DownloadTask(
      id: 'tablet-download',
      bookId: _book.id,
      bookVersionId: _book.versionId,
      chapterId: _book.chapters.first.id,
      sourceId: _book.sourceId,
      type: DownloadTaskType.chapter,
      status: paused.isEmpty
          ? DownloadTaskStatus.running
          : DownloadTaskStatus.paused,
      progress: .4,
      downloadedBytes: 4096,
      totalBytes: 10240,
      createdAt: _stamp,
      updatedAt: _stamp,
    ),
  ];
  @override
  DownloadTask? taskById(String taskId) =>
      taskId == 'tablet-download' ? tasks.single : null;
  @override
  AudioPlaybackBook? bookForTask(String taskId) =>
      taskById(taskId) == null ? null : _book;
  @override
  bool taskMatchesBook(DownloadTask task, AudioPlaybackBook book) =>
      task.sourceId == book.sourceId &&
      (task.bookVersionId == book.versionId ||
          (book.sourceBookId != null &&
              task.bookVersionId == book.sourceBookId));
  @override
  DownloadTask? taskForChapter(String chapterId) =>
      chapterId == _book.chapters.first.id ? tasks.single : null;
  @override
  DownloadTask? taskForBookChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) => taskMatchesBook(tasks.single, book) ? taskForChapter(chapter.id) : null;
  @override
  Future<void> loadPersistedTasks({bool recoverInterrupted = true}) async {}
  @override
  void attachBookContext(AudioPlaybackBook book) {}
  @override
  Future<AudioPlaybackBook> offlinePlaybackBook(AudioPlaybackBook book) async =>
      book;
  @override
  Future<void> pause(String taskId) async {
    paused.add(taskId);
    notifyListeners();
  }

  @override
  Future<void> cacheBookMetadata(AudioPlaybackBook book) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected DownloadManager call in tablet fixture: ${invocation.memberName}. '
    'No real download, network or storage fallback is permitted.',
  );
}

class _MemoryStorage extends FileDownloadStorage {
  _MemoryStorage()
    : super(rootDirectory: Directory('unused-tablet-ui-fixture'));
  @override
  Future<List<AudioPlaybackBook>> readAllMetadata() async => [_book];
  @override
  Future<void> writeMetadata(AudioPlaybackBook book) async {}
  @override
  Future<AudioPlaybackBook?> readMetadataForIds(
    String sourceId,
    String versionId,
  ) async => _book;
  @override
  Future<CardCacheStats> cardCacheStats() async =>
      const CardCacheStats(bytes: 4096, bookCount: 1);
}

class _Catalog extends SourceCatalogService {
  _Catalog() : super(registry: SourceRegistry([]));
  @override
  Future<SourceSearchResponse> search(SearchRequest request) async =>
      SourceSearchResponse(
        results: [
          BookSearchResult(
            ref: SourceBookRef(
              sourceId: _book.sourceId,
              sourceBookId: _book.sourceBookId!,
            ),
            sourceName: _book.sourceName,
            title: _book.title,
            author: _book.author,
            narrator: _book.narrator,
            duration: _book.totalDuration,
            chapterCount: _book.chapters.length,
            isFree: true,
            isFull: true,
            accessType: AccessType.free,
          ),
        ],
      );
  @override
  Future<List<BookSearchResult>> findOtherNarrations(
    SourceBookSnapshot snapshot, {
    int limit = 12,
  }) async => [];
  @override
  Future<SourceBookSnapshot> loadBook(
    SourceBookRef ref, {
    bool forceRefresh = false,
    MediaResolvePurpose purpose = MediaResolvePurpose.playback,
  }) async => SourceBookSnapshot(
    details: BookVersionDetails(
      ref: ref,
      version: BookVersion(
        id: _book.versionId,
        bookId: _book.id,
        sourceId: _book.sourceId,
        sourceBookId: _book.sourceBookId!,
        title: _book.title,
        normalizedTitle: _book.title.toLowerCase(),
        authors: [_book.author],
        narrators: [_book.narrator],
        description: _book.description,
        genres: ['Русская классика'],
        durationMs: _book.totalDuration.inMilliseconds,
        canStream: true,
        canDownload: true,
        accessType: AccessType.free,
        createdAt: _stamp,
        updatedAt: _stamp,
      ),
    ),
    chapters: [
      for (final chapter in _book.chapters)
        Chapter(
          id: chapter.id,
          bookVersionId: _book.versionId,
          sourceId: _book.sourceId,
          index: chapter.index,
          title: chapter.title,
          normalizedTitle: chapter.title.toLowerCase(),
          durationMs: chapter.duration.inMilliseconds,
          createdAt: _stamp,
          updatedAt: _stamp,
        ),
    ],
    audioBook: libraryCardBook(_book),
    playbackBook: _book,
  );
}
