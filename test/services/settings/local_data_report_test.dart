import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/services/audio/audio_persistence.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/bookmarks/bookmark_store.dart';
import 'package:slovofon/services/settings/local_data_report.dart';

void main() {
  test('manual export preserves bookmark notes and playback checkpoints', () {
    final now = DateTime.parse('2026-11-27T12:34:56+03:00');
    final result =
        jsonDecode(
              LocalDataReport.progressAndBookmarks(
                progress: [
                  PlaybackProgressSnapshot(
                    bookId: 'book',
                    bookVersionId: 'edition',
                    currentChapterId: 'chapter',
                    currentPositionMs: 820,
                    maxReachedGlobalPositionMs: 2600,
                    totalDurationMs: 12000,
                    listenedDurationMs: 1200,
                    percent: .1,
                    isFinished: false,
                    lastPlayedAt: now,
                  ),
                ],
                bookmarks: [
                  PlaybackBookmark(
                    id: 'bookmark',
                    bookId: 'book',
                    bookVersionId: 'edition',
                    chapterId: 'chapter',
                    positionMs: 810,
                    title: 'Название',
                    note: 'Личная заметка',
                    createdAt: now,
                    updatedAt: now,
                  ),
                ],
                exportedAt: now,
              ),
            )
            as Map<String, dynamic>;
    expect(result['format'], 'slovofon-playback-export');
    expect(result['schemaVersion'], 1);
    expect(result['exportedAt'], '2026-11-27T09:34:56.000Z');
    final progress = (result['progress'] as List<dynamic>).single as Map;
    final bookmark = (result['bookmarks'] as List<dynamic>).single as Map;
    expect(progress['currentPositionMs'], 820);
    expect(progress['bookVersionId'], 'edition');
    expect(bookmark['title'], 'Название');
    expect(bookmark['note'], 'Личная заметка');
    expect(bookmark.containsKey('book'), isFalse);
  });

  test(
    'diagnostics uses an explicit schema and distinguishes missing counters',
    () {
      final result =
          jsonDecode(
                LocalDataReport.diagnostics(
                  platform: TargetPlatform.windows,
                  playbackStatus: AudioPlaybackStatus.error,
                  downloadStatuses: [
                    DownloadTaskStatus.queued,
                    DownloadTaskStatus.failed,
                    DownloadTaskStatus.failed,
                  ],
                ),
              )
              as Map<String, dynamic>;
      expect(result.keys.toSet(), {
        'format',
        'schemaVersion',
        'version',
        'build',
        'platform',
        'playbackStatus',
        'downloadsByStatus',
      });
      expect(result['platform'], 'windows');
      expect(result['playbackStatus'], 'error');
      expect(result['downloadsByStatus'], {
        'queued': 1,
        'running': 0,
        'paused': 0,
        'completed': 0,
        'failed': 2,
        'canceled': 0,
      });

      final unavailable =
          jsonDecode(
                LocalDataReport.diagnostics(
                  platform: TargetPlatform.android,
                  playbackStatus: AudioPlaybackStatus.paused,
                  downloadStatuses: null,
                ),
              )
              as Map<String, dynamic>;
      expect(unavailable['downloadsByStatus'], isNull);
    },
  );
}
