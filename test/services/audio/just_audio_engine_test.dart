import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/just_audio_engine.dart';

void main() {
  group('JustAudioEngine', () {
    test('loads a URL media source and forwards playback commands', () async {
      final adapter = RecordingJustAudioPlayerAdapter();
      final engine = JustAudioEngine(player: adapter);
      final chapter = AudioPlaybackChapter(
        id: 'chapter-1',
        index: 1,
        title: 'Глава 1',
        duration: const Duration(minutes: 10),
        mediaSource: AudioMediaSource.url(
          Uri.parse('https://media.example.test/chapter-1.mp3'),
          headers: const {'User-Agent': 'Slovofon'},
        ),
      );

      await engine.load(chapter, position: const Duration(seconds: 42));
      await engine.setSpeed(1.25);
      await engine.play();
      await engine.seek(const Duration(minutes: 2));
      await engine.pause();

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.source.type, AudioMediaSourceType.url);
      expect(
        adapter.requests.single.source.uri.toString(),
        'https://media.example.test/chapter-1.mp3',
      );
      expect(adapter.requests.single.source.headers, const {
        'User-Agent': 'Slovofon',
      });
      expect(
        adapter.requests.single.initialPosition,
        const Duration(seconds: 42),
      );
      expect(adapter.speedValues, [1.25]);
      expect(adapter.seekPositions, [const Duration(minutes: 2)]);
      expect(adapter.playCount, 1);
      expect(adapter.pauseCount, 1);
    });

    test('fails explicitly when a chapter has no playable media source', () {
      final engine = JustAudioEngine(player: RecordingJustAudioPlayerAdapter());
      const chapter = AudioPlaybackChapter(
        id: 'chapter-1',
        index: 1,
        title: 'Глава 1',
        duration: Duration(minutes: 10),
      );

      expect(
        () => engine.load(chapter, position: Duration.zero),
        throwsA(isA<AudioEngineException>()),
      );
    });

    test('disposes the adapter only once when disposed repeatedly', () async {
      final adapter = RecordingJustAudioPlayerAdapter();
      final engine = JustAudioEngine(player: adapter);

      await engine.dispose();
      await engine.dispose();

      expect(adapter.disposeCount, 1);
    });
  });
}

class RecordingJustAudioPlayerAdapter implements JustAudioPlayerAdapter {
  final _positions = StreamController<Duration>.broadcast();
  final _snapshots = StreamController<JustAudioAdapterSnapshot>.broadcast();
  final requests = <AudioLoadRequest>[];
  final speedValues = <double>[];
  final seekPositions = <Duration>[];
  int playCount = 0;
  int pauseCount = 0;
  int disposeCount = 0;
  bool disposed = false;

  @override
  Stream<JustAudioAdapterSnapshot> get playbackSnapshots => _snapshots.stream;

  @override
  Stream<Duration> get positionStream => _positions.stream;

  @override
  Future<void> dispose() async {
    disposeCount++;
    disposed = true;
    await _positions.close();
    await _snapshots.close();
  }

  @override
  Future<void> load(AudioLoadRequest request) async {
    requests.add(request);
  }

  @override
  Future<void> pause() async {
    pauseCount++;
  }

  @override
  Future<void> play() async {
    playCount++;
  }

  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    speedValues.add(speed);
  }
}
