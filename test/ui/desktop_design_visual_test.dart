import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/app.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/router.dart';
import 'package:slovofon/data/mock/mock_audio_playback.dart';
import 'package:slovofon/data/mock/stage3_mock_data.dart';
import 'package:slovofon/domain/models/app_settings.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/domain/models/playback_session.dart';
import 'package:slovofon/features/book_details/saved_book_details_screen.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_persistence.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/bookmarks/bookmark_store.dart';
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
import 'package:slovofon/services/updates/update_manifest.dart';
import 'package:slovofon/services/updates/update_service.dart';
import 'package:slovofon/sources/sources.dart';
import 'package:slovofon/ui/motion/motion_controls.dart';
import 'package:slovofon/sources/knigoblud/knigoblud_mapper.dart';
import 'package:slovofon/ui/adaptive/desktop_layout.dart';
import 'package:slovofon/ui/components/book_card.dart';
import 'package:slovofon/ui/components/book_cover.dart';
import 'package:slovofon/ui/components/source_badge.dart';
import 'package:slovofon/ui/icons/app_icons.dart';
import 'package:slovofon/core/platform/app_device_profile.dart';

import 'test_search_history_store.dart';
import 'support/sliver_geometry.dart';
import 'package:slovofon/ui/components/responsive_tile_grid.dart';

