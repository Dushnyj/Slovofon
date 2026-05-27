import 'package:flutter/widgets.dart';

extension AppStringsContext on BuildContext {
  AppStrings get strings => AppStrings.of(this);
}

class AppStrings {
  AppStrings._(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = [
    Locale('ru'),
    Locale('en'),
    Locale('kk'),
    Locale('be'),
    Locale('uk'),
  ];

  static AppStrings of(BuildContext context) {
    return AppStrings._(Localizations.localeOf(context));
  }

  bool get _isRu => locale.languageCode == 'ru';

  String get appTitle => _isRu ? 'Словофон' : 'Slovofon';
  String get home => _isRu ? 'Главная' : 'Home';
  String get search => _isRu ? 'Поиск' : 'Search';
  String get library => _isRu ? 'Библиотека' : 'Library';
  String get downloads => _isRu ? 'Загрузки' : 'Downloads';
  String get downloadsQueueSubtitle => _isRu
      ? 'Очередь, прогресс, пауза, повтор и удаление оффлайн-файлов.'
      : 'Queue, progress, pause, retry, and offline file removal.';
  String get activeDownloads => _isRu ? 'Активные' : 'Active';
  String get queuedDownloads => _isRu ? 'Очередь' : 'Queued';
  String get completedDownloads => _isRu ? 'Завершённые' : 'Completed';
  String get failedDownloads => _isRu ? 'Ошибки' : 'Errors';
  String get downloading => _isRu ? 'Скачивается' : 'Downloading';
  String get queued => _isRu ? 'В очереди' : 'Queued';
  String get paused => _isRu ? 'На паузе' : 'Paused';
  String get failed => _isRu ? 'Ошибка' : 'Failed';
  String get unknownSize => _isRu ? 'Размер неизвестен' : 'Unknown size';
  String downloadChaptersProgress(int completed, int total) {
    return _isRu
        ? '$completed из $total глав'
        : '$completed of $total chapters';
  }

  String get calculatingTotalSize =>
      _isRu ? 'размер уточняется' : 'size is being calculated';
  String booksCount(int count) => _isRu ? '$count книг' : '$count books';
  String get settings => _isRu ? 'Настройки' : 'Settings';
  String get themePreview => _isRu ? 'Предпросмотр темы' : 'Theme preview';
  String get continueListening =>
      _isRu ? 'Продолжить прослушивание' : 'Continue listening';
  String get startedBooks => _isRu ? 'Начатые книги' : 'Started books';
  String get offlineDownloads =>
      _isRu ? 'Скачанные для оффлайна' : 'Offline downloads';
  String get recommended =>
      _isRu ? 'Рекомендации на mock data' : 'Mock recommendations';
  String get realSourceHomeTitle => _isRu ? 'Найдите книгу' : 'Find a book';
  String get realSourceHomeMessage => _isRu
      ? 'Поиск, карточки, главы, плеер и загрузки подключены к реальным источникам Izib и Akniga.'
      : 'Search, cards, chapters, playback, and downloads are connected to Izib and Akniga.';
  String get openSearch => _isRu ? 'Открыть поиск' : 'Open search';
  String get searchHint => _isRu
      ? 'Название, автор, чтец или цикл'
      : 'Title, author, narrator, or series';
  String get searchByTitle => _isRu ? 'Название' : 'Title';
  String get searchByAuthor => _isRu ? 'Автор' : 'Author';
  String get searchByNarrator => _isRu ? 'Чтец' : 'Narrator';
  String get searchBySeries => _isRu ? 'Цикл' : 'Series';
  String get recentSearches => _isRu ? 'История поиска' : 'Recent searches';
  String get searchReadyTitle =>
      _isRu ? 'Введите запрос' : 'Enter a search query';
  String get searchReadyMessage => _isRu
      ? 'Поиск подключён к реальным источникам Izib и Akniga.'
      : 'Search is connected to Izib and Akniga.';
  String get searchShortQueryTitle =>
      _isRu ? 'Слишком короткий запрос' : 'Query is too short';
  String get searchShortQueryMessage =>
      _isRu ? 'Введите минимум 2 символа.' : 'Enter at least 2 characters.';
  String get searchingSources =>
      _isRu ? 'Ищу в источниках...' : 'Searching sources...';
  String get sourceSearchError =>
      _isRu ? 'Не удалось выполнить поиск' : 'Search failed';
  String get noSearchResults => _isRu ? 'Ничего не найдено' : 'No results';
  String get noSearchResultsMessage => _isRu
      ? 'Попробуйте другое название, автора или чтеца.'
      : 'Try another title, author, or narrator.';
  String get filteredNoSearchResults => _isRu
      ? 'Источник вернул данные, но после фильтра по полному запросу подходящих результатов нет.'
      : 'The source returned data, but none matched every query word.';
  String sourceResultsCount(int count) {
    return _isRu ? '$count результатов' : '$count results';
  }

  String get izibSearchSubtitle => _isRu
      ? 'Реальная выдача источников, карточка и главы загружаются через SourceConnector.'
      : 'Real source results; details and chapters are loaded through SourceConnector.';
  String partialSourceFailures(int count) {
    return _isRu
        ? '$count источников вернули ошибку'
        : '$count source failures';
  }

  String get emptyLibrary =>
      _isRu ? 'Библиотека пока пуста' : 'Your library is empty';
  String get librarySourcesMessage => _isRu
      ? 'Добавляйте книги в избранное через поиск источников. Сохранённые книги появятся здесь.'
      : 'Add books to favorites through source search. Saved books will appear here.';
  String get emptyDownloads => _isRu ? 'Загрузок пока нет' : 'No downloads yet';
  String get appearance => _isRu ? 'Внешний вид' : 'Appearance';
  String get sources => _isRu ? 'Источники' : 'Sources';
  String get player => _isRu ? 'Плеер' : 'Player';
  String get proxy => _isRu ? 'Прокси' : 'Proxy';
  String get openThemePreview =>
      _isRu ? 'Открыть предпросмотр темы' : 'Open theme preview';
  String get previewButtons => _isRu ? 'Кнопки' : 'Buttons';
  String get previewChips => _isRu ? 'Чипы' : 'Chips';
  String get previewCards => _isRu ? 'Карточки' : 'Cards';
  String get previewInputs => _isRu ? 'Поля ввода' : 'Inputs';
  String get previewStates => _isRu ? 'Состояния' : 'States';
  String get snackbarPreview => _isRu ? 'Snackbar' : 'Snackbar';
  String get success => _isRu ? 'Успешно' : 'Success';
  String get warning => _isRu ? 'Внимание' : 'Warning';
  String get info => _isRu ? 'Информация' : 'Info';
  String get free => _isRu ? 'Бесплатно' : 'Free';
  String get paid => _isRu ? 'Платно' : 'Paid';
  String get subscription => _isRu ? 'Подписка' : 'Subscription';
  String get unknown => _isRu ? 'Неизвестно' : 'Unknown';
  String get play => _isRu ? 'Слушать' : 'Play';
  String get pause => _isRu ? 'Пауза' : 'Pause';
  String get resume => _isRu ? 'Продолжить' : 'Resume';
  String get cancel => _isRu ? 'Отменить' : 'Cancel';
  String get continuePlayback => _isRu ? 'Продолжить' : 'Continue';
  String get previousChapter => _isRu ? 'Предыдущая глава' : 'Previous chapter';
  String get rewind15 => _isRu ? 'Назад на 15 секунд' : 'Rewind 15 seconds';
  String get forward15 => _isRu ? 'Вперёд на 15 секунд' : 'Forward 15 seconds';
  String get nextChapter => _isRu ? 'Следующая глава' : 'Next chapter';
  String get download => _isRu ? 'Скачать' : 'Download';
  String get downloadBook => _isRu ? 'Скачать книгу' : 'Download book';
  String get pauseDownload =>
      _isRu ? 'Поставить загрузку на паузу' : 'Pause download';
  String get resumeDownload =>
      _isRu ? 'Продолжить загрузку' : 'Resume download';
  String get cancelDownload => _isRu ? 'Отменить загрузку' : 'Cancel download';
  String get details => _isRu ? 'Подробнее' : 'Details';
  String get bookDetails => _isRu ? 'Карточка книги' : 'Book details';
  String get chapters => _isRu ? 'Главы' : 'Chapters';
  String showMoreChapters(int count) {
    return _isRu ? 'Показать ещё $count глав' : 'Show $count more chapters';
  }

  String get collapseChapters => _isRu ? 'Свернуть главы' : 'Collapse chapters';
  String get otherVersions => _isRu ? 'Другие версии' : 'Other versions';
  String get fullPlayer => _isRu ? 'Полный плеер' : 'Full player';
  String get nowPlaying => _isRu ? 'Сейчас играет' : 'Now playing';
  String get bookmarks => _isRu ? 'Закладки' : 'Bookmarks';
  String get information => _isRu ? 'Информация' : 'Information';
  String get sleepTimer => _isRu ? 'Таймер сна' : 'Sleep timer';
  String get openFullPlayer =>
      _isRu ? 'Открыть полный плеер' : 'Open full player';
  String get groupedDuplicates =>
      _isRu ? 'Группировать одинаковые' : 'Grouped duplicates';
  String get sortRelevance =>
      _isRu ? 'Сортировка: релевантность' : 'Sort: relevance';
  String get all => _isRu ? 'Все' : 'All';
  String get listening => _isRu ? 'Слушаю' : 'Listening';
  String get favorites => _isRu ? 'Избранное' : 'Favorites';
  String get later => _isRu ? 'Позже' : 'Later';
  String get downloaded => _isRu ? 'Скачанные' : 'Downloaded';
  String get finished => _isRu ? 'Прослушано' : 'Finished';
  String get history => _isRu ? 'История' : 'History';
  String get language => _isRu ? 'Язык' : 'Language';
  String get diagnostics => _isRu ? 'Диагностика' : 'Diagnostics';
  String get retry => _isRu ? 'Повторить' : 'Retry';
  String get share => _isRu ? 'Поделиться' : 'Share';
  String get addFavorite => _isRu ? 'В избранное' : 'Add to favorites';
  String get removeFavorite =>
      _isRu ? 'Убрать из избранного' : 'Remove from favorites';
  String get favoriteAdded =>
      _isRu ? 'Добавлено в избранное' : 'Added to favorites';
  String get favoriteRemoved =>
      _isRu ? 'Удалено из избранного' : 'Removed from favorites';
  String get deleteDownloaded =>
      _isRu ? 'Удалить скачанное' : 'Delete downloaded';
  String get downloadQueuedMessage =>
      _isRu ? 'Книга добавлена в загрузки' : 'Book added to downloads';
  String get mockDataNotice => _isRu
      ? 'Каркас работает на локальных mock data. Источники будут подключены отдельным слоем.'
      : 'This scaffold uses local mock data. Sources will be wired through a separate layer.';
}
