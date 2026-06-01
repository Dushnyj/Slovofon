import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/book_version.dart';
import 'package:slovofon/sources/knigoblud/knigoblud_mapper.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  group('KnigobludMapper', () {
    final mapper = KnigobludMapper(clock: () => DateTime.utc(2026, 5, 27, 12));

    test('maps HTML search results to source result cards', () {
      final results = mapper.searchResults(_searchHtml);

      expect(results, hasLength(1));
      final result = results.single;
      expect(result.sourceId, 'knigoblud');
      expect(result.sourceName, 'Knigoblud');
      expect(result.sourceBookId, '09a908a6-0ff5-4080-b607-fc3ca3684672');
      expect(
        result.ref.sourceUri.toString(),
        'https://www.knigoblud.club/09a908a6-0ff5-4080-b607-fc3ca3684672',
      );
      expect(result.title, 'S.T.A.L.K.E.R. Дыхание зоны');
      expect(result.author, 'Николай Грошев');
      expect(result.series, 'Велес');
      expect(result.duration, const Duration(hours: 18));
      expect(result.year, 2019);
      expect(
        result.coverUri.toString(),
        'https://r7.audioknigi.xyz/2f9a5d7ff98284fc/pic/e083c6a9f86ef781.jpg',
      );
    });

    test('maps live icon metadata and anchor series items', () {
      final ref = SourceBookRef(
        sourceId: 'knigoblud',
        sourceBookId: '09a908a6-0ff5-4080-b607-fc3ca3684672',
        sourceUri: Uri.parse(
          'https://www.knigoblud.club/09a908a6-0ff5-4080-b607-fc3ca3684672',
        ),
      );

      final details = mapper.bookDetails(_liveLikeBookHtml, ref);

      expect(details.version.authors, ['Николай Грошев']);
      expect(details.version.seriesTitle, 'Велес');
      expect(details.version.seriesNumber, 1);
      expect(details.version.coverUrl, contains('e083c6a9f86ef781.jpg'));
      expect(details.version.durationText, '18 ч');
    });

    test('maps current live search icon metadata', () {
      final results = mapper.searchResults(_liveLikeSearchHtml);

      expect(results, hasLength(1));
      final result = results.single;
      expect(result.title, 'S.T.A.L.K.E.R. Дыхание зоны');
      expect(result.author, 'Николай Грошев');
      expect(result.series, 'Велес');
      expect(result.duration, const Duration(hours: 18));
      expect(
        result.coverUri.toString(),
        'https://r7.audioknigi.xyz/2f9a5d7ff98284fc/pic/e083c6a9f86ef781.jpg',
      );
    });

    test('maps details, chapters, and audio tracks from KB.playerInit', () {
      final ref = SourceBookRef(
        sourceId: 'knigoblud',
        sourceBookId: '09a908a6-0ff5-4080-b607-fc3ca3684672',
        sourceUri: Uri.parse(
          'https://www.knigoblud.club/09a908a6-0ff5-4080-b607-fc3ca3684672',
        ),
      );

      final details = mapper.bookDetails(_bookHtml, ref);
      final chapters = mapper.chapters(_bookHtml, ref);
      final tracks = mapper.audioTracks(chapters);

      expect(
        details.version.id,
        'knigoblud-09a908a6-0ff5-4080-b607-fc3ca3684672',
      );
      expect(details.version.title, 'S.T.A.L.K.E.R. Дыхание зоны');
      expect(details.version.authors, ['Николай Грошев']);
      expect(details.version.narrators, ['Тимофей Зобнин']);
      expect(details.version.seriesTitle, 'Велес');
      expect(details.version.seriesNumber, 1);
      expect(details.version.genres, ['Фантастика', 'фэнтези']);
      expect(details.version.description, 'Сталкеры возвращаются в Зону.');
      expect(details.version.durationMs, 64920000);
      expect(details.version.publishedYear, 2019);
      expect(details.version.accessType, AccessType.free);
      expect(details.version.playbackAccess, PlaybackAccess.streamAndDownload);
      expect(details.version.canStream, isTrue);
      expect(details.version.canDownload, isTrue);

      expect(chapters, hasLength(2));
      expect(
        chapters.first.id,
        'knigoblud-09a908a6-0ff5-4080-b607-fc3ca3684672-chapter-1655617',
      );
      expect(chapters.first.title, '01-prolog');
      expect(chapters.first.durationMs, 1246000);
      expect(
        chapters.first.streamRef,
        'https://r4.audioknigi.xyz/2f9a5d7ff98284fc/audio/01-prolog.mp3',
      );

      expect(tracks, hasLength(2));
      final headers =
          jsonDecode(tracks.first.headersJson ?? '{}') as Map<String, Object?>;
      expect(headers['Referer'], ref.sourceUri.toString());
    });

    test('marks blocked or empty playlists as restricted', () {
      final ref = SourceBookRef(
        sourceId: 'knigoblud',
        sourceBookId: 'blocked-book',
        sourceUri: Uri.parse('https://www.knigoblud.club/blocked-book'),
      );

      final details = mapper.bookDetails(_blockedBookHtml, ref);
      final chapters = mapper.chapters(_blockedBookHtml, ref);

      expect(details.version.playbackAccess, PlaybackAccess.none);
      expect(details.version.canStream, isFalse);
      expect(details.version.canDownload, isFalse);
      expect(chapters, isEmpty);
    });
  });
}