/// Opt-in native-Flutter render harness. No production bootstrap, network,
/// platform audio, database, or user folders. Books are local synthetic fixtures.
/// SLOVOFON_VISUAL_DIR must be an explicit absolute evidence directory.
/// Optional SLOVOFON_VISUAL_SIZES: comma-separated logical WxH dimensions.
/// Optional SLOVOFON_VISUAL_DPR: physical pixels per logical pixel (1..4).
/// This changes the simulated display density and PNG resolution, not font size.
/// Optional SLOVOFON_VISUAL_ACCENT: a supported preset or #RRGGBB.
/// Optional SLOVOFON_VISUAL_BOOK_COUNT: first N local mock books (0..all).
/// Optional SLOVOFON_VISUAL_RESIZE_AUDIT=1 enables explicit extra routes,
/// deterministic error/loading/overlay states and viewport-bound diagnostics.
/// Optional SLOVOFON_VISUAL_SEARCH_RESULT_COUNT: generated local results (1..30).
/// SLOVOFON_VISUAL_PAGE_FILTER accepts comma-separated page substrings.
/// Prefix a page with '=' to match exactly (for example '=search').
/// Optional SLOVOFON_VISUAL_APP_SCALES: in-app multipliers, default 1.0.
/// Optional SLOVOFON_VISUAL_SYSTEM_SCALES: platform multipliers, default 1,1.5.
/// Optional SLOVOFON_VISUAL_PLATFORM: windows (default) or android.
/// Optional SLOVOFON_VISUAL_SOURCE_ID: one of the six supported playback sources.
/// Optional SLOVOFON_VISUAL_WORKSPACE=1: deterministic populated download queue,
/// search history, and desktop workspace geometry checks. Defaults stay intact.
/// The appearance sheet is captured only when explicitly requested by filter.
/// saved-details opts into the real saved-metadata route. legacy-details is
/// retained only as an old capture-name alias; neither route renders mock UI.
void main() {
  final output = Platform.environment['SLOVOFON_VISUAL_DIR'];
  final filter = Platform.environment['SLOVOFON_VISUAL_FILTER'] ?? '';
  final pageFilter = Platform.environment['SLOVOFON_VISUAL_PAGE_FILTER'] ?? '';
  final workspace = Platform.environment['SLOVOFON_VISUAL_WORKSPACE'] == '1';
  final television = Platform.environment['SLOVOFON_VISUAL_TELEVISION'] == '1';
  final devicePixelRatio = double.parse(
    Platform.environment['SLOVOFON_VISUAL_DPR'] ?? '1',
  );
  if (!devicePixelRatio.isFinite ||
      devicePixelRatio < 1 ||
      devicePixelRatio > 4) {
    throw ArgumentError.value(devicePixelRatio, 'SLOVOFON_VISUAL_DPR', '1..4');
  }
  final resizeAudit =
      Platform.environment['SLOVOFON_VISUAL_RESIZE_AUDIT'] == '1';
  final searchResultCount = _visualSearchResultCount(
    Platform.environment['SLOVOFON_VISUAL_SEARCH_RESULT_COUNT'],
  );
  final enabled = output != null && output.isNotEmpty;
  final sizes = _visualSizes(Platform.environment['SLOVOFON_VISUAL_SIZES']);
  final appScaleOverride = Platform.environment['SLOVOFON_VISUAL_APP_SCALES'];
  final appScales = _visualScales(
    appScaleOverride,
    name: 'SLOVOFON_VISUAL_APP_SCALES',
    defaults: const [1.0],
    min: AppSettings.minTextScale,
    max: AppSettings.maxTextScale,
  );
  final systemScales = _visualScales(
    Platform.environment['SLOVOFON_VISUAL_SYSTEM_SCALES'],
    name: 'SLOVOFON_VISUAL_SYSTEM_SCALES',
    defaults: const [1.0, 1.5],
  );
  final platform = _visualPlatform(
    Platform.environment['SLOVOFON_VISUAL_PLATFORM'],
  );
  final sourceOverride = _visualSourceId(
    Platform.environment['SLOVOFON_VISUAL_SOURCE_ID'],
  );
  final fixtureBookCount = _visualBookCount(
    Platform.environment['SLOVOFON_VISUAL_BOOK_COUNT'],
  );
  final fixtureBooks = stage3MockBooks.take(fixtureBookCount).toList();
  final pageFilters = pageFilter
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
  bool explicitlyRequested(String page) =>
      pageFilters.contains(page) || pageFilters.contains('=$page');
  setUpAll(() async {
    if (!enabled) return;
    // Golden tests use Ahem by default. Load installed Windows UI glyphs under
    // the actual/default family names to obtain readable desktop renders.
    for (final family in ['Segoe UI', 'Roboto', 'Ahem']) {
      final loader = FontLoader(family);
      for (final path in [
        r'C:\Windows\Fonts\segoeui.ttf',
        if (family == 'Segoe UI') r'C:\Windows\Fonts\seguisb.ttf',
        r'C:\Windows\Fonts\segoeuib.ttf',
      ]) {
        loader.addFont(
          File(path).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      }
      await loader.load();
    }
    final editorialFont = FontLoader('Georgia');
    for (final path in [
      r'C:\Windows\Fonts\georgia.ttf',
      r'C:\Windows\Fonts\georgiab.ttf',
    ]) {
      editorialFont.addFont(
        File(path).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    }
    await editorialFont.load();
    if (workspace) {
      // ExpansionTile uses the bundled Material icon font, unlike AppIcon SVGs.
      // Flutter's test binding does not load that font automatically.
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
    Directory(output).createSync(recursive: true);
  });

  for (final dark in [true, false]) {
    for (final size in sizes) {
      for (final textScale in systemScales) {
        for (final appScale in appScales) {
          final variant =
              '${platform == TargetPlatform.windows ? '' : '${platform.name}-'}${dark ? 'dark' : 'light'}-${size.width.toInt()}x${size.height.toInt()}-scale$textScale${appScaleOverride == null || appScaleOverride.trim().isEmpty ? '' : '-app$appScale'}${sourceOverride == null ? '' : '-source$sourceOverride'}';
          testWidgets(
            '${platform.name} visual $variant',
            (tester) async {
              debugDefaultTargetPlatformOverride = platform;
              addTearDown(() => debugDefaultTargetPlatformOverride = null);
              tester.view.physicalSize = size * devicePixelRatio;
              tester.view.devicePixelRatio = devicePixelRatio;
              tester.platformDispatcher.textScaleFactorTestValue = textScale;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue,
              );
              final books = fixtureBooks.map(mockAudioPlaybackBook).toList();
              if (sourceOverride != null && books.isNotEmpty) {
                books[0] = _withVisualSource(books[0], sourceOverride);
              }
              final storage = _VisualStorage(
                books,
                Directory('$output/fixture-storage'),
              );
              final persistence = _VisualPlaybackPersistence(books);
              final controller = PlaybackController(
                engine: InMemoryAudioEngine(),
              );
              if (books.isNotEmpty) {
                await controller.loadBook(
                  books.first,
                  chapterIndex: mockCurrentChapterIndex(activeMockBook),
                  position: mockCurrentChapterPosition(activeMockBook),
                  autoPlay: false,
                );
              }
              final settings = AppSettingsStore(
                MemoryAppSettingsPersistenceStore(),
              );
              await settings.load();
              await settings.setLanguageCode('ru');
              await settings.setThemeMode(
                dark ? AppThemeMode.dark : AppThemeMode.light,
              );
              await settings.setTextScale(appScale);
              final visualAccent =
                  Platform.environment['SLOVOFON_VISUAL_ACCENT'];
              if (visualAccent != null) {
                await settings.setAccentColor(
                  visualAccent.startsWith('#')
                      ? 'custom:$visualAccent'
                      : visualAccent,
                );
              }
              var libraryClockTick = 0;
              final library = LibraryStore(
                MemoryLibraryPersistenceStore(),
                clock: () => DateTime.utc(2026, 9, 1, libraryClockTick++),
              );
              await library.load();
              for (final book in fixtureBooks) {
                await library.toggleFavorite(book.toAudioBook());
              }
              var bookmarkClockTick = 0;
              final bookmarks = BookmarkStore(
                MemoryBookmarkPersistence(),
                clock: () => DateTime.utc(2026, 9, 1, bookmarkClockTick++),
              );
              await bookmarks.load();
              await _setVisualBookmarks(bookmarks, books, empty: false);
              final searchHistory = MemorySearchHistoryStore();
              if (workspace) {
                await searchHistory.record('Мастер', SearchKind.title);
                await searchHistory.record(
                  'Михаил Булгаков',
                  SearchKind.author,
                );
                await searchHistory.record('Классика', SearchKind.genre);
              }
              final fixtureDownloads = workspace
                  ? _WorkspaceDownloads(books: books, storage: storage)
                  : null;
              final registry = SourceRegistry([
                for (final id
                    in stage3MockBooks.map((book) => book.sourceId).toSet())
                  MockSourceConnector(
                    id: id,
                    name: id,
                    host: 'fixture.$id.invalid',
                    color: '#516AA4',
                    clock: () => DateTime.utc(2026, 9, 1),
                  ),
              ]);
              final resizeCatalog = resizeAudit
                  ? _ResizeVisualCatalog(
                      registry: registry,
                      resultCount: searchResultCount ?? 15,
                    )
                  : null;
              final resizeUpdates = resizeAudit ? _ResizeVisualUpdates() : null;
              final boundaryKey = GlobalKey();
              final visualErrors = <String>[];
              appRouter.go('/');
              await tester.pumpWidget(
                ProviderScope(
                  overrides: [
                    appDeviceProfileProvider.overrideWithValue(
                      AppDeviceProfile(isTelevision: television),
                    ),
                    playbackControllerProvider.overrideWith((ref) {
                      ref.onDispose(controller.dispose);
                      return controller;
                    }),
                    playbackPersistenceStoreProvider.overrideWithValue(
                      persistence,
                    ),
                    downloadStorageProvider.overrideWithValue(storage),
                    if (fixtureDownloads != null)
                      downloadManagerProvider.overrideWith(
                        (ref) => fixtureDownloads,
                      ),
                    libraryStoreProvider.overrideWith((ref) => library),
                    bookmarkStoreProvider.overrideWith((ref) => bookmarks),
                    appSettingsStoreProvider.overrideWith((ref) => settings),
                    sourceRegistryProvider.overrideWithValue(registry),
                    if (resizeCatalog != null)
                      sourceCatalogServiceProvider.overrideWithValue(
                        resizeCatalog,
                      )
                    else if (explicitlyRequested('other-narrations'))
                      sourceCatalogServiceProvider.overrideWith(
                        (ref) => _VisualNarrationService(registry: registry),
                      )
                    else if (searchResultCount != null)
                      sourceCatalogServiceProvider.overrideWith(
                        (ref) => _VisualSearchCatalog(
                          registry: registry,
                          resultCount: searchResultCount,
                        ),
                      ),
                    searchHistoryStoreProvider.overrideWith(
                      (ref) => searchHistory,
                    ),
                    updateServiceProvider.overrideWithValue(
                      resizeUpdates ??
                          UpdateService(
                            client: const _NoNetworkUpdateClient(),
                            installer: PlatformUpdateInstaller(),
                            runtimePlatform: UpdateRuntimePlatform.unsupported,
                          ),
                    ),
                  ],
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: const SlovofonApp(),
                  ),
                ),
              );
              for (final page in <String, String>{
                'home': '/',
                'library': '/library',
                'search': '/search?reset=visual',
                'search-results': Uri(
                  path: '/search',
                  queryParameters: {'q': 'Мастер', 'run': '1'},
                ).toString(),
                'downloads': '/downloads',
                'settings': '/settings',
                'player': '/player',
                'source-details':
                    '/source-book/${activeMockBook.sourceId}/${Uri.encodeComponent(activeMockBook.id)}',
                'legacy-details': '/book/${activeMockBook.id}',
                if (explicitlyRequested('saved-details'))
                  'saved-details': '/book/${activeMockBook.id}',
                if (explicitlyRequested('appearance'))
                  'appearance': '/settings',
                if (explicitlyRequested('player-information'))
                  'player-information': '/player?tab=information',
                if (resizeAudit) ..._resizeVisualRoutes,
                if (explicitlyRequested('other-narrations'))
                  'other-narrations':
                      '/source-book/${activeMockBook.sourceId}/${Uri.encodeComponent(activeMockBook.id)}',
              }.entries) {
                if (pageFilters.isNotEmpty &&
                    !pageFilters.any(
                      (filter) => filter.startsWith('=')
                          ? page.key == filter.substring(1)
                          : page.key.contains(filter),
                    )) {
                  continue;
                }
                if (resizeAudit || page.key == 'player-information') {
                  // This screen consumes initialTabIndex in initState. Leave
                  // the previous player route before testing its Info entry.
                  appRouter.go('/');
                  await tester.pump();
                }
                resizeCatalog?.page = page.key;
                resizeUpdates?.page = page.key;
                await _setVisualBookmarks(
                  bookmarks,
                  books,
                  empty: page.key == 'player-bookmarks-empty',
                );
                appRouter.go(page.value);
                for (var frame = 0; frame < 25; frame++) {
                  await tester.pump(const Duration(milliseconds: 50));
                }
                final strings = AppStrings.of(
                  tester.element(find.byType(Navigator).first),
                );
                if (resizeAudit) {
                  await _prepareResizeVisualPage(tester, page.key, strings);
                }
                if (page.key == 'appearance' ||
                    page.key == 'appearance-scrolled') {
                  final inlineDesktop = platform == TargetPlatform.windows;
                  if (!inlineDesktop) {
                    await tester.tap(find.text(strings.appearance));
                    for (var frame = 0; frame < 15; frame++) {
                      await tester.pump(const Duration(milliseconds: 50));
                    }
                  }
                  final slider = find.byKey(
                    const ValueKey('appearance-text-scale-slider'),
                  );
                  await Scrollable.ensureVisible(
                    tester.element(slider),
                    alignment: 0.25,
                  );
                  await tester.pump();
                }
                if (page.key == 'other-narrations') {
                  final heading = find.text(strings.otherNarrations);
                  // The details ListView mounts its trailing section lazily.
                  // Scroll the outer viewport before resolving the heading.
                  final details = find.byKey(
                    const ValueKey('desktop-source-details-content'),
                  );
                  final scrollable = details.evaluate().isEmpty
                      ? find.byType(Scrollable).first
                      : find
                            .descendant(
                              of: details,
                              matching: find.byType(Scrollable),
                            )
                            .first;
                  await tester.scrollUntilVisible(
                    heading,
                    300,
                    scrollable: scrollable,
                  );
                  await Scrollable.ensureVisible(
                    tester.element(heading),
                    alignment: 0.15,
                  );
                  await tester.pump();
                }
                final lazyDetailsCheck =
                    resizeAudit &&
                        const {
                          'source-details',
                          'legacy-details',
                          'saved-details',
                        }.contains(page.key)
                    ? await _probeResizeDetails(tester)
                    : null;
                final bookmarkReachability = page.key == 'player-bookmarks'
                    ? await _probeVisualBookmarks(tester, bookmarks.entries)
                    : null;
                final lazySearchCheck =
                    resizeAudit &&
                        page.key == 'search-results' &&
                        find
                            .byKey(const ValueKey('desktop-search-primary'))
                            .evaluate()
                            .isEmpty
                    ? await _probeResizeSearch(
                        tester,
                        size,
                        appScale,
                        searchResultCount ?? 15,
                      )
                    : null;
                final lazyDownloadChecks =
                    workspace &&
                        platform == TargetPlatform.windows &&
                        page.key == 'downloads' &&
                        _visualDownloadRows().evaluate().isEmpty
                    ? await _probeVisualDownloads(tester, size, appScale, books)
                    : null;
                final errors = <String>[];
                for (
                  Object? error = tester.takeException();
                  error != null;
                  error = tester.takeException()
                ) {
                  errors.add(error.toString());
                }
                final routeChecks = <Map<String, Object>>[];
                if (page.key == 'saved-details' ||
                    page.key == 'legacy-details') {
                  final saved = find.byType(SavedBookDetailsScreen);
                  final expected = books
                      .where((book) => book.id == activeMockBook.id)
                      .firstOrNull;
                  routeChecks.add({
                    'name':
                        'production book route resolves the requested saved identity',
                    'passed':
                        saved.evaluate().length == 1 &&
                        tester.widget<SavedBookDetailsScreen>(saved).bookId ==
                            activeMockBook.id,
                    'requestedBookId': activeMockBook.id,
                  });
                  final title = find.byKey(const ValueKey('saved-book-title'));
                  routeChecks.add({
                    'name':
                        'saved details use fixture metadata or a genuine missing state',
                    'passed': expected == null
                        ? find
                                  .byKey(const ValueKey('saved-book-not-found'))
                                  .evaluate()
                                  .length ==
                              1
                        : title.evaluate().length == 1 &&
                              tester.widget<Text>(title).data == expected.title,
                    'expectedTitle': expected?.title ?? '',
                  });
                }
                final cardBounds = [
                  for (final card in tester.widgetList<BookCard>(
                    find.byType(BookCard),
                  ))
                    _cardEvidence(tester, card, size),
                ];
                final playerSources = [
                  for (final key in [
                    'windows-dock-source',
                    'windows-full-player-source',
                    'mobile-player-source',
                    'wide-player-source',
                    'mobile-full-player-source',
                    'full-player-info-source',
                    'windows-compact-player-book-source',
                  ])
                    if (find.byKey(ValueKey(key)).evaluate().isNotEmpty)
                      _labelEvidence(tester, key),
                ];
                final expectedSource = controller.state.book == null
                    ? null
                    : {
                        'id': controller.state.book!.sourceId,
                        'name': strings.sourceDisplayName(
                          controller.state.book!.sourceId,
                        ),
                        'color': _colorHex(
                          sourceColorForId(
                            controller.state.book!.sourceId,
                            Theme.of(
                              tester.element(find.byType(Scaffold).last),
                            ).colorScheme,
                          ),
                        ),
                      };
                final sourceIconCount = find
                    .byWidgetPredicate(
                      (widget) =>
                          widget is AppIcon &&
                          widget.asset == AppIconAssets.bookSource,
                    )
                    .evaluate()
                    .length;
                final narrationRows = [
                  for (final card in tester.widgetList<Card>(
                    find.byWidgetPredicate(
                      (widget) =>
                          widget is Card &&
                          widget.key is ValueKey<String> &&
                          (widget.key! as ValueKey<String>).value.startsWith(
                            'other-narration-',
                          ),
                    ),
                  ))
                    _labelEvidence(
                      tester,
                      (card.key! as ValueKey<String>).value,
                    ),
                ];
                final textProbes = <String, Object>{
                  'coverPercentBadges':
                      _paragraphEvidence(tester, find.byType(BookCover))
                          .where(
                            (p) => RegExp(
                              r'^\d{1,3}%$',
                            ).hasMatch(p['text']! as String),
                          )
                          .toList(),
                  for (final label in [
                    strings.home,
                    strings.search,
                    strings.library,
                    strings.downloads,
                    strings.bookDetails,
                    strings.themePreview,
                    strings.continueListening,
                    strings.fullPlayer,
                    strings.settings,
                    activeMockBook.title,
                    strings.textSizeLabel((appScale * 100).round()),
                  ])
                    if (find.text(label).evaluate().isNotEmpty)
                      label: _paragraphEvidence(tester, find.text(label)),
                  if (find
                      .byKey(const ValueKey('appearance-text-scale-preview'))
                      .evaluate()
                      .isNotEmpty)
                    'appearancePreview': _labelEvidence(
                      tester,
                      'appearance-text-scale-preview',
                    ),
                };
                final workspaceGeometry = workspace
                    ? _workspaceGeometry(tester, size)
                    : const <Map<String, Object>>[];
                final workspaceChecks = workspace
                    ? lazyDownloadChecks ??
                          _workspaceChecks(
                            tester,
                            page.key,
                            size,
                            appScale,
                            expectedSearchResults:
                                searchResultCount ?? (resizeAudit ? 15 : null),
                          )
                    : const <Map<String, Object>>[];
                final resizeChecks = resizeAudit
                    ? _resizeVisualChecks(
                        tester,
                        page.key,
                        size,
                        books.length,
                        bookmarks.entries,
                      )
                    : const <Map<String, Object>>[];
                if (lazyDetailsCheck != null) {
                  resizeChecks.add(lazyDetailsCheck);
                }
                if (lazySearchCheck != null) {
                  resizeChecks.add(lazySearchCheck);
                }
                if (bookmarkReachability != null) {
                  resizeChecks.add(bookmarkReachability);
                }
                await tester.runAsync(() async {
                  final boundary =
                      boundaryKey.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary;
                  final rendered = await boundary.toImage(
                    pixelRatio: devicePixelRatio,
                  );
                  final data = await rendered.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await File(
                    '$output/${page.key}-$variant.png',
                  ).writeAsBytes(data!.buffer.asUint8List());
                  rendered.dispose();
                  await File(
                    '$output/${page.key}-$variant.qa.txt',
                  ).writeAsString(
                    '$platform; ${size.width}x${size.height}; system textScale=$textScale; app textScale=$appScale; $fixtureBookCount synthetic fixture books; Flutter-rendered app content, not native-window capture.\n${errors.isEmpty ? 'No Flutter exceptions.' : errors.join('\n\n')}\nMounted BookCard bounds (logical pixels): ${jsonEncode(cardBounds)}\nPlayer source labels: ${jsonEncode(playerSources)}\nText probes: ${jsonEncode(textProbes)}\n',
                  );
                  await File(
                    '$output/${page.key}-$variant.qa.json',
                  ).writeAsString(
                    const JsonEncoder.withIndent('  ').convert({
                      'page': page.key,
                      'theme': dark ? 'dark' : 'light',
                      'viewport': {'width': size.width, 'height': size.height},
                      'devicePixelRatio': devicePixelRatio,
                      'physicalViewport': {
                        'width': size.width * devicePixelRatio,
                        'height': size.height * devicePixelRatio,
                      },
                      'systemTextScale': textScale,
                      'appTextScale': appScale,
                      'accent': settings.settings.accentColor,
                      'platform': platform.name,
                      'isTelevision': television,
                      'fixtureBookCount': fixtureBookCount,
                      'fixtureBookmarkCount': bookmarks.entries.length,
                      'fixtureBookmarks': [
                        for (final bookmark in bookmarks.entries)
                          {
                            'bookVersionId': bookmark.bookVersionId,
                            'chapterId': bookmark.chapterId,
                            'positionMs': bookmark.positionMs,
                            'title': bookmark.title,
                            'note': bookmark.note,
                          },
                      ],
                      if (page.key == 'search-results' &&
                          searchResultCount != null)
                        'fixtureSearchResultCount': searchResultCount,
                      'render':
                          'Flutter app content, not native-window capture',
                      'errors': errors,
                      if (routeChecks.isNotEmpty) 'routeChecks': routeChecks,
                      if (resizeAudit) ...{
                        'resizeChecks': resizeChecks,
                        'scrollSurfaces': _visualScrollEvidence(tester),
                        'modalParagraphs': _paragraphEvidence(
                          tester,
                          find.byType(Dialog),
                        ),
                        'route': page.value,
                        'fixtureState': resizeCatalog!.page,
                        'selectedShelf': page.key.startsWith('library-')
                            ? page.key.substring(8)
                            : null,
                      },
                      'mountedBookCards': cardBounds,
                      'playerSourceLabels': playerSources,
                      'expectedPlaybackSource': expectedSource,
                      'sourceIconCount': sourceIconCount,
                      'otherNarrationRows': narrationRows,
                      'textProbes': textProbes,
                      if (workspace) ...{
                        if (lazyDownloadChecks != null)
                          'workspaceCheckPhase':
                              'Real lazy download rows checked after scroll; initial offset restored for PNG.',
                        'workspaceGeometry': workspaceGeometry,
                        'workspaceChecks': workspaceChecks,
                        'fixtureLibraryBookCount': library.entries.length,
                        'fixtureMetadataBookCount': books.length,
                        'fixtureProgressBookCount':
                            (await persistence.loadProgress()).length,
                        'fixtureDownloadTasks': [
                          for (final task in fixtureDownloads!.tasks)
                            {
                              'bookVersionId': task.bookVersionId,
                              'chapterId': task.chapterId,
                              'status': task.status.name,
                              'progress': task.progress,
                            },
                        ],
                      },
                    }),
                  );
                });
                // Baseline diagnostics are captured, not hidden by a failed early
                // assertion. Final review reads every .qa.txt and screenshot.
                if (errors.isNotEmpty) {
                  visualErrors.add(
                    '${page.key} $variant: ${errors.join('\n')}',
                  );
                  debugPrint('VISUAL_ERRORS ${page.key} $variant: $errors');
                }
                for (final check in [
                  ...workspaceChecks,
                  ...resizeChecks,
                  ...routeChecks,
                ]) {
                  if (check['passed'] != true) {
                    visualErrors.add('${page.key} $variant: $check');
                  }
                }
                if (resizeAudit) {
                  await _closeResizeVisualOverlays(tester);
                }
                if (page.key == 'appearance' &&
                    platform != TargetPlatform.windows) {
                  appRouter.pop();
                  await tester.pump(const Duration(milliseconds: 500));
                }
              }
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump();
              // Flutter checks this before test tearDown callbacks execute.
              debugDefaultTargetPlatformOverride = null;
              expect(visualErrors, isEmpty, reason: visualErrors.join('\n\n'));
            },
            skip: !enabled || (filter.isNotEmpty && !variant.contains(filter)),
          );
        }
      }
    }
  }
}

List<double> _visualScales(
  String? override, {
  required String name,
  required List<double> defaults,
  double min = 0.1,
  double max = 4.0,
}) {
  if (override == null || override.trim().isEmpty) {
    return defaults;
  }
  return override.split(',').map((raw) {
    final value = double.tryParse(raw.trim());
    if (value == null || !value.isFinite || value < min || value > max) {
      throw ArgumentError(
        '$name must contain multipliers between $min and $max.',
      );
    }
    return value;
  }).toList();
}

TargetPlatform _visualPlatform(String? override) {
  return switch (override?.trim().toLowerCase()) {
    null || '' || 'windows' => TargetPlatform.windows,
    'android' => TargetPlatform.android,
    _ => throw ArgumentError(
      'SLOVOFON_VISUAL_PLATFORM must be windows or android.',
    ),
  };
}

String? _visualSourceId(String? override) {
  if (override == null || override.trim().isEmpty) {
    return null;
  }
  final id = override.trim().toLowerCase();
  if (!const {
    'izib',
    'akniga',
    'yakniga',
    'knigavuhe',
    'knigoblud',
    'baza_knig',
  }.contains(id)) {
    throw ArgumentError(
      'SLOVOFON_VISUAL_SOURCE_ID must name a supported source.',
    );
  }
  return id;
}

AudioPlaybackBook _withVisualSource(AudioPlaybackBook book, String sourceId) =>
    AudioPlaybackBook(
      id: book.id,
      versionId: '${book.id}-$sourceId',
      sourceId: sourceId,
      sourceName: sourceId,
      sourceBookId: book.sourceBookId,
      sourceUrl: book.sourceUrl,
      coverUrl: book.coverUrl,
      title: book.title,
      author: book.author,
      narrator: book.narrator,
      chapters: book.chapters,
      genre: book.genre,
      description: book.description,
      seriesTitle: book.seriesTitle,
      seriesNumber: book.seriesNumber,
      ratingValue: book.ratingValue,
      ratingCount: book.ratingCount,
      publishedYear: book.publishedYear,
      isFragment: book.isFragment,
    );

String? _colorHex(Color? color) => color == null
    ? null
    : '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';

List<Size> _visualSizes(String? override) {
  if (override == null || override.trim().isEmpty) {
    return const [Size(1440, 900), Size(900, 700)];
  }
  return override.split(',').map((value) {
    final match = RegExp(r'^(\d+)\s*[xX]\s*(\d+)$').firstMatch(value.trim());
    if (match == null) {
      throw ArgumentError('SLOVOFON_VISUAL_SIZES expects WxH,WxH dimensions.');
    }
    final width = double.parse(match.group(1)!);
    final height = double.parse(match.group(2)!);
    if (width <= 0 || height <= 0) {
      throw ArgumentError('SLOVOFON_VISUAL_SIZES dimensions must be positive.');
    }
    return Size(width, height);
  }).toList();
}

int _visualBookCount(String? override) {
  if (override == null || override.trim().isEmpty) {
    return stage3MockBooks.length;
  }
  final count = int.tryParse(override.trim());
  if (count == null || count < 0 || count > stage3MockBooks.length) {
    throw ArgumentError(
      'SLOVOFON_VISUAL_BOOK_COUNT must be 0..${stage3MockBooks.length}.',
    );
  }
  return count;
}

int? _visualSearchResultCount(String? override) {
  if (override == null || override.trim().isEmpty) {
    return null;
  }
  final count = int.tryParse(override.trim());
  if (count == null || count < 1 || count > 30) {
    throw ArgumentError('SLOVOFON_VISUAL_SEARCH_RESULT_COUNT must be 1..30.');
  }
  return count;
}

Map<String, Object> _cardEvidence(
  WidgetTester tester,
  BookCard card,
  Size viewport,
) {
  final bounds = tester.getRect(find.byWidget(card));
  return {
    'bookId': card.book.id,
    'sourceId': card.book.sourceId,
    'left': bounds.left,
    'top': bounds.top,
    'width': bounds.width,
    'height': bounds.height,
    'intersectsViewport': bounds.overlaps(Offset.zero & viewport),
    'metadataFooter': {
      for (final key in ['book-card-footer-source', 'book-card-footer-percent'])
        key: _paragraphEvidence(
          tester,
          find.descendant(
            of: find.byWidget(card),
            matching: find.byKey(ValueKey(key)),
          ),
        ),
    },
  };
}

Map<String, Object> _labelEvidence(WidgetTester tester, String key) {
  final finder = find.byKey(ValueKey(key));
  final bounds = tester.getRect(finder);
  final widget = tester.widget(finder);
  final texts = widget is Text
      ? [widget]
      : tester.widgetList<Text>(
          find.descendant(of: finder, matching: find.byType(Text)),
        );
  return {
    'key': key,
    'text': texts
        .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
        .join(' '),
    'left': bounds.left,
    'top': bounds.top,
    'width': bounds.width,
    'height': bounds.height,
    'paragraphs': _paragraphEvidence(tester, finder),
    'iconAssets': tester
        .widgetList<AppIcon>(
          find.descendant(of: finder, matching: find.byType(AppIcon)),
        )
        .map((icon) => icon.asset)
        .toList(),
  };
}

List<Map<String, Object?>> _paragraphEvidence(
  WidgetTester tester,
  Finder finder,
) => [
  for (final element
      in find
          .descendant(of: finder, matching: find.byType(RichText))
          .evaluate())
    if (element.renderObject case final RenderParagraph paragraph)
      {
        'text': paragraph.text.toPlainText(),
        'baseFontSize': paragraph.text.style?.fontSize,
        'fontFamily': paragraph.text.style?.fontFamily,
        'scaledFontSize': paragraph.text.style?.fontSize == null
            ? null
            : paragraph.textScaler.scale(paragraph.text.style!.fontSize!),
        'color': _colorHex(paragraph.text.style?.color),
        'left': paragraph.localToGlobal(Offset.zero).dx,
        'top': paragraph.localToGlobal(Offset.zero).dy,
        'width': paragraph.size.width,
        'height': paragraph.size.height,
        'maxLines': paragraph.maxLines,
        'didExceedMaxLines': paragraph.didExceedMaxLines,
        'selectionLineCount': paragraph
            .getBoxesForSelection(
              TextSelection(
                baseOffset: 0,
                extentOffset: paragraph.text.toPlainText().length,
              ),
            )
            .map((box) => box.top)
            .toSet()
            .length,
      },
];

class _NoNetworkUpdateClient extends UpdateClient {
  const _NoNetworkUpdateClient();
  @override
  Future<UpdateManifest> fetchManifest(Uri uri) async =>
      UpdateManifest.fromJson({'status': 'no_release'});
}

List<Map<String, Object>> _workspaceGeometry(WidgetTester tester, Size size) =>
    [
      for (final element in find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            (key.value.startsWith('desktop-') ||
                key.value.startsWith('windows-') ||
                key.value.startsWith('workspace-') ||
                key.value.startsWith('settings-') ||
                key.value.startsWith('appearance-') ||
                key.value.startsWith('library-book-') ||
                key.value.startsWith('home-history-') ||
                key.value.startsWith('source-details-') ||
                key.value.startsWith('saved-book-') ||
                key.value.startsWith('book-card-'));
      }).evaluate())
        if (_workspaceRenderBounds(element.findRenderObject())
            case final Rect bounds)
          {
            'key': (element.widget.key! as ValueKey<String>).value,
            'renderType': element.findRenderObject().runtimeType.toString(),
            'left': bounds.left,
            'top': bounds.top,
            'width': bounds.width,
            'height': bounds.height,
            'visible': bounds.overlaps(Offset.zero & size),
          },
    ];

