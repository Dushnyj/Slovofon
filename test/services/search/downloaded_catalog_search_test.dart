import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/search/downloaded_catalog_search.dart';
import 'package:slovofon/sources/source_models.dart';

void main() {
  test(
    'offline search verifies files, keeps editions and matches reversed names',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'slovofon-local-search-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final storage = FileDownloadStorage(rootDirectory: directory);
      final complete = _edition('complete', narrator: 'Сергей Кузнецов');
      final fragment = _edition(
        'fragment',
        narrator: 'Иван Иванов',
        fragment: true,
      );
      final partial = _edition('partial', narrator: 'Сергей Кузнецов');
      final cachedOnly = _edition('cached', narrator: 'Сергей Кузнецов');

      for (final book in [complete, fragment, partial, cachedOnly]) {
        await storage.writeMetadata(book);
      }
      for (final book in [complete, fragment, partial]) {
        for (final chapter
            in (book == partial ? book.chapters.take(1) : book.chapters)) {
          final file = storage.chapterFileFor(book, chapter, extension: 'mp3');
          await file.parent.create(recursive: true);
          await file.writeAsBytes([1, 2, 3]);
        }
      }

      final search = DownloadedCatalogSearch(storage);
      final all = await search.search(
        const SearchRequest(query: 'Во мрак Андрей Дьяков Метро 2033'),
      );
      expect(all.results.map((result) => result.sourceBookId).toSet(), {
        'complete',
        'fragment',
      });
      expect(all.results.every((result) => result.coverUri == null), isTrue);
      expect(
        all.results.where((result) => result.isFragment).single.sourceBookId,
        'fragment',
      );
      final matched = await search.search(
        const SearchRequest(
          query: 'Кузнецов Сергей',
          kind: SearchKind.narrator,
        ),
      );
      final book = matched.bookFor(matched.results.single)!;
      expect(book.versionId, complete.versionId);
      final playable = (await search.playableBook(book))!;
      expect(playable.offlineOnly, isTrue);
      expect(playable.coverUrl, isNull);
      expect(
        playable.chapters.map((value) => value.mediaSource?.type),
        everyElement(AudioMediaSourceType.file),
      );
      expect(playable.chapters, hasLength(book.chapters.length));

      final removed = storage.chapterFileFor(
        complete,
        complete.chapters.last,
        extension: 'mp3',
      );
      await removed.delete();
      expect(await search.playableBook(book), isNull);
    },
  );
}

AudioPlaybackBook _edition(
  String id, {
  required String narrator,
  bool fragment = false,
}) => AudioPlaybackBook(
  id: 'same-work',
  versionId: id,
  sourceId: 'izib',
  sourceBookId: 'same-source-book',
  title: 'Во мрак',
  author: 'Андрей Дьяков',
  narrator: narrator,
  seriesTitle: 'Метро 2033',
  genre: 'Фантастика',
  sourceName: 'Izib',
  coverUrl: 'https://example.invalid/no-online-cover.png',
  isFragment: fragment,
  chapters: [
    for (var i = 0; i < (fragment ? 1 : 2); i++)
      AudioPlaybackChapter(
        id: '$id-$i',
        index: i,
        title: 'Глава $i',
        duration: const Duration(minutes: 1),
        storageIdentity: 'id:$id-$i',
      ),
  ],
);
