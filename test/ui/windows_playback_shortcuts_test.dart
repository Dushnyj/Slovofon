import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/ui/adaptive/windows_playback_shortcuts.dart';

const _book = AudioPlaybackBook(
  id: 'shortcut-book',
  versionId: 'shortcut-version',
  sourceId: 'fixture',
  title: 'Book',
  author: 'Author',
  narrator: 'Narrator',
  sourceName: 'Fixture',
  chapters: [
    AudioPlaybackChapter(
      id: 'one',
      index: 0,
      title: 'One',
      duration: Duration(minutes: 10),
    ),
    AudioPlaybackChapter(
      id: 'two',
      index: 1,
      title: 'Two',
      duration: Duration(minutes: 10),
    ),
    AudioPlaybackChapter(
      id: 'three',
      index: 2,
      title: 'Three',
      duration: Duration(minutes: 10),
    ),
  ],
);

void main() {
  testWidgets('Space toggles the shared controller once per physical press', (
    tester,
  ) async {
    final playback = await _playback();
    await _pump(tester, playback);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(playback.toggles, 1);
    expect(playback.state.isPlaying, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(playback.toggles, 2);
    expect(playback.state.isPlaying, isFalse);
  });

  testWidgets('Ctrl arrows seek15s and Alt arrows switch exactly one chapter', (
    tester,
  ) async {
    final playback = await _playback();
    await _pump(tester, playback);
    await _chord(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.arrowRight,
    );
    expect(playback.state.position, const Duration(seconds: 75));
    await _chord(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.arrowLeft,
    );
    expect(playback.state.position, const Duration(seconds: 60));
    expect(playback.skips, [
      const Duration(seconds: 15),
      const Duration(seconds: -15),
    ]);
    await _chord(
      tester,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.arrowRight,
    );
    expect(playback.state.chapterIndex, 2);
    expect(playback.nextCalls, 1);
    await _chord(
      tester,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.arrowLeft,
    );
    expect(playback.state.chapterIndex, 1);
    expect(playback.previousCalls, 1);
  });

  testWidgets('typing and editing shortcuts do not control playback', (
    tester,
  ) async {
    final playback = await _playback();
    final text = TextEditingController(text: 'Find this book');
    addTearDown(text.dispose);
    await _pump(tester, playback, child: TextField(controller: text));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await _chord(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.arrowLeft,
    );
    await _chord(
      tester,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.arrowRight,
    );
    expect(playback.toggles, 0);
    expect(playback.skips, isEmpty);
    expect(playback.nextCalls, 0);
    expect(playback.state.position, const Duration(seconds: 60));
  });

  testWidgets(
    'Space still activates the focused button without playing audio',
    (tester) async {
      final playback = await _playback();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var activations = 0;
      await _pump(
        tester,
        playback,
        child: FilledButton(
          focusNode: focus,
          onPressed: () => activations++,
          child: const Text('Action'),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(activations, 1);
      expect(playback.toggles, 0);
    },
  );

  testWidgets(
    'Android and TV hardware keys are not registered by this wrapper',
    (tester) async {
      final playback = await _playback();
      await _pump(tester, playback, platform: TargetPlatform.android);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await _chord(
        tester,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.arrowRight,
      );
      await _chord(
        tester,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.arrowRight,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
      expect(playback.toggles, 0);
      expect(playback.skips, isEmpty);
      expect(playback.nextCalls, 0);
    },
  );

  testWidgets(
    'unmodified arrows, media keys and empty playback remain untouched',
    (tester) async {
      final playback = await _playback();
      await _pump(tester, playback);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
      await _chord(
        tester,
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.space,
      );
      expect(playback.toggles, 0);
      expect(playback.nextCalls, 0);
      expect(playback.skips, isEmpty);
      final empty = _RecordingPlaybackController();
      addTearDown(empty.dispose);
      await _pump(tester, empty);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(empty.toggles, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<_RecordingPlaybackController> _playback() async {
  final playback = _RecordingPlaybackController();
  addTearDown(playback.dispose);
  await playback.loadBook(
    _book,
    chapterIndex: 1,
    position: const Duration(seconds: 60),
  );
  return playback;
}

Future<void> _pump(
  WidgetTester tester,
  PlaybackController playback, {
  TargetPlatform platform = TargetPlatform.windows,
  Widget? child,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [playbackControllerProvider.overrideWithValue(playback)],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        builder: (context, child) => WindowsPlaybackShortcuts(child: child!),
        home: Scaffold(
          body:
              child ??
              const Focus(autofocus: true, child: Text('Playback surface')),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _chord(
  WidgetTester tester,
  LogicalKeyboardKey modifier,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
}

class _RecordingPlaybackController extends PlaybackController {
  _RecordingPlaybackController() : super(engine: InMemoryAudioEngine());
  int toggles = 0;
  int nextCalls = 0;
  int previousCalls = 0;
  final skips = <Duration>[];

  @override
  Future<void> togglePlayPause() {
    toggles++;
    return super.togglePlayPause();
  }

  @override
  Future<void> skipBy(Duration delta) {
    skips.add(delta);
    return super.skipBy(delta);
  }

  @override
  Future<void> nextChapter() {
    nextCalls++;
    return super.nextChapter();
  }

  @override
  Future<void> previousChapter() {
    previousCalls++;
    return super.previousChapter();
  }
}