Rect? _workspaceRenderBounds(RenderObject? render) =>
    scrollContentBounds(render);

List<Map<String, Object>> _workspaceChecks(
  WidgetTester tester,
  String page,
  Size size,
  double appScale, {
  int? expectedSearchResults,
}) {
  if (Theme.of(tester.element(find.byType(Scaffold).last)).platform !=
      TargetPlatform.windows) {
    return [];
  }
  final checks = <Map<String, Object>>[];
  Rect? keyedRect(String key) {
    final finder = find.byKey(ValueKey(key), skipOffstage: false);
    return finder.evaluate().length == 1
        ? _workspaceRenderBounds(tester.element(finder).findRenderObject())
        : null;
  }

  void check(
    String name,
    bool passed, [
    Map<String, Object> evidence = const {},
  ]) {
    checks.add({'name': name, 'passed': passed, ...evidence});
  }

  final frame = find.byKey(const ValueKey('desktop-content-frame'));
  final sidebar =
      find
          .byKey(const ValueKey('desktop-navigation-sidebar'))
          .evaluate()
          .isNotEmpty
      ? find.byKey(const ValueKey('desktop-navigation-sidebar'))
      : find.byKey(const ValueKey('windows-compact-navigation-rail'));
  double? pageWidth;
  if (frame.evaluate().isNotEmpty) {
    final exists =
        frame.evaluate().length == 1 && sidebar.evaluate().length == 1;
    checks.add({'name': 'workspace shell is mounted', 'passed': exists});
    if (exists) {
      final content = tester.getRect(frame);
      final navigation = tester.getRect(sidebar);
      pageWidth = content.width - (size.width < 900 ? 32 : 64);
      checks.add({
        'name': 'workspace consumes window width after sidebar',
        'passed':
            (content.right - size.width).abs() <= 1 &&
            (content.left - navigation.right - 1).abs() <= 1,
        'actualLeft': content.left,
        'actualRight': content.right,
        'expectedLeft': navigation.right + 1,
        'expectedRight': size.width,
      });
    }
  }
  void checkPanes(String workspaceKey, String primaryKey, String secondaryKey) {
    final primary = keyedRect(primaryKey);
    final secondary = keyedRect(secondaryKey);
    check(
      'primary and contextual secondary are mounted',
      primary != null && secondary != null,
    );
    if (primary == null || secondary == null || pageWidth == null) return;
    final combined = primary.expandToInclude(secondary);
    check(
      'semantic workspace spans available width',
      combined.width >= pageWidth * 0.95,
      {'actualWidth': combined.width, 'availableWidth': pageWidth},
    );
    final workspaceFinder = find.byKey(
      ValueKey(workspaceKey),
      skipOffstage: false,
    );
    final workspaceWidget = tester.widget(workspaceFinder);
    final (
      minimumPrimaryWidth,
      secondaryWidth,
      gap,
    ) = switch (workspaceWidget) {
      DesktopWorkspaceColumns value => (
        value.minimumPrimaryWidth,
        value.secondaryWidth,
        value.gap,
      ),
      SliverWorkspaceColumns value => (
        value.minimumPrimaryWidth,
        value.secondaryWidth,
        value.gap,
      ),
      _ => throw StateError(
        'Unexpected workspace ${workspaceWidget.runtimeType}',
      ),
    };
    final factor = DesktopLayout.workspaceScaleFactor(
      tester.element(workspaceFinder),
    );
    final available = scrollContentRect(tester, workspaceFinder).width;
    final minimumSplitWidth =
        (minimumPrimaryWidth + secondaryWidth) * factor + gap;
    if (available >= minimumSplitWidth) {
      check(
        'context occupies right side when both readable columns fit',
        (primary.top - secondary.top).abs() <= 6 &&
            secondary.left >= primary.right &&
            secondary.right >= size.width - 38,
        {
          'primaryRight': primary.right,
          'secondaryLeft': secondary.left,
          'secondaryRight': secondary.right,
        },
      );
    } else {
      check(
        'stacked context follows primary and both retain full width',
        secondary.top >= primary.bottom + gap - 1 &&
            (secondary.left - primary.left).abs() <= 2 &&
            (primary.width - available).abs() <= 2 &&
            (secondary.width - available).abs() <= 2,
        {
          'primaryBottom': primary.bottom,
          'secondaryTop': secondary.top,
          'primaryWidth': primary.width,
          'secondaryWidth': secondary.width,
          'availableWidth': available,
          'minimumSplitWidth': minimumSplitWidth,
        },
      );
    }
  }

  if (page == 'home') {
    check(
      'home does not reintroduce the rejected find-next block',
      find.byKey(const ValueKey('desktop-home-find-next')).evaluate().isEmpty,
    );
    checkPanes(
      'desktop-home-workspace',
      'desktop-home-feature',
      'desktop-home-chapter-rail',
    );
  }
  if (page == 'search' || page == 'search-results') {
    final controls = keyedRect('desktop-search-controls');
    final context = keyedRect('desktop-search-secondary');
    check(
      'search controls use the full page width before all other content',
      controls != null &&
          pageWidth != null &&
          (controls.width - pageWidth).abs() <= 2,
    );
    if (page == 'search') {
      check(
        'empty search context follows controls immediately without placeholder',
        controls != null &&
            context != null &&
            (context.top - controls.bottom - 24).abs() <= 2 &&
            (context.width - controls.width).abs() <= 2 &&
            find
                .byKey(const ValueKey('desktop-search-primary'))
                .evaluate()
                .isEmpty,
      );
      final history = keyedRect('desktop-search-history');
      final sources = keyedRect('desktop-search-sources');
      check(
        'empty search history and sources exist',
        history != null && sources != null,
      );
      if (history != null && sources != null && context != null) {
        final factor = DesktopLayout.workspaceScaleFactor(
          tester.element(
            find.byKey(const ValueKey('desktop-search-secondary')),
          ),
        );
        final split = context.width >= 720 * factor + 24;
        check(
          'empty search uses readable equal context columns or ordered stacking',
          split
              ? (history.top - sources.top).abs() <= 2 &&
                    (sources.left - history.right - 24).abs() <= 2 &&
                    (history.width - sources.width).abs() <= 2
              : (sources.top - history.bottom - 24).abs() <= 2 &&
                    (history.width - context.width).abs() <= 2 &&
                    (sources.width - context.width).abs() <= 2,
          {'split': split, 'contextWidth': context.width},
        );
      }
    } else {
      checkPanes(
        'desktop-search-workspace',
        'desktop-search-primary',
        'desktop-search-secondary',
      );
      final primary = keyedRect('desktop-search-primary');
      check(
        'results start directly below full-width controls',
        primary != null &&
            controls != null &&
            (primary.top - controls.bottom - 12).abs() <= 2,
      );
      final cards = [
        for (final element
            in find
                .descendant(
                  of: find.byKey(
                    const ValueKey('desktop-search-primary'),
                    skipOffstage: false,
                  ),
                  matching: find.byType(BookCard, skipOffstage: false),
                  skipOffstage: false,
                )
                .evaluate())
          _workspaceRenderBounds(element.findRenderObject())!,
      ];
      if (expectedSearchResults != null) {
        check(
          'all synthetic search results are delivered to the UI',
          tester
                  .widgetList<SliverResponsiveTileGrid>(
                    find.descendant(
                      of: find.byKey(
                        const ValueKey('desktop-search-primary'),
                        skipOffstage: false,
                      ),
                      matching: find.byType(
                        SliverResponsiveTileGrid,
                        skipOffstage: false,
                      ),
                      skipOffstage: false,
                    ),
                  )
                  .fold<int>(0, (count, grid) => count + grid.itemCount) ==
              expectedSearchResults,
          {
            'mountedCount': cards.length,
            'expectedDataCount': expectedSearchResults,
          },
        );
      }
      if (primary != null && cards.isNotEmpty) {
        for (final card in cards) {
          check(
            'search result is a full-width editorial row',
            (card.width - primary.width).abs() <= 2 &&
                (card.left - primary.left).abs() <= 2 &&
                (card.right - primary.right).abs() <= 2,
            {'actualWidth': card.width, 'expectedWidth': primary.width},
          );
        }
        for (var row = 1; row < cards.length; row++) {
          final previous = cards[row - 1];
          final current = cards[row];
          check(
            'search result rows follow in a compact non-overlapping sequence',
            (current.top - previous.bottom - 12).abs() <= 2,
            {
              'row': row,
              'previousBottom': previous.bottom,
              'currentTop': current.top,
            },
          );
        }
      }
    }
  }
  if (page == 'library' || page == 'downloads') {
    final prefix = page == 'library'
        ? 'library-book-'
        : 'desktop-download-book-';
    final rows = _workspaceGeometry(
      tester,
      size,
    ).where((entry) => (entry['key']! as String).startsWith(prefix)).toList();
    check('real media or status rows are mounted', rows.isNotEmpty);
    if (pageWidth != null) {
      for (final row in rows) {
        check(
          'media/status row fills page width',
          (row['width']! as double) >= pageWidth * 0.95,
          {
            'key': row['key']!,
            'actualWidth': row['width']!,
            'availableWidth': pageWidth,
          },
        );
      }
    }
  }
  if (page == 'downloads') {
    final compactRows = _workspaceGeometry(tester, size).where(
      (entry) =>
          (entry['key']! as String).startsWith('desktop-download-compact-'),
    );
    for (final row in compactRows) {
      final suffix = (row['key']! as String).substring(
        'desktop-download-compact-'.length,
      );
      final title = keyedRect('desktop-download-title-$suffix');
      final transfer = keyedRect('desktop-download-transfer-$suffix');
      final metadata = keyedRect('desktop-download-metadata-$suffix');
      check(
        'compact downloads prioritize title and transfer before bibliography',
        title != null &&
            transfer != null &&
            metadata != null &&
            title.bottom <= transfer.top &&
            transfer.bottom <= metadata.top,
        {'bookKey': suffix},
      );
    }
  }
  if (page == 'settings' ||
      page == 'appearance' ||
      page == 'appearance-scrolled') {
    checkPanes(
      'settings-desktop-workspace',
      'settings-desktop-primary',
      'settings-desktop-secondary',
    );
    final appearance = keyedRect('settings-group-appearance');
    final cards = keyedRect('settings-group-cards');
    final primary = keyedRect('settings-desktop-primary');
    final secondary = keyedRect('settings-desktop-secondary');
    check(
      'appearance and card preferences begin their own meaningful columns',
      appearance != null &&
          cards != null &&
          primary != null &&
          secondary != null &&
          (appearance.top - primary.top).abs() <= 2 &&
          (appearance.width - primary.width).abs() <= 2 &&
          (cards.top - secondary.top).abs() <= 2 &&
          (cards.width - secondary.width).abs() <= 2,
    );
    final editor = find.byKey(const ValueKey('settings-appearance-editor'));
    check(
      'real inline appearance editor exists',
      editor.evaluate().length == 1,
    );
    for (final key in [
      'settings-theme-system',
      'settings-theme-light',
      'settings-theme-dark',
      'appearance-text-scale-slider',
      'appearance-text-scale-preview',
      'appearance-text-scale-reset',
    ]) {
      check(
        'appearance control is inline rather than a navigation placeholder',
        find
                .descendant(of: editor, matching: find.byKey(ValueKey(key)))
                .evaluate()
                .length ==
            1,
        {'key': key},
      );
    }
    final slider = find.byKey(const ValueKey('appearance-text-scale-slider'));
    if (slider.evaluate().length == 1) {
      final widget = _readSlider(tester, slider);
      check(
        'inline slider reflects actual app scale and can edit it',
        (widget.value - appScale).abs() <= 0.001 &&
            widget.onChanged != null &&
            widget.onChangeEnd != null,
        {'sliderValue': widget.value, 'actualAppScale': appScale},
      );
    }
    for (final key in [
      'settings-compact-cards',
      'settings-show-source',
      'settings-show-percent',
    ]) {
      final finder = find.byKey(ValueKey(key));
      final exists = finder.evaluate().length == 1;
      check(
        'card preference is an enabled inline switch',
        exists && tester.widget<AppSwitchListTile>(finder).onChanged != null,
        {'key': key},
      );
    }
    final groups = [
      cards,
      keyedRect('settings-group-personalization'),
      keyedRect('settings-group-content'),
      keyedRect('settings-group-application'),
    ].whereType<Rect>().toList();
    check('all four secondary preference groups exist', groups.length == 4);
    for (var i = 1; i < groups.length; i++) {
      check(
        'secondary settings form a readable vertical sequence',
        (groups[i].top - groups[i - 1].bottom - 16).abs() <= 2 &&
            (groups[i].left - groups[i - 1].left).abs() <= 2 &&
            (groups[i].width - groups[i - 1].width).abs() <= 2,
      );
    }
  }
  if (page == 'source-details' ||
      page == 'legacy-details' ||
      page == 'saved-details') {
    final summary = keyedRect('desktop-details-summary');
    final main = keyedRect('desktop-details-main-column');
    final identity = keyedRect('desktop-details-identity');
    final actions = keyedRect('desktop-details-actions');
    final artwork = keyedRect('desktop-details-artwork');
    check(
      'details identity, real actions and bounded artwork exist',
      identity != null && actions != null && artwork != null,
    );
    if (size == const Size(1024, 600) &&
        summary != null &&
        identity != null &&
        actions != null) {
      final scale =
          MediaQuery.textScalerOf(
            tester.element(
              find.byKey(const ValueKey('desktop-details-summary')),
            ),
          ).scale(14) /
          14;
      if (scale <= 1.001 && frame.evaluate().length == 1) {
        final bounds = tester.getRect(frame);
        check(
          'short-window title narrator and playback actions precede scrolling',
          identity.top >= bounds.top &&
              identity.bottom <= bounds.bottom &&
              actions.top >= bounds.top &&
              actions.bottom <= bounds.bottom,
          {
            'identityBottom': identity.bottom,
            'actionsBottom': actions.bottom,
            'viewportBottom': bounds.bottom,
          },
        );
      }
    }
    check(
      'details summary and content both exist',
      summary != null &&
          find
                  .byKey(
                    const ValueKey('desktop-details-main-column'),
                    skipOffstage: false,
                  )
                  .evaluate()
                  .length ==
              1,
    );
    if (summary != null &&
        main != null &&
        find
            .byKey(const ValueKey('desktop-details-split'))
            .evaluate()
            .isNotEmpty) {
      check(
        'details content starts beside summary, not after cover',
        main.left >= summary.right && (main.top - summary.top).abs() <= 2,
        {
          'summaryTop': summary.top,
          'mainTop': main.top,
          'summaryRight': summary.right,
          'mainLeft': main.left,
        },
      );
      check(
        'details main column reaches right gutter',
        main.right >= size.width - 38,
        {'actualRight': main.right},
      );
    }
  }
  return checks;
}

