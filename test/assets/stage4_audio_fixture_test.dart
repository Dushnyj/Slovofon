import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/data/mock/mock_audio_playback.dart';
import 'package:slovofon/data/mock/stage3_mock_data.dart';
import 'package:slovofon/services/audio/audio_state.dart';

void main() {
  test('Stage 4 local audio fixture exists and is used by mock playback', () {
    final fixture = File('assets/audio/stage4_mock_chapter.wav');
    final book = mockAudioPlaybackBook(activeMockBook);

    expect(fixture.existsSync(), isTrue);
    expect(fixture.lengthSync(), greaterThan(1024));
    expect(book.chapters, isNotEmpty);
    expect(book.chapters.first.mediaSource?.type, AudioMediaSourceType.asset);
    expect(
      book.chapters.first.mediaSource?.assetPath,
      'assets/audio/stage4_mock_chapter.wav',
    );
  });

  test('mock audio fixture is long enough for every mock chapter', () {
    for (final mockBook in stage3MockBooks) {
      final book = mockAudioPlaybackBook(mockBook);

      for (final chapter in book.chapters) {
        final source = chapter.mediaSource;
        expect(source?.type, AudioMediaSourceType.asset);

        final fixture = File(_assetPath(source!.assetPath));
        final fixtureDuration = _wavDuration(fixture);

        expect(
          fixtureDuration.inMilliseconds,
          greaterThanOrEqualTo(chapter.duration.inMilliseconds),
          reason:
              '${source.assetPath} must cover ${mockBook.title} / '
              '${chapter.title} (${chapter.duration}).',
        );
      }
    }
  });
}

String _assetPath(String assetPath) {
  return assetPath.replaceAll('/', Platform.pathSeparator);
}

Duration _wavDuration(File file) {
  expect(file.existsSync(), isTrue, reason: '${file.path} must exist.');

  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  final riff = String.fromCharCodes(bytes.sublist(0, 4));
  final wave = String.fromCharCodes(bytes.sublist(8, 12));
  expect(riff, 'RIFF');
  expect(wave, 'WAVE');

  int? byteRate;
  int? dataSize;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final chunkSize = data.getUint32(offset + 4, Endian.little);
    final chunkDataOffset = offset + 8;

    if (chunkId == 'fmt ') {
      byteRate = data.getUint32(chunkDataOffset + 8, Endian.little);
    } else if (chunkId == 'data') {
      dataSize = chunkSize;
    }

    offset = chunkDataOffset + chunkSize + (chunkSize.isOdd ? 1 : 0);
  }

  expect(byteRate, isNotNull);
  expect(dataSize, isNotNull);

  return Duration(
    microseconds: ((dataSize! / byteRate!) * Duration.microsecondsPerSecond)
        .round(),
  );
}
