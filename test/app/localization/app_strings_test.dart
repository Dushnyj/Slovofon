import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/localization/app_strings.dart';

void main() {
  final ru = AppStrings.forLocale(const Locale('ru'));
  final en = AppStrings.forLocale(const Locale('en'));
  final forms = [
    (
      name: 'one',
      counts: [1, 21, 31, 101, 121, 201, 1001],
      book: 'книга',
      chapter: 'глава',
      result: 'результат',
      failure: 'источник вернул ошибку',
      enabled: 'источник включён',
      more: 'главу',
      of: 'главы',
    ),
    (
      name: 'few',
      counts: [2, 3, 4, 22, 23, 24, 32, 102, 103, 104, 122, 123, 124],
      book: 'книги',
      chapter: 'главы',
      result: 'результата',
      failure: 'источника вернули ошибку',
      enabled: 'источника включены',
      more: 'главы',
      of: 'глав',
    ),
    (
      name: 'many',
      counts: [
        0,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19,
        20,
        25,
        100,
        111,
        112,
        113,
        114,
        115,
        1000,
      ],
      book: 'книг',
      chapter: 'глав',
      result: 'результатов',
      failure: 'источников вернули ошибку',
      enabled: 'источников включено',
      more: 'глав',
      of: 'глав',
    ),
  ];

  for (final form in forms) {
    test('Russian ${form.name} counts use the correct noun and verb', () {
      for (final count in form.counts) {
        expect(
          ru.booksCount(count),
          '$count ${form.book}',
          reason: '$count books',
        );
        expect(
          ru.chaptersCount(count),
          '$count ${form.chapter}',
          reason: '$count chapters',
        );
        expect(
          ru.sourceResultsCount(count),
          '$count ${form.result}',
          reason: '$count results',
        );
        expect(
          ru.partialSourceFailures(count),
          '$count ${form.failure}',
          reason: '$count failures',
        );
        expect(
          ru.selectedSourcesCount(count),
          '$count ${form.enabled}',
          reason: '$count enabled',
        );
        expect(
          ru.cacheBooks(count),
          '$count ${form.book}',
          reason: '$count cached books',
        );
        expect(
          ru.cacheCleared(count, '8 МБ'),
          'Кэш очищен: $count ${form.book}, 8 МБ',
        );
      }
    });

    test('Russian ${form.name} chapter actions use the required cases', () {
      for (final count in form.counts) {
        expect(ru.showMoreChapters(count), 'Показать ещё $count ${form.more}');
        expect(ru.downloadChaptersProgress(0, count), '0 из $count ${form.of}');
      }
    });
  }

  test('English has a singular only for one, not for 21 or 101', () {
    for (final count in [0, 1, 2, 4, 5, 11, 14, 20, 21, 101]) {
      final books = count == 1 ? 'book' : 'books';
      final chapters = count == 1 ? 'chapter' : 'chapters';
      final results = count == 1 ? 'result' : 'results';
      final sources = count == 1 ? 'source' : 'sources';
      final failures = count == 1 ? 'source failure' : 'source failures';
      expect(en.booksCount(count), '$count $books');
      expect(en.chaptersCount(count), '$count $chapters');
      expect(en.sourceResultsCount(count), '$count $results');
      expect(en.partialSourceFailures(count), '$count $failures');
      expect(en.selectedSourcesCount(count), '$count $sources enabled');
      expect(en.cacheBooks(count), '$count $books');
      expect(
        en.cacheCleared(count, '8 MB'),
        'Cache cleared: $count $books, 8 MB',
      );
      expect(en.showMoreChapters(count), 'Show $count more $chapters');
      expect(en.downloadChaptersProgress(0, count), '0 of $count $chapters');
    }
  });

  test('Russian rules also apply to regional Russian locales', () {
    final regional = AppStrings.forLocale(const Locale('ru', 'RU'));
    expect(regional.booksCount(21), '21 книга');
    expect(regional.chaptersCount(112), '112 глав');
    expect(regional.showMoreChapters(21), 'Показать ещё 21 главу');
  });

  test('cache explanation is plain language and preserves data guarantees', () {
    final russian = [
      ru.cacheAndMetadataHint,
      ru.clearCardCacheConfirm,
      ru.downloadedBooksPreserved,
      ru.clearCacheSafetyHint,
    ].join(' ');
    final english = [
      en.cacheAndMetadataHint,
      en.clearCardCacheConfirm,
      en.downloadedBooksPreserved,
      en.clearCacheSafetyHint,
    ].join(' ');
    expect(russian.toLowerCase(), isNot(contains('metadata')));
    expect(english.toLowerCase(), isNot(contains('metadata')));
    for (final guarantee in [
      'Скачанные книги и главы',
      'избранное',
      'история',
      'прогресс',
      'сохранятся',
    ]) {
      expect(ru.clearCardCacheConfirm, contains(guarantee));
    }
    for (final guarantee in [
      'Downloaded books and chapters',
      'favorites',
      'history',
      'progress',
      'will be kept',
    ]) {
      expect(en.clearCardCacheConfirm, contains(guarantee));
    }
    expect(ru.clearCardCacheConfirm, contains('без скачанных файлов'));
    expect(en.clearCardCacheConfirm, contains('without downloaded files'));
    expect(ru.clearCacheSafetyHint, 'Незавершённые загрузки также сохранятся.');
    expect(en.clearCacheSafetyHint, 'Partial downloads will also be kept.');
  });

  test('home chapter subset and search feedback have explicit context', () {
    expect(ru.currentAndNextChapters, 'Текущая и следующие');
    expect(en.currentAndNextChapters, 'Current and next');
    expect(ru.chapterPosition(3, 3), 'Глава 3 из 3');
    expect(en.chapterPosition(3, 3), 'Chapter 3 of 3');
    expect(ru.allChapters, 'Все главы');
    expect(en.allChapters, 'All chapters');
    expect(
      ru.partialSearchSources('Akniga, Книга в ухе'),
      'Не ответили: Akniga, Книга в ухе',
    );
    expect(
      en.partialSearchSources('Akniga, Knigavuhe'),
      'Unavailable: Akniga, Knigavuhe',
    );
    expect(ru.partialSearchRetry, 'Повторить поиск');
    expect(en.partialSearchRetry, 'Retry search');
    expect(ru.searchResults, 'Результаты');
    expect(en.searchResults, 'Results');
  });

  test('bookmark confirmation and actions have distinct labels', () {
    expect(ru.deleteBookmark, 'Удалить закладку?');
    expect(ru.deleteBookmarkAction, 'Удалить');
    expect(ru.saveBookmark, 'Сохранить закладку');
    expect(en.deleteBookmark, 'Delete bookmark?');
    expect(en.deleteBookmarkAction, 'Delete');
    expect(en.saveBookmark, 'Save bookmark');
    expect(
      ru.deleteBookmarkDescription,
      contains('Книга и прогресс прослушивания сохранятся'),
    );
    expect(
      en.deleteBookmarkDescription,
      contains('The book and listening progress will be kept'),
    );
  });

  test('search scope explains why its last selected field is required', () {
    expect(ru.selectAtLeastOneSearchKind, 'Выберите хотя бы одно поле поиска.');
    expect(en.selectAtLeastOneSearchKind, 'Select at least one search field.');
  });

  test('empty shelf messages describe their own next action', () {
    expect(ru.emptyListeningShelfMessage, contains('Начните слушать'));
    expect(ru.emptyFavoritesShelfMessage, contains('сердца'));
    expect(ru.emptyLaterShelfMessage, contains('«Отложить»'));
    expect(ru.emptyDownloadedShelfMessage, contains('Скачайте книгу'));
    expect(ru.emptyFinishedShelfMessage, contains('дослушали'));
    expect(ru.emptyBookmarksShelfMessage, contains('закладку в плеере'));
    expect(
      ru.emptyHistoryShelfMessage,
      contains('Книги, которые вы запускали'),
    );
    expect(
      ru.librarySourcesMessage,
      'Сохраняйте книги или начните слушать — они появятся здесь.',
    );
    expect(ru.removeFromLater, 'Убрать из «Позже»');
    expect(en.removeFromLater, 'Remove from listen later');
    expect(ru.emptyDownloadsMessage, contains('скачайте её главы'));
    expect(en.emptyDownloadsMessage, contains('download its chapters'));
  });

  for (final language in ['kk', 'be', 'uk']) {
    test('$language retains the existing English fallback', () {
      final fallback = AppStrings.forLocale(Locale(language));
      expect(_newUiStrings(fallback), _newUiStrings(en));
      for (final count in [0, 1, 2, 11, 21]) {
        expect(fallback.booksCount(count), en.booksCount(count));
        expect(fallback.chaptersCount(count), en.chaptersCount(count));
        expect(
          fallback.sourceResultsCount(count),
          en.sourceResultsCount(count),
        );
        expect(
          fallback.partialSourceFailures(count),
          en.partialSourceFailures(count),
        );
        expect(
          fallback.selectedSourcesCount(count),
          en.selectedSourcesCount(count),
        );
        expect(
          fallback.cacheCleared(count, '8 MB'),
          en.cacheCleared(count, '8 MB'),
        );
      }
      expect(fallback.appTitle, 'Slovofon');
    });
  }
}