/// Fixed DTO state, not a simulated transfer. No scheduler or source I/O runs.
class _WorkspaceDownloads extends DownloadManager {
  _WorkspaceDownloads({required this.books, required super.storage})
    : super(
        client: const _NoNetworkVisualDownloadClient(),
        persistence: MemoryDownloadPersistenceStore(),
      ) {
    fixtureTasks = [
      for (var index = 0; index < books.length; index++)
        for (final chapter in books[index].chapters)
          _fixtureTask(books[index], chapter, index),
    ];
  }

  final List<AudioPlaybackBook> books;
  late final List<DownloadTask> fixtureTasks;

  DownloadTask _fixtureTask(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
    int bookIndex,
  ) {
    final status = books.length == 1
        ? DownloadTaskStatus.completed
        : const [
            DownloadTaskStatus.running,
            DownloadTaskStatus.queued,
            DownloadTaskStatus.failed,
            DownloadTaskStatus.completed,
          ][bookIndex % 4];
    final progress = switch (status) {
      DownloadTaskStatus.completed => 1.0,
      DownloadTaskStatus.running => 0.42,
      DownloadTaskStatus.failed => 0.23,
      _ => 0.0,
    };
    return DownloadTask(
      id: 'visual-${book.versionId}-${chapter.id}',
      bookId: book.id,
      bookVersionId: book.versionId,
      chapterId: chapter.id,
      sourceId: book.sourceId,
      type: DownloadTaskType.chapter,
      status: status,
      progress: progress,
      downloadedBytes: (32 * 1024 * 1024 * progress).round(),
      totalBytes: 32 * 1024 * 1024,
      speedBytesPerSecond: status == DownloadTaskStatus.running ? 786432 : 0,
      errorCode: status == DownloadTaskStatus.failed ? 'visual_fixture' : null,
      errorMessage: status == DownloadTaskStatus.failed
          ? 'Синтетическая ошибка загрузки для UI QA'
          : null,
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    );
  }

