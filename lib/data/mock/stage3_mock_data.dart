import '../../domain/models/audio_book.dart';

enum MockDownloadStatus { downloaded, downloading, queued, paused, failed }

class MockBook {
  const MockBook({
    required this.id,
    required this.title,
    required this.author,
    required this.narrator,
    required this.sourceId,
    required this.sourceName,
    required this.durationLabel,
    required this.chapterCount,
    required this.progress,
    required this.access,
    required this.description,
    required this.year,
    required this.audioYear,
    required this.genre,
    required this.series,
    required this.ratingLabel,
    required this.activeChapterTitle,
    required this.positionLabel,
    required this.remainingLabel,
    required this.downloadStatus,
    required this.isFavorite,
    required this.isLater,
    required this.isFinished,
    required this.versions,
    required this.chapters,
    required this.bookmarks,
  });

  final String id;
  final String title;
  final String author;
  final String narrator;
  final String sourceId;
  final String sourceName;
  final String durationLabel;
  final int chapterCount;
  final double progress;
  final BookAccess access;
  final String description;
  final int year;
  final int audioYear;
  final String genre;
  final String series;
  final String ratingLabel;
  final String activeChapterTitle;
  final String positionLabel;
  final String remainingLabel;
  final MockDownloadStatus downloadStatus;
  final bool isFavorite;
  final bool isLater;
  final bool isFinished;
  final List<MockBookVersion> versions;
  final List<MockChapter> chapters;
  final List<MockBookmark> bookmarks;

  AudioBook toAudioBook() {
    return AudioBook(
      id: id,
      title: title,
      author: author,
      narrator: narrator,
      sourceId: sourceId,
      sourceName: sourceName,
      durationLabel: durationLabel,
      chapterCount: chapterCount,
      progress: progress,
      access: access,
    );
  }
}

class MockBookVersion {
  const MockBookVersion({
    required this.sourceName,
    required this.narrator,
    required this.durationLabel,
    required this.accessLabel,
  });

  final String sourceName;
  final String narrator;
  final String durationLabel;
  final String accessLabel;
}

class MockChapter {
  const MockChapter({
    required this.index,
    required this.title,
    required this.durationLabel,
    required this.progress,
    required this.isDownloaded,
    required this.isCurrent,
  });

  final int index;
  final String title;
  final String durationLabel;
  final double progress;
  final bool isDownloaded;
  final bool isCurrent;
}

class MockBookmark {
  const MockBookmark({
    required this.chapterTitle,
    required this.positionLabel,
    required this.note,
  });

  final String chapterTitle;
  final String positionLabel;
  final String note;
}

class MockDownloadItem {
  const MockDownloadItem({
    required this.book,
    required this.chapterTitle,
    required this.status,
    required this.progress,
    required this.sizeLabel,
  });

  final MockBook book;
  final String chapterTitle;
  final MockDownloadStatus status;
  final double progress;
  final String sizeLabel;
}

class MockLibraryShelf {
  const MockLibraryShelf({required this.label, required this.books});

  final String label;
  final List<MockBook> books;
}

