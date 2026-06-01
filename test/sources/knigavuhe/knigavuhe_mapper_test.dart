import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/book_version.dart';
import 'package:slovofon/sources/knigavuhe/knigavuhe_mapper.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  group('KnigavuheMapper', () {
    final mapper = KnigavuheMapper(clock: () => DateTime.utc(2026, 5, 27, 12));

    test('maps HTML search results to source result cards', () {
      final results = mapper.searchResults(_searchHtml);

      expect(results, hasLength(1));
      final result = results.single;
      expect(result.sourceId, 'knigavuhe');
      expect(result.sourceName, 'Knigavuhe');
      expect(result.sourceBookId, 'book/8996-stalker-dykhanie-zony');
      expect(
        result.ref.sourceUri.toString(),
        'https://knigavuhe.org/book/8996-stalker-dykhanie-zony/',
      );
      expect(result.title, 'S.T.A.L.K.E.R. Дыхание зоны');
      expect(result.author, 'Николай Грошев');
      expect(result.narrator, 'Тимофей Зобнин');
      expect(result.series, 'Велес');
      expect(result.duration, const Duration(hours: 18, minutes: 1));
      expect(result.accessType, AccessType.free);
      expect(
        result.coverUri.toString(),
        'https://s5.knigavuhe.org/1/covers/8996/2-1.jpg?v=2',
      );
    });

    test('maps details, chapters, and audio tracks from BookPlayer data', () {
      final ref = SourceBookRef(
        sourceId: 'knigavuhe',
        sourceBookId: 'book/8996-stalker-dykhanie-zony',
        sourceUri: Uri.parse(
          'https://knigavuhe.org/book/8996-stalker-dykhanie-zony/',
        ),
      );

      final details = mapper.bookDetails(_bookHtml, ref);
      final chapters = mapper.chapters(_bookHtml, ref);
      final tracks = mapper.audioTracks(chapters);

      expect(details.version.id, 'knigavuhe-book-8996-stalker-dykhanie-zony');
      expect(
        details.version.bookId,
        'knigavuhe-book-book-8996-stalker-dykhanie-zony',
      );
      expect(details.version.sourceUrl, ref.sourceUri.toString());
      expect(details.version.title, 'S.T.A.L.K.E.R. Дыхание зоны');
      expect(details.version.authors, ['Николай Грошев']);
      expect(details.version.narrators, ['Тимофей Зобнин']);
      expect(details.version.seriesTitle, 'Велес');
      expect(details.version.seriesNumber, 1);
      expect(details.version.genres, ['Фантастика', 'S.T.A.L.K.E.R.']);
      expect(details.version.description, 'Сталкеры возвращаются в Зону.');
      expect(details.version.durationMs, 64920000);
      expect(details.version.publishedYear, 2015);
      expect(details.version.ratingValue, 4.5);
      expect(details.version.ratingCount, 20);
      expect(details.version.accessType, AccessType.free);
      expect(details.version.playbackAccess, PlaybackAccess.streamAndDownload);
      expect(details.version.canStream, isTrue);
      expect(details.version.canDownload, isTrue);
      expect(details.alternatives, hasLength(1));
      expect(
        details.alternatives.single.sourceBookId,
        'book/29141-stalker-dykhanie-zony-1',
      );
      expect(details.alternatives.single.narrator, 'Олег Шубин');
      expect(
        details.version.coverUrl,
        'https://s5.knigavuhe.org/1/covers/8996/2-2.jpg?v=2',
      );

      expect(chapters, hasLength(2));
      expect(
        chapters.first.id,
        'knigavuhe-book-8996-stalker-dykhanie-zony-chapter-874852',
      );
      expect(chapters.first.sourceChapterId, '874852');
      expect(chapters.first.index, 1);
      expect(chapters.first.title, '0.1 prolog');
      expect(chapters.first.durationMs, 1246000);
      expect(
        chapters.first.streamRef,
        'https://s12.knigavuhe.org/1/audio/8996/01-prolog.mp3',
      );
      expect(chapters.last.durationMs, 60000);
      expect(chapters.last.audioFormat, 'mp3');

      expect(tracks, hasLength(2));
      expect(tracks.first.mediaRef, chapters.first.streamRef);
      final headers =
          jsonDecode(tracks.first.headersJson ?? '{}') as Map<String, Object?>;
      expect(headers['Referer'], ref.sourceUri.toString());
    });

    test('marks pages without playable BookPlayer tracks as restricted', () {
      final ref = SourceBookRef(
        sourceId: 'knigavuhe',
        sourceBookId: 'book/paid-book',
        sourceUri: Uri.parse('https://knigavuhe.org/book/paid-book/'),
      );

      final details = mapper.bookDetails(_bookHtmlWithoutTracks, ref);
      final chapters = mapper.chapters(_bookHtmlWithoutTracks, ref);

      expect(details.version.playbackAccess, PlaybackAccess.none);
      expect(details.version.canStream, isFalse);
      expect(details.version.canDownload, isFalse);
      expect(chapters, isEmpty);
    });
  });
}

