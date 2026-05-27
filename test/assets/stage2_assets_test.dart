import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Stage 2 app icon draft assets exist', () {
    final iconDrafts = [
      'assets/app/app_icon_draft.svg',
      'assets/app/android_adaptive_icon_foreground.svg',
    ];

    for (final path in iconDrafts) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path must exist');

      final content = file.readAsStringSync();
      final contentWithoutNamespace = _withoutSvgNamespace(content);
      expect(content, contains('<svg'));
      expect(contentWithoutNamespace, isNot(contains('http://')));
      expect(contentWithoutNamespace, isNot(contains('https://')));
      expect(content, isNot(contains('<image')));
    }
  });

  test('Stage 2 SVG icon inventory exists and follows project style', () {
    for (final entry in _expectedLucideIcons.entries) {
      final path = entry.key;
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path must exist');

      final content = file.readAsStringSync();
      expect(
        content,
        contains('Source: Lucide v1.16.0 icon: ${entry.value}'),
        reason: path,
      );
      expect(content, contains('viewBox="0 0 24 24"'), reason: path);
      expect(content, contains('stroke="currentColor"'), reason: path);
      expect(content, contains('stroke-width="2"'), reason: path);
      final contentWithoutNamespace = _withoutSvgNamespace(content);
      expect(contentWithoutNamespace, isNot(contains('http://')), reason: path);
      expect(
        contentWithoutNamespace,
        isNot(contains('https://')),
        reason: path,
      );
      expect(content, isNot(contains('<image')), reason: path);
    }
  });

  test('Stage 2 download-state icons are visually distinct', () {
    const stateIcons = [
      'assets/icons/downloads/download.svg',
      'assets/icons/downloads/downloading.svg',
      'assets/icons/downloads/queued.svg',
      'assets/icons/downloads/downloaded.svg',
      'assets/icons/downloads/delete_download.svg',
      'assets/icons/downloads/retry.svg',
      'assets/icons/downloads/error.svg',
      'assets/icons/downloads/pause_download.svg',
      'assets/icons/downloads/resume_download.svg',
    ];

    final normalizedShapes = <String, String>{};
    for (final path in stateIcons) {
      final content = File(path).readAsStringSync();
      final shape = _normalizedSvgShape(content);
      final duplicate = normalizedShapes[shape];
      expect(
        duplicate,
        isNull,
        reason: '$path must not reuse the same glyph as $duplicate',
      );
      normalizedShapes[shape] = path;
    }
  });

  test(
    'Stage 2 app UI uses checked-in SVG icons instead of Material glyphs',
    () {
      final offenders =
          Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))
              .where((file) => file.readAsStringSync().contains('Icons.'))
              .map((file) => file.path)
              .toList()
            ..sort();

      expect(
        offenders,
        isEmpty,
        reason: 'User-facing app UI must use AppIcon/AppIconAssets SVG assets.',
      );
    },
  );
}

const _expectedLucideIcons = {
  'assets/icons/nav/home.svg': 'house',
  'assets/icons/nav/search.svg': 'search',
  'assets/icons/nav/library.svg': 'library-big',
  'assets/icons/nav/downloads.svg': 'download',
  'assets/icons/nav/settings.svg': 'settings',
  'assets/icons/book/author.svg': 'user-pen',
  'assets/icons/book/narrator.svg': 'mic',
  'assets/icons/book/duration.svg': 'clock-3',
  'assets/icons/book/year.svg': 'calendar',
  'assets/icons/book/published_year.svg': 'calendar-days',
  'assets/icons/book/audio_year.svg': 'calendar-clock',
  'assets/icons/book/series.svg': 'layers-3',
  'assets/icons/book/genre.svg': 'tags',
  'assets/icons/book/rating.svg': 'star',
  'assets/icons/book/source.svg': 'globe',
  'assets/icons/book/language.svg': 'languages',
  'assets/icons/book/full.svg': 'book-check',
  'assets/icons/book/fragment.svg': 'book-dashed',
  'assets/icons/book/favorite.svg': 'heart',
  'assets/icons/book/paid.svg': 'credit-card',
  'assets/icons/book/free.svg': 'unlock',
  'assets/icons/book/subscription.svg': 'ticket-check',
  'assets/icons/book/unknown_access.svg': 'badge-question-mark',
  'assets/icons/player/play.svg': 'play',
  'assets/icons/player/audio.svg': 'audio-lines',
  'assets/icons/player/pause.svg': 'pause',
  'assets/icons/player/stop.svg': 'square',
  'assets/icons/player/previous_chapter.svg': 'skip-back',
  'assets/icons/player/next_chapter.svg': 'skip-forward',
  'assets/icons/player/rewind_10.svg': 'rotate-ccw',
  'assets/icons/player/rewind_15.svg': 'undo-2',
  'assets/icons/player/rewind_30.svg': 'history',
  'assets/icons/player/forward_10.svg': 'rotate-cw',
  'assets/icons/player/forward_15.svg': 'redo-2',
  'assets/icons/player/forward_30.svg': 'refresh-cw',
  'assets/icons/player/speed.svg': 'gauge',
  'assets/icons/player/sleep_timer.svg': 'timer',
  'assets/icons/player/bookmark.svg': 'bookmark',
  'assets/icons/player/chapters.svg': 'list-ordered',
  'assets/icons/player/volume.svg': 'volume-2',
  'assets/icons/player/volume_off.svg': 'volume-x',
  'assets/icons/player/repeat.svg': 'repeat-2',
  'assets/icons/downloads/download.svg': 'download',
  'assets/icons/downloads/downloading.svg': 'loader-circle',
  'assets/icons/downloads/queued.svg': 'clock',
  'assets/icons/downloads/downloaded.svg': 'circle-check',
  'assets/icons/downloads/delete_download.svg': 'trash-2',
  'assets/icons/downloads/retry.svg': 'rotate-ccw',
  'assets/icons/downloads/error.svg': 'triangle-alert',
  'assets/icons/downloads/pause_download.svg': 'pause',
  'assets/icons/downloads/resume_download.svg': 'play',
  'assets/icons/system/back.svg': 'chevron-left',
  'assets/icons/system/forward.svg': 'chevron-right',
  'assets/icons/system/close.svg': 'x',
  'assets/icons/system/more.svg': 'ellipsis',
  'assets/icons/system/filter.svg': 'list-filter',
  'assets/icons/system/sort.svg': 'arrow-up-down',
  'assets/icons/system/refresh.svg': 'refresh-cw',
  'assets/icons/system/check.svg': 'check',
  'assets/icons/system/warning.svg': 'triangle-alert',
  'assets/icons/system/info.svg': 'info',
  'assets/icons/system/notification.svg': 'bell',
  'assets/icons/system/proxy.svg': 'waypoints',
  'assets/icons/system/theme.svg': 'paintbrush',
  'assets/icons/system/accent_color.svg': 'palette',
  'assets/icons/system/language.svg': 'languages',
  'assets/icons/system/trash.svg': 'trash-2',
  'assets/icons/system/edit.svg': 'pencil',
  'assets/icons/system/share.svg': 'share-2',
};

String _withoutSvgNamespace(String content) {
  return content.replaceAll('xmlns="http://www.w3.org/2000/svg"', '');
}

String _normalizedSvgShape(String content) {
  return content
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
      .replaceAll(RegExp(r'class="[^"]*"'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