List<String> _newUiStrings(AppStrings strings) => [
  strings.settingsSections,
  strings.previousTabs,
  strings.nextTabs,
  strings.searchResults,
  strings.partialSearchSources('Akniga'),
  strings.partialSearchRetry,
  strings.emptyDownloadsMessage,
  strings.selectAtLeastOneSource,
  strings.selectAtLeastOneSearchKind,
  strings.sourceSearchEnabled,
  strings.sourceSearchDisabled,
  strings.currentAndNextChapters,
  strings.chapterPosition(1, 21),
  strings.allChapters,
  strings.addBookmark,
  strings.saveBookmark,
  strings.bookmarkAdded,
  strings.noBookmarks,
  strings.bookmarkNote,
  strings.deleteBookmark,
  strings.deleteBookmarkAction,
  strings.deleteBookmarkDescription,
  strings.bookmarkRemoved,
  strings.playbackSpeed,
  strings.colorPreview,
  strings.updatePreparingTitle,
  strings.addToLater,
  strings.removeFromLater,
  strings.bookActions,
  strings.emptyListeningShelf,
  strings.emptyListeningShelfMessage,
  strings.emptyFavoritesShelf,
  strings.emptyFavoritesShelfMessage,
  strings.emptyLaterShelf,
  strings.emptyLaterShelfMessage,
  strings.emptyDownloadedShelf,
  strings.emptyDownloadedShelfMessage,
  strings.emptyFinishedShelf,
  strings.emptyFinishedShelfMessage,
  strings.emptyBookmarksShelf,
  strings.emptyBookmarksShelfMessage,
  strings.emptyHistoryShelf,
  strings.emptyHistoryShelfMessage,
  strings.libraryLoadError,
  strings.libraryActionError,
  strings.bookmarkUnavailable,
];