  @override
  List<DownloadTask> get tasks => List.unmodifiable(fixtureTasks);

  @override
  DownloadTask? taskById(String id) =>
      fixtureTasks.where((task) => task.id == id).firstOrNull;

  @override
  AudioPlaybackBook? bookForTask(String taskId) {
    final task = taskById(taskId);
    return books
        .where((book) => book.versionId == task?.bookVersionId)
        .firstOrNull;
  }

  @override
  DownloadTask? taskForChapter(String chapterId) =>
      fixtureTasks.where((task) => task.chapterId == chapterId).firstOrNull;

  @override
  DownloadTask? taskForBookChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) => fixtureTasks
      .where(
        (task) =>
            task.bookVersionId == book.versionId &&
            task.chapterId == chapter.id,
      )
      .firstOrNull;
}

class _NoNetworkVisualDownloadClient implements DownloadClient {
  const _NoNetworkVisualDownloadClient();

  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async => throw StateError('Visual fixtures do not open media or network.');
}

/// Deterministic DTO delivery to the real search UI. This does not simulate
/// catalog relevance, source parsing, enrichment, or network availability.
class _VisualSearchCatalog extends SourceCatalogService {
  _VisualSearchCatalog({required super.registry, required this.resultCount});

  final int resultCount;

  @override
  Future<SourceSearchResponse> search(
    SearchRequest request, {
    void Function(SourceSearchResponse response)? onUpdate,
    SourceSearchCancellation? cancellation,
  }) async {
    const sources = [
      'yakniga',
      'akniga',
      'izib',
      'knigavuhe',
      'knigoblud',
      'baza_knig',
    ];
    const narrators = [
      'Вячеслав Герасимов',
      'Олег Табаков',
      'Александр Клюквин',
    ];
    return SourceSearchResponse(
      results: [
        for (var index = 0; index < resultCount; index++)
          BookSearchResult(
            ref: SourceBookRef(
              sourceId: sources[index % sources.length],
              sourceBookId: 'visual-master-${index + 1}',
            ),
            sourceName: sources[index % sources.length],
            title: 'Мастер и Маргарита — озвучка ${index + 1}',
            author: 'Михаил Булгаков',
            narrator: narrators[index % narrators.length],
            duration: Duration(hours: 15 + index % 2, minutes: 42),
            year: 1967,
            chapterCount: 32,
            ratingValue: 4.8,
            ratingCount: 120,
            isFull: true,
            isFree: true,
          ),
      ],
    );
  }
}