const stage3MockBooks = [
  MockBook(
    id: 'yakniga-master-and-margarita',
    title: 'Мастер и Маргарита',
    author: 'Михаил Булгаков',
    narrator: 'Вячеслав Герасимов',
    sourceId: 'yakniga',
    sourceName: 'Yakniga',
    durationLabel: '15 ч 42 мин',
    chapterCount: 32,
    progress: 0.36,
    access: BookAccess.free,
    description:
        'Сатирический роман о Москве, Воланде, любви и рукописи, которая не горит. В mock data книга показывает продолжение, главы, версии и закладки.',
    year: 1967,
    audioYear: 2021,
    genre: 'Классика',
    series: 'Вне цикла',
    ratingLabel: '4.8',
    activeChapterTitle: 'Глава 03. Погоня',
    positionLabel: '01:25:10',
    remainingLabel: '10 ч 04 мин осталось',
    downloadStatus: MockDownloadStatus.downloading,
    isFavorite: true,
    isLater: false,
    isFinished: false,
    versions: [
      MockBookVersion(
        sourceName: 'Yakniga',
        narrator: 'Вячеслав Герасимов',
        durationLabel: '15 ч 42 мин',
        accessLabel: 'Бесплатно',
      ),
      MockBookVersion(
        sourceName: 'Akniga',
        narrator: 'Олег Табаков',
        durationLabel: '16 ч 08 мин',
        accessLabel: 'Подписка',
      ),
    ],
    chapters: [
      MockChapter(
        index: 1,
        title: 'Никогда не разговаривайте с неизвестными',
        durationLabel: '31 мин',
        progress: 1,
        isDownloaded: true,
        isCurrent: false,
      ),
      MockChapter(
        index: 2,
        title: 'Понтий Пилат',
        durationLabel: '28 мин',
        progress: 1,
        isDownloaded: true,
        isCurrent: false,
      ),
      MockChapter(
        index: 3,
        title: 'Погоня',
        durationLabel: '24 мин',
        progress: 0.48,
        isDownloaded: false,
        isCurrent: true,
      ),
    ],
    bookmarks: [
      MockBookmark(
        chapterTitle: 'Глава 2',
        positionLabel: '12:40',
        note: 'Сцена у Пилата',
      ),
      MockBookmark(
        chapterTitle: 'Глава 3',
        positionLabel: '05:18',
        note: 'Вернуться к диалогу',
      ),
    ],
  ),
  MockBook(
    id: 'akniga-picnic',
    title: 'Пикник на обочине',
    author: 'Аркадий и Борис Стругацкие',
    narrator: 'Александр Клюквин',
    sourceId: 'akniga',
    sourceName: 'Akniga',
    durationLabel: '6 ч 18 мин',
    chapterCount: 12,
    progress: 0,
    access: BookAccess.free,
    description:
        'Фантастическая повесть о Зоне, сталкерах и цене желания. В mock UI используется как новая книга без прогресса.',
    year: 1972,
    audioYear: 2019,
    genre: 'Фантастика',
    series: 'Вне цикла',
    ratingLabel: '4.7',
    activeChapterTitle: 'Глава 01. Рэдрик Шухарт',
    positionLabel: '00:00',
    remainingLabel: '6 ч 18 мин осталось',
    downloadStatus: MockDownloadStatus.queued,
    isFavorite: false,
    isLater: true,
    isFinished: false,
    versions: [
      MockBookVersion(
        sourceName: 'Akniga',
        narrator: 'Александр Клюквин',
        durationLabel: '6 ч 18 мин',
        accessLabel: 'Бесплатно',
      ),
    ],
    chapters: [
      MockChapter(
        index: 1,
        title: 'Рэдрик Шухарт',
        durationLabel: '34 мин',
        progress: 0,
        isDownloaded: false,
        isCurrent: true,
      ),
      MockChapter(
        index: 2,
        title: 'После визита',
        durationLabel: '29 мин',
        progress: 0,
        isDownloaded: false,
        isCurrent: false,
      ),
    ],
    bookmarks: [],
  ),
  MockBook(
    id: 'izib-metro',
    title: 'Метро 2033',
    author: 'Дмитрий Глуховский',
    narrator: 'Петр Иващенко',
    sourceId: 'izib',
    sourceName: 'Izib',
    durationLabel: '13 ч 06 мин',
    chapterCount: 28,
    progress: 0.74,
    access: BookAccess.unknown,
    description:
        'Постапокалиптическое путешествие по московскому метро. Mock-карточка демонстрирует высокий прогресс и неизвестный доступ.',
    year: 2005,
    audioYear: 2020,
    genre: 'Постапокалипсис',
    series: 'Метро',
    ratingLabel: '4.5',
    activeChapterTitle: 'Глава 21. Полис',
    positionLabel: '09:41:00',
    remainingLabel: '3 ч 25 мин осталось',
    downloadStatus: MockDownloadStatus.downloaded,
    isFavorite: true,
    isLater: false,
    isFinished: false,
    versions: [
      MockBookVersion(
        sourceName: 'Izib',
        narrator: 'Петр Иващенко',
        durationLabel: '13 ч 06 мин',
        accessLabel: 'Неизвестно',
      ),
      MockBookVersion(
        sourceName: 'Knigavuhe',
        narrator: 'Сергей Чонишвили',
        durationLabel: '12 ч 58 мин',
        accessLabel: 'Бесплатно',
      ),
    ],
    chapters: [
      MockChapter(
        index: 20,
        title: 'Библиотека',
        durationLabel: '33 мин',
        progress: 1,
        isDownloaded: true,
        isCurrent: false,
      ),
      MockChapter(
        index: 21,
        title: 'Полис',
        durationLabel: '42 мин',
        progress: 0.62,
        isDownloaded: true,
        isCurrent: true,
      ),
      MockChapter(
        index: 22,
        title: 'Башня',
        durationLabel: '36 мин',
        progress: 0,
        isDownloaded: true,
        isCurrent: false,
      ),
    ],
    bookmarks: [
      MockBookmark(
        chapterTitle: 'Глава 21',
        positionLabel: '18:02',
        note: 'Описание Полиса',
      ),
    ],
  ),
  MockBook(
    id: 'baza-451',
    title: '451 градус по Фаренгейту',
    author: 'Рэй Брэдбери',
    narrator: 'Владимир Самойлов',
    sourceId: 'baza_knig',
    sourceName: 'Baza-knig',
    durationLabel: '5 ч 12 мин',
    chapterCount: 9,
    progress: 1,
    access: BookAccess.subscription,
    description:
        'Антиутопия о книгах, памяти и цензуре. В mock data помечена как прослушанная и доступная по подписке.',
    year: 1953,
    audioYear: 2018,
    genre: 'Антиутопия',
    series: 'Вне цикла',
    ratingLabel: '4.6',
    activeChapterTitle: 'Финал',
    positionLabel: '05:12:00',
    remainingLabel: 'Прослушано',
    downloadStatus: MockDownloadStatus.failed,
    isFavorite: false,
    isLater: false,
    isFinished: true,
    versions: [
      MockBookVersion(
        sourceName: 'Baza-knig',
        narrator: 'Владимир Самойлов',
        durationLabel: '5 ч 12 мин',
        accessLabel: 'Подписка',
      ),
    ],
    chapters: [
      MockChapter(
        index: 9,
        title: 'Город и костры',
        durationLabel: '38 мин',
        progress: 1,
        isDownloaded: false,
        isCurrent: false,
      ),
    ],
    bookmarks: [],
  ),
];

