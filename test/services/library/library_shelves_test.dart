import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/services/audio/audio_persistence.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/bookmarks/bookmark_store.dart';
import 'package:slovofon/services/library/library_metadata.dart';
import 'package:slovofon/services/library/library_shelves.dart';
import 'package:slovofon/services/library/library_store.dart';

void main() {
  final time = DateTime(2026, 9, 6);
  LibraryBookEntry saved(String id) => LibraryBookEntry(
    book: libraryCardBook(book(id)),
    isFavorite: true,
    updatedAt: time,
  );
  PlaybackProgressSnapshot progress(String id, {bool finished = false}) =>
      PlaybackProgressSnapshot(
        bookId: book(id).id,
        bookVersionId: book(id).versionId,
        currentChapterId: '$id-chapter',
        currentPositionMs: finished ? 60000 : 12000,
        maxReachedGlobalPositionMs: finished ? 60000 : 12000,
        totalDurationMs: 60000,
        listenedDurationMs: 12000,
        percent: finished ? 100 : 20,
        isFinished: finished,
        lastPlayedAt: time,
      );
  DownloadTask download(
    String id, {
    DownloadTaskStatus status = DownloadTaskStatus.completed,
  }) => DownloadTask(
    id: 'download-$id',
    bookId: book(id).id,
    bookVersionId: book(id).versionId,
    sourceId: 'source',
    chapterId: '$id-chapter',
    type: DownloadTaskType.chapter,
    status: status,
    createdAt: time,
    updatedAt: time,
  );

  test('all is a real union; cached search metadata is not membership', () {
    final result = projectLibraryShelves(
      favorites: [saved('favorite')],
      later: [saved('later')],
      metadata: [
        for (final id in [
          'favorite',
          'later',
          'active',
          'done',
          'offline',
          'mark',
          'search-only',
        ])
          book(id),
      ],
      progress: [progress('active'), progress('done', finished: true)],
      downloads: [download('offline')],
      bookmarks: [
        PlaybackBookmark(
          id: 'mark',
          bookId: book('mark').id,
          bookVersionId: book('mark').versionId,
          chapterId: 'mark-chapter',
          positionMs: 5000,
          title: 'Chapter',
          createdAt: time,
          updatedAt: time,
        ),
      ],
    );
    Set<String> ids(LibraryShelf shelf) => result
        .where((e) => e.shelves.contains(shelf))
        .map((e) => e.book.sourceBookId!)
        .toSet();
    expect(ids(LibraryShelf.all), {
      'favorite',
      'later',
      'active',
      'done',
      'offline',
      'mark',
    });
    expect(ids(LibraryShelf.favorites), {'favorite'});
    expect(ids(LibraryShelf.later), {'later'});
    expect(ids(LibraryShelf.listening), {'active'});
    expect(ids(LibraryShelf.finished), {'done'});
    expect(ids(LibraryShelf.history), {'active', 'done'});
    expect(ids(LibraryShelf.downloaded), {'offline'});
    expect(ids(LibraryShelf.bookmarks), {'mark'});
  });

  test('same source title is deduplicated across every membership', () {
    final b = book('one');
    final result = projectLibraryShelves(
      favorites: [saved('one')],
      later: [saved('one')],
      metadata: [b],
      progress: [progress('one')],
      downloads: [download('one')],
      bookmarks: [],
      current: AudioPlaybackState(
        book: b,
        position: const Duration(seconds: 20),
      ),
    );
    expect(result, hasLength(1));
    expect(
      result.single.shelves,
      containsAll([
        LibraryShelf.all,
        LibraryShelf.favorites,
        LibraryShelf.later,
        LibraryShelf.downloaded,
        LibraryShelf.history,
        LibraryShelf.listening,
      ]),
    );
    expect(result.single.book.progress, closeTo(1 / 3, .001));
  });

  test('source-specific narration identity does not merge equal local ids', () {
    final left = book('same');
    final right = book('same', source: 'other');
    final result = projectLibraryShelves(
      favorites: [],
      later: [],
      metadata: [left, right],
      progress: [progress('same')],
      downloads: [
        DownloadTask(
          id: 'right',
          bookId: right.id,
          bookVersionId: right.versionId,
          sourceId: 'other',
          type: DownloadTaskType.chapter,
          status: DownloadTaskStatus.completed,
          createdAt: time,
          updatedAt: time,
        ),
      ],
      bookmarks: [],
    );
    expect(result, hasLength(2));
    expect(
      result.singleWhere((e) => e.book.sourceId == 'other').shelves,
      isNot(contains(LibraryShelf.history)),
    );
    expect(
      result.singleWhere((e) => e.book.sourceId == 'source').shelves,
      isNot(contains(LibraryShelf.downloaded)),
    );
  });

  test('paused current book at zero belongs to listening and history', () {
    final result = projectLibraryShelves(
      favorites: [],
      later: [],
      metadata: [],
      progress: [],
      downloads: [],
      bookmarks: [],
      current: AudioPlaybackState(
        book: book('now'),
        status: AudioPlaybackStatus.paused,
      ),
    );
    expect(
      result.single.shelves,
      containsAll([
        LibraryShelf.all,
        LibraryShelf.history,
        LibraryShelf.listening,
      ]),
    );
  });

  test('completed current book moves to finished, restarting moves back', () {
    List<LibraryShelfEntry> project(AudioPlaybackState state) =>
        projectLibraryShelves(
          favorites: [],
          later: [],
          metadata: [],
          progress: [progress('one', finished: true)],
          downloads: [],
          bookmarks: [],
          current: state,
        );
    expect(
      project(
        AudioPlaybackState(
          book: book('one'),
          position: const Duration(minutes: 1),
          status: AudioPlaybackStatus.completed,
        ),
      ).single.shelves,
      contains(LibraryShelf.finished),
    );
    final restarted = project(
      AudioPlaybackState(
        book: book('one'),
        status: AudioPlaybackStatus.playing,
      ),
    ).single;
    expect(restarted.shelves, contains(LibraryShelf.listening));
    expect(restarted.shelves, isNot(contains(LibraryShelf.finished)));
  });

  test('queued downloads are in all but never falsely shown as offline', () {
    final result = projectLibraryShelves(
      favorites: [],
      later: [],
      metadata: [book('queued')],
      progress: [],
      downloads: [download('queued', status: DownloadTaskStatus.queued)],
      bookmarks: [],
    );
    expect(result.single.shelves, {LibraryShelf.all});
  });

  test('canonical favorite metadata recovers progress without card cache', () {
    final result = projectLibraryShelves(
      favorites: [saved('one')],
      later: [],
      metadata: [],
      progress: [progress('one')],
      downloads: [],
      bookmarks: [],
    );
    expect(result, hasLength(1));
    expect(result.single.shelves, contains(LibraryShelf.listening));
    expect(result.single.book.progress, .2);
  });
}

AudioPlaybackBook book(String id, {String source = 'source'}) =>
    AudioPlaybackBook(
      id: '$source-book-$id',
      versionId: '$source-$id',
      sourceId: source,
      sourceBookId: id,
      title: 'Book $id',
      author: 'Author',
      narrator: 'Narrator',
      sourceName: source,
      chapters: [
        AudioPlaybackChapter(
          id: '$id-chapter',
          index: 0,
          title: 'Chapter',
          duration: const Duration(minutes: 1),
        ),
      ],
    );