/// Parser-to-widget fixture delivery only. Service matching/filtering has its
/// own regression tests; this capture never calls a real source or network.
class _VisualNarrationService extends SourceCatalogService {
  _VisualNarrationService({required super.registry});

  @override
  Future<List<BookSearchResult>> findOtherNarrations(
    SourceBookSnapshot snapshot, {
    int limit = 12,
  }) async => [
    ...KnigobludMapper().searchResults(
      File(
        'test/sources/knigoblud/fixtures/search_combined_people.html',
      ).readAsStringSync(),
    ),
    const BookSearchResult(
      ref: SourceBookRef(
        sourceId: 'knigoblud',
        sourceBookId: 'visual-missing-narrator',
      ),
      sourceName: 'Knigoblud',
      title: 'Название не должно подменять отсутствующего чтеца',
      author: 'Автор не должен подменять отсутствующего чтеца',
    ),
  ];
}

class _VisualStorage extends FileDownloadStorage {
  _VisualStorage(this.books, Directory root) : super(rootDirectory: root);
  final List<AudioPlaybackBook> books;
  @override
  Future<List<AudioPlaybackBook>> readAllMetadata() async => books;
  @override
  Future<void> saveBook(AudioPlaybackBook book) async {}
  @override
  Future<void> writeMetadata(AudioPlaybackBook book) async {}
  @override
  Future<AudioPlaybackBook?> loadBook({
    required String sourceId,
    required String versionId,
  }) async => books
      .where((book) => book.sourceId == sourceId && book.versionId == versionId)
      .firstOrNull;
  @override
  Future<CardCacheStats> cardCacheStats() async =>
      CardCacheStats(bytes: 42000, bookCount: books.length);
  @override
  Future<AudioPlaybackBook> offlinePlaybackBook(AudioPlaybackBook book) async =>
      book;
}

class _VisualPlaybackPersistence implements PlaybackPersistenceStore {
  _VisualPlaybackPersistence(this.books);
  final List<AudioPlaybackBook> books;
  @override
  Future<PlaybackSession?> loadSession({String id = 'active'}) async => null;
  @override
  Future<void> saveSession(PlaybackSession session) async {}
  @override
  Future<void> saveProgress(PlaybackProgressSnapshot progress) async {}
  @override
  Future<List<PlaybackProgressSnapshot>> loadProgress() async => [
    for (var index = 0; index < books.length; index++)
      PlaybackProgressSnapshot(
        bookId: books[index].id,
        bookVersionId: books[index].versionId,
        currentChapterId: books[index].chapters.first.id,
        currentPositionMs: 60000,
        maxReachedGlobalPositionMs: 60000,
        totalDurationMs: books[index].totalDuration.inMilliseconds,
        listenedDurationMs: 60000,
        percent: 12.0 + index * 9,
        isFinished: false,
        lastPlayedAt: DateTime(2026, 9, 1, index),
      ),
  ];
}

/// These aliases opt into real app routes; no replacement widgets are rendered.
final _resizeVisualRoutes = <String, String>{
  'scoped-search': '/scoped-search?q=Мастер&run=1',
  'theme-preview': '/theme-preview',
  'theme-preview-bottom': '/theme-preview',
  'player-chapters': '/player?tab=chapters',
  'player-bookmarks': '/player?tab=bookmarks',
  'player-bookmarks-empty': '/player?tab=bookmarks',
  'player-information': '/player?tab=information',
  'appearance-scrolled': '/settings',
  'other-narrations':
      '/source-book/${activeMockBook.sourceId}/${Uri.encodeComponent(activeMockBook.id)}',
  'downloads-expanded': '/downloads',
  for (final shelf in [
    'listening',
    'favorites',
    'later',
    'downloaded',
    'finished',
    'bookmarks',
    'history',
  ])
    'library-$shelf': '/library',
  'home-empty': '/',
  'library-empty': '/library',
  'downloads-empty': '/downloads',
  'player-empty': '/player',
  'search-no-results': '/search?q=visual-empty&run=1&reset=empty',
  'search-partial-errors': '/search?q=Мастер&run=1&reset=failures',
  'source-details-loading':
      '/source-book/${activeMockBook.sourceId}/visual-loading',
  'source-details-error':
      '/source-book/${activeMockBook.sourceId}/visual-error',
  for (final dialog in [
    'language',
    'animations',
    'sources',
    'cache',
    'cache-confirm',
    'about',
    'custom-accent',
    'update-available',
    'update-progress',
    'update-error',
  ])
    'dialog-$dialog': '/settings',
  'dialog-search-kind': '/search?reset=kind',
  'dialog-search-sort': '/search?reset=sort',
  'dialog-share':
      '/source-book/${activeMockBook.sourceId}/${Uri.encodeComponent(activeMockBook.id)}',
  'dialog-speed': '/player',
  'dialog-sleep': '/player',
  'dialog-volume': '/',
  'dialog-full-volume': '/player',
  'dialog-bookmark-add': '/player?tab=bookmarks',
  'dialog-bookmark-delete': '/player?tab=bookmarks',
  // Only captured at a compact profile. There is no such button on the wide layout.
  'dialog-player-book': '/player',
};

Future<void> _setVisualBookmarks(
  BookmarkStore store,
  List<AudioPlaybackBook> books, {
  required bool empty,
}) async {
  final expected = empty || books.isEmpty ? 0 : 2;
  if (store.entries.length == expected) {
    return;
  }
  for (final bookmark in store.entries) {
    await store.remove(bookmark.id);
  }
  if (expected == 0) {
    return;
  }
  final book = books.first;
  // Seed the production store with actual chapters and positions, not mock UI
  // rows. The IDs are intentionally excluded from evidence (clock-generated).
  for (final entry in [
    (1, 760000, activeMockBook.bookmarks[0].note),
    (2, 318000, activeMockBook.bookmarks[1].note),
  ]) {
    await store.add(
      book: book,
      chapterId: book.chapters[entry.$1].id,
      positionMs: entry.$2,
      note: entry.$3,
    );
  }
}

Future<Map<String, Object>> _probeVisualBookmarks(
  WidgetTester tester,
  List<PlaybackBookmark> bookmarks,
) async {
  final list = find.byKey(const PageStorageKey('player-bookmarks-list'));
  final scrollable = find
      .descendant(of: list, matching: find.byType(Scrollable))
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  var reachable = 0;
  for (final bookmark in bookmarks) {
    final note = find.text(bookmark.note!);
    await tester.scrollUntilVisible(note, 160, scrollable: scrollable);
    await tester.pump();
    if (note.evaluate().length == 1 &&
        tester.getRect(note).overlaps(tester.getRect(list))) {
      reachable++;
    }
  }
  position.jumpTo(0);
  await tester.pump();
  return {
    'name':
        'both real stored bookmark notes are reachable in the scrollable tab',
    'passed': bookmarks.length == 2 && reachable == 2,
    'fixtureCount': bookmarks.length,
    'reachableCount': reachable,
    'captureScrollOffset': position.pixels,
  };
}

