import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/television_theme.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/ui/adaptive/television_layout.dart';
import 'package:slovofon/ui/adaptive/television_metrics.dart';
import 'package:slovofon/ui/adaptive/television_shell.dart';
import 'package:slovofon/ui/components/book_cover.dart';
import 'package:slovofon/ui/components/playback_source_label.dart';

const _book = AudioPlaybackBook(
  id: 'tv-transport-book',
  versionId: 'tv-transport-version',
  sourceId: 'izib',
  sourceName: 'Izib',
  title: 'White nights',
  author: 'Fyodor Dostoevsky',
  narrator: 'Narrator',
  chapters: [
    AudioPlaybackChapter(
      id: 'chapter-one',
      index: 0,
      title: 'The first night',
      duration: Duration(minutes: 100),
    ),
  ],
);
final _strings = AppStrings.forLocale(const Locale('en'));
final _navigationBook = _book.copyWith(
  chapters: [
    _book.chapters.single,
    const AudioPlaybackChapter(
      id: 'chapter-two',
      index: 1,
      title: 'The second night',
      duration: Duration(minutes: 40),
    ),
    const AudioPlaybackChapter(
      id: 'chapter-three',
      index: 2,
      title: 'The third night',
      duration: Duration(minutes: 30),
    ),
  ],
);

