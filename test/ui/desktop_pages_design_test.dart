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
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/features/downloads/downloads_screen.dart';
import 'package:slovofon/features/home/home_screen.dart';
import 'package:slovofon/features/library/library_screen.dart';
import 'package:slovofon/features/search/search_screen.dart';
import 'package:slovofon/features/settings/settings_screen.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/search/search_history_store.dart';
import 'package:slovofon/services/library/library_store.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/services/sources/source_settings_store.dart';
import 'package:slovofon/sources/sources.dart';
import 'package:slovofon/ui/adaptive/desktop_layout.dart';
import 'package:slovofon/ui/adaptive/slovofon_shell.dart';
import 'package:slovofon/ui/components/book_card.dart';

import 'test_search_history_store.dart';

const _pages = <Widget>[
  HomeScreen(),
  SearchScreen(),
  LibraryScreen(),
  DownloadsScreen(),
  SettingsScreen(),
];

void main() {
  for (final width in [900.0, 1440.0]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 1.3, 2.6]) {
        testWidgets('Windows pages fit width $width dark $dark text $scale', (
          tester,
        ) async {
          for (final page in _pages) {
            await _pumpPage(
              tester,
              page,
              width: width,
              dark: dark,
              scale: scale,
              locale: dark ? const Locale('ru') : const Locale('en'),
            );
            expect(find.byType(DesktopPageHeader), findsOneWidget);
            expect(tester.takeException(), isNull, reason: '$page');
            // Also lay out the bottom settings group at enlarged font sizes.
            if (page is SettingsScreen) {
              await tester.scrollUntilVisible(
                find.byKey(const ValueKey('settings-group-application')),
                300,
                scrollable: find.byType(Scrollable).first,
              );
              expect(tester.takeException(), isNull);
            }
            await tester.pumpWidget(const SizedBox.shrink());
          }
        });
      }
    }
  }

  for (final profile in [
    (TargetPlatform.android, 430.0),
    (TargetPlatform.android, 1440.0),
    (TargetPlatform.windows, 899.0),
  ]) {
    testWidgets('page presentation follows platform for $profile', (
      tester,
    ) async {
      for (final page in _pages) {
        await _pumpPage(
          tester,
          page,
          platform: profile.$1,
          width: profile.$2,
          sidebarWidth: 0,
        );
        final desktop = profile.$1 == TargetPlatform.windows;
        expect(
          find.byType(DesktopPageHeader),
          desktop ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const ValueKey('desktop-library-shelves')),
          desktop && page is LibraryScreen ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const ValueKey('desktop-search-controls')),
          desktop && page is SearchScreen ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const ValueKey('settings-desktop-content')),
          desktop && page is SettingsScreen ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }

  testWidgets('Windows search and settings use the wide workspace', (
    tester,
  ) async {
    await _pumpPage(tester, const SearchScreen(), width: 1920);
    final primary = tester.getRect(
      find.byKey(const ValueKey('desktop-search-controls')),
    );
    final secondary = tester.getRect(
      find.byKey(const ValueKey('desktop-search-secondary')),
    );
    expect(primary.left, 220 + 32);
    expect(primary.right, 1920 - 32);
    expect(secondary.right, 1920 - 32);
    expect(secondary.left, primary.left);
    expect(secondary.top - primary.bottom, 24);
    expect(primary.width, greaterThan(820));
    await _pumpPage(tester, const SettingsScreen(), width: 1920);
    final bounds = tester.getRect(
      find.byKey(const ValueKey('settings-desktop-content')),
    );
    expect(bounds.left, 220 + 32);
    expect(bounds.right, 1920 - 32);
    expect(bounds.width, greaterThan(1040));
    expect(tester.takeException(), isNull);
  });

  for (final scale in [.75, 1.0, 2.0, 3.0]) {
    testWidgets(
      'Windows empty search has no artificial gap at text scale $scale',
      (tester) async {
        for (final width in [900.0, 1280.0, 1920.0]) {
          for (final dark in [false, true]) {
            await _pumpPage(
              tester,
              const SearchScreen(),
              width: width,
              scale: scale,
              dark: dark,
            );
            final controls = tester.getRect(
              find.byKey(const ValueKey('desktop-search-controls')),
            );
            final history = tester.getRect(
              find.byKey(const ValueKey('desktop-search-history')),
            );
            final sources = tester.getRect(
              find.byKey(const ValueKey('desktop-search-sources')),
            );
            expect(controls.left, 252);
            expect(controls.right, width - 32);
            expect(history.top - controls.bottom, closeTo(24, .01));
            expect(history.left, controls.left);
            expect(
              find.byKey(const ValueKey('desktop-search-ready')),
              findsNothing,
            );
            expect(find.text('Enter a search query'), findsNothing);
            final factor = (1 + .3 * (scale - 1)).clamp(1.0, 2.0);
            if (controls.width >= 2 * 360 * factor + 24) {
              expect(sources.top, history.top);
              expect(sources.left - history.right, closeTo(24, .01));
              expect(sources.width, history.width);
            } else {
              expect(sources.top - history.bottom, closeTo(24, .01));
              expect(sources.left, history.left);
            }
            expect(sources.right, controls.right);
            // Do not stretch the short history panel to the taller source list.
            expect(history.height, lessThan(sources.height));
            final title = tester.renderObject<RenderParagraph>(
              find.text('Recent searches'),
            );
            final fontSize = title.text.style!.fontSize!;
            expect(
              title.textScaler.scale(fontSize),
              closeTo(fontSize * scale, .001),
            );
            expect(tester.takeException(), isNull);
          }
        }
      },
    );
  }

  testWidgets('Windows library shelves select inline without a modal', (
    tester,
  ) async {
    await _pumpPage(tester, const LibraryScreen());
    final shelves = find.byKey(const ValueKey('desktop-library-shelves'));
    expect(
      find.descendant(of: shelves, matching: find.byType(ChoiceChip)),
      findsNWidgets(8),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Favorites'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Favorites'))
          .selected,
      isTrue,
    );
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets(
    'Windows search keeps the query visible and returns to its form',
    (tester) async {
      const query = 'Long audiobook title for a focused desktop search';
      await _pumpPage(tester, const SearchScreen(), width: 900, scale: 2.6);
      await tester.enterText(find.byType(TextField), query);
      await tester.tap(find.byKey(const ValueKey('search-submit')));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.byKey(const ValueKey('desktop-search-results-heading')),
        findsOneWidget,
      );
      expect(find.widgetWithText(DesktopPageHeader, 'Search'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('desktop-search-controls')),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        query,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [.75, 1.0, 2.0, 3.0]) {
    testWidgets('Windows settings groups reflow at real text scale $scale', (
      tester,
    ) async {
      for (final width in [900.0, 1280.0, 1920.0, 2560.0]) {
        await _pumpPage(
          tester,
          const SettingsScreen(),
          width: width,
          scale: scale,
        );
        final primary = tester.getRect(
          find.byKey(const ValueKey('settings-desktop-primary')),
        );
        final secondary = tester.getRect(
          find.byKey(const ValueKey('settings-desktop-secondary')),
        );
        final bounds = [
          for (final group in ['personalization', 'content', 'application'])
            tester.getRect(find.byKey(ValueKey('settings-group-$group'))),
        ];
        final factor = (1 + .3 * (scale - 1)).clamp(1.0, 2.0);
        final available = width - 220 - 64;
        final sideWidth = ((available - 24) / 2).clamp(
          360 * factor,
          double.infinity,
        );
        final split = available >= 420 * factor + sideWidth + 24;
        expect(primary.left, 252);
        if (split) {
          expect(secondary.top, primary.top);
          expect(secondary.left - primary.right, closeTo(24, .01));
          expect(secondary.width, closeTo(sideWidth, .01));
        } else {
          expect(secondary.top - primary.bottom, closeTo(24, .01));
          expect(primary.width, closeTo(available, .01));
          expect(secondary.width, closeTo(available, .01));
        }
        expect(secondary.right, closeTo(width - 32, .01));
        for (var index = 0; index < bounds.length; index++) {
          expect(bounds[index].left, secondary.left);
          expect(bounds[index].width, closeTo(secondary.width, .01));
          if (index > 0) {
            expect(
              bounds[index].top - bounds[index - 1].bottom,
              closeTo(16, .01),
            );
          }
        }
        expect(
          find.byKey(const ValueKey('settings-appearance-editor')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('appearance-text-scale-slider')),
          findsOneWidget,
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text('Personalization'),
        );
        final fontSize = paragraph.text.style!.fontSize!;
        expect(
          paragraph.textScaler.scale(fontSize),
          closeTo(fontSize * scale, .001),
        );
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets(
    'Windows search repeats/deletes real history and follows enabled sources',
    (tester) async {
      final history = MemorySearchHistoryStore();
      await history.record('Earlier query', SearchKind.author);
      final sources = SourceSettingsStore(
        MemorySourceSettingsPersistenceStore(),
      );
      await sources.setEnabledSources({'akniga', 'yakniga'});
      final catalog = _SearchWorkspaceCatalog();
      await _pumpPage(
        tester,
        const SearchScreen(),
        width: 1920,
        historyStore: history,
        sourceSettings: sources,
        catalog: catalog,
      );
      expect(
        find.byKey(const ValueKey('desktop-search-source-akniga')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('desktop-search-source-izib')),
        findsNothing,
      );
      await sources.setEnabledSources({'izib'});
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('desktop-search-source-izib')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('desktop-search-source-akniga')),
        findsNothing,
      );
      final historyPanel = find.byKey(const ValueKey('desktop-search-history'));
      await tester.tap(
        find.descendant(of: historyPanel, matching: find.text('Earlier query')),
      );
      await tester.pumpAndSettle();
      expect(catalog.requests, hasLength(1));
      expect(catalog.requests.single.query, 'Earlier query');
      expect(catalog.requests.single.kind, SearchKind.author);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Earlier query',
      );
      await tester.ensureVisible(
        find.descendant(
          of: historyPanel,
          matching: find.byTooltip('Delete from history'),
        ),
      );
      await tester.tap(
        find.descendant(
          of: historyPanel,
          matching: find.byTooltip('Delete from history'),
        ),
      );
      await tester.pumpAndSettle();
      expect(await history.load(), isEmpty);
      expect(
        find.descendant(of: historyPanel, matching: find.text('Earlier query')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets(
      'Windows search preserves query and fills result rows on resize scale $scale',
      (tester) async {
        final catalog = _SearchWorkspaceCatalog();
        await _pumpPage(
          tester,
          const SearchScreen(),
          width: 2560,
          scale: scale,
          catalog: catalog,
        );
        await tester.enterText(find.byType(TextField), 'Audiobook');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(catalog.requests, hasLength(1));
        expect(find.byType(BookCard), findsNWidgets(2));
        for (final width in [1920.0, 1280.0, 2560.0]) {
          tester.view.physicalSize = Size(width, 1000);
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'Audiobook',
          );
          expect(catalog.requests, hasLength(1));
          expect(find.byType(BookCard), findsNWidgets(2));
          final primary = tester.getRect(
            find.byKey(const ValueKey('desktop-search-primary')),
          );
          final secondary = tester.getRect(
            find.byKey(const ValueKey('desktop-search-secondary')),
          );
          final factor = (1 + .3 * (scale - 1)).clamp(1.0, 2.0);
          final controls = tester.getRect(
            find.byKey(const ValueKey('desktop-search-controls')),
          );
          expect(controls.left, 252);
          expect(controls.right, width - 32);
          expect(primary.top - controls.bottom, closeTo(12, .01));
          final sideWidth = 340 * (1 + .3 * (scale - 1)).clamp(1.0, 2.0);
          if (width - 284 >= 620 * factor + sideWidth + 24) {
            expect(secondary.top, primary.top);
            expect(secondary.left - primary.right, closeTo(24, .01));
          } else {
            expect(secondary.top - primary.bottom, closeTo(24, .01));
          }

          expect(
            tester.getSize(find.byType(BookCard).first).width,
            closeTo(primary.width, .01),
          );
          expect(tester.takeException(), isNull);
        }
        await tester.ensureVisible(find.byKey(const ValueKey('search-submit')));
        await tester.enterText(find.byType(TextField), 'Refined query');
        // Focusing the scaled field may scroll its caret into view. Wait for
        // that first, then center the actual submit target before pointer tap.
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(
          tester.element(find.byKey(const ValueKey('search-submit'))),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('search-submit')));
        await tester.pumpAndSettle();
        expect(catalog.requests, hasLength(2));
        expect(catalog.requests.last.query, 'Refined query');
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Windows 15 search results fill complete rows at scale $scale',
      (tester) async {
        for (final width in [1267.0, 1920.0]) {
          for (final dark in [false, true]) {
            final catalog = _SearchWorkspaceCatalog(resultCount: 15);
            await _pumpPage(
              tester,
              const SearchScreen(),
              width: width,
              sidebarWidth: 244,
              scale: scale,
              dark: dark,
              catalog: catalog,
            );
            await tester.enterText(find.byType(TextField), 'Audiobook');
            await tester.testTextInput.receiveAction(TextInputAction.search);
            await tester.pumpAndSettle();
            expect(find.byType(BookCard), findsNWidgets(15));
            final controls = tester.getRect(
              find.byKey(const ValueKey('desktop-search-controls')),
            );
            final primary = tester.getRect(
              find.byKey(const ValueKey('desktop-search-primary')),
            );
            final secondary = tester.getRect(
              find.byKey(const ValueKey('desktop-search-secondary')),
            );
            expect(controls.width, width - 244 - 64);
            expect(primary.top - controls.bottom, closeTo(12, .01));
            for (var index = 0; index < 15; index++) {
              final card = tester.getRect(find.byType(BookCard).at(index));
              expect(card.left, primary.left);
              expect(card.right, closeTo(primary.right, .01));
              expect(
                tester
                    .widget<BookCard>(find.byType(BookCard).at(index))
                    .desktopPresentation,
                DesktopBookPresentation.result,
              );
              if (index > 0) {
                final previous = tester.getRect(
                  find.byType(BookCard).at(index - 1),
                );
                expect(card.top - previous.bottom, closeTo(12, .01));
              }
            }
            final factor = (1 + .3 * (scale - 1)).clamp(1.0, 2.0);
            if (controls.width >= (620 + 340) * factor + 24) {
              expect(secondary.top, primary.top);
              expect(secondary.left - primary.right, closeTo(24, .01));
            } else {
              expect(secondary.top - primary.bottom, closeTo(24, .01));
            }
            expect(tester.takeException(), isNull);
          }
        }
      },
    );
  }

  for (final width in [900.0, 1024.0, 1920.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'first search actions are visible above actual dock $width/$dark',
        (tester) async {
          await _pumpPage(
            tester,
            const SearchScreen(
              initialQuery: 'Audiobook',
              submitInitialSearch: true,
            ),
            width: width,
            height: 600,
            actualShell: true,
            dark: dark,
            catalog: _SearchWorkspaceCatalog(),
          );
          final play = tester.getRect(
            find.byKey(const ValueKey('book-card-play-akniga-0')),
          );
          final download = tester.getRect(
            find.byKey(const ValueKey('book-card-download-akniga-0')),
          );
          final dock = tester.getRect(
            find.byKey(const ValueKey('windows-playback-dock')),
          );
          expect(play.bottom, lessThan(dock.top));
          expect(download.bottom, lessThan(dock.top));
          expect(play.top, greaterThan(0));
          expect(
            find.byWidgetPredicate(
              (widget) => widget is Text && widget.data == 'Audiobook',
            ),
            findsOneWidget,
          ); // History only; no repeated result heading.
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'partial search names failed sources and retries original query',
    (tester) async {
      final catalog = _SearchWorkspaceCatalog(
        failures: const [
          SourceFailure(
            sourceId: 'izib',
            kind: SourceErrorKind.unknown,
            message: 'private low-level detail',
          ),
        ],
      );
      await _pumpPage(
        tester,
        const SearchScreen(
          initialQuery: 'Audiobook',
          submitInitialSearch: true,
        ),
        width: 1920,
        catalog: catalog,
      );
      expect(find.byType(BookCard), findsNWidgets(2));
      expect(find.textContaining('private low-level detail'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('search-source-failures')),
          matching: find.textContaining(
            AppStrings.forLocale(const Locale('en')).sourceDisplayName('izib'),
          ),
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'Not submitted');
      await tester.tap(find.byKey(const ValueKey('search-retry')));
      await tester.pumpAndSettle();
      expect(catalog.requests, hasLength(2));
      expect(catalog.requests.last.query, 'Audiobook');
      expect(find.byType(BookCard), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search book menu saves and removes Later without changing Favorites',
    (tester) async {
      final library = LibraryStore(MemoryLibraryPersistenceStore());
      await library.load();
      await _pumpPage(
        tester,
        const SearchScreen(
          initialQuery: 'Audiobook',
          submitInitialSearch: true,
        ),
        width: 1920,
        catalog: _SearchWorkspaceCatalog(),
        library: library,
      );
      final menu = find.byKey(const ValueKey('book-card-more-akniga-0'));
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen later'));
      await tester.pumpAndSettle();
      expect(library.later, hasLength(1));
      expect(library.favorites, isEmpty);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from listen later'));
      await tester.pumpAndSettle();
      expect(library.later, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  for (final language in ['ru', 'en']) {
    testWidgets('Windows grouped About keeps GitHub in $language', (
      tester,
    ) async {
      await _pumpPage(tester, const SettingsScreen(), locale: Locale(language));
      final strings = AppStrings.forLocale(Locale(language));
      expect(
        find.byKey(const ValueKey('settings-group-personalization')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings-group-content')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings-group-application')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text(strings.aboutApp));
      await tester.tap(find.text(strings.aboutApp));
      await tester.pumpAndSettle();
      expect(find.text('https://github.com/Dushnyj/Slovofon'), findsOneWidget);
      expect(find.textContaining('t.me/'), findsNothing);
      expect(find.text('Сайт проекта'), findsNothing);
      expect(find.text('Project website'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final dark in [false, true]) {
    testWidgets('Windows populated downloads stay readable dark $dark', (
      tester,
    ) async {
      for (final width in [900.0, 1280.0]) {
        await _pumpPage(
          tester,
          const DownloadsScreen(),
          width: width,
          dark: dark,
          scale: 2.6,
          locale: const Locale('ru'),
          downloadManager: _PopulatedDownloads(),
        );
        expect(find.byType(ExpansionTile), findsNWidgets(3));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}

Future<void> _pumpPage(
  WidgetTester tester,
  Widget page, {
  double width = 1440,
  double height = 1000,
  bool actualShell = false,
  double sidebarWidth = 220,
  bool dark = false,
  double scale = 1,
  TargetPlatform platform = TargetPlatform.windows,
  Locale locale = const Locale('en'),
  DownloadManager? downloadManager,
  SearchHistoryStore? historyStore,
  SourceSettingsStore? sourceSettings,
  SourceCatalogService? catalog,
  LibraryStore? library,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = PlaybackController(engine: InMemoryAudioEngine());
  addTearDown(controller.dispose);
  if (actualShell) {
    await controller.loadBook(
      const AudioPlaybackBook(
        id: 'playing',
        versionId: 'playing-version',
        sourceId: 'izib',
        title: 'Current book',
        author: 'Current author',
        narrator: 'Current narrator',
        sourceName: 'Изибук',
        chapters: [
          AudioPlaybackChapter(
            id: 'c1',
            index: 0,
            title: 'Chapter 1',
            duration: Duration(minutes: 10),
          ),
        ],
      ),
      autoPlay: false,
    );
  }
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
        builder: (context, state) => actualShell
            ? DesktopStandaloneShell(selectedIndex: 1, child: page)
            : Scaffold(
                body: Row(
                  children: [
                    SizedBox(width: sidebarWidth),
                    Expanded(child: page),
                  ],
                ),
              ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        playbackControllerProvider.overrideWith((ref) => controller),
        if (library != null)
          libraryStoreProvider.overrideWith((ref) => library),
        downloadStorageProvider.overrideWith((ref) => _MemoryStorage()),
        if (downloadManager != null)
          downloadManagerProvider.overrideWith((ref) => downloadManager),
        searchHistoryStoreProvider.overrideWith(
          (ref) => historyStore ?? MemorySearchHistoryStore(),
        ),
        sourceRegistryProvider.overrideWith((ref) => SourceRegistry([])),
        if (sourceSettings != null)
          sourceSettingsStoreProvider.overrideWith((ref) => sourceSettings),
        if (catalog != null)
          sourceCatalogServiceProvider.overrideWith((ref) => catalog),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: theme,
        locale: locale,
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
}

class _MemoryStorage extends FileDownloadStorage {
  _MemoryStorage()
    : super(rootDirectory: Directory('desktop-design-memory-only'));

  @override
  Future<CardCacheStats> cardCacheStats() async =>
      const CardCacheStats(bytes: 0, bookCount: 0);

  @override
  Future<List<AudioPlaybackBook>> readAllMetadata() async => const [];
}

class _PopulatedDownloads extends DownloadManager {
  _PopulatedDownloads()
    : super(
        client: DefaultDownloadClient(),
        storage: _MemoryStorage(),
        persistence: MemoryDownloadPersistenceStore(),
      );

  static const _chapter = AudioPlaybackChapter(
    id: 'chapter-1',
    index: 0,
    title: 'Глава первая',
    duration: Duration(hours: 12, minutes: 30),
  );

  @override
  List<DownloadTask> get tasks => [
    for (var index = 0; index < 3; index++)
      DownloadTask(
        id: 'download-$index',
        bookId: 'book-$index',
        bookVersionId: 'version-$index',
        chapterId: _chapter.id,
        sourceId: 'baza_knig',
        type: DownloadTaskType.chapter,
        status: DownloadTaskStatus.completed,
        progress: 1,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
  ];

  @override
  AudioPlaybackBook bookForTask(String taskId) {
    final index = int.parse(taskId.split('-').last);
    return AudioPlaybackBook(
      id: 'book-$index',
      versionId: 'version-$index',
      sourceId: 'baza_knig',
      title: 'Путешествие к центру Земли $index',
      author: 'Жюль Верн',
      narrator: 'Александр Константинович',
      sourceName: 'База книг',
      chapters: const [_chapter],
    );
  }
}

class _SearchWorkspaceCatalog extends SourceCatalogService {
  _SearchWorkspaceCatalog({this.resultCount = 2, this.failures = const []})
    : super(registry: SourceRegistry([]));

  final int resultCount;
  final List<SourceFailure> failures;
  final requests = <SearchRequest>[];

  @override
  Future<SourceSearchResponse> search(SearchRequest request) async {
    requests.add(request);
    return SourceSearchResponse(
      failures: failures,
      results: [
        for (var index = 0; index < resultCount; index++)
          BookSearchResult(
            ref: SourceBookRef(
              sourceId: index.isEven ? 'akniga' : 'yakniga',
              sourceBookId: '$index',
            ),
            sourceName: index.isEven ? 'Akniga' : 'Yakniga',
            title: 'Audiobook ${index + 1}',
            author: 'Author',
            narrator: 'Narrator',
          ),
      ],
    );
  }
}
