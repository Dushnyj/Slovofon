import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/book_version.dart';
import 'package:slovofon/sources/yakniga/yakniga_mapper.dart';

void main() {
  group('YaknigaMapper', () {
    final mapper = YaknigaMapper(clock: () => DateTime.utc(2026, 5, 27, 12));

    test('maps GraphQL search books to source result cards', () {
      final results = mapper.searchResults([
        _searchBook(),
        const {'__typename': 'Ebook', 'id': 'skip-me'},
      ]);

      expect(results, hasLength(1));
      final result = results.single;
      expect(result.sourceId, 'yakniga');
      expect(result.sourceName, 'Yakniga');
      expect(result.sourceBookId, '50148');
      expect(
        result.ref.sourceUri.toString(),
        'https://yakniga.org/groshev-nikolay/s-t-a-l-k-e-r-dyhanie-zony',
      );
      expect(result.title, 'S.T.A.L.K.E.R. Дыхание зоны');
      expect(result.author, 'Грошев Николай');
      expect(result.narrator, 'Зобнин Тимофей');
      expect(result.series, 'Велес');
      expect(
        result.coverUri.toString(),
        'https://yakniga.org/covers/50148.webp',
      );
      expect(result.duration, const Duration(hours: 18, minutes: 2));
      expect(result.year, 2021);
      expect(result.chapterCount, 12);
      expect(result.accessType, AccessType.free);
      expect(result.ratingValue, 4.1);
    });

    test('decodes HTML entities from GraphQL text fields', () {
      final results = mapper.searchResults([
        {
          ..._searchBook(),
          'title': 'Как Coca-Cola, Ernst &amp; Young вдохновляют сотрудников',
          'authors': [
            {'name': 'Кожевникова &amp; партнёры'},
          ],
        },
      ]);

      expect(
        results.single.title,
        'Как Coca-Cola, Ernst & Young вдохновляют сотрудников',
      );
      expect(results.single.author, 'Кожевникова & партнёры');
    });

    test('maps details, chapters, and audio tracks from GraphQL book', () {
      final details = mapper.bookDetails(_bookWithChapters());
      final chapters = mapper.chapters(_bookWithChapters());
      final tracks = mapper.audioTracks(_bookWithChapters());

      expect(details.ref.sourceId, 'yakniga');
      expect(details.ref.sourceBookId, '50148');
      expect(
        details.ref.sourceUri.toString(),
        'https://yakniga.org/groshev-nikolay/s-t-a-l-k-e-r-dyhanie-zony',
      );
      expect(details.version.id, 'yakniga-50148');
      expect(details.version.bookId, 'yakniga-book-50148');
      expect(details.version.title, 'S.T.A.L.K.E.R. Дыхание зоны');
      expect(details.version.authors, ['Грошев Николай']);
      expect(details.version.narrators, ['Зобнин Тимофей']);
      expect(details.version.seriesTitle, 'Велес');
      expect(details.version.genres, ['Фантастика']);
      expect(details.version.description, 'Сталкеры возвращаются в Зону.');
      expect(details.version.durationMs, 64920000);
      expect(details.version.publishedYear, 2021);
      expect(details.version.ratingValue, 4.1);
      expect(details.version.accessType, AccessType.free);
      expect(details.version.playbackAccess, PlaybackAccess.streamAndDownload);
      expect(details.version.canStream, isTrue);
      expect(details.version.canDownload, isTrue);

      expect(chapters, hasLength(2));
      expect(chapters.first.id, 'yakniga-50148-chapter-606684');
      expect(chapters.first.bookVersionId, 'yakniga-50148');
      expect(chapters.first.sourceChapterId, '606684');
      expect(chapters.first.index, 1);
      expect(chapters.first.title, '0 вступление');
      expect(chapters.first.durationMs, 64000);
      expect(
        chapters.first.streamRef,
        'https://yakniga.org/files/sata1/books/50/50148/chapter_0.mp3',
      );
      expect(chapters.last.index, 2);
      expect(chapters.last.audioFormat, 'mp3');
      expect(chapters.last.mimeType, 'audio/mpeg');

      expect(tracks, hasLength(2));
      expect(tracks.first.chapterId, chapters.first.id);
      expect(tracks.first.mediaRef, chapters.first.streamRef);
      final headers =
          jsonDecode(tracks.first.headersJson ?? '{}') as Map<String, Object?>;
      expect(
        headers['Referer'],
        'https://yakniga.org/groshev-nikolay/s-t-a-l-k-e-r-dyhanie-zony',
      );
    });

    test('marks copyright-blocked books as restricted', () {
      final details = mapper.bookDetails({
        ..._bookWithChapters(),
        'copyrightBlock': true,
        'chapters': const {'collection': <Object?>[]},
      });

      expect(details.version.playbackAccess, PlaybackAccess.none);
      expect(details.version.canStream, isFalse);
      expect(details.version.canDownload, isFalse);
      expect(details.version.accessType, AccessType.unknown);
    });
  });
}

Map<String, Object?> _searchBook() {
  return {
    '__typename': 'Book',
    'id': '50148',
    'title': 'S.T.A.L.K.E.R. Дыхание зоны',
    'aliasName': 's-t-a-l-k-e-r-dyhanie-zony',
    'authorAlias': 'groshev-nikolay',
    'authorName': 'Грошев Николай',
    'cover180': '/covers/50148.webp',
    'duration': 64920,
    'chaptersCount': 12,
    'rating': 8.25,
    'price': null,
    'publishDate': '2021-05-01T00:00:00+03:00',
    'readers': [
      {'id': '3551', 'name': 'Зобнин Тимофей', 'aliasName': 'zobnin-timofey'},
    ],
    'authors': [
      {'id': '6929', 'name': 'Грошев Николай', 'aliasName': 'groshev-nikolay'},
    ],
    'series': {'id': '1873', 'name': 'Велес', 'aliasName': 'veles'},
    'genres': {
      'collection': [
        {'name': 'Фантастика', 'aliasName': 'fantastika'},
      ],
    },
  };
}

Map<String, Object?> _bookWithChapters() {
  return {
    ..._searchBook(),
    'cover360': '/covers/50148-large.webp',
    'copyrightBlock': false,
    'description': '<p>Сталкеры возвращаются в Зону.</p>',
    'summary': '',
    'summaryShort': '',
    'chapters': {
      'collection': [
        {
          'id': '606684',
          'name': '0 вступление',
          'duration': 64,
          'fileUrl': '/files/sata1/books/50/50148/chapter_0.mp3',
          'pos': 0,
        },
        {
          'id': '606766',
          'name': '1 глава',
          'duration': 1245,
          'fileUrl': '/files/sata1/books/50/50148/chapter_1.mp3',
          'pos': 1,
        },
      ],
    },
  };
}
