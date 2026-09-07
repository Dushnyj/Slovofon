import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_text_scaler.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/television_theme.dart';
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
  for (final dpr in [2.0, 4.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets(
          'TV downloads full-width queue DPR=$dpr text=$scale dark=$dark',
          (tester) async {
            tester.view.devicePixelRatio = dpr;
            tester.view.physicalSize = Size(960 * dpr, 540 * dpr);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPhysicalSize);
            final manager = _Downloads();
            final playback = PlaybackController(engine: InMemoryAudioEngine());
            addTearDown(playback.dispose);
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  downloadManagerProvider.overrideWith((ref) => manager),
                  playbackControllerProvider.overrideWithValue(playback),
                  playbackProgressSnapshotsProvider.overrideWith(
                    (ref) async => [],
                  ),
                ],
                child: MaterialApp(
                  theme: TelevisionTheme.from(
                    (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                      platform: TargetPlatform.android,
                    ),
                  ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: AppTextScaler(TextScaler.noScaling, scale),
                    ),
                    child: TelevisionLayout(
                      enabled: true,
                      child: TelevisionViewport(child: child!),
                    ),
                  ),
                  home: const Scaffold(
                    body: Row(
                      children: [
                        SizedBox(width: 56),
                        Expanded(child: DownloadsScreen()),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final first = find.byKey(
              const ValueKey('tv-download-book-izib:version-0'),
            );
            final second = find.byKey(
              const ValueKey('tv-download-book-izib:version-1'),
            );
            expect(first, findsOneWidget);
            expect(second, findsOneWidget);
            final firstRect = tester.getRect(first);
            final secondRect = tester.getRect(second);
            expect(firstRect.width, greaterThan(700));
            expect(secondRect.width, firstRect.width);
            expect(secondRect.top, greaterThan(firstRect.bottom));
            final layout = find.byKey(
              ValueKey(
                'tv-download-summary-${scale == 1 ? 'inline' : 'stacked'}-izib:version-0',
              ),
            );
            expect(layout, findsOneWidget);
            if (scale == 1) expect(firstRect.height, lessThanOrEqualTo(180));
            final context = tester.element(first);
            expect(MediaQuery.devicePixelRatioOf(context), dpr);
            expect(MediaQuery.textScalerOf(context).scale(14), 14 * scale);
            final progress = find.byKey(
              const ValueKey('tv-download-progress-izib:version-0'),
            );
            expect(tester.widget<LinearProgressIndicator>(progress).value, .4);
            final pause = find.descendant(
              of: first,
              matching: find.byTooltip('Pause download'),
            );
            await tester.ensureVisible(pause);
            await tester.pumpAndSettle();
            expect(pause.hitTestable(), findsOneWidget);
            _focusInside(pause).requestFocus();
            await tester.pumpAndSettle();
            await tester.sendKeyEvent(LogicalKeyboardKey.select);
            await tester.pumpAndSettle();
            expect(manager.paused, ['task-0']);
            final expansion = find.byKey(
              const PageStorageKey('tv-download-chapters-izib:version-0'),
            );
            await tester.ensureVisible(expansion);
            await tester.pumpAndSettle();
            await tester.tap(
              find.descendant(
                of: expansion,
                matching: find.text('0 of 1 chapter'),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Chapter 0'), findsOneWidget);
            expect(
              find.descendant(of: expansion, matching: find.text('1')),
              findsOneWidget,
            );
            expect(manager.books.first.chapters.single.index, 0);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

FocusNode _focusInside(Finder finder) {
  final root = finder.evaluate().single;
  return FocusManager.instance.rootScope.descendants.firstWhere((node) {
    if (!node.canRequestFocus || node.context == null) return false;
    var found = identical(node.context, root);
    node.context!.visitAncestorElements((element) {
      if (identical(element, root)) found = true;
      return !found;
    });
    return found;
  });
}

class _Downloads extends ChangeNotifier implements DownloadManager {
  final paused = <String>[];
  final books = [
    for (var i = 0; i < 2; i++)
      AudioPlaybackBook(
        id: 'book-$i',
        versionId: 'version-$i',
        sourceId: 'izib',
        sourceBookId: 'book-$i',
        sourceName: 'Izib',
        title: 'Classic $i',
        author: 'Author',
        narrator: 'Narrator',
        chapters: [
          AudioPlaybackChapter(
            id: 'chapter-$i',
            index: 0,
            title: 'Chapter $i',
            duration: const Duration(hours: 1),
          ),
        ],
      ),
  ];
  @override
  List<DownloadTask> get tasks => [
    for (var i = 0; i < 2; i++)
      DownloadTask(
        id: 'task-$i',
        bookId: books[i].id,
        bookVersionId: books[i].versionId,
        chapterId: books[i].chapters.single.id,
        sourceId: 'izib',
        type: DownloadTaskType.chapter,
        status: paused.contains('task-$i')
            ? DownloadTaskStatus.paused
            : DownloadTaskStatus.running,
        progress: .4,
        downloadedBytes: 4096,
        totalBytes: 10240,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
  ];
  @override
  AudioPlaybackBook? bookForTask(String id) {
    final index = tasks.indexWhere((task) => task.id == id);
    return index < 0 ? null : books[index];
  }

  @override
  Future<void> pause(String id) async {
    paused.add(id);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected fixture call: ${invocation.memberName}',
  );
}
