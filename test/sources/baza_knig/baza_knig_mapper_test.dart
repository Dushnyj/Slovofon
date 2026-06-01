import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/book_version.dart';
import 'package:slovofon/sources/baza_knig/baza_knig_mapper.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  test('Baza Knig connector declares expiring media urls', () {
    expect(BazaKnigSourceConnector().capabilities.hasTemporaryUrls, isTrue);
  });

  group('BazaKnigMapper', () {
    final mapper = BazaKnigMapper(clock: () => DateTime.utc(2026, 5, 27, 12));

    test('maps HTML search results to source result cards', () {
      final results = mapper.searchResults(_searchHtml);

      expect(results, hasLength(1));
      final result = results.single;
      expect(result.sourceId, 'baza_knig');
      expect(result.sourceName, 'Baza Knig');
      expect(
        result.sourceBookId,
        'fantastika-fentezii/7411-dyhanie-zony-nikolay-groshev.html',
      );
      expect(
        result.ref.sourceUri.toString(),
        'https://baza-knig.top/fantastika-fentezii/7411-dyhanie-zony-nikolay-groshev.html',
      );
      expect(result.title, 'Дыхание зоны (S.T.A.L.K.E.R.)');
      expect(result.author, 'Грошев Николай');
      expect(result.narrator, 'Орлов Глеб');
      expect(result.series, 'Велес');
      expect(result.duration, const Duration(hours: 7, minutes: 53));
      expect(result.year, 2015);
      expect(result.ratingValue, 4.5);
      expect(result.ratingCount, 20);
      expect(
        result.coverUri.toString(),
        'https://baza-knig.top/uploads/posts/2017-12/1513920913_2-22x.jpg',
      );
    });

    test('cleans narrator voice notes from search metadata', () {
      final results = mapper.searchResults(_searchHtmlWithVoiceNote);

      expect(results.single.narrator, 'Орлов Глеб');
    });

    test('maps current search cards with comments rating and added date', () {
      final results = mapper.searchResults(_searchHtmlWithCommentsStats);

      expect(results.single.title, 'Период полураспада');
      expect(
        results.single.duration,
        const Duration(hours: 11, minutes: 21, seconds: 32),
      );
      expect(results.single.year, 2020);
      expect(results.single.ratingValue, 5.0);
      expect(results.single.ratingCount, 3);
    });

    test('cleans live detail title and accepts archive audio tracks', () {
      final ref = SourceBookRef(
        sourceId: 'baza_knig',
        sourceBookId:
            'fantastika-fentezii/7411-dyhanie-zony-nikolay-groshev.html',
        sourceUri: Uri.parse(
          'https://baza-knig.top/fantastika-fentezii/7411-dyhanie-zony-nikolay-groshev.html',
        ),
      );

      final details = mapper.bookDetails(_bookHtmlWithArchiveAudio, ref);
      final chapters = mapper.chapters(_bookHtmlWithArchiveAudio, ref);

      expect(details.version.title, 'Дыхание зоны');
      expect(details.version.authors, ['Грошев Николай']);
      expect(chapters, hasLength(1));
      expect(
        chapters.single.streamRef,
        'https://archive.org/download/08-chast-03-00/01-chast-00-00.mp3',
      );
    });

    test('decodes strDecode Playerjs playlists from live Baza pages', () {
      final ref = SourceBookRef(
        sourceId: 'baza_knig',
        sourceBookId:
            'fantastika-fentezii/7411-dyhanie-zony-nikolay-groshev.html',
        sourceUri: Uri.parse(
          'https://baza-knig.top/fantastika-fentezii/7411-dyhanie-zony-nikolay-groshev.html',
        ),
      );

      final details = mapper.bookDetails(_bookHtmlWithStrDecodeAudio, ref);
      final chapters = mapper.chapters(_bookHtmlWithStrDecodeAudio, ref);

      expect(details.version.canStream, isTrue);
      expect(chapters, hasLength(1));
      expect(chapters.single.title, 'encoded');
      expect(
        chapters.single.streamRef,
        'https://1s.abooka.casa/book/encoded.mp3',
      );
    });

    test('maps details, chapters, and audio tracks from Playerjs data', () {
      final ref = SourceBookRef(
        sourceId: 'baza_knig',
        sourceBookId:
            'fantastika-fentezii/7411-dyhanie-zony-nikolay-groshev.html',
        sourceUri: Uri.parse(
          'https://baza-knig.top/fantastika-fentezii/7411-dyhanie-zony-nikolay-groshev.html',
        ),
      );

      final details = mapper.bookDetails(_bookHtml, ref);
      final chapters = mapper.chapters(_bookHtml, ref);
      final tracks = mapper.audioTracks(chapters);

      expect(
        details.version.id,
        'baza-knig-fantastika-fentezii-7411-dyhanie-zony-nikolay-groshev-html',
      );
      expect(details.version.title, 'Дыхание зоны (S.T.A.L.K.E.R.)');
      expect(details.version.authors, ['Грошев Николай']);
      expect(details.version.narrators, ['Орлов Глеб']);
      expect(details.version.seriesTitle, 'Велес');
      expect(details.version.genres, [
        'Фантастика',
        'фэнтези',
        'S.T.A.L.K.E.R.',
      ]);
      expect(details.version.description, 'Сталкеры возвращаются в Зону.');
      expect(details.version.durationMs, 28380000);
      expect(details.version.publishedYear, 2015);
      expect(details.version.ratingValue, 4.5);
      expect(details.version.ratingCount, 20);
      expect(details.version.accessType, AccessType.free);
      expect(details.version.playbackAccess, PlaybackAccess.streamAndDownload);
      expect(details.version.canStream, isTrue);
      expect(details.version.canDownload, isTrue);

      expect(chapters, hasLength(2));
      expect(
        chapters.first.id,
        'baza-knig-fantastika-fentezii-7411-dyhanie-zony-nikolay-groshev-html-chapter-1',
      );
      expect(chapters.first.title, '0-vstuplenie');
      expect(
        chapters.first.streamRef,
        'https://1s.abooka.casa/audioknigi/7411/2/0-vstuplenie.mp3',
      );

      expect(tracks, hasLength(2));
      final headers =
          jsonDecode(tracks.first.headersJson ?? '{}') as Map<String, Object?>;
      expect(headers['Referer'], ref.sourceUri.toString());
    });

    test('filters non-allowlisted media and marks page as restricted', () {
      final ref = SourceBookRef(
        sourceId: 'baza_knig',
        sourceBookId: 'archive-only.html',
        sourceUri: Uri.parse('https://baza-knig.top/archive-only.html'),
      );

      final details = mapper.bookDetails(_archiveOnlyHtml, ref);
      final chapters = mapper.chapters(_archiveOnlyHtml, ref);

      expect(details.version.playbackAccess, PlaybackAccess.none);
      expect(details.version.canStream, isFalse);
      expect(details.version.canDownload, isFalse);
      expect(chapters, isEmpty);
    });
  });
}