const _searchHtml = '''
<html><body>
  <div class="bookkitem">
    <a class="bookkitem_img" href="/book/8996-stalker-dykhanie-zony/">
      <img src="https://s5.knigavuhe.org/1/covers/8996/2-1.jpg?v=2">
    </a>
    <div class="bookkitem_name">
      <a href="/book/8996-stalker-dykhanie-zony/">S.T.A.L.K.E.R. Дыхание зоны</a>
      <span class="bookkitem_author">автор <a>Николай Грошев</a></span>
    </div>
    <div class="bookkitem_meta_block">
      <span class="bookkitem_icon -reader"></span>
      <span class="bookkitem_meta_label">Читает <a>Тимофей Зобнин</a></span>
    </div>
    <div class="bookkitem_meta_block">
      <span class="bookkitem_icon -serie"></span>
      <span class="bookkitem_meta_label">Цикл <a>Велес</a> <span>1.</span></span>
    </div>
    <div class="bookkitem_meta_time">18 часов 1 минута</div>
  </div>
</body></html>
''';

const _bookHtml = '''
<html><body>
  <div class="book_title">
    <h1 class="book_title_elem book_title_name">S.T.A.L.K.E.R. Дыхание зоны</h1>
    <div class="book_title_elem"><span>автор</span><a>Николай Грошев</a></div>
    <div class="book_title_elem"><span>читает</span><a>Тимофей Зобнин</a></div>
  </div>
  <img class="book_cover" src="https://s5.knigavuhe.org/1/covers/8996/2-2.jpg?v=2">
  <div class="book_info_line icon_serie"><a>Велес (2)</a></div>
  <div class="book_info_line_serie_index">1.</div>
  <div class="book_info_block_year">
    <div class="book_info_block_title">Год издания</div>
    <div class="book_info_block_tag">2015</div>
  </div>
  <div class="book_genre_pretitle"><a>Фантастика</a><a>S.T.A.L.K.E.R.</a></div>
  <div class="book_duration">18 часов 2 минуты</div>
  <div class="book_description">Сталкеры возвращаются в Зону.</div>
  <div class="book_rating">
    <span class="ls-vote-item" data-vote-value="1"><span class="counter-number">18</span></span>
    <span class="ls-vote-item" data-vote-value="-1"><span class="counter-number">2</span></span>
  </div>
  <div class="book_blue_block book_serie_block">
    <div class="book_serie_block_title">Другие озвучки</div>
    <div class="book_serie_block_item">
      <a href="/book/29141-stalker-dykhanie-zony-1/">S.T.A.L.K.E.R. Дыхание зоны</a>
      <span>в исполнении</span>
      <a href="/reader/oleg-shubin/">Олег Шубин</a>
    </div>
  </div>
  <script>
  new BookPlayer(8996, [
    {"id":874852,"title":"0.1 prolog","url":"https:\\/\\/s12.knigavuhe.org\\/1\\/audio\\/8996\\/01-prolog.mp3","duration":1246},
    {"id":874853,"title":"0.2 glava","url":"https:\\/\\/s12.knigavuhe.org\\/1\\/audio\\/8996\\/02-glava.mp3","duration_float":60.4}
  ]);
  </script>
</body></html>
''';

const _bookHtmlWithoutTracks = '''
<html><body>
  <h1 class="book_title_elem book_title_name">Платная книга</h1>
  <script>new BookPlayer(1, []);</script>
</body></html>
''';
