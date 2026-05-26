import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/book_version.dart';
import 'package:slovofon/domain/models/chapter.dart';
import 'package:slovofon/sources/izib/izib_mapper.dart';

void main() {
  group('IzibMapper', () {
    final mapper = IzibMapper(clock: () => DateTime.utc(2026, 5, 26, 12));

    test('maps search books to source results', () {
      final payload = _fixture('izib_search_response.json');
      final items =
          ((payload['data'] as Map<String, Object?>)['booksSearch']!
                  as Map<String, Object?>)['items']!
              as List<Object?>;

      final results = mapper.searchResults(items);

      expect(results, hasLength(1));
      expect(results.single.sourceId, 'izib');
      expect(results.single.sourceBookId, '2033');
      expect(
        results.single.ref.sourceUri.toString(),
        'https://izib.uk/art2033',
      );
      expect(results.single.sourceName, 'Izib');
      expect(results.single.title, 'Метро 2033');
      expect(results.single.author, 'Дмитрий Глуховский');
      expect(results.single.narrator, 'Петр Иващенко');
      expect(
        results.single.coverUri.toString(),
        'https://izib.uk/covers/metro-2033.jpg',
      );
      expect(results.single.duration, const Duration(hours: 13, minutes: 6));
      expect(results.single.isFree, isNull);
      expect(results.single.accessType, AccessType.unknown);
    });

    test('maps book details, chapters, and audio tracks', () {
      final book = _bookFixture();
      final ref = mapper.bookRef(book);

      final details = mapper.bookDetails(book);
      final chapters = mapper.chapters(book);
      final tracks = mapper.audioTracks(book);

      expect(ref.sourceId, 'izib');
      expect(ref.sourceBookId, '2033');
      expect(details.version.id, 'izib-2033');
      expect(details.version.bookId, 'izib-book-2033');
      expect(details.version.sourceUrl, 'https://izib.uk/art2033');
      expect(details.version.title, 'Метро 2033');
      expect(details.version.authors, ['Дмитрий Глуховский']);
      expect(details.version.narrators, ['Петр Иващенко']);
      expect(details.version.genres, ['Фантастика']);
      expect(details.version.durationMs, 47160000);
      expect(details.version.publishedYear, 2020);
      expect(details.version.ratingValue, 4.5);
      expect(details.version.ratingCount, 10);
      expect(details.version.accessType, AccessType.free);
      expect(details.version.playbackAccess, PlaybackAccess.streamAndDownload);
      expect(details.version.canStream, isTrue);
      expect(details.version.canDownload, isTrue);

      expect(chapters, hasLength(2));
      expect(chapters.first.id, 'izib-2033-chapter-501');
      expect(chapters.first.index, 1);
      expect(chapters.first.title, 'Глава 01. Артем');
      expect(chapters.first.durationMs, 1260000);
      expect(
        chapters.first.streamRef,
        'https://audio.izib.uk/books/2033/001.mp3',
      );
      expect(chapters.first.audioFormat, 'mp3');
      expect(chapters.first.downloadStatus, ChapterDownloadStatus.none);
      expect(chapters.last.title, '002');

      expect(tracks, hasLength(2));
      expect(tracks.first.id, 'izib-2033-track-501');
      expect(tracks.first.mediaRef, 'https://audio.izib.uk/books/2033/001.mp3');
      expect(
        tracks.first.directUrl,
        'https://audio.izib.uk/books/2033/001.mp3',
      );
      expect(tracks.first.format, 'mp3');
      expect(tracks.first.mimeType, 'audio/mpeg');
    });

    test('marks books without API files as restricted', () {
      final book = Map<String, Object?>.from(_bookFixture())
        ..['files'] = {'full': <Object?>[], 'mobile': <Object?>[]};

      final details = mapper.bookDetails(book);
      final chapters = mapper.chapters(book);

      expect(details.version.accessType, AccessType.unknown);
      expect(details.version.playbackAccess, PlaybackAccess.none);
      expect(details.version.canStream, isFalse);
      expect(details.version.canDownload, isFalse);
      expect(chapters, isEmpty);
    });
  });
}

Map<String, Object?> _bookFixture() {
  final payload = _fixture('izib_book_response.json');
  return ((payload['data'] as Map<String, Object?>)['book']!
      as Map<String, Object?>);
}

Map<String, Object?> _fixture(String name) {
  final file = File('test/sources/izib/fixtures/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}
