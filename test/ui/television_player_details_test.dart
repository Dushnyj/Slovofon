import 'dart:async';
import 'dart:io';
import 'dart:ui' show Tristate;

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
import 'package:slovofon/features/book_details/book_details_screen.dart';
import 'package:slovofon/features/book_details/saved_book_details_screen.dart';
import 'package:slovofon/features/player/full_player_screen.dart';
import 'package:slovofon/features/source_books/source_book_details_screen.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/bookmarks/bookmark_store.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/library/library_metadata.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/sources/sources.dart';
import 'package:slovofon/ui/adaptive/desktop_book_details_layout.dart';
import 'package:slovofon/ui/adaptive/slovofon_shell.dart';
import 'package:slovofon/ui/adaptive/television_layout.dart';
import 'package:slovofon/ui/adaptive/television_shell.dart';
import 'package:slovofon/ui/components/mini_player_bar.dart';

void main() {
  for (final size in [
    const Size(393, 852),
    const Size(800, 1280),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Phone/tablet player dots have 48dp touch targets and labels $size scale=$scale',
        (tester) async {
          await _pump(
            tester,
            television: false,
            logicalSize: size,
            scale: scale,
          );
          final semantics = tester.ensureSemantics();
          try {
            final strings = tester
                .element(find.byType(FullPlayerScreen))
                .strings;
            final labels = [
              strings.nowPlaying,
              strings.chapters,
              strings.bookmarks,
              strings.information,
            ];
            for (var i = 0; i < 4; i++) {
              final dot = find.byKey(ValueKey('mobile-player-dot-$i'));
              expect(tester.getSize(dot), const Size(48, 48));
              final node = tester.getSemantics(dot);
              expect(node.label, labels[i]);
              expect(node.flagsCollection.isButton, isTrue);
              expect(
                node.flagsCollection.isSelected,
                i == 0 ? Tristate.isTrue : Tristate.isFalse,
              );
              expect(
                tester
                    .getSize(
                      find.byKey(ValueKey('mobile-player-dot-visual-$i')),
                    )
                    .height,
                8,
              );
            }
            for (final i in [1, 2, 3, 0]) {
              final dot = find.byKey(ValueKey('mobile-player-dot-$i'));
              // The corner is outside the visible dot: this proves the full target,
              // not merely its semantics bounds, actually handles a finger tap.
              await tester.tapAt(tester.getTopLeft(dot) + const Offset(2, 2));
              await tester.pumpAndSettle();
              expect(
                tester
                    .widget<TabBarView>(find.byType(TabBarView))
                    .controller!
                    .index,
                i,
              );
              expect(
                tester.getSemantics(dot).flagsCollection.isSelected,
                Tristate.isTrue,
              );
              expect(tester.takeException(), isNull);
            }
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
  for (final dpr in [2.0, 4.0]) {
    for (final scale in [.75, 1.0, 2.0]) {
      for (final dark in [true, false]) {
        testWidgets('TV player FHD/4K DPR=$dpr text=$scale dark=$dark', (
          tester,
        ) async {
          await _pump(
            tester,
            dpr: dpr,
            scale: scale,
            dark: dark,
            title: 'Мастер и Маргарита',
          );
          expect(
            find.byKey(const ValueKey('television-full-player')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('windows-compact-full-player-header')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('tv-player-artwork')),
            findsOneWidget,
          );
          expect(
            tester.getSize(find.byKey(const ValueKey('tv-player-artwork'))),
            const Size(88, 126),
          );
          if (scale == 2) {
            final header = tester.getRect(
              find.byKey(const ValueKey('tv-player-identity-stacked')),
            );
            final title = tester.getRect(
              find.byKey(const ValueKey('tv-player-title')),
            );
            final artwork = tester.getRect(
              find.byKey(const ValueKey('tv-player-artwork')),
            );
            expect(title.top, greaterThanOrEqualTo(artwork.bottom + 12));
            expect(title.width, closeTo(header.width, .01));
            expect(title.left, header.left);
            expect(title.width, greaterThan(artwork.width + 100));
            expect(
              tester
                  .widget<Text>(find.byKey(const ValueKey('tv-player-title')))
                  .style!
                  .fontSize,
              22,
            );
          }
          final sourceContext = tester.element(
            find.byKey(const ValueKey('tv-full-player-source')),
          );
          expect(MediaQuery.devicePixelRatioOf(sourceContext), dpr);
          expect(MediaQuery.textScalerOf(sourceContext).scale(16), 16 * scale);
          expect(
            MediaQuery.navigationModeOf(sourceContext),
            NavigationMode.directional,
          );
          expect(tester.takeException(), isNull);
          for (final tab in [1, 2, 3, 0]) {
            final button = find.byKey(ValueKey('tv-player-tab-$tab'));
            await tester.ensureVisible(button);
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'tab=$tab');
            expect(
              tester.getSize(find.byType(TabBarView)).height,
              greaterThan(80),
            );
          }
          final controls = tester.getRect(
            find.byKey(const ValueKey('windows-full-player-controls')),
          );
          expect(controls.bottom, lessThanOrEqualTo(540 - 21.6 + .01));
          expect(find.byType(SlovofonBottomNavigationBar), findsNothing);
          expect(find.byType(MiniPlayerBar), findsNothing);
        });
      }
    }
  }

  testWidgets('TV D-pad enters bookmarks and Up returns to selected tab', (
    tester,
  ) async {
    await _pump(tester);
    final tab = tester.widget<TextButton>(
      find.byKey(const ValueKey('tv-player-tab-2')),
    );
    tab.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final add = find.byKey(const ValueKey('player-bookmark-add'));
    expect(_primaryFocusIsWithin(tester.element(add)), isTrue);
    expect(
      tester.widget<TabBarView>(find.byType(TabBarView)).controller!.index,
      2,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(tab.focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final doneAction in [true, false]) {
    testWidgets(
      'TV bookmark ${doneAction ? 'IME Done' : 'Down after IME'} focuses Save without Tab',
      (tester) async {
        final fixture = await _pump(tester);
        await tester.tap(find.byKey(const ValueKey('tv-player-tab-2')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('player-bookmark-add')));
        await tester.pumpAndSettle();
        final note = find.byKey(const ValueKey('player-bookmark-note'));
        final field = tester.widget<TextField>(note);
        expect(field.textInputAction, TextInputAction.done);
        await tester.enterText(note, 'Ночь вторая');
        if (doneAction) {
          await tester.testTextInput.receiveAction(TextInputAction.done);
        } else {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        }
        await tester.pumpAndSettle();
        final save = tester.widget<FilledButton>(
          find.byKey(const ValueKey('player-bookmark-save')),
        );
        expect(save.focusNode!.hasFocus, isTrue);
        expect(
          find.byKey(const ValueKey('player-bookmark-save')).hitTestable(),
          findsOneWidget,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(fixture.bookmarks.entries.single.note, 'Ночь вторая');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'TV bookmark Down stays in editor while Dialog consumes visible IME inset',
    (tester) async {
      final fixture = await _pump(tester);
      addTearDown(tester.view.resetViewInsets);
      await tester.tap(find.byKey(const ValueKey('tv-player-tab-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('player-bookmark-add')));
      await tester.pumpAndSettle();
      final note = find.byKey(const ValueKey('player-bookmark-note'));
      await tester.enterText(note, 'Ночь вторая');
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(note);
      final save = tester.widget<FilledButton>(
        find.byKey(const ValueKey('player-bookmark-save')),
      );
      final context = tester.element(note);
      // Guard the actual bug precondition: the dialog's MediaQuery says zero,
      // although the view (physical pixels) reports an open keyboard.
      expect(MediaQuery.viewInsetsOf(context).bottom, 0);
      expect(View.of(context).viewInsets.bottom, 320);
      expect(field.focusNode!.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(field.focusNode!.hasFocus, isTrue);
      expect(save.focusNode!.hasFocus, isFalse);
      expect(field.controller!.text, 'Ночь вторая');
      expect(fixture.bookmarks.entries, isEmpty);
      expect(tester.takeException(), isNull);

      // Back may hide Android's IME without submitting or unfocusing the editor.
      tester.testTextInput.hide();
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(save.focusNode!.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final route in ['/saved', '/legacy']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('TV root details $route retain TV shell at scale=$scale', (
        tester,
      ) async {
        final fixture = await _pump(tester, scale: scale);
        fixture.router.go(route);
        await tester.pumpAndSettle();
        expect(find.byType(TelevisionStandaloneShell), findsOneWidget);
        expect(
          find.byKey(const ValueKey('television-book-summary')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('television-details-artwork')),
          findsOneWidget,
        );
        expect(find.byType(SlovofonBottomNavigationBar), findsNothing);
        expect(find.byType(MiniPlayerBar), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('TV source loading and error remain inside TV root frame', (
    tester,
  ) async {
    final pending = _PendingCatalog();
    final fixture = await _pump(tester, catalog: pending);
    fixture.router.go('/source');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TelevisionStandaloneShell), findsOneWidget);
    expect(find.byType(SlovofonBottomNavigationBar), findsNothing);
    expect(find.byType(MiniPlayerBar), findsNothing);
    pending.result.completeError(StateError('Fixture error'));
    await tester.pumpAndSettle();
    expect(find.byType(TelevisionStandaloneShell), findsOneWidget);
    expect(find.byType(SlovofonBottomNavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [true, false]) {
    testWidgets('TV selected tabs and Play retain focus contrast dark=$dark', (
      tester,
    ) async {
      await _pump(tester, dark: dark);
      final finder = find.byKey(const ValueKey('tv-player-tab-0'));
      final tab = tester.widget<TextButton>(finder);
      final colors = Theme.of(tester.element(finder)).colorScheme;
      final focused = {WidgetState.focused};
      expect(tab.style!.backgroundColor!.resolve(focused), colors.primary);
      expect(tab.style!.foregroundColor!.resolve(focused), colors.onPrimary);
      expect(tab.style!.foregroundColor!.resolve({}), colors.onSurface);
      final play = tester.widget<IconButton>(
        find.byKey(const ValueKey('tv-full-player-toggle')),
      );
      expect(play.style!.side!.resolve(focused)!.color, colors.onPrimary);
      expect(play.style!.side!.resolve(focused)!.width, 2);
      expect(play.style!.side!.resolve({})!.width, 1);

      await tester.tap(find.byKey(const ValueKey('tv-player-tab-1')));
      await tester.pumpAndSettle();
      final chapters = tester.widget<ListView>(
        find.byKey(const ValueKey('full-player-chapters-list')),
      );
      chapters.controller!.jumpTo(
        chapters.controller!.position.maxScrollExtent,
      );
      await tester.pumpAndSettle();
      final currentFinder = find.byKey(
        const ValueKey('full-player-current-chapter-button'),
      );
      final current = tester.widget<TextButton>(currentFinder);
      expect(current.style?.foregroundColor, isNull);
      expect(current.style?.backgroundColor, isNull);
      final inherited = TextButtonTheme.of(
        tester.element(currentFinder),
      ).style!;
      expect(inherited.backgroundColor!.resolve(focused), colors.primary);
      expect(inherited.foregroundColor!.resolve(focused), colors.onPrimary);
      expect(inherited.foregroundColor!.resolve({}), colors.onSurface);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TV source links inherit readable focused state dark=$dark', (
      tester,
    ) async {
      final pending = _PendingCatalog();
      final fixture = await _pump(tester, dark: dark, catalog: pending);
      final catalog = SourceCatalogService(
        registry: SourceRegistry([MockSourceConnector.yakniga()]),
      );
      pending.result.complete(
        await catalog.loadBook(
          SourceBookRef(
            sourceId: activeMockBook.sourceId,
            sourceBookId: activeMockBook.id,
          ),
        ),
      );
      fixture.router.go('/source');
      await tester.pumpAndSettle();
      expect(find.byType(TelevisionStandaloneShell), findsOneWidget);
      for (final key in [
        'tv-source-details-url',
        'tv-source-details-author-0',
        'tv-source-details-narrator-0',
        'tv-source-details-series-0',
        'source-details-description-toggle',
      ]) {
        // This is a lazy SliverList. Restore the initial viewport before looking
        // up an earlier fact which may have been disposed after the last scroll.
        tester
            .widget<CustomScrollView>(
              find.byKey(const ValueKey('desktop-details-scroll')),
            )
            .controller!
            .jumpTo(0);
        await tester.pumpAndSettle();
        final finder = find.byKey(ValueKey(key));
        expect(finder, findsOneWidget, reason: key);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        final button = tester.widget<TextButton>(finder);
        final context = tester.element(finder);
        final themeStyle = TextButtonTheme.of(context).style!;
        final colors = Theme.of(context).colorScheme;
        final focused = {WidgetState.focused};
        expect(button.style?.foregroundColor, isNull, reason: key);
        expect(button.style?.backgroundColor, isNull, reason: key);
        expect(
          themeStyle.backgroundColor!.resolve(focused),
          colors.primary,
          reason: key,
        );
        expect(
          themeStyle.foregroundColor!.resolve(focused),
          colors.onPrimary,
          reason: key,
        );
        expect((button.child! as Text).style?.color, isNull, reason: key);
        final padding =
            button.style?.padding?.resolve({}) ??
            themeStyle.padding!.resolve({})!;
        expect(
          padding.resolve(TextDirection.ltr).horizontal,
          greaterThanOrEqualTo(16),
        );
        expect(tester.takeException(), isNull, reason: key);
      }
    });
  }

  for (final television in [true, false]) {
    for (final direction in TextDirection.values) {
      testWidgets('Details split follows $direction TV=$television', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark().copyWith(platform: TargetPlatform.windows),
            home: Directionality(
              textDirection: direction,
              child: TelevisionLayout(
                enabled: television,
                child: const Scaffold(
                  body: DesktopBookDetailsLayout(
                    summary: SizedBox(height: 160, child: Text('Summary')),
                    contentSlivers: [
                      SliverToBoxAdapter(
                        child: SizedBox(
                          key: ValueKey('details-content-probe'),
                          height: 200,
                          child: Text('Chapters'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('desktop-details-split')),
          findsOneWidget,
        );
        final summary = tester.getRect(
          find.byKey(const ValueKey('desktop-details-summary')),
        );
        final content = tester.getRect(
          find.byKey(const ValueKey('details-content-probe')),
        );
        expect(summary.top, content.top);
        final actualGap = direction == TextDirection.rtl
            ? summary.left - content.right
            : content.left - summary.right;
        expect(actualGap, closeTo(television ? 16 : 32, .01));
        expect(tester.takeException(), isNull);
      });
    }
  }
}

bool _primaryFocusIsWithin(Element ancestor) {
  var inside = false;
  FocusManager.instance.primaryFocus?.context?.visitAncestorElements((element) {
    if (identical(element, ancestor)) {
      inside = true;
      return false;
    }
    return true;
  });
  return inside;
}

Future<
  ({PlaybackController controller, GoRouter router, BookmarkStore bookmarks})
>
_pump(
  WidgetTester tester, {
  double dpr = 2,
  double scale = 1,
  bool dark = true,
  bool television = true,
  Size logicalSize = const Size(960, 540),
  String title = 'Белые ночи',
  SourceCatalogService? catalog,
}) async {
  tester.view.physicalSize = logicalSize * dpr;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = PlaybackController(engine: InMemoryAudioEngine());
  addTearDown(controller.dispose);
  final book = AudioPlaybackBook(
    id: 'tv-player-book',
    versionId: 'tv-player-version',
    sourceId: 'izib',
    sourceBookId: 'tv-player-book',
    sourceName: 'Izib',
    title: title,
    author: 'Федор Достоевский',
    narrator: 'Василий Дахненко',
    chapters: [
      for (var i = 0; i < 12; i++)
        AudioPlaybackChapter(
          id: 'chapter-$i',
          index: i,
          title: '03-noch-vtoraja-part-$i-long-file-name.mp3',
          duration: const Duration(minutes: 12),
        ),
    ],
  );
  await controller.loadBook(
    book,
    chapterIndex: 2,
    position: const Duration(minutes: 4, seconds: 1),
    autoPlay: false,
  );
  final bookmarks = BookmarkStore(MemoryBookmarkPersistence());
  await bookmarks.load();
  final storage = _MemoryStorage();
  final manager = DownloadManager(
    client: _NoNetworkClient(),
    storage: storage,
    persistence: MemoryDownloadPersistenceStore(),
  );
  final router = GoRouter(
    initialLocation: '/player',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(path: '/player', builder: (_, _) => const FullPlayerScreen()),
      GoRoute(
        path: '/saved',
        builder: (_, _) =>
            const SavedBookDetailsScreen(bookId: 'tv-player-book'),
      ),
      GoRoute(
        path: '/legacy',
        builder: (_, _) => BookDetailsScreen(book: activeMockBook),
      ),
      GoRoute(
        path: '/source',
        builder: (_, _) => const SourceBookDetailsScreen(
          ref: SourceBookRef(sourceId: 'izib', sourceBookId: 'pending'),
        ),
      ),
      for (final route in ['/search', '/library', '/downloads', '/settings'])
        GoRoute(
          path: route,
          builder: (_, _) => const Scaffold(body: Text('Destination')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playbackControllerProvider.overrideWith((ref) => controller),
        bookmarkStoreProvider.overrideWith((ref) => bookmarks),
        downloadManagerProvider.overrideWith((ref) => manager),
        downloadStorageProvider.overrideWithValue(storage),
        libraryPlaybackBooksProvider.overrideWith((ref) async => [book]),
        if (catalog != null)
          sourceCatalogServiceProvider.overrideWithValue(catalog),
      ],
      child: MaterialApp.router(
        theme:
            (television
                    ? TelevisionTheme.from(
                        dark ? AppTheme.dark() : AppTheme.light(),
                      )
                    : dark
                    ? AppTheme.dark()
                    : AppTheme.light())
                .copyWith(platform: TargetPlatform.android),
        routerConfig: router,
        locale: const Locale('ru'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: TelevisionLayout(
            enabled: television,
            child: television ? TelevisionViewport(child: child!) : child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (controller: controller, router: router, bookmarks: bookmarks);
}

class _NoNetworkClient implements DownloadClient {
  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async => throw StateError('TV layout tests do not access media');
}

class _MemoryStorage extends FileDownloadStorage {
  _MemoryStorage() : super(rootDirectory: Directory('unused-tv-player-test'));
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

class _PendingCatalog extends SourceCatalogService {
  _PendingCatalog() : super(registry: SourceRegistry([]));
  final result = Completer<SourceBookSnapshot>();
  @override
  Future<SourceBookSnapshot> loadBook(
    SourceBookRef ref, {
    bool forceRefresh = false,
    MediaResolvePurpose purpose = MediaResolvePurpose.playback,
  }) => result.future;
}
