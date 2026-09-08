import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/television_theme.dart';
import 'package:slovofon/app/theme/windows_theme.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/features/downloads/downloads_screen.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/ui/adaptive/television_layout.dart';

void main() {
  for (final platform in ['phone', 'windows', 'tv']) {
    testWidgets('$platform mounts only visible download books', (tester) async {
      final manager = _Downloads(bookCount: 120, chapterCount: 1);
      await _pump(tester, manager, platform);
      expect(
        find.descendant(
          of: find.byKey(const PageStorageKey('downloads-scroll')),
          matching: find.byType(SliverList),
        ),
        findsOneWidget,
        reason: 'All download sections share one zero-origin lazy list.',
      );
      final mounted = find.byType(ExpansionTile).evaluate().length;
      expect(mounted, greaterThan(0));
      expect(
        mounted,
        lessThan(25),
        reason: '120 book widgets cannot be built eagerly',
      );
      final scroll = find.byKey(const PageStorageKey('downloads-scroll'));
      await tester.drag(scroll, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.byType(ExpansionTile).evaluate().length, lessThan(25));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$platform collapsed thousand-chapter book has linear lookup cost',
      (tester) async {
        final manager = _Downloads(bookCount: 1, chapterCount: 1000);
        _CountingChapter.idReads = 0;
        await _pump(tester, manager, platform);
        final expansion = tester.widget<ExpansionTile>(
          find.byType(ExpansionTile),
        );
        expect(expansion.children, hasLength(1));
        expect(
          expansion.children.single,
          isA<Builder>(),
          reason:
              'Collapsed chapters must not be materialized into a List<Widget>',
        );
        expect(find.text('Chapter 999'), findsNothing);
        expect(
          _CountingChapter.idReads,
          lessThan(10000),
          reason:
              'Build indexes once instead of chapter scans in each sort comparison',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$platform expansion creates actual chapter rows when opened', (
      tester,
    ) async {
      final manager = _Downloads(bookCount: 1, chapterCount: 6);
      await _pump(tester, manager, platform);
      expect(find.text('Chapter 0'), findsNothing);
      final element = tester.element(
        find
            .descendant(
              of: find.byType(ExpansionTile),
              matching: find.byType(ListTile),
            )
            .first,
      );
      ExpansibleController.of(element).expand();
      await tester.pumpAndSettle();
      expect(find.text('Chapter 0'), findsOneWidget);
      expect(find.text('Chapter 5'), findsOneWidget);
      final chapterTexts = [
        for (final index in [0, 1, 2, 3, 4, 5])
          tester.getTopLeft(find.text('Chapter $index')).dy,
      ];
      expect(chapterTexts, orderedEquals([...chapterTexts]..sort()));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'hidden downloads detach progress listener without discarding scroll state',
    (tester) async {
      final manager = _Downloads(bookCount: 120, chapterCount: 1);
      final active = ValueNotifier(true);
      addTearDown(active.dispose);
      await _pump(tester, manager, 'windows', active: active);
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const PageStorageKey('downloads-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      scroll.position.jumpTo(400);
      await tester.pumpAndSettle();
      active.value = false;
      await tester.pump();
      final reads = manager.taskReads;
      for (var i = 0; i < 10; i++) {
        manager.pulse();
        await tester.pump();
      }
      expect(manager.taskReads, reads);
      active.value = true;
      await tester.pump();
      expect(manager.taskReads, greaterThan(reads));
      expect(scroll.position.pixels, 400);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  _Downloads manager,
  String platform, {
  ValueNotifier<bool>? active,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = platform == 'phone'
      ? const Size(420, 800)
      : const Size(1100, 800);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final playback = PlaybackController(engine: InMemoryAudioEngine());
  addTearDown(playback.dispose);
  final base = AppTheme.dark();
  final theme = switch (platform) {
    'windows' => WindowsTheme.from(
      base,
    ).copyWith(platform: TargetPlatform.windows),
    'tv' => TelevisionTheme.from(
      base,
    ).copyWith(platform: TargetPlatform.android),
    _ => base.copyWith(platform: TargetPlatform.android),
  };
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        downloadManagerProvider.overrideWith((ref) => manager),
        playbackControllerProvider.overrideWithValue(playback),
        playbackProgressSnapshotsProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        theme: theme,
        home: TelevisionLayout(
          enabled: platform == 'tv',
          child: active == null
              ? const DownloadsScreen()
              : ValueListenableBuilder<bool>(
                  valueListenable: active,
                  builder: (context, enabled, child) =>
                      TickerMode(enabled: enabled, child: child!),
                  child: const DownloadsScreen(),
                ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Downloads extends ChangeNotifier implements DownloadManager {
  _Downloads({required int bookCount, required int chapterCount}) {
    for (var index = 0; index < bookCount; index++) {
      final book = AudioPlaybackBook(
        id: 'book-$index',
        versionId: 'version-$index',
        sourceId: 'izib',
        sourceName: 'Izib',
        title: 'Book ${index.toString().padLeft(3, '0')}',
        author: 'Author',
        narrator: 'Narrator',
        chapters: [
          for (var chapter = 0; chapter < chapterCount; chapter++)
            _CountingChapter(chapter),
        ],
      );
      for (var chapter = chapterCount - 1; chapter >= 0; chapter--) {
        final id = 'task-$index-$chapter';
        booksByTask[id] = book;
        values.add(
          DownloadTask(
            id: id,
            bookId: book.id,
            bookVersionId: book.versionId,
            chapterId: 'chapter-$chapter',
            sourceId: 'izib',
            type: DownloadTaskType.chapter,
            status: DownloadTaskStatus.paused,
            progress: .4,
            downloadedBytes: 400,
            totalBytes: 1000,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
      }
    }
  }
  final booksByTask = <String, AudioPlaybackBook>{};
  final values = <DownloadTask>[];
  int taskReads = 0;
  void pulse() => notifyListeners();
  @override
  List<DownloadTask> get tasks {
    taskReads++;
    return values;
  }

  @override
  AudioPlaybackBook? bookForTask(String id) => booksByTask[id];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected fixture call ${invocation.memberName}',
  );
}

class _CountingChapter extends AudioPlaybackChapter {
  _CountingChapter(int number)
    : super(
        id: 'chapter-$number',
        index: number,
        title: 'Chapter $number',
        duration: const Duration(minutes: 5),
      );
  static int idReads = 0;
  @override
  String get id {
    idReads++;
    return super.id;
  }
}