Future<void> _visualPump(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _visualTap(WidgetTester tester, Finder finder) async {
  expect(
    finder,
    findsWidgets,
    reason: 'The capture must open the actual app control.',
  );
  final target = finder.first;
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await _visualPump(tester);
}

Future<void> _prepareResizeVisualPage(
  WidgetTester tester,
  String page,
  AppStrings strings,
) async {
  if (page.startsWith('library-') && page != 'library-empty') {
    final names = {
      'listening': strings.listening,
      'favorites': strings.favorites,
      'later': strings.later,
      'downloaded': strings.downloaded,
      'finished': strings.finished,
      'bookmarks': strings.bookmarks,
      'history': strings.history,
    };
    await _visualTap(
      tester,
      find.widgetWithText(ChoiceChip, names[page.substring(8)]!),
    );
  }
  if (page == 'theme-preview-bottom') {
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    // Re-evaluate the extent after each lazy section is mounted.
    for (var i = 0; i < 6; i++) {
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();
    }
  }
  if (page == 'downloads-expanded') {
    final expansion = find.byType(ExpansionTile).first;
    await _visualTap(
      tester,
      find.descendant(of: expansion, matching: find.byType(ListTile)).first,
    );
  }
  if (!page.startsWith('dialog-')) return;
  final setting = {
    'dialog-language': strings.language,
    'dialog-animations': strings.animations,
    'dialog-sources': strings.sources,
    'dialog-cache': strings.cacheAndMetadata,
    'dialog-cache-confirm': strings.cacheAndMetadata,
    'dialog-about': strings.aboutApp,
    'dialog-update-available': strings.appUpdates,
    'dialog-update-progress': strings.appUpdates,
    'dialog-update-error': strings.appUpdates,
  }[page];
  if (setting != null) {
    await _visualTap(tester, find.text(setting));
    if (page == 'dialog-cache-confirm') {
      await _visualTap(tester, find.text(strings.clearCardCache));
    }
    if (page == 'dialog-update-progress' || page == 'dialog-update-error') {
      await _visualTap(tester, find.text(strings.updateNow));
    }
    return;
  }
  switch (page) {
    case 'dialog-custom-accent':
      await _visualTap(tester, find.byTooltip(strings.customColor));
    case 'dialog-search-kind':
      await _visualTap(tester, find.byType(InputChip).first);
    case 'dialog-search-sort':
      await _visualTap(tester, find.byType(InputChip).at(1));
    case 'dialog-share':
      await _visualTap(
        tester,
        find.byKey(const ValueKey('source-details-share')),
      );
    case 'dialog-speed':
      await _visualTap(
        tester,
        find.byKey(const ValueKey('windows-player-speed')),
      );
    case 'dialog-sleep':
      await _visualTap(tester, find.byTooltip(strings.sleepTimer));
    case 'dialog-volume':
      await _visualTap(tester, find.byTooltip(strings.volume));
    case 'dialog-full-volume':
      await _visualTap(
        tester,
        find.byKey(const ValueKey('windows-full-player-volume')),
      );
    case 'dialog-bookmark-add':
      await _visualTap(
        tester,
        find.byKey(const ValueKey('player-bookmark-add')),
      );
    case 'dialog-bookmark-delete':
      await _visualTap(tester, find.byTooltip(strings.deleteBookmarkAction));
    case 'dialog-player-book':
      await _visualTap(
        tester,
        find.byKey(const ValueKey('windows-compact-player-book-details')),
      );
  }
}

Future<void> _closeResizeVisualOverlays(WidgetTester tester) async {
  // Teardown only: do not Apply preferences, clear cache, retry/download, copy
  // links or launch an installer. Busy update futures belong to a fake service.
  for (var i = 0; i < 4 && find.byType(Dialog).evaluate().isNotEmpty; i++) {
    Navigator.of(tester.element(find.byType(Dialog).last)).pop();
    await _visualPump(tester, 8);
  }
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await _visualPump(tester, 4);
}

List<Map<String, Object>> _visualScrollEvidence(WidgetTester tester) => [
  for (final element in find.byType(Scrollable).evaluate())
    if (element is StatefulElement && element.state is ScrollableState)
      (() {
        final state = element.state as ScrollableState;
        final bounds = _workspaceRenderBounds(element.findRenderObject());
        return <String, Object>{
          'axis': state.position.axis.name,
          'pixels': state.position.pixels,
          'minExtent': state.position.minScrollExtent,
          'maxExtent': state.position.maxScrollExtent,
          'viewportDimension': state.position.viewportDimension,
          if (bounds != null) ...{
            'left': bounds.left,
            'top': bounds.top,
            'width': bounds.width,
            'height': bounds.height,
          },
        };
      })(),
];

List<Map<String, Object>> _resizeVisualChecks(
  WidgetTester tester,
  String page,
  Size size,
  int fixtureBooks,
  List<PlaybackBookmark> fixtureBookmarks,
) {
  final checks = <Map<String, Object>>[];
  void check(
    String name,
    bool passed, [
    Map<String, Object> details = const {},
  ]) => checks.add({'name': name, 'passed': passed, ...details});
  final viewport = Offset.zero & size;
  final strings = tester.element(find.byType(Scaffold).last).strings;
  for (final paragraph in _paragraphEvidence(tester, find.byType(BookCover))) {
    if (RegExp(r'^\d{1,3}%$').hasMatch(paragraph['text']! as String)) {
      check(
        'cover listening percentage stays whole on one unclipped line',
        paragraph['selectionLineCount'] == 1 &&
            paragraph['didExceedMaxLines'] == false,
        {'text': paragraph['text']!, 'lines': paragraph['selectionLineCount']!},
      );
    }
  }
  if (const {
    'home',
    'library',
    'search',
    'search-results',
    'downloads',
    'settings',
    'source-details',
    'legacy-details',
    'saved-details',
  }.contains(page)) {
    check(
      'real desktop content frame exists on this shell route',
      find.byKey(const ValueKey('desktop-content-frame')).evaluate().length ==
          1,
    );
  }
  if (page == 'player-chapters') {
    check(
      'chapters tab mounts actual chapter rows',
      find
          .byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith(
                  'full-player-chapter-',
                ),
          )
          .evaluate()
          .isNotEmpty,
    );
  }
  if (page == 'player-bookmarks') {
    check(
      'bookmarks tab contains notes from two actual persisted fixture entries',
      fixtureBookmarks.length == 2 &&
          fixtureBookmarks.any(
            (bookmark) => find.text(bookmark.note!).evaluate().isNotEmpty,
          ),
    );
  }
  if (page == 'player-bookmarks' || page == 'player-bookmarks-empty') {
    final add = find.byKey(const ValueKey('player-bookmark-add'));
    check(
      'loaded-book bookmarks expose the enabled production add action',
      fixtureBooks > 0 &&
          add.evaluate().length == 1 &&
          tester.widget<FilledButton>(add).onPressed != null,
    );
  }
  if (page == 'player-bookmarks-empty') {
    check(
      'empty bookmarks reflect the empty real store, not a replacement widget',
      fixtureBookmarks.isEmpty &&
          find
                  .byKey(const ValueKey('player-bookmarks-empty'))
                  .evaluate()
                  .length ==
              1 &&
          find.text(strings.noBookmarks).evaluate().isNotEmpty,
    );
  }
  if (page == 'player-information') {
    check(
      'information tab mounts real book metadata source',
      find
          .byKey(const ValueKey('full-player-info-source'))
          .evaluate()
          .isNotEmpty,
    );
  }
  if (page == 'theme-preview-bottom') {
    check(
      'theme preview reaches its final Focus state',
      find.text('Focus').evaluate().isNotEmpty &&
          tester.getRect(find.text('Focus')).overlaps(viewport),
    );
  }
  if (page == 'search-partial-errors') {
    final failureNames = [
      strings.sourceDisplayName('izib'),
      strings.sourceDisplayName('akniga'),
    ].join(', ');
    final retry = find.byKey(const ValueKey('search-retry'));
    check(
      'partial failures name both real fixture sources and expose Retry',
      find.byKey(const ValueKey('search-source-failures')).evaluate().length ==
              1 &&
          find
                  .text(strings.partialSearchSources(failureNames))
                  .evaluate()
                  .length ==
              1 &&
          retry.evaluate().length == 1 &&
          tester.widget<TextButton>(retry).onPressed != null,
    );
    check(
      'partial failure retains real result cards',
      find.byType(BookCard).evaluate().isNotEmpty,
    );
  }
  if (const {
    'home-empty',
    'library-empty',
    'downloads-empty',
    'player-empty',
  }.contains(page)) {
    check(
      'empty state uses genuinely empty in-memory stores',
      fixtureBooks == 0,
    );
    check(
      'empty state contains no BookCard',
      find.byType(BookCard).evaluate().isEmpty,
    );
    check(
      'empty state has no persistent playback dock',
      find.byKey(const ValueKey('windows-playback-dock')).evaluate().isEmpty,
    );
  }
  if (page == 'player-empty') {
    check(
      'idle player renders the real localized empty state',
      find
                  .byKey(const ValueKey('windows-player-empty-state'))
                  .evaluate()
                  .length ==
              1 &&
          find.text(strings.realSourceHomeTitle).evaluate().isNotEmpty,
    );
    final search = find.byKey(const ValueKey('windows-player-empty-search'));
    check(
      'idle player exposes an enabled real search action',
      search.evaluate().length == 1 &&
          tester.widget<FilledButton>(search).onPressed != null,
    );
    check(
      'idle player has no indefinite loading indicator',
      find.byType(CircularProgressIndicator).evaluate().isEmpty,
    );
    check(
      'idle player has no active transport or seek slider',
      find
              .byKey(const ValueKey('windows-full-player-controls'))
              .evaluate()
              .isEmpty &&
          find
              .byKey(const ValueKey('windows-compact-player-controls'))
              .evaluate()
              .isEmpty &&
          find.byType(Slider).evaluate().isEmpty,
    );
    check(
      'idle player retains a real back action',
      find
              .byKey(const ValueKey('windows-empty-player-back'))
              .evaluate()
              .length ==
          1,
    );
  }
  if (page == 'downloads-empty') {
    final search = find.byKey(const ValueKey('desktop-downloads-empty-search'));
    check(
      'empty downloads omit zero counters and expose explanatory copy and search',
      find
              .byKey(const ValueKey('desktop-download-summary'))
              .evaluate()
              .isEmpty &&
          find.text(strings.emptyDownloadsMessage).evaluate().isNotEmpty &&
          search.evaluate().length == 1 &&
          tester.widget<FilledButton>(search).onPressed != null,
    );
  }
  if (page == 'dialog-bookmark-add') {
    check(
      'bookmark editor renders the actual note field and save action',
      find.byKey(const ValueKey('player-bookmark-note')).evaluate().length ==
              1 &&
          find
                  .byKey(const ValueKey('player-bookmark-save'))
                  .evaluate()
                  .length ==
              1,
    );
  }
  if (page == 'dialog-bookmark-delete') {
    check(
      'bookmark deletion presents its real confirmation without mutating fixtures',
      fixtureBookmarks.length == 2 &&
          find
                  .byKey(const ValueKey('player-bookmark-delete-confirm'))
                  .evaluate()
                  .length ==
              1 &&
          find
                  .byKey(const ValueKey('player-bookmark-delete-cancel'))
                  .evaluate()
                  .length ==
              1,
    );
  }
  if (page.startsWith('library-') && page != 'library-empty') {
    final selected = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .where((chip) => chip.selected)
        .toList();
    check('a real library shelf is selected', selected.length == 1, {
      'selectedLabel': selected.isEmpty
          ? ''
          : (selected.single.label as Text).data ?? '',
    });
  }
  if (page == 'search-no-results') {
    check(
      'empty search contains no fake result cards',
      find.byType(BookCard).evaluate().isEmpty,
    );
  }
  if (page == 'source-details-loading') {
    check(
      'real details loading state is mounted',
      find.byType(CircularProgressIndicator).evaluate().isNotEmpty,
    );
  }
  if (page == 'source-details-error') {
    check(
      'real details error provides Retry',
      find.text(strings.retry).evaluate().isNotEmpty,
    );
  }
  if (page.startsWith('dialog-')) {
    final dialogs = find.byType(Dialog);
    final volume = find.byKey(const ValueKey('desktop-volume-popover'));
    check(
      'actual app overlay is mounted',
      dialogs.evaluate().isNotEmpty || volume.evaluate().isNotEmpty,
    );
    final surfaces = [
      for (final dialog in dialogs.evaluate())
        ...find
            .descendant(
              of: find.byWidget(dialog.widget),
              matching: find.byType(Material),
            )
            .evaluate()
            .take(1),
      ...volume.evaluate(),
    ];
    for (final surface in surfaces) {
      final bounds = _workspaceRenderBounds(surface.findRenderObject());
      check(
        'overlay material stays inside the client viewport',
        bounds != null &&
            bounds.left >= -1 &&
            bounds.top >= -1 &&
            bounds.right <= size.width + 1 &&
            bounds.bottom <= size.height + 1,
        bounds == null
            ? {}
            : {
                'left': bounds.left,
                'top': bounds.top,
                'right': bounds.right,
                'bottom': bounds.bottom,
              },
      );
    }
    final pickerAction = find.byKey(const ValueKey('desktop-picker-action'));
    if (pickerAction.evaluate().isNotEmpty) {
      final bounds = tester.getRect(pickerAction.first);
      check(
        'picker primary action is visible without scrolling the window',
        bounds.top >= 0 &&
            bounds.bottom <= size.height &&
            bounds.left >= 0 &&
            bounds.right <= size.width,
      );
    }
    final close = find.byKey(const ValueKey('desktop-options-close'));
    if (page == 'dialog-speed' || page == 'dialog-sleep') {
      check(
        'player options share the explicit desktop close action',
        close.evaluate().length == 1 &&
            find
                    .byKey(const ValueKey('desktop-options-dialog'))
                    .evaluate()
                    .length ==
                1,
      );
    }
    if (close.evaluate().isNotEmpty) {
      final bounds = tester.getRect(close.first);
      check(
        'desktop panel close action remains visible',
        viewport.contains(bounds.topLeft) &&
            viewport.contains(bounds.bottomRight),
      );
    }
  }
  final mobileNavigation = find.byKey(const ValueKey('mobile-navigation-bar'));
  check(
    'Windows never falls back to phone navigation',
    mobileNavigation.evaluate().isEmpty,
  );
  for (final key in [
    'windows-playback-dock',
    'windows-full-player',
    'windows-compact-navigation-rail',
  ]) {
    final finder = find.byKey(ValueKey(key));
    if (finder.evaluate().isNotEmpty) {
      final bounds = tester.getRect(finder.first);
      check(
        'desktop chrome remains bounded by the client',
        bounds.left >= -1 &&
            bounds.top >= -1 &&
            bounds.right <= size.width + 1 &&
            bounds.bottom <= size.height + 1,
        {
          'key': key,
          'left': bounds.left,
          'top': bounds.top,
          'right': bounds.right,
          'bottom': bounds.bottom,
        },
      );
    }
  }
  return checks;
}