MockBook get activeMockBook => stage3MockBooks.first;

MockBook mockBookById(String? id) {
  return stage3MockBooks.firstWhere(
    (book) => book.id == id,
    orElse: () => activeMockBook,
  );
}

List<MockDownloadItem> get stage3MockDownloads => [
  MockDownloadItem(
    book: stage3MockBooks[2],
    chapterTitle: 'Глава 21. Полис',
    status: MockDownloadStatus.downloaded,
    progress: 1,
    sizeLabel: '148 МБ',
  ),
  MockDownloadItem(
    book: stage3MockBooks[0],
    chapterTitle: 'Глава 03. Погоня',
    status: MockDownloadStatus.downloading,
    progress: 0.48,
    sizeLabel: '64 МБ',
  ),
  MockDownloadItem(
    book: stage3MockBooks[1],
    chapterTitle: 'Вся книга',
    status: MockDownloadStatus.queued,
    progress: 0,
    sizeLabel: '312 МБ',
  ),
  MockDownloadItem(
    book: stage3MockBooks[0],
    chapterTitle: 'Глава 04. Появление Воланда',
    status: MockDownloadStatus.paused,
    progress: 0.22,
    sizeLabel: '58 МБ',
  ),
  MockDownloadItem(
    book: stage3MockBooks[3],
    chapterTitle: 'Глава 09. Город и костры',
    status: MockDownloadStatus.failed,
    progress: 0.31,
    sizeLabel: '44 МБ',
  ),
];

List<MockLibraryShelf> get stage3LibraryShelves => [
  const MockLibraryShelf(label: 'All', books: stage3MockBooks),
  MockLibraryShelf(
    label: 'Listening',
    books: stage3MockBooks
        .where((book) => book.progress > 0 && !book.isFinished)
        .toList(),
  ),
  MockLibraryShelf(
    label: 'Favorites',
    books: stage3MockBooks.where((book) => book.isFavorite).toList(),
  ),
  MockLibraryShelf(
    label: 'Later',
    books: stage3MockBooks.where((book) => book.isLater).toList(),
  ),
  MockLibraryShelf(
    label: 'Downloaded',
    books: stage3MockBooks
        .where((book) => book.downloadStatus == MockDownloadStatus.downloaded)
        .toList(),
  ),
  MockLibraryShelf(
    label: 'Finished',
    books: stage3MockBooks.where((book) => book.isFinished).toList(),
  ),
  MockLibraryShelf(
    label: 'Bookmarks',
    books: stage3MockBooks.where((book) => book.bookmarks.isNotEmpty).toList(),
  ),
  MockLibraryShelf(label: 'History', books: stage3MockBooks.take(3).toList()),
];