const _searchHtml = '''
<html><body>
  <div class="short">
    <a class="short-title" href="/fantastika-fentezii/7411-dyhanie-zony-nikolay-groshev.html">
      Дыхание зоны (S.T.A.L.K.E.R.)
    </a>
    <img src="/uploads/posts/2017-12/1513920913_2-22x.jpg">
    <div class="short-items">
      <div>Автор: <a>Грошев Николай</a></div>
      <div>Исполнитель: <a>Орлов Глеб</a></div>
      <div>Цикл: <a>Велес (2)</a></div>
      <div>Год: 2015</div>
      <div>Время звучания: 07:53:00</div>
    </div>
    <div class="short-rate">
      <a onclick="doRate('1', '7411')">18</a>
      <a onclick="doRate('-1', '7411')">2</a>
    </div>
  </div>
</body></html>
''';

const _bookHtml = '''
<html><body>
  <h1 class="full-title">Дыхание зоны (S.T.A.L.K.E.R.)</h1>
  <div class="full-img"><img src="/uploads/posts/2017-12/1513920913_2-22x.jpg"></div>
  <div class="full-items">
    <div>Автор: <a>Грошев Николай</a></div>
    <div>Читает: <a>Орлов Глеб</a></div>
    <div>Год: 2015</div>
    <div>Время звучания: 07:53:00</div>
    <div>Цикл: <a>Велес (2)</a></div>
    <div>Жанр: <a>Фантастика, фэнтези</a> / <a>S.T.A.L.K.E.R.</a></div>
  </div>
  <div class="short-text">Сталкеры возвращаются в Зону.</div>
  <div class="short-rate">
    <a onclick="doRate('1', '7411')">18</a>
    <a onclick="doRate('-1', '7411')">2</a>
  </div>
  <script>
  new Playerjs({ id:"player2", file:[
    {"title":"0-vstuplenie","file":"https:\\/\\/1s.abooka.casa\\/audioknigi\\/7411\\/2\\/0-vstuplenie.mp3"},
    {"title":"1-glava","file":"https:\\/\\/1s.abooka.casa\\/audioknigi\\/7411\\/2\\/1-glava.mp3"}
  ]});
  </script>
</body></html>
''';

