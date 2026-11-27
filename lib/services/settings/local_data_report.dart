import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../app/app_version.dart';
import '../../domain/models/download_task.dart';
import '../audio/audio_persistence.dart';
import '../audio/audio_state.dart';
import '../bookmarks/bookmark_store.dart';

/// Distinct allowlists: the export includes explicitly selected personal data;
/// the diagnostic report never serializes books, IDs, URL/headers or errors.
abstract final class LocalDataReport {
  static const _encoder = JsonEncoder.withIndent('  ');

  static String progressAndBookmarks({
    required List<PlaybackProgressSnapshot> progress,
    required List<PlaybackBookmark> bookmarks,
    required DateTime exportedAt,
  }) => _encoder.convert({
    'format': 'slovofon-playback-export',
    'schemaVersion': 1,
    'exportedAt': _utc(exportedAt),
    'progress': [
      for (final item in progress)
        {
          'bookId': item.bookId,
          'bookVersionId': item.bookVersionId,
          'currentChapterId': item.currentChapterId,
          'currentPositionMs': item.currentPositionMs,
          'maxReachedGlobalPositionMs': item.maxReachedGlobalPositionMs,
          'totalDurationMs': item.totalDurationMs,
          'listenedDurationMs': item.listenedDurationMs,
          'percent': item.percent.isFinite ? item.percent : null,
          'isFinished': item.isFinished,
          'lastPlayedAt': _utc(item.lastPlayedAt),
        },
    ],
    'bookmarks': [
      for (final item in bookmarks)
        {
          'id': item.id,
          'bookId': item.bookId,
          'bookVersionId': item.bookVersionId,
          'chapterId': item.chapterId,
          'positionMs': item.positionMs,
          'title': item.title,
          'note': item.note,
          'createdAt': _utc(item.createdAt),
          'updatedAt': _utc(item.updatedAt),
        },
    ],
  });

  static String diagnostics({
    required TargetPlatform platform,
    required AudioPlaybackStatus playbackStatus,
    required Iterable<DownloadTaskStatus>? downloadStatuses,
  }) {
    final downloadCounts = downloadStatuses == null
        ? null
        : {for (final status in DownloadTaskStatus.values) status.name: 0};
    if (downloadCounts != null && downloadStatuses != null) {
      for (final status in downloadStatuses) {
        downloadCounts.update(status.name, (total) => total + 1);
      }
    }
    return _encoder.convert({
      'format': 'slovofon-local-diagnostic',
      'schemaVersion': 1,
      'version': AppVersion.version,
      'build': AppVersion.buildNumber,
      'platform': platform.name,
      'playbackStatus': playbackStatus.name,
      'downloadsByStatus': downloadCounts,
    });
  }

  static String _utc(DateTime date) => date.toUtc().toIso8601String();
}
