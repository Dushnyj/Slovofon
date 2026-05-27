import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/book_version.dart';
import 'package:slovofon/sources/akniga/akniga_mapper.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  group('AknigaMapper', () {
    final mapper = AknigaMapper(clock: () => DateTime.utc(2026, 5, 27, 12));

    test('maps HTML search results to source result cards', () {
      final results = mapper.searchResults(_searchHtml);

      expect(results, hasLength(1));
      final result = results.single;
      expect(result.sourceId, 'akniga');
      expect(result.sourceName, 'Akniga');
      expect(result.sourceBookId, 'metro-2033');
      expect(result.ref.sourceUri.toString(), 'https://akniga.org/metro-2033');
      expect(result.title, 'Метро 2033');
      expect(result.author, 'Дмитрий Глуховский');
      expect(result.narrator, 'Петр Иващенко');
      expect(result.series, 'Метро (1)');
      expect(result.duration, const Duration(hours: 13, minutes: 6));
      expect(result.year, 2020);
      expect(result.accessType, AccessType.free);
      expect(
        result.coverUri.toString(),
        'https://akniga.org/covers/metro-search.jpg',
      );
    });

    test(
      'maps details, chapters, and audio tracks from page and ajax data',
      () {
        final ref = SourceBookRef(
          sourceId: 'akniga',
          sourceBookId: 'metro-2033',
          sourceUri: Uri.parse('https://akniga.org/metro-2033'),
        );
        final tracksPayload = _trackItems();

        final bid = mapper.bookIdFromHtml(_bookHtml);
        final details = mapper.bookDetails(_bookHtml, ref);
        final chapters = mapper.chapters(_bookHtml, ref, tracksPayload);
        final tracks = mapper.audioTracks(chapters);

        expect(bid, '777');
        expect(details.version.id, 'akniga-metro-2033');
        expect(details.version.bookId, 'akniga-book-metro-2033');
        expect(details.version.sourceUrl, 'https://akniga.org/metro-2033');
        expect(details.version.title, 'Метро 2033');
        expect(details.version.authors, ['Дмитрий Глуховский']);
        expect(details.version.narrators, ['Петр Иващенко']);
        expect(details.version.seriesTitle, 'Метро');
        expect(details.version.genres, ['Фантастика', 'постапокалипсис']);
        expect(details.version.description, 'Москва после войны.');
        expect(details.version.publishedYear, 2020);
        expect(details.version.audioYear, 2021);
        expect(details.version.durationMs, 47160000);
        expect(details.version.ratingValue, 4.0);
        expect(details.version.ratingCount, 10);
        expect(details.version.accessType, AccessType.free);
        expect(
          details.version.playbackAccess,
          PlaybackAccess.streamAndDownload,
        );
        expect(details.version.canStream, isTrue);
        expect(details.version.canDownload, isTrue);
        expect(
          details.version.coverUrl,
          'https://akniga.org/covers/metro-details.jpg',
        );

        expect(chapters, hasLength(2));
        expect(chapters.first.id, 'akniga-metro-2033-chapter-501');
        expect(chapters.first.bookVersionId, 'akniga-metro-2033');
        expect(chapters.first.sourceChapterId, '501');
        expect(chapters.first.index, 1);
        expect(chapters.first.title, 'Глава 01. Артем');
        expect(chapters.first.durationMs, 1260000);
        expect(
          chapters.first.streamRef,
          'https://r1.akniga.club/books/metro/001.mp3',
        );
        expect(chapters.last.durationMs, 1243000);
        expect(chapters.last.audioFormat, 'mp3');

        expect(tracks, hasLength(2));
        expect(tracks.first.mediaRef, chapters.first.streamRef);
        final headers =
            jsonDecode(tracks.first.headersJson ?? '{}')
                as Map<String, Object?>;
        expect(headers['Referer'], 'https://akniga.org/metro-2033');
      },
    );

    test('marks pages without ajax/bid as restricted', () {
      final ref = SourceBookRef(
        sourceId: 'akniga',
        sourceBookId: 'paid-book',
        sourceUri: Uri.parse('https://akniga.org/paid-book'),
      );

      final details = mapper.bookDetails(_bookHtmlWithoutBid, ref);

      expect(details.version.playbackAccess, PlaybackAccess.none);
      expect(details.version.canStream, isFalse);
      expect(details.version.canDownload, isFalse);
    });
  });
}

List<Map<String, Object?>> _trackItems() {
  return [
    {
      'id': '501',
      'title': 'Глава 01. Артем',
      'mp3': 'https://r1.akniga.club/books/metro/001.mp3',
      'duration': 1260,
      'time': 1260,
    },
    {
      'id': '502',
      'titleonly': '002',
      'file': 'https://cdn.audioknigi.xyz/books/metro/002.mp3',
      'time': 2503,
    },
  ];
}

const _searchHtml = '''
<html><body>
  <div class="content__main__articles--item" data-bid="777">
    <a href="https://akniga.org/metro-2033" class="content__article-main-link">
      <h2 class="caption__article-main">Дмитрий Глуховский – Метро 2033</h2>
    </a>
    <img class="topic" data-src="/covers/metro-search.jpg">
    <span class="link__action">
      <svg class="icon--author"></svg>
      <a href="/author/gluhovskiy/">Дмитрий Глуховский</a>
    </span>
    <span class="link__action">
      <svg class="icon--performer"></svg>
      <a href="/performer/ivaschenko/">Петр Иващенко</a>
    </span>
    <span class="link__action--label--time">13 ч 6 мин</span>
    <div class="book-series"><a>Метро (1)</a></div>
    <span class="link__action--label--year">2020</span>
  </div>
</body></html>
''';

const _bookHtml = '''
<html><body>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Audiobook",
    "name": "Метро 2033",
    "description": "Описание из json",
    "image": "https://akniga.org/covers/fallback.jpg",
    "duration": "PT13H6M",
    "isAccessibleForFree": true,
    "readBy": {"name": "Петр Иващенко"}
  }
  </script>
  <script>LIVESTREET_SECURITY_KEY = 'live-key';</script>
  <article data-bid="777">
    <h1 class="caption__article-main">Дмитрий Глуховский – Метро 2033</h1>
    <img class="topic" data-src="/covers/metro-details.jpg">
    <span class="link__action">
      <svg class="icon--author"></svg>
      <a href="/author/gluhovskiy/">Дмитрий Глуховский</a>
    </span>
    <span class="link__action">
      <svg class="icon--performer"></svg>
      <a href="/performer/ivaschenko/">Петр Иващенко</a>
    </span>
    <span class="hours">13 ч</span> <span class="minutes">6 мин</span>
    <a class="link__series" href="/series/metro">Метро (1)</a>
    <a class="section__title"><span>Фантастика, постапокалипсис</span></a>
    <div class="description__article-main">
      <div class="content__main__book--item--caption">Описание</div>
      Москва после войны.
    </div>
    <div class="description__article-main">
      <div class="content__main__book--item--caption">Год издания</div>
      2020
    </div>
    <div class="description__article-main">
      <div class="content__main__book--item--caption">Год озвучки</div>
      2021
    </div>
    <button class="ls-vote-item" data-vote-value="1">
      <span class="counter-number">8</span>
    </button>
    <button class="ls-vote-item" data-vote-value="-1">
      <span class="counter-number">2</span>
    </button>
  </article>
</body></html>
''';

const _bookHtmlWithoutBid = '''
<html><body>
  <h1 class="caption__article-main">Платная книга</h1>
  <a href="https://akniga.org/paid/">Слушать полностью</a>
</body></html>
''';
