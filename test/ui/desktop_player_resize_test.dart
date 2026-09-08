import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_text_scaler.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/windows_theme.dart';
import 'package:slovofon/features/player/full_player_screen.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/bookmarks/bookmark_store.dart';
import 'package:slovofon/ui/components/seek_interval_icon.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/ui/adaptive/slovofon_shell.dart';
import 'package:slovofon/ui/components/mini_player_bar.dart';

void main() {
  for (final fullPlayer in [false, true]) {
    testWidgets(
      '${fullPlayer ? 'full player' : 'dock'} seek buttons move exactly 15 seconds without changing playback state',
      (tester) async {
        final fixture = await _pump(
          tester,
          size: const Size(900, 600),
          appScale: 1,
          systemScale: 1,
        );
        if (fullPlayer) {
          fixture.router.go('/player');
        }
        await fixture.controller.setSpeed(1.25);
        final strings = AppStrings.forLocale(const Locale('ru'));
        final surface = find.byKey(
          ValueKey(
            fullPlayer ? 'windows-full-player' : 'windows-playback-dock',
          ),
        );

        for (final playing in [false, true]) {
          await fixture.controller.seekChapterAt(
            3,
            const Duration(seconds: 60),
            play: playing,
          );
          for (final action in [
            (strings.rewind15, const Duration(seconds: 45)),
            (strings.forward15, const Duration(seconds: 75)),
          ]) {
            // Each direction starts at 60s, rather than undoing the prior tap.
            await fixture.controller.seek(const Duration(seconds: 60));
            await tester.pumpAndSettle();
            final before = fixture.controller.state;
            expect(before.position, const Duration(seconds: 60));
            expect(before.chapterIndex, 3);
            expect(before.speed, 1.25);
            expect(before.isPlaying, playing);
            final button = find.descendant(
              of: surface,
              matching: find.byTooltip(action.$1),
            );
            expect(button.hitTestable(), findsOneWidget);
            await tester.tap(button);
            await tester.pumpAndSettle();
            final after = fixture.controller.state;
            expect(after.position, action.$2);
            expect(after.book, same(before.book));
            expect(after.chapterIndex, before.chapterIndex);
            expect(after.currentChapter?.id, before.currentChapter?.id);
            expect(after.speed, before.speed);
            expect(after.isPlaying, before.isPlaying);
            expect(after.status, before.status);
            expect(tester.takeException(), isNull);
          }
        }
      },
    );
  }

  for (final size in [
    const Size(640, 480),
    const Size(900, 600),
    const Size(1024, 600),
    const Size(1267, 600),
    const Size(1267, 720),
    const Size(1920, 720),
  ]) {
    for (final scale in [(.75, 1.0), (1.0, 1.0), (2.0, 1.0), (2.0, 1.5)]) {
      testWidgets(
        'Windows shell dock and full player resize $size app/system=$scale',
        (tester) async {
          final fixture = await _pump(
            tester,
            size: size,
            appScale: scale.$1,
            systemScale: scale.$2,
          );
          final compactNav = size.width < 1100;
          expect(
            find.byKey(const ValueKey('windows-compact-navigation-rail')),
            compactNav ? findsOneWidget : findsNothing,
          );
          expect(find.byType(SlovofonBottomNavigationBar), findsNothing);
          expect(find.byType(MiniPlayerBar), findsNothing);
          final frame = tester.getSize(
            find.byKey(const ValueKey('desktop-content-frame')),
          );
          expect(frame.width, greaterThan(250));
          expect(frame.height, greaterThan(60));
          final dock = find.byKey(const ValueKey('windows-playback-dock'));
          expect(dock, findsOneWidget);
          expect(
            tester.getRect(dock).bottom,
            lessThanOrEqualTo(size.height + .01),
          );
          _expectScale(tester, 'windows-dock-source', scale.$1 * scale.$2);
          expect(tester.takeException(), isNull);
          fixture.router.go('/player');
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('windows-full-player')),
            findsOneWidget,
          );
          final heightFactor =
              1 + .35 * (scale.$1 * scale.$2 - 1).clamp(0.0, 2.0);
          final compactPlayer =
              size.width < 1100 || size.height / heightFactor < 700;
          expect(
            find.byKey(const ValueKey('windows-compact-full-player-header')),
            compactPlayer ? findsOneWidget : findsNothing,
          );
          _expectScale(
            tester,
            'windows-full-player-source',
            scale.$1 * scale.$2,
          );
          expect(
            tester.getSize(find.byType(TabBarView)).height,
            greaterThan(30),
          );
          expect(tester.takeException(), isNull);
          for (final tab in [1, 2, 3, 0]) {
            final button = find.byKey(ValueKey('windows-player-tab-$tab'));
            await tester.ensureVisible(button);
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'tab=$tab');
          }
          final play = find.byTooltip(
            AppStrings.forLocale(const Locale('ru')).play,
          );
          await tester.tap(play);
          await tester.pumpAndSettle();
          expect(fixture.controller.state.isPlaying, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'full player volume shares state and survives resize at $scale',
      (tester) async {
        final fixture = await _pump(
          tester,
          size: const Size(900, 600),
          appScale: scale,
          systemScale: 1,
        );
        await fixture.controller.setVolume(.37);
        fixture.router.go('/player');
        await tester.pumpAndSettle();
        expect(find.byType(SeekIntervalIcon), findsNWidgets(2));
        final volume = find.byKey(const ValueKey('windows-full-player-volume'));
        await tester.tap(volume);
        await tester.pumpAndSettle();
        final slider = find.byKey(const ValueKey('desktop-volume-slider'));
        expect(_readSlider(tester, slider).value, closeTo(.37, .001));
        await tester.tapAt(tester.getCenter(slider));
        await tester.pumpAndSettle();
        expect(fixture.controller.state.volume, closeTo(.5, .03));
        final setVolume = fixture.controller.state.volume;
        await tester.tap(
          find.byKey(const ValueKey('desktop-volume-mute-button')),
        );
        await tester.pumpAndSettle();
        expect(fixture.controller.state.volume, 0);
        await tester.tap(
          find.byKey(const ValueKey('desktop-volume-mute-button')),
        );
        await tester.pumpAndSettle();
        expect(fixture.controller.state.volume, setVolume);
        tester.view.physicalSize = const Size(1920, 1200);
        await tester.pumpAndSettle();
        // Flutter closes anchored menus after host resize; reopen if necessary.
        if (find
            .byKey(const ValueKey('desktop-volume-popover'))
            .evaluate()
            .isEmpty) {
          await tester.tap(volume);
          await tester.pumpAndSettle();
        }
        expect(_readSlider(tester, slider).value, setVolume);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('desktop-volume-popover')),
          findsNothing,
        );
        fixture.router.go('/');
        await tester.pumpAndSettle();
        await tester.tap(
          find.byTooltip(AppStrings.forLocale(const Locale('ru')).volume),
        );
        await tester.pumpAndSettle();
        expect(_readSlider(tester, slider).value, setVolume);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'real player bookmarks add jump persist resize and confirm delete at $scale',
      (tester) async {
        final persistence = MemoryBookmarkPersistence();
        final store = BookmarkStore(persistence);
        await store.load();
        final fixture = await _pump(
          tester,
          size: const Size(900, 600),
          appScale: scale,
          systemScale: 1,
          bookmarkStore: store,
        );
        await fixture.controller.seek(const Duration(minutes: 3, seconds: 12));
        fixture.router.go('/player');
        await tester.pumpAndSettle();
        final tab = find.byKey(const ValueKey('windows-player-tab-2'));
        await tester.ensureVisible(tab);
        await tester.tap(tab);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('player-bookmarks-empty')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('player-bookmark-add')));
        await tester.pumpAndSettle();
        final note = find.byKey(const ValueKey('player-bookmark-note'));
        await tester.enterText(note, 'Вернуться к важному разговору');
        // The dialog draft and the captured position must survive a host resize.
        await fixture.controller.seek(const Duration(minutes: 7));
        tester.view.physicalSize = const Size(1920, 1200);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(note).controller!.text,
          'Вернуться к важному разговору',
        );
        final save = find.byKey(const ValueKey('player-bookmark-save'));
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(store.entries, hasLength(1));
        final bookmark = store.entries.single;
        expect(
          bookmark.positionMs,
          const Duration(minutes: 3, seconds: 12).inMilliseconds,
        );
        expect(bookmark.note, 'Вернуться к важному разговору');
        final reloaded = BookmarkStore(persistence);
        await reloaded.load();
        expect(reloaded.entries.single.id, bookmark.id);
        reloaded.dispose();
        await fixture.controller.seekChapterAt(4, Duration.zero, play: false);
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(900, 600);
        await tester.pumpAndSettle();
        final row = find.byKey(ValueKey('player-bookmark-${bookmark.id}'));
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(fixture.controller.state.chapterIndex, 0);
        expect(
          fixture.controller.state.position,
          const Duration(minutes: 3, seconds: 12),
        );
        expect(fixture.controller.state.isPlaying, isTrue);
        final remove = find.byKey(
          ValueKey('player-bookmark-delete-${bookmark.id}'),
        );
        await tester.tap(remove);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('player-bookmark-delete-cancel')),
        );
        await tester.pumpAndSettle();
        expect(store.entries, hasLength(1));
        await tester.tap(remove);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('player-bookmark-delete-confirm')),
        );
        await tester.pumpAndSettle();
        expect(store.entries, isEmpty);
        expect(
          fixture.controller.state.position,
          const Duration(minutes: 3, seconds: 12),
        );
        expect(fixture.controller.state.book, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scale in [2.0, 3.0]) {
    testWidgets(
      'low height dock prioritizes title source and controls at $scale',
      (tester) async {
        await _pump(
          tester,
          size: const Size(900, 600),
          appScale: 2,
          systemScale: scale / 2,
        );
        final dock = find.byKey(const ValueKey('windows-playback-dock'));
        expect(
          tester.getSize(dock).height,
          lessThanOrEqualTo(scale == 2 ? 132 : 172),
        );
        _expectScale(tester, 'windows-dock-source', scale);
        final strings = AppStrings.forLocale(const Locale('ru'));
        for (final tooltip in [
          strings.play,
          strings.previousChapter,
          strings.nextChapter,
          strings.rewind15,
          strings.forward15,
          strings.volume,
          strings.chapters,
        ]) {
          expect(find.byTooltip(tooltip).hitTestable(), findsOneWidget);
        }
        expect(find.byType(SeekIntervalIcon), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'full player large text uses compact header and explicit overflow tabs',
    (tester) async {
      final fixture = await _pump(
        tester,
        size: const Size(1267, 720),
        appScale: 2,
        systemScale: 1.5,
      );
      fixture.router.go('/player');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('windows-compact-full-player-header')),
        findsOneWidget,
      );
      final next = find.byKey(const ValueKey('windows-player-tabs-forward'));
      expect(next.hitTestable(), findsOneWidget);
      final info = find.byKey(const ValueKey('windows-player-tab-3'));
      for (
        var attempt = 0;
        attempt < 4 && info.hitTestable().evaluate().isEmpty;
        attempt++
      ) {
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      expect(info.hitTestable(), findsOneWidget);
      await tester.tap(info);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(900, 600);
      await tester.pumpAndSettle();
      expect(info.hitTestable(), findsOneWidget);
      expect(
        tester.widget<TabBarView>(find.byType(TabBarView)).controller!.index,
        3,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    for (final profile in [
      (const Size(640, 480), 2.0, 1.5),
      (const Size(900, 600), 1.0, 1.0),
      (const Size(1920, 1080), 2.0, 1.0),
    ]) {
      testWidgets(
        'Windows empty player offers search without idle spinner $profile dark=$dark',
        (tester) async {
          final fixture = await _pump(
            tester,
            size: profile.$1,
            appScale: profile.$2,
            systemScale: profile.$3,
            loadBook: false,
            dark: dark,
          );
          fixture.router.go('/player');
          await tester.pumpAndSettle();
          expect(fixture.controller.state.status, AudioPlaybackStatus.idle);
          expect(
            find.byKey(const ValueKey('windows-player-empty-state')),
            findsOneWidget,
          );
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(
            find.byKey(const ValueKey('windows-full-player-controls')),
            findsNothing,
          );
          expect(find.byType(Slider), findsNothing);
          expect(find.byType(TabBarView), findsNothing);
          final strings = AppStrings.forLocale(const Locale('ru'));
          expect(find.byTooltip(strings.play), findsNothing);
          final prompt = find.text(strings.realSourceHomeTitle);
          expect(prompt, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(prompt);
          final fontSize = paragraph.text.style!.fontSize!;
          expect(
            paragraph.textScaler.scale(fontSize),
            closeTo(fontSize * profile.$2 * profile.$3, .001),
          );
          final search = find.byKey(
            const ValueKey('windows-player-empty-search'),
          );
          await tester.ensureVisible(search);
          expect(search.hitTestable(), findsOneWidget);
          await tester.tap(search);
          await tester.pumpAndSettle();
          expect(fixture.router.state.uri.path, '/search');
          fixture.router.go('/player');
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('windows-empty-player-back')),
          );
          await tester.pumpAndSettle();
          expect(fixture.router.state.uri.path, '/');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'Windows empty player does not replace a genuine pending book load',
    (tester) async {
      final engine = _PendingLoadEngine();
      addTearDown(() {
        if (!engine.ready.isCompleted) engine.ready.complete();
      });
      final controller = PlaybackController(engine: engine);
      final fixture = await _pump(
        tester,
        size: const Size(900, 600),
        appScale: 2,
        systemScale: 1,
        loadBook: false,
        playbackController: controller,
      );
      fixture.router.go('/player');
      await tester.pumpAndSettle();
      final pending = controller.loadBook(
        const AudioPlaybackBook(
          id: 'loading-book',
          versionId: 'loading-version',
          sourceId: 'izib',
          title: 'Загружаемая книга',
          author: 'Автор',
          narrator: 'Чтец',
          sourceName: 'Изибук',
          chapters: [
            AudioPlaybackChapter(
              id: 'chapter-1',
              index: 0,
              title: 'Глава 1',
              duration: Duration(hours: 1),
            ),
          ],
        ),
      );
      await tester.pump();
      expect(controller.state.status, AudioPlaybackStatus.loading);
      expect(
        find.byKey(const ValueKey('windows-player-empty-state')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('windows-compact-full-player-header')),
        findsOneWidget,
      );
      engine.ready.complete();
      await pending;
      await tester.pumpAndSettle();
      expect(controller.state.status, AudioPlaybackStatus.paused);
      expect(
        find.byKey(const ValueKey('windows-player-empty-state')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final speed in [true, false]) {
    testWidgets(
      'Windows player ${speed ? 'speed' : 'timer'} options have an explicit close action',
      (tester) async {
        final fixture = await _pump(
          tester,
          size: const Size(640, 480),
          appScale: 2,
          systemScale: 1.5,
        );
        fixture.router.go('/player');
        await tester.pumpAndSettle();
        await tester.tap(
          speed
              ? find.byKey(const ValueKey('windows-player-speed'))
              : find.byTooltip(
                  AppStrings.forLocale(const Locale('ru')).sleepTimer,
                ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('windows-player-options')),
          findsOneWidget,
        );
        final close = find.byKey(const ValueKey('desktop-options-close'));
        expect(close.hitTestable(), findsOneWidget);
        final dialog = tester.getRect(
          find.byKey(const ValueKey('desktop-options-dialog')),
        );
        expect(dialog.top, greaterThanOrEqualTo(0));
        expect(dialog.bottom, lessThanOrEqualTo(480));
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('windows-player-options')),
          findsNothing,
        );
        expect(fixture.router.state.uri.path, '/player');
        expect(fixture.controller.state.speed, 1);
        expect(fixture.controller.state.sleepTimerRemaining, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'volume Escape returns focus and does not consume Escape after closing',
    (tester) async {
      var hostEscapes = 0;
      await _pump(
        tester,
        size: const Size(900, 600),
        appScale: 2,
        systemScale: 1.5,
        onEscape: () => hostEscapes++,
      );
      final volume = find.byTooltip(
        AppStrings.forLocale(const Locale('ru')).volume,
      );
      await tester.tap(volume);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('desktop-volume-popover')),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('desktop-volume-popover')),
        findsNothing,
      );
      expect(hostEscapes, 0);
      // AppIconButton puts the policy-controlled tooltip around the stock
      // IconButton. Assert focus on the actual interactive button, not its
      // former ancestor relationship to the framework tooltip.
      final anchor = tester.widget<IconButton>(
        find.descendant(of: volume, matching: find.byType(IconButton)),
      );
      expect(anchor.focusNode!.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(hostEscapes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resizing desktop player preserves playback speed timer and selected tab',
    (tester) async {
      final fixture = await _pump(
        tester,
        size: const Size(900, 600),
        appScale: 2,
        systemScale: 1.5,
      );
      await fixture.controller.seek(const Duration(minutes: 10));
      await fixture.controller.setSpeed(1.25);
      fixture.controller.setSleepTimer(const Duration(minutes: 90));
      await fixture.controller.togglePlayPause();
      fixture.router.go('/player');
      await tester.pumpAndSettle();
      final chapters = find.byKey(const ValueKey('windows-player-tab-1'));
      await tester.ensureVisible(chapters);
      await tester.tap(chapters);
      await tester.pumpAndSettle();
      final chapterList = find.byWidgetPredicate(
        (widget) =>
            widget is ListView &&
            widget.itemExtent != null &&
            widget.controller != null,
      );
      await tester.drag(chapterList, const Offset(0, -700));
      await tester.pumpAndSettle();
      final originalList = tester.widget<ListView>(chapterList);
      final originalScroll = originalList.controller!;
      final originalVisibleIndex =
          originalScroll.offset / originalList.itemExtent!;
      expect(originalScroll.offset, greaterThan(500));
      double firstVisibleChapterTop() {
        final viewport = tester.getRect(chapterList);
        final chapterBoxes = tester.widgetList<Widget>(
          find.byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'full-player-chapter-',
                ),
          ),
        );
        for (final tile in chapterBoxes) {
          final rect = tester.getRect(find.byKey(tile.key!));
          if (rect.bottom > viewport.top && rect.top < viewport.bottom) {
            return rect.top - viewport.top;
          }
        }
        throw TestFailure('No chapter intersects the visible list');
      }

      final originalChapterTop = firstVisibleChapterTop();
      for (final size in [
        const Size(640, 480),
        const Size(1920, 1200),
        const Size(900, 600),
        const Size(1024, 600),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size');
        final resizedList = tester.widget<ListView>(chapterList);
        expect(resizedList.controller, same(originalScroll));
        expect(
          originalScroll.offset / resizedList.itemExtent!,
          closeTo(originalVisibleIndex, .01),
        );
        expect(firstVisibleChapterTop(), closeTo(originalChapterTop, .01));
        expect(fixture.controller.state.isPlaying, isTrue);
        expect(fixture.controller.state.speed, 1.25);
        expect(fixture.controller.state.position, const Duration(minutes: 10));
        expect(fixture.controller.state.sleepTimerRemaining, isNotNull);
        expect(
          tester.widget<TabBarView>(find.byType(TabBarView)).controller!.index,
          1,
        );
        expect(tester.getSize(find.byType(TabBarView)).height, greaterThan(30));
        final speedText = find.descendant(
          of: find.byKey(const ValueKey('windows-player-speed')),
          matching: find.text('1.25x'),
        );
        final speed = tester.renderObject<RenderParagraph>(speedText);
        expect(speed.didExceedMaxLines, isFalse);
        expect(speed.size.height, lessThan(90));
        expect(find.byKey(const ValueKey('sleep-timer-pill')), findsOneWidget);
        expect(
          tester
              .getRect(
                find.byKey(const ValueKey('windows-full-player-controls')),
              )
              .bottom,
          lessThanOrEqualTo(size.height),
        );
      }
    },
  );

  testWidgets(
    'compact desktop book information remains available on small work area and DPI',
    (tester) async {
      final fixture = await _pump(
        tester,
        size: const Size(900, 600),
        appScale: 2,
        systemScale: 1.5,
        dpr: 1.5,
      );
      fixture.router.go('/player');
      await tester.pumpAndSettle();
      final info = find.byKey(
        const ValueKey('windows-compact-player-book-details'),
      );
      await tester.tap(info);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('desktop-options-dialog')),
        findsOneWidget,
      );
      final author = find.text(fixture.controller.state.book!.author);
      await tester.ensureVisible(author);
      expect(
        tester.renderObject<RenderParagraph>(author).didExceedMaxLines,
        isFalse,
      );
      final source = find.byKey(
        const ValueKey('windows-compact-player-book-source'),
      );
      await tester.ensureVisible(source);
      _expectScale(tester, 'windows-compact-player-book-source', 3);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(640 * 1.5, 480 * 1.5);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final close = find.byKey(const ValueKey('desktop-options-close'));
      expect(tester.getRect(close).top, greaterThanOrEqualTo(0));
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('desktop-options-dialog')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('windows-full-player')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

void _expectScale(WidgetTester tester, String key, double scale) {
  final text = find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(Text),
  );
  expect(text, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(text);
  final fontSize = paragraph.text.style!.fontSize!;
  expect(paragraph.textScaler.scale(fontSize), closeTo(fontSize * scale, .001));
  expect(paragraph.didExceedMaxLines, isFalse);
}

Future<({PlaybackController controller, GoRouter router})> _pump(
  WidgetTester tester, {
  required Size size,
  required double appScale,
  required double systemScale,
  double dpr = 1,
  VoidCallback? onEscape,
  bool loadBook = true,
  bool dark = true,
  PlaybackController? playbackController,
  BookmarkStore? bookmarkStore,
}) async {
  tester.view.physicalSize = size * dpr;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller =
      playbackController ?? PlaybackController(engine: InMemoryAudioEngine());
  addTearDown(controller.dispose);
  if (loadBook) {
    await controller.loadBook(
      AudioPlaybackBook(
        id: 'resize-book',
        versionId: 'resize-version',
        sourceId: 'baza_knig',
        sourceName: 'База книг',
        title: 'Название аудиокниги для проверки окна',
        author: 'Полное имя автора проверочной книги',
        narrator: 'Полное имя чтеца проверочной книги',
        description: 'Описание книги, доступное при любом размере окна.',
        chapters: [
          for (var index = 0; index < 20; index++)
            AudioPlaybackChapter(
              id: 'chapter-$index',
              index: index,
              title: 'Глава ${index + 1}',
              duration: const Duration(hours: 2),
            ),
        ],
      ),
    );
  }
  final manager = DownloadManager(
    client: _NoNetworkClient(),
    storage: FileDownloadStorage(
      rootDirectory: Directory('unused-resize-test-storage'),
    ),
    persistence: MemoryDownloadPersistenceStore(),
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => DesktopStandaloneShell(
          selectedIndex: 0,
          child: ListView(
            children: const [Text('Рабочая область'), SizedBox(height: 1000)],
          ),
        ),
      ),
      GoRoute(path: '/player', builder: (_, _) => const FullPlayerScreen()),
      for (final path in ['/search', '/library', '/downloads', '/settings'])
        GoRoute(
          path: path,
          builder: (_, _) => const Scaffold(body: Text('Раздел')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playbackControllerProvider.overrideWith((ref) => controller),
        downloadManagerProvider.overrideWith((ref) => manager),
        if (bookmarkStore != null)
          bookmarkStoreProvider.overrideWith((ref) => bookmarkStore),
      ],
      child: MaterialApp.router(
        theme: WindowsTheme.from(
          dark ? AppTheme.dark() : AppTheme.light(),
        ).copyWith(platform: TargetPlatform.windows),
        routerConfig: router,
        locale: const Locale('ru'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: AppTextScaler(TextScaler.linear(systemScale), appScale),
            disableAnimations: true,
          ),
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): ?onEscape,
            },
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (controller: controller, router: router);
}

class _NoNetworkClient implements DownloadClient {
  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async => throw StateError('Resize tests do not download audio');
}

class _PendingLoadEngine extends InMemoryAudioEngine {
  final ready = Completer<void>();

  @override
  Future<void> load(
    AudioPlaybackChapter chapter, {
    required Duration position,
    AudioPlaybackBook? book,
  }) async {
    await ready.future;
    await super.load(chapter, position: position, book: book);
  }
}

Slider _readSlider(WidgetTester tester, Finder root) {
  final widget = tester.widget(root);
  if (widget is Slider) return widget;
  return tester.widget<Slider>(
    find.descendant(of: root, matching: find.byType(Slider)),
  );
}
