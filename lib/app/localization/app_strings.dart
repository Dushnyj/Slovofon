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

  @visibleForTesting
  static AppStrings forLocale(Locale locale) {
    return AppStrings._(locale);
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
  String navigationTabLabel(String label, int index, int total) {
    return _isRu
        ? '$label\nВкладка $index из $total'
        : '$label\nTab $index of $total';
  }

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
      ? 'Поиск, карточки, главы, плеер и загрузки подключены к реальным источникам Izib, Akniga, Yakniga, Knigavuhe, Knigoblud и Baza Knig.'
      : 'Search, cards, chapters, playback, and downloads are connected to Izib, Akniga, Yakniga, Knigavuhe, Knigoblud, and Baza Knig.';
  String get openSearch => _isRu ? 'Открыть поиск' : 'Open search';
  String get searchHint => _isRu
      ? 'Название, автор, чтец, цикл или жанр'
      : 'Title, author, narrator, series, or genre';
  String get searchByTitle => _isRu ? 'Название' : 'Title';
  String get searchByAuthor => _isRu ? 'Автор' : 'Author';
  String get searchByNarrator => _isRu ? 'Чтец' : 'Narrator';
  String get searchBySeries => _isRu ? 'Цикл' : 'Series';
  String get searchByGenre => _isRu ? 'Жанр' : 'Genre';
  String get searchScope => _isRu ? 'Искать по' : 'Search in';
  String get sourceFilter => _isRu ? 'Источники' : 'Sources';
  String get allSources => _isRu ? 'Все источники' : 'All sources';
  String get apply => _isRu ? 'Готово' : 'Done';
  String get recentSearches => _isRu ? 'История поиска' : 'Recent searches';
  String get deleteSearchHistoryEntry =>
      _isRu ? 'Удалить из истории' : 'Delete from history';
  String get searchReadyTitle =>
      _isRu ? 'Введите запрос' : 'Enter a search query';
  String get searchReadyMessage => _isRu
      ? 'Поиск подключён к реальным источникам Izib, Akniga, Yakniga, Knigavuhe, Knigoblud и Baza Knig.'
      : 'Search is connected to Izib, Akniga, Yakniga, Knigavuhe, Knigoblud, and Baza Knig.';
  String sourceDisplayName(String sourceId) {
    return switch (sourceId) {
      'izib' => _isRu ? 'Изибук' : 'Izib',
      'akniga' => _isRu ? 'Akniga' : 'Akniga',
      'yakniga' => _isRu ? 'Yakniga' : 'Yakniga',
      'knigavuhe' => _isRu ? 'Книга в ухе' : 'Knigavuhe',
      'knigoblud' => _isRu ? 'Книгоблуд' : 'Knigoblud',
      'baza_knig' => _isRu ? 'База книг' : 'Baza Knig',
      _ => sourceId,
    };
  }

  String get searchShortQueryTitle =>
      _isRu ? 'Слишком короткий запрос' : 'Query is too short';
  String get searchShortQueryMessage =>
      _isRu ? 'Введите минимум 2 символа.' : 'Enter at least 2 characters.';
  String get searchingSources =>
      _isRu ? 'Ищу в источниках...' : 'Searching sources...';
  String get sourceSearchError =>
      _isRu ? 'Не удалось выполнить поиск' : 'Search failed';
  String get noInternetTitle =>
      _isRu ? 'Нет соединения с интернетом' : 'No internet connection';
  String get noInternetMessage => _isRu
      ? 'Проверьте Wi-Fi или мобильную сеть и повторите попытку.'
      : 'Check Wi-Fi or mobile data and try again.';
  String sourceUnavailableTitle(String sourceName) {
    return _isRu
        ? 'Источник «$sourceName» недоступен'
        : '$sourceName is unavailable';
  }

  String get sourceUnavailableMessage => _isRu
      ? 'Повторите попытку позже или проверьте соединение.'
      : 'Try again later or check your connection.';
  String get bookDetailsLoadFailedTitle => _isRu
      ? 'Не удалось открыть карточку книги'
      : 'Could not open book details';
  String bookDetailsLoadFailedMessage(String sourceName) {
    return _isRu
        ? 'Не получилось загрузить данные из источника «$sourceName».'
        : 'Could not load data from $sourceName.';
  }

  String bookNotFoundMessage(String sourceName) {
    return _isRu
        ? 'Источник «$sourceName» не нашёл эту книгу. Возможно, страница была удалена.'
        : '$sourceName did not find this book. The page may have been removed.';
  }

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
  String selectedSourcesCount(int count) {
    return _isRu ? '$count источников включено' : '$count sources enabled';
  }

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
  String get enabled => _isRu ? 'Включено' : 'Enabled';
  String get disabled => _isRu ? 'Выключено' : 'Disabled';
  String get play => _isRu ? 'Слушать' : 'Play';
  String get pause => _isRu ? 'Пауза' : 'Pause';
  String get resume => _isRu ? 'Продолжить' : 'Resume';
  String get cancel => _isRu ? 'Отменить' : 'Cancel';
  String get continuePlayback => _isRu ? 'Продолжить' : 'Continue';
  String get previousChapter => _isRu ? 'Предыдущая глава' : 'Previous chapter';
  String get rewind15 => _isRu ? 'Назад на 15 секунд' : 'Rewind 15 seconds';
  String get forward15 => _isRu ? 'Вперёд на 15 секунд' : 'Forward 15 seconds';
  String get nextChapter => _isRu ? 'Следующая глава' : 'Next chapter';
  String get goToCurrentChapter =>
      _isRu ? 'К текущей главе' : 'Current chapter';
  String get download => _isRu ? 'Скачать' : 'Download';
  String get downloadBook => _isRu ? 'Скачать книгу' : 'Download book';
  String get pauseDownload =>
      _isRu ? 'Поставить загрузку на паузу' : 'Pause download';
  String get resumeDownload =>
      _isRu ? 'Продолжить загрузку' : 'Resume download';
  String get cancelDownload => _isRu ? 'Отменить загрузку' : 'Cancel download';
  String get details => _isRu ? 'Подробнее' : 'Details';
  String get bookDetails => _isRu ? 'Карточка книги' : 'Book details';
  String get description => _isRu ? 'Описание' : 'Description';
  String get showFullDescription =>
      _isRu ? 'Показать полностью' : 'Show full description';
  String get hideDescription => _isRu ? 'Скрыть описание' : 'Hide description';
  String get sourcePage =>
      _isRu ? 'Страница на сайте источника' : 'Source page';
  String get sourcePageOpenError => _isRu
      ? 'Не удалось открыть страницу источника'
      : 'Could not open source page';
  String get genre => _isRu ? 'Жанр' : 'Genre';
  String get sourceStats => _isRu ? 'Статистика источника' : 'Source stats';
  String get chapters => _isRu ? 'Главы' : 'Chapters';
  String chaptersCount(int count) => _isRu ? '$count глав' : '$count chapters';
  String showMoreChapters(int count) {
    return _isRu ? 'Показать ещё $count глав' : 'Show $count more chapters';
  }

  String get collapseChapters => _isRu ? 'Свернуть главы' : 'Collapse chapters';
  String get otherVersions => _isRu ? 'Другие версии' : 'Other versions';
  String get otherNarrations => _isRu ? 'Другие озвучки' : 'Other narrations';
  String get series => _isRu ? 'Цикл' : 'Series';
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
  String get filter => _isRu ? 'Фильтр' : 'Filter';
  String get listening => _isRu ? 'Слушаю' : 'Listening';
  String get favorites => _isRu ? 'Избранное' : 'Favorites';
  String get later => _isRu ? 'Позже' : 'Later';
  String get downloaded => _isRu ? 'Скачанные' : 'Downloaded';
  String get finished => _isRu ? 'Прослушано' : 'Finished';
  String get history => _isRu ? 'История' : 'History';
  String get language => _isRu ? 'Язык' : 'Language';
  String get systemLanguage => _isRu ? 'Язык системы' : 'System language';
  String get russianLanguage => 'Русский';
  String get englishLanguage => 'English';
  String get kazakhLanguage => 'Қазақша';
  String get belarusianLanguage => 'Беларуская';
  String get ukrainianLanguage => 'Українська';
  String get diagnostics => _isRu ? 'Диагностика' : 'Diagnostics';
  String get playback => _isRu ? 'Воспроизведение' : 'Playback';
  String get dataAndDownloads =>
      _isRu ? 'Данные и загрузки' : 'Data and downloads';
  String get cards => _isRu ? 'Карточки' : 'Cards';
  String get theme => _isRu ? 'Тема' : 'Theme';
  String get themeSystem => _isRu ? 'Системная' : 'System';
  String get themeLight => _isRu ? 'Светлая' : 'Light';
  String get themeDark => _isRu ? 'Тёмная' : 'Dark';
  String get themeAmoled => _isRu ? 'AMOLED' : 'AMOLED';
  String get accentColor => _isRu ? 'Акцентный цвет' : 'Accent color';
  String get customColor => _isRu ? 'Свой цвет' : 'Custom color';
  String get colorHue => _isRu ? 'Тон' : 'Hue';
  String get colorSaturation => _isRu ? 'Насыщенность' : 'Saturation';
  String get colorBrightness => _isRu ? 'Яркость' : 'Brightness';
  String get textSize => _isRu ? 'Размер текста' : 'Text size';
  String get compactCards => _isRu ? 'Компактные карточки' : 'Compact cards';
  String get showSourceOnCards =>
      _isRu ? 'Название источника на карточках' : 'Source name on cards';
  String get showPercentOnCovers => _isRu
      ? 'Процент прослушивания на обложках'
      : 'Progress percent on covers';
  String get animations => _isRu ? 'Анимации' : 'Animations';
  String get animationsFull => _isRu ? 'Полные' : 'Full';
  String get animationsReduced => _isRu ? 'Сниженные' : 'Reduced';
  String get animationsOff => _isRu ? 'Выключены' : 'Off';
  String get enabledInSearch =>
      _isRu ? 'Используются в поиске' : 'Enabled in search';
  String get openPlayer => _isRu ? 'Открыть плеер' : 'Open player';
  String get playerSettingsHint => _isRu
      ? 'Скорость, таймер сна и управление главами находятся в полном плеере.'
      : 'Speed, sleep timer, and chapter controls live in the full player.';
  String get openDownloads => _isRu ? 'Открыть загрузки' : 'Open downloads';
  String get downloadsSettingsHint => _isRu
      ? 'Очередь, пауза, повтор и удаление оффлайн-файлов находятся на вкладке загрузок.'
      : 'Queue, pause, retry, and offline file removal live on the downloads tab.';
  String get cacheAndMetadata => _isRu ? 'Кэш карточек' : 'Card cache';
  String get cacheAndMetadataHint => _isRu
      ? 'Названия, обложки и данные карточек сохраняются для оффлайна и обновляются при открытии карточки книги.'
      : 'Titles, covers, and card facts are cached for offline use and refresh when book details open.';
  String cacheSize(String value) => _isRu ? 'Размер: $value' : 'Size: $value';
  String cacheBooks(int count) => _isRu ? '$count книг' : '$count books';
  String get clearCardCache =>
      _isRu ? 'Очистить кэш карточек' : 'Clear card cache';
  String get clearCardCacheConfirm => _isRu
      ? 'Будут удалены только временные обложки и metadata для карточек без скачанных файлов. Скачанные книги, главы, избранное, история и прогресс останутся.'
      : 'Only temporary covers and metadata for cards without downloaded files will be removed. Downloaded books, chapters, favorites, history, and progress stay intact.';
  String get downloadedBooksPreserved =>
      _isRu ? 'Скачанные книги не удаляются' : 'Downloaded books are preserved';
  String get clearCacheSafetyHint => _isRu
      ? 'Очистка не трогает папки, где есть главы или части загрузок.'
      : 'Cleanup skips folders with chapters or partial downloads.';
  String cacheCleared(int count, String size) {
    return _isRu
        ? 'Очищено: $count книг, $size'
        : 'Cleared: $count books, $size';
  }

  String get aboutApp => _isRu ? 'О приложении' : 'About';
  String get aboutAppHint =>
      _isRu ? 'Версия, сборка и ссылки проекта' : 'Version, build, and links';
  String get appVersion => _isRu ? 'Версия' : 'Version';
  String get buildNumber => _isRu ? 'Номер сборки' : 'Build number';
  String get projectWebsite => _isRu ? 'Сайт проекта' : 'Project website';
  String get githubRepository =>
      _isRu ? 'GitHub приложения' : 'Application GitHub';
  String get telegramSupportBot =>
      _isRu ? 'Telegram-бот поддержки' : 'Telegram support bot';
  String get telegramChannel => _isRu ? 'Telegram-канал' : 'Telegram channel';
  String get telegramChat => _isRu ? 'Telegram-чат' : 'Telegram chat';
  String get updateChannel => _isRu ? 'Канал обновлений' : 'Update channel';
  String get diagnosticsHint => _isRu
      ? 'Предпросмотр темы и безопасная проверка интерфейсных состояний.'
      : 'Theme preview and safe UI state checks.';
  String themeModeLabel(String value) {
    return _isRu ? 'Тема: $value' : 'Theme: $value';
  }

  String textSizeLabel(int percent) {
    return _isRu ? 'Размер текста: $percent%' : 'Text size: $percent%';
  }

  String get retry => _isRu ? 'Повторить' : 'Retry';
  String get share => _isRu ? 'Поделиться' : 'Share';
  String get shareSlovofonLink => _isRu ? 'Ссылка Словофон' : 'Slovofon link';
  String get shareSourceLink => _isRu ? 'Ссылка источника' : 'Source link';
  String get shareLinkCopied => _isRu ? 'Ссылка скопирована' : 'Link copied';
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