class _ResizeVisualCatalog extends _VisualSearchCatalog {
  _ResizeVisualCatalog({required super.registry, required super.resultCount});
  String page = '';
  @override
  Future<SourceSearchResponse> search(
    SearchRequest request, {
    void Function(SourceSearchResponse response)? onUpdate,
    SourceSearchCancellation? cancellation,
  }) async {
    if (page == 'search-no-results') {
      return const SourceSearchResponse(results: []);
    }
    final response = await super.search(request);
    return SourceSearchResponse(
      results: response.results,
      failures: page == 'search-partial-errors'
          ? const [
              SourceFailure(
                sourceId: 'izib',
                kind: SourceErrorKind.network,
                message:
                    'Синтетическая ошибка сети: источник временно недоступен.',
              ),
              SourceFailure(
                sourceId: 'akniga',
                kind: SourceErrorKind.network,
                message: 'Синтетическое превышение времени ожидания.',
              ),
            ]
          : const [],
    );
  }

  @override
  Future<SourceBookSnapshot> loadBook(
    SourceBookRef ref, {
    bool forceRefresh = false,
    MediaResolvePurpose purpose = MediaResolvePurpose.playback,
  }) {
    if (page == 'source-details-loading') {
      return Completer<SourceBookSnapshot>().future;
    }
    if (page == 'source-details-error') {
      return Future.error(
        const SourceException(
          sourceId: 'izib',
          kind: SourceErrorKind.network,
          message: 'Синтетический источник временно недоступен.',
        ),
      );
    }
    return super.loadBook(ref, forceRefresh: forceRefresh, purpose: purpose);
  }

  @override
  Future<List<BookSearchResult>> findOtherNarrations(
    SourceBookSnapshot snapshot, {
    int limit = 12,
  }) async {
    if (page != 'other-narrations') {
      return super.findOtherNarrations(snapshot, limit: limit);
    }
    return KnigobludMapper().searchResults(
      File(
        'test/sources/knigoblud/fixtures/search_combined_people.html',
      ).readAsStringSync(),
    );
  }
}

Finder _visualDownloadRows() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> &&
      key.value.startsWith('desktop-download-book-');
});

Future<List<Map<String, Object>>> _probeVisualDownloads(
  WidgetTester tester,
  Size size,
  double appScale,
  List<AudioPlaybackBook> books,
) async {
  final frame = find.byKey(const ValueKey('desktop-content-frame'));
  final scrollable = find
      .descendant(of: frame, matching: find.byType(Scrollable))
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  final initial = position.pixels;
  final checks = <Map<String, Object>>[];
  for (final book in books) {
    final row = find.byKey(
      ValueKey('desktop-download-book-${book.sourceId}:${book.versionId}'),
    );
    await tester.scrollUntilVisible(row, 180, scrollable: scrollable);
    await tester.pump();
    final bounds = tester.getRect(row);
    final viewport = tester.getRect(frame);
    checks.add({
      'name': 'each genuine lazy download group is reachable by scrolling',
      'passed': bounds.overlaps(viewport) && bounds.width > 0,
      'bookVersionId': book.versionId,
      'scrollOffset': position.pixels,
      'rowTop': bounds.top,
      'rowBottom': bounds.bottom,
    });
    // Execute exactly the normal row-width and transfer-order assertions at a
    // phase where these lazy children have real paint/layout geometry.
    checks.addAll(_workspaceChecks(tester, 'downloads', size, appScale));
  }
  position.jumpTo(initial);
  await tester.pump();
  checks.add({
    'name': 'lazy download probe restores the original capture scroll offset',
    'passed': books.isNotEmpty && (position.pixels - initial).abs() <= 0.01,
    'restoredOffset': position.pixels,
    'initialOffset': initial,
  });
  return checks;
}

class _ResizeVisualUpdates extends UpdateService {
  _ResizeVisualUpdates()
    : super(
        client: const _NoNetworkUpdateClient(),
        installer: PlatformUpdateInstaller(),
        runtimePlatform: UpdateRuntimePlatform.unsupported,
      );
  String page = '';
  final info = (() {
    final manifest = UpdateManifest.fromJson({
      'schema': 1,
      'app': 'slovofon',
      'channel': 'stable',
      'status': 'available',
      'version': '99.0.0',
      'build': 990,
      'published_at': '2026-09-01T00:00:00Z',
      'mandatory': false,
      'release_notes': 'Синтетическое обновление для проверки интерфейса.',
      'assets': [
        {
          'platform': 'windows',
          'arch': 'x64',
          'kind': 'installer',
          'url': 'https://fixture.invalid/never-requested.exe',
          'file_name': 'Slovofon-v99.0.0-windows-x64-setup.exe',
          'sha256': '0' * 64,
          'size': 128 * 1024 * 1024,
        },
      ],
    });
    return UpdateInfo(manifest: manifest, asset: manifest.assets.single);
  })();
  @override
  Future<UpdateCheckResult> checkForUpdate({
    bool includeSkipped = false,
  }) async => includeSkipped
      ? UpdateCheckResult.available(info)
      : const UpdateCheckResult.noUpdate();
  @override
  Future<void> downloadAndInstall(
    UpdateInfo info, {
    void Function(int downloadedBytes, int? totalBytes)? onProgress,
  }) {
    if (page == 'dialog-update-error') {
      return Future.error(
        StateError(
          'Synthetic update error; no download or installer was started.',
        ),
      );
    }
    onProgress?.call(48 * 1024 * 1024, info.asset.size);
    return Completer<void>().future;
  }
}

/// Probe the actual lazy main sliver after scrolling, then restore the initial
/// view for the screenshot. Offscreen slivers need not have paint geometry.
Future<Map<String, Object>> _probeResizeDetails(WidgetTester tester) async {
  final host = find.byKey(const ValueKey('desktop-details-scroll'));
  final scrollable = find
      .descendant(of: host, matching: find.byType(Scrollable))
      .first;
  final state = tester.state<ScrollableState>(scrollable);
  final initial = state.position.pixels;
  final clip = tester.getRect(host);
  var reached = false;
  var reachedOffset = initial;
  Rect? reachedBounds;
  for (var step = 0; step < 10; step++) {
    final main = find.byKey(const ValueKey('desktop-details-main-column'));
    if (main.evaluate().length == 1) {
      final bounds = _workspaceRenderBounds(
        tester.element(main).findRenderObject(),
      );
      if (bounds != null && bounds.height > 0 && bounds.overlaps(clip)) {
        reached = true;
        reachedOffset = state.position.pixels;
        reachedBounds = bounds;
        break;
      }
    }
    final next =
        (state.position.pixels + state.position.viewportDimension * .75).clamp(
          0.0,
          state.position.maxScrollExtent,
        );
    if (next == state.position.pixels) break;
    state.position.jumpTo(next);
    await tester.pump();
  }
  state.position.jumpTo(initial);
  await tester.pump();
  return {
    'name':
        'lazy details main content is reachable in its actual scroll viewport',
    'passed': reached,
    'reachedScrollOffset': reachedOffset,
    'restoredScrollOffset': state.position.pixels,
    if (reachedBounds != null) ...{
      'mainTop': reachedBounds.top,
      'mainBottom': reachedBounds.bottom,
      'clipTop': clip.top,
      'clipBottom': clip.bottom,
    },
  };
}

/// A tall search form can push the actual results below the onstage finder
/// boundary. Prove data, layout and both contextual panels after real scrolling;
/// then restore the initial offset. Hidden cards are scoped to this search only.
Future<Map<String, Object>> _probeResizeSearch(
  WidgetTester tester,
  Size size,
  double appScale,
  int expectedCount,
) async {
  final controls = find.byKey(const ValueKey('desktop-search-controls'));
  final scrolling = find
      .ancestor(of: controls, matching: find.byType(Scrollable))
      .first;
  final state = tester.state<ScrollableState>(scrolling);
  final initial = state.position.pixels;
  final viewport = tester.getRect(scrolling);
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('desktop-search-primary')),
    200,
    scrollable: scrolling,
  );
  final primary = find.byKey(
    const ValueKey('desktop-search-primary'),
    skipOffstage: false,
  );
  Finder cards() => find.descendant(
    of: primary,
    matching: find.byType(BookCard, skipOffstage: false),
    skipOffstage: false,
  );
  final count = cards().evaluate().length;
  var gridVisible = false;
  var gridOffset = state.position.pixels;
  if (count > 0) {
    await Scrollable.ensureVisible(tester.element(cards().first), alignment: 0);
    await tester.pump();
    gridOffset = state.position.pixels;
    gridVisible = tester.getRect(cards().first).overlaps(viewport);
  }
  final layoutChecks = _workspaceChecks(
    tester,
    'search-results',
    size,
    appScale,
    expectedSearchResults: expectedCount,
  );
  final contextChecks = <Map<String, Object>>[];
  for (final key in ['desktop-search-history', 'desktop-search-sources']) {
    final panel = find.byKey(ValueKey(key), skipOffstage: false);
    var reached = false;
    if (panel.evaluate().length == 1) {
      await Scrollable.ensureVisible(tester.element(panel), alignment: 0);
      await tester.pump();
      final bounds = tester.getRect(panel);
      reached =
          bounds.width > 0 && bounds.height > 0 && bounds.overlaps(viewport);
    }
    contextChecks.add({
      'key': key,
      'reached': reached,
      'scrollOffset': state.position.pixels,
    });
  }
  state.position.jumpTo(initial);
  await tester.pump();
  return {
    'name':
        'lazy search delivers all results and both contextual panels are reachable',
    'passed':
        count == expectedCount &&
        gridVisible &&
        layoutChecks.every((c) => c['passed'] == true) &&
        contextChecks.every((c) => c['reached'] == true),
    'actualBookCardCount': count,
    'expectedBookCardCount': expectedCount,
    'gridVisible': gridVisible,
    'gridScrollOffset': gridOffset,
    'layoutWhileGridVisible': layoutChecks,
    'contextReachability': contextChecks,
    'restoredScrollOffset': state.position.pixels,
  };
}

Slider _readSlider(WidgetTester tester, Finder root) {
  final widget = tester.widget(root);
  if (widget is Slider) return widget;
  return tester.widget<Slider>(
    find.descendant(of: root, matching: find.byType(Slider)),
  );
}
