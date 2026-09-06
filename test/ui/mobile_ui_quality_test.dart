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
import 'package:slovofon/domain/models/audio_book.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/features/library/library_screen.dart';
import 'package:slovofon/features/downloads/downloads_screen.dart';
import 'package:slovofon/features/player/full_player_screen.dart';
import 'package:slovofon/features/settings/settings_screen.dart';
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
import 'package:slovofon/services/settings/app_settings_store.dart';
import 'package:slovofon/ui/adaptive/adaptive_sheet.dart';
import 'package:slovofon/ui/adaptive/desktop_layout.dart';
import 'package:slovofon/ui/components/book_card.dart';
import 'package:slovofon/ui/components/filter_picker_sheet.dart';

const _book = AudioBook(
  id: 'phone-book',
  sourceId: 'izib',
  sourceBookId: 'phone-book',
  title: 'A journey through the world',
  author: 'Author',
  narrator: 'Narrator',
  sourceName: 'Izib',
  durationLabel: '1 h 40 min',
  chapterCount: 1,
  progress: .85,
  access: BookAccess.free,
);
const _playbackBook = AudioPlaybackBook(
  id: 'phone-book',
  versionId: 'phone-version',
  sourceId: 'izib',
  sourceBookId: 'phone-book',
  title: 'A journey through the world',
  author: 'Author',
  narrator: 'Narrator',
  sourceName: 'Izib',
  chapters: [
    AudioPlaybackChapter(
      id: 'chapter',
      index: 0,
      title: 'The first chapter',
      duration: Duration(minutes: 100),
    ),
  ],
);
final _strings = AppStrings.forLocale(const Locale('en'));

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    for (final code in ['source_download_disabled', 'unrelated_failure']) {
      testWidgets(
        'download policy message exact code=$code platform=$platform',
        (tester) async {
          _size(
            tester,
            Size(platform == TargetPlatform.windows ? 960 : 390, 1000),
          );
          final manager = _FailedDownloads(errorCode: code);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                downloadManagerProvider.overrideWith((ref) => manager),
                playbackControllerProvider.overrideWith(
                  (ref) => PlaybackController(engine: InMemoryAudioEngine()),
                ),
                playbackProgressSnapshotsProvider.overrideWith(
                  (ref) async => [],
                ),
              ],
              child: _app(
                scale: 2,
                platform: platform,
                child: const DownloadsScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final expected = code == 'source_download_disabled';
          final bookMessage = find.byKey(
            const ValueKey('download-policy-book-izib-phone-version'),
          );
          expect(bookMessage, expected ? findsOneWidget : findsNothing);
          final title = find.text(_playbackBook.title);
          await _reveal(tester, title);
          await tester.tap(title);
          await tester.pumpAndSettle();
          final chapterMessage = find.byKey(
            const ValueKey('download-policy-task-phone-task'),
          );
          expect(chapterMessage, expected ? findsOneWidget : findsNothing);
          if (expected) {
            await _reveal(tester, chapterMessage);
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: chapterMessage, matching: find.byType(Text)),
            );
            expect(
              paragraph.text.toPlainText(),
              _strings.sourceDownloadDisabled,
            );
            expect(paragraph.didExceedMaxLines, isFalse);
            expect(paragraph.textScaler.scale(14), 28);
          }
          expect(
            find.textContaining('sensitive-fixture-payload'),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'download task never guesses a mock book from matching id on $platform',
      (tester) async {
        _size(
          tester,
          Size(platform == TargetPlatform.windows ? 960 : 390, 1000),
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const DownloadsScreen(),
            ),
            GoRoute(
              path: '/search',
              builder: (context, state) =>
                  const Scaffold(body: Text('Search recovery destination')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              downloadManagerProvider.overrideWith(
                (ref) => _MissingMetadataDownloads(),
              ),
              playbackControllerProvider.overrideWith(
                (ref) => PlaybackController(engine: InMemoryAudioEngine()),
              ),
              playbackProgressSnapshotsProvider.overrideWith((ref) async => []),
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
        expect(find.text('Мастер и Маргарита'), findsNothing);
        expect(find.text('Михаил Булгаков'), findsNothing);
        expect(
          find.text(_strings.downloadMetadataUnavailableTitle),
          findsOneWidget,
        );
        final actions = find.byKey(
          const ValueKey('mobile-download-actions-missing-version'),
        );
        final buttons = tester.widgetList<IconButton>(
          find.descendant(of: actions, matching: find.byType(IconButton)),
        );
        expect(
          buttons
              .where((button) => button.tooltip == _strings.play)
              .single
              .onPressed,
          isNull,
        );
        expect(
          buttons
              .where((button) => button.tooltip == _strings.retry)
              .single
              .onPressed,
          isNull,
        );
        expect(
          buttons
              .where((button) => button.tooltip == _strings.deleteDownloaded)
              .single
              .onPressed,
          isNotNull,
        );
        final recover = find.text(_strings.openSearch);
        await _reveal(tester, recover);
        await tester.tap(recover);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/search');
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final failLoad in [false, true]) {
    testWidgets('cache clear awaits persisted downloads failLoad=$failLoad', (
      tester,
    ) async {
      _size(tester, const Size(390, 844));
      final manager = _LoadingDownloads();
      final storage = _MemoryStorage();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            downloadManagerProvider.overrideWith((ref) => manager),
            downloadStorageProvider.overrideWith((ref) => storage),
          ],
          child: _app(child: const SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(_strings.cacheAndMetadata));
      await tester.pumpAndSettle();
      final clear = find.byKey(const ValueKey('cache-clear-action'));
      await _reveal(tester, clear);
      await tester.tap(clear);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byWidgetPredicate((widget) => widget is FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(storage.clears, 0);
      expect(manager.loads, 1);
      if (failLoad) {
        manager.loaded.completeError(
          StateError('Memory fixture task load failed'),
        );
      } else {
        manager.loaded.complete();
      }
      await tester.pumpAndSettle();
      expect(storage.clears, failLoad ? 0 : 1);
      if (failLoad) {
        expect(find.text(_strings.cacheClearFailed), findsOneWidget);
        expect(tester.widget<FilledButton>(clear).onPressed, isNotNull);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(310, 844), const Size(844, 390)]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('Android downloads reflow all actions $size scale=$scale', (
        tester,
      ) async {
        _size(tester, size);
        final manager = _RunningDownloads();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              downloadManagerProvider.overrideWith((ref) => manager),
              playbackControllerProvider.overrideWith(
                (ref) => PlaybackController(engine: InMemoryAudioEngine()),
              ),
              playbackProgressSnapshotsProvider.overrideWith((ref) async => []),
            ],
            child: _app(scale: scale, child: const DownloadsScreen()),
          ),
        );
        await tester.pumpAndSettle();
        final actions = find.byKey(
          const ValueKey('mobile-download-actions-phone-version'),
        );
        expect(actions, findsOneWidget);
        for (final label in [
          _strings.pauseDownload,
          _strings.cancelDownload,
          _strings.play,
          _strings.bookDetails,
        ]) {
          final button = find.descendant(
            of: actions,
            matching: find.byTooltip(label),
          );
          await _reveal(tester, button);
          final bounds = tester.getRect(button);
          expect(bounds.width, greaterThanOrEqualTo(48));
          expect(bounds.height, greaterThanOrEqualTo(48));
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(size.width));
        }
        final pause = find.descendant(
          of: actions,
          matching: find.byTooltip(_strings.pauseDownload),
        );
        await _reveal(tester, pause);
        await tester.tap(pause);
        await tester.pumpAndSettle();
        expect(manager.paused, ['phone-task']);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Android empty full player has real search action $size scale=$scale',
        (tester) async {
          _size(tester, size);
          final router = GoRouter(
            initialLocation: '/player',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) =>
                    const Scaffold(body: Text('Home destination')),
              ),
              GoRoute(
                path: '/player',
                builder: (context, state) => const FullPlayerScreen(),
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
              overrides: [
                downloadManagerProvider.overrideWith(
                  (ref) => _EmptyDownloads(),
                ),
                playbackControllerProvider.overrideWith(
                  (ref) => PlaybackController(engine: InMemoryAudioEngine()),
                ),
              ],
              child: MaterialApp.router(
                routerConfig: router,
                theme: AppTheme.dark().copyWith(
                  platform: TargetPlatform.android,
                ),
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
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.byTooltip(_strings.play), findsNothing);
          expect(find.byType(Slider), findsNothing);
          expect(find.text(_strings.realSourceHomeTitle), findsOneWidget);
          final search = find.byKey(
            const ValueKey('windows-player-empty-search'),
          );
          await _reveal(tester, search);
          await tester.tap(search);
          await tester.pumpAndSettle();
          expect(router.state.uri.path, '/search');
          expect(find.text('Search destination'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final width in [310.0, 430.0, 900.0]) {
    for (final scale in [.75, 2.0, 3.0]) {
      for (final dark in [false, true]) {
        testWidgets(
          'Android card actions stay reachable width=$width scale=$scale dark=$dark',
          (tester) async {
            _size(tester, Size(width, 1000));
            var opens = 0;
            var plays = 0;
            var favorites = 0;
            var downloads = 0;
            final library = LibraryStore(MemoryLibraryPersistenceStore());
            await library.load();
            addTearDown(library.dispose);
            await tester.pumpWidget(
              _app(
                scale: scale,
                dark: dark,
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: ListenableBuilder(
                      listenable: library,
                      builder: (context, _) => BookCard(
                        book: _book,
                        onTap: () => opens++,
                        onPlay: () => plays++,
                        onFavoritePressed: () => favorites++,
                        onDownloadPressed: () => downloads++,
                        isLater: library.isLater(_book),
                        onLaterPressed: () => library.toggleLater(_book),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            for (final action in ['favorite', 'download', 'play', 'more']) {
              final finder = find.byKey(
                ValueKey('book-card-$action-izib-phone-book'),
              );
              await _reveal(tester, finder);
              final box = tester.getRect(finder);
              expect(box.width, greaterThanOrEqualTo(48));
              expect(box.height, greaterThanOrEqualTo(48));
              expect(box.left, greaterThanOrEqualTo(0));
              expect(box.right, lessThanOrEqualTo(width));
              await tester.tap(finder);
              await tester.pumpAndSettle();
            }
            expect(plays, 1);
            expect(favorites, 1);
            expect(downloads, 1);
            expect(opens, 0);
            await tester.tap(find.text(_strings.addToLater));
            await tester.pumpAndSettle();
            expect(library.isLater(_book), isTrue);
            await tester.tap(
              find.byKey(const ValueKey('book-card-more-izib-phone-book')),
            );
            await tester.pumpAndSettle();
            expect(find.text(_strings.removeFromLater), findsOneWidget);
            await tester.tap(find.text(_strings.removeFromLater));
            await tester.pumpAndSettle();
            expect(library.isLater(_book), isFalse);
            final source = find.text(_strings.sourceDisplayName('izib'));
            expect(source, findsOneWidget);
            final paragraph = tester.renderObject<RenderParagraph>(source);
            expect(paragraph.textScaler.scale(14), closeTo(14 * scale, .01));
            expect(paragraph.didExceedMaxLines, isFalse);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('Android library shelf draft survives rotation scale=$scale', (
      tester,
    ) async {
      _size(tester, const Size(390, 844));
      final fixture = await _library(tester, scale: scale);
      await tester.tap(find.byKey(const ValueKey('library-shelf-picker')));
      await tester.pumpAndSettle();
      await _reveal(
        tester,
        find.byKey(const ValueKey('library-shelf-option-6')),
      );
      await tester.tap(find.byKey(const ValueKey('library-shelf-option-6')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<RadioGroup<int>>(find.byType(RadioGroup<int>)).groupValue,
        6,
      );
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(
        tester.widget<RadioGroup<int>>(find.byType(RadioGroup<int>)).groupValue,
        6,
      );
      await _reveal(tester, find.byKey(const ValueKey('library-shelf-apply')));
      await tester.tap(find.byKey(const ValueKey('library-shelf-apply')));
      await tester.pumpAndSettle();
      expect(
        find.text('${_strings.filter}: ${_strings.bookmarks}'),
        findsOneWidget,
      );
      final bookmark = fixture.bookmarks.entries.single;
      final tile = find.byKey(ValueKey('library-bookmark-${bookmark.id}'));
      await _reveal(tester, tile);
      final remove = find.descendant(
        of: tile,
        matching: find.text(_strings.deleteBookmarkAction),
      );
      await _reveal(tester, remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.text(_strings.cancel));
      await tester.pumpAndSettle();
      expect(fixture.bookmarks.entries, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Android library cancels draft and removes Later from phone scale=$scale',
      (tester) async {
        _size(tester, const Size(390, 844));
        final fixture = await _library(tester, scale: scale);
        await fixture.library.toggleLater(_book);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('library-shelf-picker')));
        await tester.pumpAndSettle();
        await _reveal(
          tester,
          find.byKey(const ValueKey('library-shelf-option-3')),
        );
        await tester.tap(find.byKey(const ValueKey('library-shelf-option-3')));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          find.text('${_strings.filter}: ${_strings.all}'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('library-shelf-picker')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<RadioGroup<int>>(find.byType(RadioGroup<int>))
              .groupValue,
          0,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        final more = find.byKey(
          const ValueKey('book-card-more-izib-phone-book'),
        );
        await _reveal(tester, more);
        await tester.tap(more);
        await tester.pumpAndSettle();
        await tester.tap(find.text(_strings.removeFromLater));
        await tester.pumpAndSettle();
        expect(fixture.library.isLater(_book), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('Android picker remains above keyboard $size scale=$scale', (
        tester,
      ) async {
        _size(tester, size);
        final keyboard = size.height > 400 ? 310.0 : 170.0;
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        addTearDown(tester.view.resetViewInsets);
        var applied = false;
        await tester.pumpWidget(
          _app(
            scale: scale,
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showAdaptiveSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => FilterPickerSheet(
                      options: [
                        for (var i = 0; i < 8; i++)
                          ListTile(title: Text('Option $i')),
                      ],
                      action: FilledButton(
                        key: const ValueKey('phone-picker-apply'),
                        onPressed: () {
                          applied = true;
                          Navigator.of(context).pop();
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ),
                  child: const Text('Open picker'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open picker'));
        await tester.pumpAndSettle();
        final action = find.byKey(const ValueKey('phone-picker-apply'));
        await _reveal(tester, action);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(action).bottom,
          lessThanOrEqualTo(size.height - keyboard),
        );
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(applied, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final dark in [false, true]) {
    testWidgets(
      'Android accent targets and landscape cache confirmation dark=$dark',
      (tester) async {
        _size(tester, const Size(390, 844));
        final storage = _MemoryStorage();
        final settings = AppSettingsStore(MemoryAppSettingsPersistenceStore());
        await settings.load();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appSettingsStoreProvider.overrideWith((ref) => settings),
              downloadStorageProvider.overrideWith((ref) => storage),
            ],
            child: _app(scale: 2, dark: dark, child: const SettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(_strings.appearance));
        await tester.pumpAndSettle();
        final accent = find.byKey(const ValueKey('settings-accent-green'));
        await _reveal(tester, accent);
        expect(tester.getSize(accent), const Size(48, 48));
        await tester.tap(accent);
        await tester.pumpAndSettle();
        expect(settings.settings.accentColor, 'green');
        final custom = find.text(_strings.customColor);
        await _reveal(tester, custom);
        await tester.tap(custom);
        await tester.pumpAndSettle();
        final preset = find.byKey(
          const ValueKey('settings-custom-accent-custom:#2563EB'),
        );
        await _reveal(tester, preset);
        expect(tester.getSize(preset), const Size(48, 48));
        await tester.tap(preset);
        await _reveal(
          tester,
          find.byKey(const ValueKey('custom-accent-apply')),
        );
        await tester.tap(find.byKey(const ValueKey('custom-accent-apply')));
        await tester.pumpAndSettle();
        expect(settings.settings.accentColor, 'custom:#2563EB');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        final cache = find.text(_strings.cacheAndMetadata);
        await _reveal(tester, cache);
        await tester.tap(cache);
        await tester.pumpAndSettle();
        await _reveal(tester, find.text(_strings.clearCardCache));
        await tester.tap(find.text(_strings.clearCardCache));
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(844, 390);
        await tester.pumpAndSettle();
        final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
        expect(dialog.scrollable, isTrue);
        expect(storage.clears, 0);
        await tester.tap(find.text(_strings.cancel));
        await tester.pumpAndSettle();
        expect(storage.clears, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  // Commit both state changes and scroll extent updates before the next touch.
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
}

Widget _app({
  required Widget child,
  double scale = 1,
  bool dark = true,
  TargetPlatform platform = TargetPlatform.android,
}) => MaterialApp(
  theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
    platform: platform,
  ),
  locale: const Locale('en'),
  supportedLocales: AppStrings.supportedLocales,
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: DesktopPreferences(
      compactCards: false,
      showSourceOnCards: true,
      showPercentOnCovers: true,
      child: child!,
    ),
  ),
  home: child,
);

Future<({LibraryStore library, BookmarkStore bookmarks})> _library(
  WidgetTester tester, {
  required double scale,
}) async {
  final library = LibraryStore(MemoryLibraryPersistenceStore());
  await library.load();
  final bookmarks = BookmarkStore(MemoryBookmarkPersistence());
  await bookmarks.load();
  await bookmarks.add(
    book: _playbackBook,
    chapterId: 'chapter',
    positionMs: 12345,
  );
  final playback = PlaybackController(engine: InMemoryAudioEngine());
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LibraryScreen()),
      GoRoute(
        path: '/player',
        builder: (context, state) =>
            const Scaffold(body: Text('Player destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        libraryStoreProvider.overrideWith((ref) => library),
        bookmarkStoreProvider.overrideWith((ref) => bookmarks),
        playbackControllerProvider.overrideWith((ref) => playback),
        libraryPlaybackBooksProvider.overrideWith(
          (ref) async => [_playbackBook],
        ),
        playbackProgressSnapshotsProvider.overrideWith((ref) async => []),
        downloadManagerProvider.overrideWith((ref) => _EmptyDownloads()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.dark().copyWith(platform: TargetPlatform.android),
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
  return (library: library, bookmarks: bookmarks);
}

class _EmptyDownloads extends ChangeNotifier implements DownloadManager {
  @override
  List<DownloadTask> get tasks => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RunningDownloads extends _EmptyDownloads {
  final paused = <String>[];
  @override
  List<DownloadTask> get tasks => [
    DownloadTask(
      id: 'phone-task',
      bookId: _playbackBook.id,
      bookVersionId: _playbackBook.versionId,
      chapterId: 'chapter',
      sourceId: 'izib',
      type: DownloadTaskType.chapter,
      status: DownloadTaskStatus.running,
      progress: .5,
      downloadedBytes: 1024,
      totalBytes: 2048,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];
  @override
  AudioPlaybackBook bookForTask(String id) => _playbackBook;
  @override
  DownloadTask? taskForChapter(String chapterId) => tasks.single;
  @override
  Future<void> pause(String id) async {
    paused.add(id);
  }
}

class _LoadingDownloads extends _EmptyDownloads {
  final loaded = Completer<void>();
  int loads = 0;
  @override
  Future<void> loadPersistedTasks({bool recoverInterrupted = true}) {
    loads++;
    return loaded.future;
  }
}

class _FailedDownloads extends _RunningDownloads {
  _FailedDownloads({required this.errorCode});
  final String errorCode;
  @override
  List<DownloadTask> get tasks => [
    DownloadTask(
      id: 'phone-task',
      bookId: _playbackBook.id,
      bookVersionId: _playbackBook.versionId,
      chapterId: 'chapter',
      sourceId: 'izib',
      type: DownloadTaskType.chapter,
      status: DownloadTaskStatus.failed,
      errorCode: errorCode,
      errorMessage: 'sensitive-fixture-payload must not appear',
      progress: .5,
      downloadedBytes: 1024,
      totalBytes: 2048,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];
}

class _MissingMetadataDownloads extends _EmptyDownloads {
  @override
  List<DownloadTask> get tasks => [
    DownloadTask(
      id: 'missing-task',
      bookId: 'yakniga-master-and-margarita',
      bookVersionId: 'missing-version',
      chapterId: 'missing-chapter',
      sourceId: 'yakniga',
      type: DownloadTaskType.chapter,
      status: DownloadTaskStatus.failed,
      errorCode: 'missing_job_context',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];
  @override
  AudioPlaybackBook? bookForTask(String taskId) => null;
}

class _MemoryStorage extends FileDownloadStorage {
  _MemoryStorage()
    : super(rootDirectory: Directory('unused-mobile-ui-quality-storage'));
  int clears = 0;
  @override
  Future<CardCacheStats> cardCacheStats() async =>
      const CardCacheStats(bytes: 1024, bookCount: 1);
  @override
  Future<CardCacheStats> clearCardCache() async {
    clears++;
    return const CardCacheStats(bytes: 0, bookCount: 0);
  }
}