const _searchHtmlWithVoiceNote = '''
<html><body>
  <div class="short">
    <a class="short-title" href="/fantastika-fentezii/7411-dyhanie-zony-nikolay-groshev.html">
      Дыхание зоны (S.T.A.L.K.E.R.)
    </a>
    <div class="short-items">
      <div>Автор: Грошев Николай</div>
      <div>Исполнитель: Орлов Глеб, (альтернативная озвучка)</div>
      <div>Время звучания: 07:53:00</div>
    </div>
  </div>
</body></html>
''';

const _searchHtmlWithCommentsStats = '''
<html><body>
  <div class="short">
    <div class="short-title">
      <a href="https://baza-knig.top/roman-proza/37566-period-poluraspada-elena-kotova.html">
        Период полураспада
      </a>
    </div>
    <div class="short-img">
      <img src="/uploads/posts/2020-02/1582621569_period2.jpg">
    </div>
    <ul class="reset short-items">
      <li>Автор: <b><a>Котова Елена</a></b></li>
      <li>Читает: <b><a>Луганская Лариса</a></b></li>
      <li>Длительность: <b>11:21:32</b></li>
      <li>Жанр: <a>Роман, проза</a></li>
      <li>Добавлена: 25.02.20</li>
    </ul>
    <div class="short-bottom">
      <div class="comments"><img src="/templates/knigi/img/like.png"><span data-likes-id="37566">3</span></div>
      <div class="comments"><img src="/templates/knigi/img/dislike.png"><span data-dislikes-id="37566">0</span></div>
    </div>
  </div>
</body></html>
''';

const _bookHtmlWithArchiveAudio = '''
<html><body>
  <div style="text-align:center;">
    <h1 style="font-size:13pt;">
      <b style="color: #d0d0d0;">Скачать аудиокнигу </b>
      Дыхание зоны - Николай Грошев
    </h1>
  </div>
  <div class="full-items">
    <div>Автор: <a>Грошев Николай</a></div>
  </div>
  <script>
  new Playerjs({ id:"player2", file:[
    {"title":"Николай Грошев - Дыхание Зоны [Пролог]","file":"https:\\/\\/archive.org\\/download\\/08-chast-03-00\\/01-chast-00-00.mp3"}
  ]});
  </script>
</body></html>
''';

const _bookHtmlWithStrDecodeAudio = '''
<html><body>
  <h1 class="full-title">Дыхание зоны</h1>
  <div class="full-items">
    <div>Автор: <a>Грошев Николай</a></div>
  </div>
  <script>
    var file = strDecode("[{N0bzac16mc4z7zA1mPMSjctKHzlzjP1bjqHIHPV6aL827zxSrWrORNASmiQVBPMVgihSRPESeFE1mPMSjctKBPylrFAEWv==}]");
    var player = new Playerjs({
      id:"player",
      file: file,
      autonext:1
    });
  </script>
</body></html>
''';

const _archiveOnlyHtml = '''
<html><body>
  <h1 class="full-title">Архивная книга</h1>
  <script>
  new Playerjs({ id:"player3", file:[
    {"title":"archive","file":"https:\\/\\/example.com\\/book\\/chapter.mp3"}
  ]});
  </script>
</body></html>
''';