void main() {
  for (final dark in [false, true]) {
    for (final scale in [.75, 1.0, 2.0]) {
      testWidgets(
        'TV transport identity, time and natural layout dark=$dark scale=$scale',
        (tester) async {
          final controller = await _pump(tester, dark: dark, scale: scale);
          final transport = find.byType(TelevisionTransport);
          final safe = TelevisionMetrics.safeInsetsFor(
            const Size(960, 540),
          ).deflateRect(const Rect.fromLTWH(0, 0, 960, 540));
          final bounds = tester.getRect(transport);
          expect(bounds.left, greaterThanOrEqualTo(safe.left - .01));
          expect(bounds.right, lessThanOrEqualTo(safe.right + .01));
          expect(bounds.bottom, lessThanOrEqualTo(safe.bottom + .01));
          expect(bounds.height, greaterThan(50));
          expect(bounds.height, lessThan(250));
          expect(
            tester
                .getSize(find.byKey(const ValueKey('tv-transport-controls')))
                .width,
            closeTo(196, .01),
          );
          for (final key in [
            'tv-previous-chapter',
            'tv-rewind-15',
            'tv-forward-15',
            'tv-next-chapter',
          ]) {
            expect(
              tester.getSize(find.byKey(ValueKey(key))),
              const Size.square(36),
            );
          }
          expect(
            tester.getSize(find.byKey(const ValueKey('tv-play-pause'))),
            const Size.square(40),
          );
          if (scale <= 1) {
            expect(
              find.byKey(const ValueKey('tv-transport-wide')),
              findsOneWidget,
            );
            expect(
              tester
                  .getSize(find.byKey(const ValueKey('tv-chapter-progress')))
                  .width,
              greaterThan(200),
            );
          }
          final cover = find.descendant(
            of: transport,
            matching: find.byType(BookCover),
          );
          expect(cover, findsOneWidget);
          expect(
            tester.widget<BookCover>(cover).imageUrl,
            controller.state.book!.coverUrl,
          );
          expect(tester.widget<BookCover>(cover).title, _book.title);
          for (final text in [
            _book.title,
            'The first night',
            '1:00',
            '1:40:00',
            _strings.sourceDisplayName('izib'),
          ]) {
            final label = find.descendant(
              of: transport,
              matching: find.text(text),
            );
            expect(label, findsOneWidget);
            final paragraph = tester.renderObject<RenderParagraph>(label);
            expect(paragraph.textScaler.scale(14), scale * 14);
            final labelBounds = tester.getRect(label);
            expect(labelBounds.left, greaterThanOrEqualTo(bounds.left - .01));
            expect(labelBounds.right, lessThanOrEqualTo(bounds.right + .01));
            expect(labelBounds.bottom, lessThanOrEqualTo(bounds.bottom + .01));
          }
          final source = find.descendant(
            of: transport,
            matching: find.byType(PlaybackSourceLabel),
          );
          final sourceText = find.descendant(
            of: source,
            matching: find.byType(Text),
          );
          final sourceColor = tester.widget<Text>(sourceText).style!.color;
          final identity = find.byKey(const ValueKey('tv-open-player'));
          _focus(tester, identity);
          await tester.pumpAndSettle();
          final button = tester.widget<TextButton>(identity);
          final colors = Theme.of(tester.element(identity)).colorScheme;
          for (final state in [
            WidgetState.focused,
            WidgetState.hovered,
            WidgetState.pressed,
          ]) {
            expect(
              button.style!.backgroundColor!.resolve({state}),
              colors.surfaceContainer,
            );
            expect(button.style!.overlayColor!.resolve({state})!.a, 0);
          }
          expect(tester.widget<Text>(sourceText).style!.color, sourceColor);
          expect(
            button.style!.side!.resolve({WidgetState.focused})!.color,
            colors.primary,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('TV transport uses logical geometry, not physical 4K pixels', (
    tester,
  ) async {
    Rect? baseline;
    for (final dpr in [1.0, 2.0, 4.0]) {
      await _pump(tester, dpr: dpr);
      final bounds = tester.getRect(find.byType(TelevisionTransport));
      if (baseline == null) {
        baseline = bounds;
      } else {
        expect(bounds, baseline);
      }
      expect(
        MediaQuery.devicePixelRatioOf(
          tester.element(find.byType(TelevisionTransport)),
        ),
        dpr,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'TV focused seek slider moves exactly 15 seconds and releases Up',
    (tester) async {
      final controller = await _pump(tester);
      final slider = find.byKey(const ValueKey('tv-chapter-progress'));
      _focus(tester, slider);
      await tester.pumpAndSettle();
      expect(_focusedWithin(slider), isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(controller.state.position, const Duration(seconds: 75));
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(controller.state.position, const Duration(seconds: 90));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(controller.state.position, const Duration(seconds: 90));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(controller.state.position, const Duration(seconds: 75));
      expect(_focusedWithin(slider), isTrue);
      expect(tester.widget<Slider>(slider).value, closeTo(75 / 6000, .00001));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(_focusedWithin(slider), isFalse);
      expect(controller.state.position, const Duration(seconds: 75));
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'TV transport controls are traversable with D-pad and can leave Up scale=$scale',
      (tester) async {
        final controller = await _pump(
          tester,
          scale: scale,
          book: _navigationBook,
          chapterIndex: 1,
        );
        final transport = find.byType(TelevisionTransport);
        final identity = find.byKey(const ValueKey('tv-open-player'));
        final previous = find.byKey(const ValueKey('tv-previous-chapter'));
        final rewind = find.descendant(
          of: transport,
          matching: find.byTooltip(_strings.rewind15),
        );
        final play = find.byKey(const ValueKey('tv-play-pause'));
        final forward = find.descendant(
          of: transport,
          matching: find.byTooltip(_strings.forward15),
        );
        final slider = find.byKey(const ValueKey('tv-chapter-progress'));
        final next = find.byKey(const ValueKey('tv-next-chapter'));
        _focus(tester, identity);
        await tester.pumpAndSettle();
        for (final control in [previous, rewind, play, forward, next]) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
          expect(_focusedWithin(control), isTrue);
        }
        await tester.sendKeyEvent(
          scale == 1
              ? LogicalKeyboardKey.arrowRight
              : LogicalKeyboardKey.arrowDown,
        );
        await tester.pumpAndSettle();
        expect(_focusedWithin(slider), isTrue);
        for (final control in [
          identity,
          previous,
          rewind,
          play,
          forward,
          next,
          slider,
        ]) {
          _focus(tester, control);
          await tester.pumpAndSettle();
          for (var step = 0; step < 3 && _focusedWithin(transport); step++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
            await tester.pumpAndSettle();
          }
          expect(
            _focusedWithin(transport),
            isFalse,
            reason:
                'Up must leave every transport control, including the reflowed slider.',
          );
        }
        expect(controller.state.position, const Duration(seconds: 60));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('TV transport shows nothing for an empty playback session', (
    tester,
  ) async {
    await _pump(tester, empty: true);
    expect(find.byKey(const ValueKey('tv-open-player')), findsNothing);
    expect(find.byKey(const ValueKey('tv-chapter-progress')), findsNothing);
    expect(find.byType(BookCover), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'TV previous and next chapters work with D-pad and respect book boundaries',
    (tester) async {
      final controller = await _pump(tester, book: _navigationBook);
      final previous = find.byKey(const ValueKey('tv-previous-chapter'));
      final next = find.byKey(const ValueKey('tv-next-chapter'));
      expect(tester.widget<IconButton>(previous).onPressed, isNull);
      expect(tester.widget<IconButton>(next).tooltip, _strings.nextChapter);
      for (final index in [1, 2]) {
        _focus(tester, next);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(controller.state.chapterIndex, index);
        expect(tester.widget<IconButton>(previous).onPressed, isNotNull);
      }
      expect(tester.widget<IconButton>(next).onPressed, isNull);
      expect(
        tester.widget<IconButton>(previous).tooltip,
        _strings.previousChapter,
      );
      for (final index in [1, 0]) {
        _focus(tester, previous);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(controller.state.chapterIndex, index);
      }
      expect(tester.widget<IconButton>(previous).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TV single-chapter boundaries are disabled and skipped by D-pad',
    (tester) async {
      await _pump(tester);
      for (final key in ['tv-previous-chapter', 'tv-next-chapter']) {
        expect(
          tester.widget<IconButton>(find.byKey(ValueKey(key))).onPressed,
          isNull,
        );
      }
      _focus(tester, find.byKey(const ValueKey('tv-open-player')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        _focusedWithin(find.byKey(const ValueKey('tv-rewind-15'))),
        isTrue,
      );
      _focus(tester, find.byKey(const ValueKey('tv-forward-15')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        _focusedWithin(find.byKey(const ValueKey('tv-chapter-progress'))),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TV chapter navigation and seek are disabled during a pending chapter load',
    (tester) async {
      final engine = _GatedEngine();
      final controller = await _pump(
        tester,
        book: _navigationBook,
        engine: engine,
      );
      engine.gate = Completer<void>();
      final pending = controller.nextChapter();
      try {
        await tester.pump();
        expect(controller.state.status, AudioPlaybackStatus.loading);
        // The controller starts loading after an async metadata refresh. Its
        // notification schedules a frame after pump's microtask drain; render
        // that frame while the engine remains deliberately blocked.
        await tester.pump();
        for (final key in [
          'tv-previous-chapter',
          'tv-next-chapter',
          'tv-rewind-15',
          'tv-forward-15',
        ]) {
          expect(
            tester.widget<IconButton>(find.byKey(ValueKey(key))).onPressed,
            isNull,
            reason: key,
          );
        }
        expect(
          tester
              .widget<Slider>(find.byKey(const ValueKey('tv-chapter-progress')))
              .onChanged,
          isNull,
        );
        // Pause remains available to cancel a pending automatic start.
        expect(
          tester
              .widget<IconButton>(find.byKey(const ValueKey('tv-play-pause')))
              .onPressed,
          isNotNull,
        );
      } finally {
        engine.gate!.complete();
        await pending;
        await tester.pumpAndSettle();
      }
      expect(controller.state.chapterIndex, 1);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('tv-previous-chapter')),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('tv-next-chapter')))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TV unknown-duration chapter keeps elapsed time and relative seek',
    (tester) async {
      final controller = await _pump(tester, unknownDuration: true);
      final transport = find.byType(TelevisionTransport);
      final slider = find.byKey(const ValueKey('tv-chapter-progress'));
      expect(controller.state.chapterDuration, Duration.zero);
      expect(tester.widget<Slider>(slider).onChanged, isNull);
      expect(
        find.descendant(of: transport, matching: find.text('1:00')),
        findsOneWidget,
      );
      final forward = find.descendant(
        of: transport,
        matching: find.byTooltip(_strings.forward15),
      );
      _focus(tester, forward);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(controller.state.position, const Duration(seconds: 75));
      expect(
        find.descendant(of: transport, matching: find.text('1:15')),
        findsOneWidget,
      );
      final rewind = find.descendant(
        of: transport,
        matching: find.byTooltip(_strings.rewind15),
      );
      _focus(tester, rewind);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(controller.state.position, const Duration(seconds: 60));
      expect(tester.takeException(), isNull);
    },
  );
}

void _focus(WidgetTester tester, Finder target) {
  final targetElement = tester.element(target);
  // Buttons can own their FocusNode in private state, rather than expose it on
  // the public Focus widget. Inspect the attached focus tree for either case.
  for (final node in FocusManager.instance.rootScope.descendants) {
    if (!node.canRequestFocus || node.skipTraversal) continue;
    final context = node.context;
    if (context == null) continue;
    var inside = identical(context, targetElement);
    context.visitAncestorElements((element) {
      if (identical(element, targetElement)) inside = true;
      return !inside;
    });
    if (!inside) continue;
    node.requestFocus();
    return;
  }
  throw StateError('Target must have a real focusable descendant: $target');
}

bool _focusedWithin(Finder finder) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null || finder.evaluate().length != 1) return false;
  final target = finder.evaluate().single;
  var found = identical(focused, target);
  focused.visitAncestorElements((element) {
    if (identical(element, target)) found = true;
    return !found;
  });
  return found;
}

Future<PlaybackController> _pump(
  WidgetTester tester, {
  bool dark = true,
  double scale = 1,
  double dpr = 1,
  bool empty = false,
  bool unknownDuration = false,
  AudioPlaybackBook? book,
  int chapterIndex = 0,
  AudioEngine? engine,
}) async {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = const Size(960, 540) * dpr;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final controller = PlaybackController(
    engine: engine ?? InMemoryAudioEngine(),
  );
  if (!empty) {
    final baseBook = book ?? _book;
    final playbackBook = unknownDuration
        ? baseBook.copyWith(
            chapters: [
              for (final chapter in baseBook.chapters)
                chapter.copyWith(duration: Duration.zero),
            ],
          )
        : baseBook;
    await controller.loadBook(
      playbackBook,
      chapterIndex: chapterIndex,
      position: const Duration(seconds: 60),
    );
  }
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => TelevisionShell(
          selectedIndex: 0,
          onSelected: (_) {},
          child: Align(
            alignment: Alignment.topCenter,
            child: TextButton(
              key: const ValueKey('tv-catalog-focus-target'),
              onPressed: () {},
              child: const Text('Catalog'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) => const Scaffold(body: Text('Player')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playbackControllerProvider.overrideWith((ref) {
          ref.onDispose(controller.dispose);
          return controller;
        }),
      ],
      child: MaterialApp.router(
        theme: TelevisionTheme.from(
          (dark
                  ? AppTheme.dark(accent: const Color(0xff7c3aed))
                  : AppTheme.light(accent: const Color(0xff7c3aed)))
              .copyWith(platform: TargetPlatform.android),
        ),
        routerConfig: router,
        locale: const Locale('en'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: TelevisionLayout(
            enabled: true,
            child: TelevisionViewport(child: child!),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

class _GatedEngine extends InMemoryAudioEngine {
  Completer<void>? gate;
  @override
  Future<void> load(
    AudioPlaybackChapter chapter, {
    required Duration position,
    AudioPlaybackBook? book,
  }) async {
    await gate?.future;
    await super.load(chapter, position: position, book: book);
  }
}