const _searchHtml = '''
<html><body>
  <div class="bookListItem" id="book18590">
    <a class="bookListItemCover" href="/09a908a6-0ff5-4080-b607-fc3ca3684672">
      <img class="bookListItemCoverImg"
        src="https://r7.audioknigi.xyz/2f9a5d7ff98284fc/pic/e083c6a9f86ef781.jpg">
    </a>
    <a class="bookListItemCoverNameText" href="/09a908a6-0ff5-4080-b607-fc3ca3684672">
      S.T.A.L.K.E.R. Дыхание зоны
    </a>
    <div class="bookListItemInfo">
      <div>Автор: <a>Николай Грошев</a></div>
      <div>Серия: <a>Велес</a></div>
      <div>Год: 2019</div>
      <div>Жанр: <a>Фантастика, фэнтези</a></div>
      <div>18 ч. 0 мин.</div>
    </div>
  </div>
</body></html>
''';

const _bookHtml = '''
<html><body>
  <h1 class="BookTitle">S.T.A.L.K.E.R. Дыхание зоны</h1>
  <img id="BookCoverImage"
    src="https://r7.audioknigi.xyz/2f9a5d7ff98284fc/pic/e083c6a9f86ef781.jpg">
  <div class="BookMetaBlockLine">Автор: <a>Николай Грошев</a></div>
  <div class="BookMetaBlockLine">Читает: <a>Тимофей Зобнин</a></div>
  <div class="BookMetaBlockLine">Жанр: <a>Фантастика</a>, <a>фэнтези</a></div>
  <div class="BookMetaBlockLine">Год: 2019</div>
  <div class="BookMetaBlockLine">Длительность: 18 ч. 2 мин.</div>
  <div class="BookDescriptionContent">Сталкеры возвращаются в Зону.</div>
  <div class="BookDescription BookSeries">
    <div class="BookDescriptionLabel">📚 Цикл «Велес»</div>
    <div class="BookDescriptionSeriesItem">
      <span class="BookDescriptionSeriesItemIndex">1.</span>
      <a href="/09a908a6-0ff5-4080-b607-fc3ca3684672">S.T.A.L.K.E.R. Дыхание зоны</a>
    </div>
    <div class="BookDescriptionSeriesItem">
      <span class="BookDescriptionSeriesItemIndex">21.1</span>
      <a href="/next">S.T.A.L.K.E.R. Другая книга</a>
    </div>
  </div>
  <script>
  KB.playerInit({
    "uuid":"09a908a6-0ff5-4080-b607-fc3ca3684672",
    "blocked":false,
    "playlist":[
      {"fileId":1655617,"title":"01-prolog","duration":1246,"src":"https:\\/\\/r4.audioknigi.xyz\\/2f9a5d7ff98284fc\\/audio\\/01-prolog.mp3"},
      {"fileId":1655618,"title":"02-glava","duration":60,"src":"https:\\/\\/r4.audioknigi.xyz\\/2f9a5d7ff98284fc\\/audio\\/02-glava.mp3"}
    ]
  });
  </script>
</body></html>
''';

