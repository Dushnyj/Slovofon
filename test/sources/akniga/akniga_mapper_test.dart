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
      expect(result.series, 'Метро');
      expect(result.duration, const Duration(hours: 13, minutes: 6));
      expect(result.year, 2020);
      expect(result.ratingValue, 4.0);
      expect(result.ratingCount, 10);
      expect(result.accessType, AccessType.free);
      expect(
        result.coverUri.toString(),
        'https://akniga.org/covers/metro-search.jpg',
      );
    });

    test('uses title prefix as author fallback on search cards', () {
      final results = mapper.searchResults(_searchHtmlWithoutAuthorAction);

      expect(results, hasLength(1));
      expect(results.single.title, 'Метро 2033');
      expect(results.single.author, 'Дмитрий Глуховский');
    });

    test('search preserves a recognized fragment before enrichment', () {
      const html = '''
<div class="content__main__articles--item">
  <a class="content__article-main-link" href="/fixture">Книга</a>
  <h2 class="caption__article-main">Книга</h2>
  <a href="https://akniga.org/paid/">Фрагмент</a>
</div>''';
      final result = mapper.searchResults(html).single;
      expect(result.isFull, isFalse);
      expect(result.isFragment, isTrue);
    });

    test('author fallback does not invent a missing narrator', () {
      const html = '''
<article data-bid="1">
  <h1 class="caption__article-main">Книга</h1>
  <div class="about-author"><a href="/author/fixture">Автор книги</a></div>
</article>''';
      const ref = SourceBookRef(sourceId: 'akniga', sourceBookId: 'fixture');
      final details = mapper.bookDetails(html, ref);
      expect(details.version.authors, ['Автор книги']);
      expect(details.version.narrators, isEmpty);
      final narrated = mapper.bookDetails(
        '$html<div class="link__action"><i class="icon--performer"></i><a href="/reader/fixture">Автор книги</a></div>',
        ref,
      );
      expect(narrated.version.narrators, ['Автор книги']);
    });

    test('uses Akniga slug year when search card has no year label', () {
      final results = mapper.searchResults(_searchHtmlWithSlugYear);

      expect(results, hasLength(1));
      expect(results.single.title, 'Полураспад');
      expect(results.single.author, 'Зорич Александр');
      expect(results.single.series, 'S.T.A.L.K.E.R.: Комбат и Тополь');
      expect(results.single.year, 2010);
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
    <button class="ls-vote-item" data-vote-value="1">
      <span class="counter-number">8</span>
    </button>
    <button class="ls-vote-item" data-vote-value="-1">
      <span class="counter-number">2</span>
    </button>
  </div>
</body></html>
''';

const _searchHtmlWithoutAuthorAction = '''
<html><body>
  <div class="content__main__articles--item">
    <a href="https://akniga.org/metro-2033" class="content__article-main-link">
      <h2 class="caption__article-main">Дмитрий Глуховский – Метро 2033</h2>
    </a>
    <span class="link__action">
      <svg class="icon--performer"></svg>
      <a href="/performer/ivaschenko/">Петр Иващенко</a>
    </span>
  </div>
</body></html>
''';

const _searchHtmlWithSlugYear = '''
<html><body>
  <div class="content__main__articles--item">
    <a href="https://akniga.org/aleksandr-zorich-poluraspad-stalker-2010"
       class="content__article-main-link">
      <h2 class="caption__article-main">Зорич Александр – Полураспад</h2>
    </a>
    <span class="link__action">
      <svg class="icon--author"></svg>
      <a href="/author/zorich/">Зорич Александр</a>
    </span>
    <span class="link__action">
      <svg class="icon--performer"></svg>
      <a href="/performer/chaytsyn/">Чайцын Александр</a>
    </span>
    <span class="link__action--label--time">11 часов 49 минут</span>
    <div class="book-series">
      <a>S.T.A.L.K.E.R.: Комбат и Тополь (2)</a>
    </div>
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
