import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/ui/components/mini_player_bar.dart';

void main() {
  for (final wide in [false, true]) {
    for (var position = 0; position < 3; position++) {
      testWidgets(
        'mini-player ordinal uses list position wide=$wide chapter=$position',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(wide ? 1000 : 430, 800);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final controller = PlaybackController(engine: InMemoryAudioEngine());
          addTearDown(controller.dispose);
          final book = AudioPlaybackBook(
            id: 'ordinal',
            versionId: 'ordinal-v',
            sourceId: 'izib',
            sourceName: 'Izib',
            title: 'Classic',
            author: 'Author',
            narrator: 'Narrator',
            chapters: [
              for (final (i, rawIndex) in [0, 4, 97].indexed)
                AudioPlaybackChapter(
                  id: 'part-$i',
                  index: rawIndex,
                  title: 'Part $i',
                  duration: const Duration(minutes: 10),
                ),
            ],
          );
          await controller.loadBook(
            book,
            chapterIndex: position,
            autoPlay: false,
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                playbackControllerProvider.overrideWithValue(controller),
              ],
              child: MaterialApp(
                theme: AppTheme.dark().copyWith(
                  platform: TargetPlatform.android,
                ),
                home: Scaffold(
                  body: const SizedBox.expand(),
                  bottomNavigationBar: wide
                      ? const DesktopMiniPlayerBar()
                      : const MiniPlayerBar(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(
              'Chapter ${(position + 1).toString().padLeft(2, '0')}. Part $position',
            ),
            findsOneWidget,
          );
          expect(
            controller.state.book!.chapters.map((chapter) => chapter.index),
            [0, 4, 97],
          );
          expect(controller.state.currentChapter!.id, 'part-$position');
          expect(controller.state.chapterIndex, position);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