const _liveLikeBookHtml = '''
<html><head>
  <meta property="og:title" content="Николай Грошев - S.T.A.L.K.E.R. Дыхание зоны">
  <meta property="og:image" content="https://r7.audioknigi.xyz/2f9a5d7ff98284fc/pic/e083c6a9f86ef781.jpg">
</head><body>
  <h1 itemprop="name">S.T.A.L.K.E.R. Дыхание зоны</h1>
  <img id="BookCoverImage"
    src="https://r7.audioknigi.xyz/2f9a5d7ff98284fc/pic/e083c6a9f86ef781.jpg">
  <div class="BookMetaBlockLine">
    <span>📕</span> <a href="/genre"><b>Фантастика, фэнтези</b></a>
  </div>
  <div class="BookMetaBlockLine">
    <span>✍️</span>
    <span itemprop="author">
      <a href="/author">Николай Грошев</a>
    </span>
  </div>
  <div class="bookListItemNameDur">18 ч. 0 мин.</div>
  <div class="BookDescription BookSeries">
    <div class="BookDescriptionLabel">
      <span>📚</span> Цикл «<a href="/series"><b>Велес</b></a>»
    </div>
    <div class="BookDescriptionContent">
      <a href="/09a908a6-0ff5-4080-b607-fc3ca3684672" class="BookDescriptionSeriesItem">
        <span class="BookDescriptionSeriesItemIndex __NoSelect">1. </span>
        <b>S.T.A.L.K.E.R. Дыхание зоны</b>
      </a>
      <a href="/next" class="BookDescriptionSeriesItem">
        <span class="BookDescriptionSeriesItemIndex __NoSelect">21.1. </span>
        <span class="BookDescriptionSeriesItemName">Следующая книга</span>
      </a>
    </div>
  </div>
  <script>
  KB.playerInit({
    "uuid":"09a908a6-0ff5-4080-b607-fc3ca3684672",
    "blocked":false,
    "playlist":[
      {"fileId":2205845,"title":"01-prolog","duration":1246,"src":"https:\\/\\/r4.audioknigi.xyz\\/2f9a5d7ff98284fc\\/audio\\/01-prolog.mp3"}
    ]
  });
  </script>
</body></html>
''';

const _liveLikeSearchHtml = '''
<html><body>
  <div class="bookListItem" id="book18590">
    <div class="bookListItemInner">
      <a class="bookListItemCover" href="/09a908a6-0ff5-4080-b607-fc3ca3684672">
        <div class="bookListItemCoverImg js-parallax"
          data-img="https://r7.audioknigi.xyz/2f9a5d7ff98284fc/pic/e083c6a9f86ef781.jpg"></div>
        <div class="bookListItemCoverName">
          <div class="bookListItemCoverNameText">
            S.T.A.L.K.E.R. <span class="highlight_keyword">Дыхание</span>
            <span class="highlight_keyword">зоны</span>
          </div>
        </div>
      </a>
      <div class="bookListItemRight">
        <div class="bookListItemMetaBlock">
          <span>📕</span>
          <a class="bookListItemGenreLink WithUnderline Bold">Фантастика, фэнтези</a>
        </div>
        <div class="bookListItemMetaBlock">
          <span>✍️</span>
          <a class="WithUnderline">Николай Грошев</a>
        </div>
        <div class="bookListItemMetaBlock">
          <span>📚</span>
          <a class="WithUnderline">Велес</a>
        </div>
        <div class="bookListItemMetaBlock">
          <span>🕒</span>
          <span class="bookListItemNameDur">18 ч. 0 мин.</span>
        </div>
      </div>
    </div>
  </div>
</body></html>
''';

const _blockedBookHtml = '''
<html><body>
  <h1 class="BookTitle">Заблокированная книга</h1>
  <script>KB.playerInit({"uuid":"blocked-book","blocked":true,"playlist":[]});</script>
</body></html>
''';
