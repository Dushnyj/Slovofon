import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';
import 'package:slovofon/services/downloads/download_storage.dart';

void main() {
  for (final width in [390.0, 430.0, 900.0, 1267.0]) {
    for (final scales in [(0.75, 1.0), (1.0, 1.0), (2.0, 1.0), (2.0, 1.5)]) {
      for (final dark in scales.$2 == 1.5 ? [true, false] : [true]) {
        testWidgets('full player width $width app/system $scales dark $dark', (
          tester,
        ) async {
          final controller = await _pumpPlayer(
            tester,
            width,
            scales,
            dark: dark,
          );
          expect(tester.takeException(), isNull);
          if (width >= 900) {
            final source = find.descendant(
              of: find.byKey(const ValueKey('windows-full-player-source')),
              matching: find.byType(Text),
            );
            expect(source, findsOneWidget);
            expect(
              tester.renderObject<RenderParagraph>(source).didExceedMaxLines,
              isFalse,
            );
          }
          final timestampRects = <Rect>[];
          for (final text in ['12:34', '1:23:34', '45:00']) {
            final finder = find.text(text);
            expect(finder, findsOneWidget);
            final widget = tester.widget<Text>(finder);
            final actualScale = MediaQuery.textScalerOf(tester.element(finder));
            expect(
              actualScale.scale(widget.style!.fontSize!),
              closeTo(widget.style!.fontSize! * scales.$1 * scales.$2, 0.01),
            );
            expect(
              tester.renderObject<RenderParagraph>(finder).didExceedMaxLines,
              isFalse,
            );
            timestampRects.add(tester.getRect(finder));
          }
          for (var i = 0; i < timestampRects.length; i++) {
            for (var j = i + 1; j < timestampRects.length; j++) {
              expect(timestampRects[i].overlaps(timestampRects[j]), isFalse);
            }
          }
          final tabs = tester.widget<TabBarView>(find.byType(TabBarView));
          for (var tab = 1; tab < 4; tab++) {
            tabs.controller!.animateTo(tab, duration: Duration.zero);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.tap(find.byTooltip('Таймер сна'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final untilEnd = find.text('До конца главы');
          await tester.ensureVisible(untilEnd);
          await tester.tap(untilEnd);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(controller.state.sleepTimerRemaining, isNotNull);
          await tester.tap(
            width >= 900
                ? find.byKey(const ValueKey('windows-player-speed'))
                : find.byTooltip('1.00x'),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final fastest = find.text('2.00x');
          await tester.ensureVisible(fastest);
          await tester.tap(fastest);
          await tester.pumpAndSettle();
          expect(controller.state.speed, 2);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final width in [390.0, 900.0]) {
    testWidgets('chapter navigation wins over extent correction at $width', (
      tester,
    ) async {
      final scale = ValueNotifier<TextScaler>(
        const AppTextScaler(TextScaler.linear(1.5), 2),
      );
      addTearDown(scale.dispose);
      final controller = await _pumpPlayer(
        tester,
        width,
        (2, 1.5),
        dark: true,
        liveTextScaler: scale,
      );
      await controller.loadBook(
        _chapterScrollBook('old', const Duration(hours: 123, minutes: 23)),
        chapterIndex: 8,
      );
      await tester.pumpAndSettle();
      tester
          .widget<TabBarView>(find.byType(TabBarView))
          .controller!
          .animateTo(1);
      await tester.pumpAndSettle();
      var list = _chapterList(tester);
      final oldExtent = list.itemExtent!;
      expect(list.controller!.offset, closeTo(8 * oldExtent, 0.01));
      // The compact desktop chapter list has enough width for both duration
      // labels on one line. Force a real extent change in the same frame as
      // book/chapter navigation instead of depending on that incidental wrap.
      scale.value = const AppTextScaler(TextScaler.noScaling, 2);
      await controller.loadBook(
        _chapterScrollBook('new', const Duration(minutes: 1)),
        chapterIndex: 2,
      );
      await tester.pumpAndSettle();
      list = _chapterList(tester);
      expect(list.itemExtent, lessThan(oldExtent));
      expect(list.controller!.offset, closeTo(2 * list.itemExtent!, 0.01));
      expect(
        find.byKey(const ValueKey('full-player-chapter-new-2')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('font-only chapter resize preserves fractional scroll position', (
    tester,
  ) async {
    final scale = ValueNotifier<TextScaler>(
      const AppTextScaler(TextScaler.noScaling, 1),
    );
    addTearDown(scale.dispose);
    final controller = await _pumpPlayer(
      tester,
      390,
      (1, 1),
      dark: true,
      liveTextScaler: scale,
    );
    await controller.loadBook(
      _chapterScrollBook('resize', const Duration(hours: 1, minutes: 23)),
      chapterIndex: 5,
    );
    await tester.pumpAndSettle();
    tester.widget<TabBarView>(find.byType(TabBarView)).controller!.animateTo(1);
    await tester.pumpAndSettle();
    var list = _chapterList(tester);
    list.controller!.jumpTo(5.25 * list.itemExtent!);
    await tester.pumpAndSettle();
    final oldExtent = list.itemExtent!;
    scale.value = const AppTextScaler(TextScaler.linear(1.5), 2);
    await tester.pumpAndSettle();
    list = _chapterList(tester);
    expect(list.itemExtent, greaterThan(oldExtent));
    expect(list.controller!.offset, closeTo(5.25 * list.itemExtent!, 0.01));
    expect(controller.state.chapterIndex, 5);
    expect(tester.takeException(), isNull);
  });
}

ListView _chapterList(WidgetTester tester) => tester.widget<ListView>(
  find.byWidgetPredicate(
    (widget) => widget is ListView && widget.itemExtent != null,
  ),
);

AudioPlaybackBook _chapterScrollBook(String id, Duration duration) =>
    AudioPlaybackBook(
      id: id,
      versionId: id,
      sourceId: 'izib',
      sourceName: 'Izib',
      title: 'Книга',
      author: 'Автор',
      narrator: 'Чтец',
      chapters: [
        for (var i = 0; i < 24; i++)
          AudioPlaybackChapter(
            id: '$id-$i',
            index: i + 1,
            title: 'Глава ${i + 1}',
            duration: duration,
          ),
      ],
    );

Future<PlaybackController> _pumpPlayer(
  WidgetTester tester,
  double width,
  (double, double) scales, {
  required bool dark,
  ValueNotifier<TextScaler>? liveTextScaler,
}) async {
  tester.view.physicalSize = Size(width, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = PlaybackController(engine: InMemoryAudioEngine());
  await controller.loadBook(
    const AudioPlaybackBook(
      id: 'font-scale-book',
      versionId: 'font-scale-version',
      sourceId: 'izib',
      sourceName: 'Izib',
      title: 'Книга о путешествиях',
      author: 'Александр Северный',
      narrator: 'Михаил Речной',
      description: 'История долгого путешествия через незнакомые города.',
      chapters: [
        AudioPlaybackChapter(
          id: 'first',
          index: 1,
          title: 'Дорога к старой обсерватории',
          duration: Duration(hours: 1, minutes: 23, seconds: 34),
        ),
        AudioPlaybackChapter(
          id: 'second',
          index: 2,
          title: 'Письмо и карта',
          duration: Duration(minutes: 30),
        ),
      ],
    ),
  );
  await controller.seek(const Duration(minutes: 12, seconds: 34));
  controller.setSleepTimer(const Duration(minutes: 45));
  final manager = DownloadManager(
    client: _NoNetworkClient(),
    storage: FileDownloadStorage(
      rootDirectory: Directory(
        '${Directory.systemTemp.path}/unused-scale-test',
      ),
    ),
    persistence: MemoryDownloadPersistenceStore(),
  );
  final router = GoRouter(
    initialLocation: '/player',
    routes: [
      GoRoute(
        path: '/player',
        builder: (context, state) => const FullPlayerScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  final base = (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
    platform: width >= 900 ? TargetPlatform.windows : TargetPlatform.android,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playbackControllerProvider.overrideWith((ref) {
          ref.onDispose(controller.dispose);
          return controller;
        }),
        downloadManagerProvider.overrideWith((ref) {
          ref.onDispose(manager.dispose);
          return manager;
        }),
      ],
      child: MaterialApp.router(
        locale: const Locale('ru'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: width >= 900 ? WindowsTheme.from(base) : base,
        routerConfig: router,
        builder: (context, child) {
          Widget scaledChild(TextScaler scaler) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: scaler, disableAnimations: true),
            child: child!,
          );
          return liveTextScaler == null
              ? scaledChild(
                  AppTextScaler(TextScaler.linear(scales.$2), scales.$1),
                )
              : ValueListenableBuilder<TextScaler>(
                  valueListenable: liveTextScaler,
                  builder: (context, value, _) => scaledChild(value),
                );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

class _NoNetworkClient implements DownloadClient {
  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async => throw StateError('Text scaling tests must not download media');
}
