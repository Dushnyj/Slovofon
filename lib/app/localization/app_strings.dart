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

  // Cardinal rules are shared, but callers supply case-appropriate noun forms
  // (for example, "1 глава", "ещё 1 главу", and "из 1 главы").
  static String _russianForm(int count, String one, String few, String many) {
    final absolute = count.abs();
    final lastTwo = absolute % 100;
    if (lastTwo >= 11 && lastTwo <= 14) return many;
    return switch (absolute % 10) {
      1 => one,
      2 || 3 || 4 => few,
      _ => many,
    };
  }

  String _counted(
    int count,
    String ruOne,
    String ruFew,
    String ruMany,
    String enOne,
    String enOther,
  ) {
    final form = _isRu
        ? _russianForm(count, ruOne, ruFew, ruMany)
        : count.abs() == 1
        ? enOne
        : enOther;
    return '$count $form';
  }

  String get appTitle => _isRu ? 'Словофон' : 'Slovofon';
  String get desktopLibraryLabel => _isRu ? 'Аудиокниги' : 'Audiobooks';
  String get bookProgress => _isRu ? 'Прогресс книги' : 'Book progress';
  String get playbackSource => _isRu ? 'Источник' : 'Source';
  String get settingsPersonalization =>
      _isRu ? 'Персонализация' : 'Personalization';
  String get settingsContent =>
      _isRu ? 'Контент и хранение' : 'Content and storage';
  String get settingsApplication => _isRu ? 'Приложение' : 'Application';
  String get settingsSections =>
      _isRu ? 'Разделы настроек' : 'Settings sections';
  String get bookFragment => _isRu ? 'Ознакомительный фрагмент' : 'Sample';
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
        ? '$completed из $total ${_russianForm(total, 'главы', 'глав', 'глав')}'
        : '$completed of $total ${total.abs() == 1 ? 'chapter' : 'chapters'}';
  }

  String get calculatingTotalSize =>
      _isRu ? 'размер уточняется' : 'size is being calculated';
  String booksCount(int count) =>
      _counted(count, 'книга', 'книги', 'книг', 'book', 'books');
  String get settings => _isRu ? 'Настройки' : 'Settings';
  String navigationTabLabel(String label, int index, int total) {
    return _isRu
        ? '$label\nВкладка $index из $total'
        : '$label\nTab $index of $total';
  }

  String get themePreview => _isRu ? 'Предпросмотр темы' : 'Theme preview';
  String get previousTabs => _isRu ? 'Предыдущие вкладки' : 'Previous tabs';
  String get nextTabs => _isRu ? 'Следующие вкладки' : 'Next tabs';
  String get continueListening =>
      _isRu ? 'Продолжить прослушивание' : 'Continue listening';
  String get searchHistoryEmptyMessage => _isRu
      ? 'Здесь появятся ваши недавние запросы — их можно повторить или удалить.'
      : 'Your recent searches will appear here so you can repeat or delete them.';
  String get homeLibraryShortcutMessage => _isRu
      ? 'Избранные книги и сохранённые озвучки.'
      : 'Favorite books and saved narrations.';
  String get homeDownloadsShortcutMessage => _isRu
      ? 'Книги, которые можно слушать без интернета.'
      : 'Books you can listen to offline.';
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
    return _counted(
      count,
      'результат',
      'результата',
      'результатов',
      'result',
      'results',
    );
  }

  String get searchResults => _isRu ? 'Результаты' : 'Results';
  String partialSearchSources(String names) =>
      _isRu ? 'Не ответили: $names' : 'Unavailable: $names';
  String get partialSearchRetry => _isRu ? 'Повторить поиск' : 'Retry search';

  String get izibSearchSubtitle => _isRu
      ? 'Реальная выдача источников, карточка и главы загружаются через SourceConnector.'
      : 'Real source results; details and chapters are loaded through SourceConnector.';
  String partialSourceFailures(int count) {
    return _counted(
      count,
      'источник вернул ошибку',
      'источника вернули ошибку',
      'источников вернули ошибку',
      'source failure',
      'source failures',
    );
  }

  String get emptyLibrary =>
      _isRu ? 'Библиотека пока пуста' : 'Your library is empty';
  String get librarySourcesMessage => _isRu
      ? 'Сохраняйте книги или начните слушать — они появятся здесь.'
      : 'Save books or start listening to see them here.';
  String get emptyListeningShelf =>
      _isRu ? 'Пока ничего не слушаете' : 'No books in progress';
  String get emptyListeningShelfMessage => _isRu
      ? 'Начните слушать книгу — здесь появится ваш прогресс.'
      : 'Start listening to a book to see your progress here.';
  String get emptyFavoritesShelf =>
      _isRu ? 'В избранном пока пусто' : 'No favorites yet';
  String get emptyFavoritesShelfMessage => _isRu
      ? 'Добавляйте понравившиеся книги с помощью сердца.'
      : 'Use the heart button to add books you like.';
  String get emptyLaterShelf =>
      _isRu ? 'Нет отложенных книг' : 'No books saved for later';
  String get emptyLaterShelfMessage => _isRu
      ? 'Выберите «Отложить» в меню книги, чтобы сохранить её на потом.'
      : 'Choose Listen later in a book’s menu to save it for later.';
  String get emptyDownloadedShelf =>
      _isRu ? 'Нет скачанных книг' : 'No downloaded books';
  String get emptyDownloadedShelfMessage => _isRu
      ? 'Скачайте книгу, чтобы слушать без интернета.'
      : 'Download a book to listen offline.';
  String get emptyFinishedShelf =>
      _isRu ? 'Нет прослушанных книг' : 'No finished books';
  String get emptyFinishedShelfMessage => _isRu
      ? 'Здесь появятся книги, которые вы дослушали.'
      : 'Books you finish listening to will appear here.';
  String get emptyBookmarksShelf => _isRu ? 'Нет закладок' : 'No bookmarks';
  String get emptyBookmarksShelfMessage => _isRu
      ? 'Добавьте закладку в плеере, чтобы вернуться к нужному моменту.'
      : 'Add a bookmark in the player to return to a specific moment.';
  String get emptyHistoryShelf =>
      _isRu ? 'История прослушивания пуста' : 'Listening history is empty';
  String get emptyHistoryShelfMessage => _isRu
      ? 'Книги, которые вы запускали, будут показаны здесь.'
      : 'Books you have played will appear here.';
  String get libraryLoadError =>
      _isRu ? 'Не удалось загрузить библиотеку' : 'Could not load the library';
  String get libraryActionError =>
      _isRu ? 'Не удалось сохранить изменение' : 'Could not save the change';
  String get bookmarkUnavailable => _isRu
      ? 'Не удалось открыть книгу для этой закладки'
      : 'Could not open the book for this bookmark';
  String get emptyDownloads => _isRu ? 'Загрузок пока нет' : 'No downloads yet';
  String get emptyDownloadsMessage => _isRu
      ? 'Найдите книгу и скачайте её главы, чтобы слушать без интернета.'
      : 'Find a book and download its chapters to listen offline.';
  String get appearance => _isRu ? 'Внешний вид' : 'Appearance';
  String get sources => _isRu ? 'Источники' : 'Sources';
  String selectedSourcesCount(int count) {
    return _counted(
      count,
      'источник включён',
      'источника включены',
      'источников включено',
      'source enabled',
      'sources enabled',
    );
  }

  String get selectAtLeastOneSource =>
      _isRu ? 'Выберите хотя бы один источник' : 'Select at least one source';
  String get selectAtLeastOneSearchKind => _isRu
      ? 'Выберите хотя бы одно поле поиска.'
      : 'Select at least one search field.';
  String get sourceSearchEnabled =>
      _isRu ? 'Включён в поиск' : 'Included in search';
  String get sourceSearchDisabled =>
      _isRu ? 'Исключён из поиска' : 'Excluded from search';

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
  String get mute => _isRu ? 'Без звука' : 'Mute';
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
  String chaptersCount(int count) =>
      _counted(count, 'глава', 'главы', 'глав', 'chapter', 'chapters');
  String showMoreChapters(int count) {
    return _isRu
        ? 'Показать ещё $count ${_russianForm(count, 'главу', 'главы', 'глав')}'
        : 'Show $count more ${count.abs() == 1 ? 'chapter' : 'chapters'}';
  }

  String get currentAndNextChapters =>
      _isRu ? 'Текущая и следующие' : 'Current and next';
  String chapterPosition(int current, int total) =>
      _isRu ? 'Глава $current из $total' : 'Chapter $current of $total';
  String get allChapters => _isRu ? 'Все главы' : 'All chapters';

  String get collapseChapters => _isRu ? 'Свернуть главы' : 'Collapse chapters';
  String get otherVersions => _isRu ? 'Другие версии' : 'Other versions';
  String get otherNarrations => _isRu ? 'Другие озвучки' : 'Other narrations';
  String get narratorUnknown =>
      _isRu ? 'Чтец не указан' : 'Narrator not specified';
  String get series => _isRu ? 'Цикл' : 'Series';
  String get fullPlayer => _isRu ? 'Полный плеер' : 'Full player';
  String get nowPlaying => _isRu ? 'Сейчас играет' : 'Now playing';
  String get bookmarks => _isRu ? 'Закладки' : 'Bookmarks';
  String get addBookmark => _isRu ? 'Добавить закладку' : 'Add bookmark';
  String get saveBookmark => _isRu ? 'Сохранить закладку' : 'Save bookmark';
  String get bookmarkAdded => _isRu ? 'Закладка добавлена' : 'Bookmark added';
  String get noBookmarks => _isRu ? 'Нет закладок' : 'No bookmarks';
  String get bookmarkNote => _isRu ? 'Заметка' : 'Note';
  String get deleteBookmark => _isRu ? 'Удалить закладку?' : 'Delete bookmark?';
  String get deleteBookmarkAction => _isRu ? 'Удалить' : 'Delete';
  String get deleteBookmarkDescription => _isRu
      ? 'Закладка будет удалена. Книга и прогресс прослушивания сохранятся.'
      : 'The bookmark will be removed. The book and listening progress will be kept.';
  String get bookmarkRemoved => _isRu ? 'Закладка удалена' : 'Bookmark removed';
  String get information => _isRu ? 'Информация' : 'Information';
  String get sleepTimer => _isRu ? 'Таймер сна' : 'Sleep timer';
  String get playbackSpeed =>
      _isRu ? 'Скорость воспроизведения' : 'Playback speed';
  String get volume => _isRu ? 'Громкость' : 'Volume';
  String get openFullPlayer =>
      _isRu ? 'Открыть полный плеер' : 'Open full player';
  String get groupedDuplicates =>
      _isRu ? 'Группировать одинаковые' : 'Grouped duplicates';
  String get sort => _isRu ? 'Сортировка' : 'Sort';
  String get sortByRelevance => _isRu ? 'релевантность' : 'relevance';
  String get sortByRating => _isRu ? 'рейтинг' : 'rating';
  String get sortByYear => _isRu ? 'год' : 'year';
  String get sortByDuration => _isRu ? 'длительность' : 'duration';
  String get sortByTitle => _isRu ? 'название' : 'title';
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
  String get colorPreview => _isRu ? 'Предпросмотр' : 'Preview';
  String get colorHue => _isRu ? 'Тон' : 'Hue';
  String get colorSaturation => _isRu ? 'Насыщенность' : 'Saturation';
  String get colorBrightness => _isRu ? 'Яркость' : 'Brightness';
  String get textSize => _isRu ? 'Размер текста' : 'Text size';
  String get textSizePreview => _isRu
      ? 'Так будет выглядеть текст в приложении.'
      : 'This is how text will look in the app.';
  String get textSizeHint => _isRu
      ? '100% — системный размер текста. Изменения применяются после отпускания ползунка.'
      : '100% follows the system text size. Changes apply when you release the slider.';
  String get textSizeReset => _isRu ? 'Вернуть 100%' : 'Reset to 100%';
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
      ? 'Обложки и сведения о книгах доступны без интернета и обновляются при открытии карточки.'
      : 'Covers and book details are available offline and refresh when you open a book.';
  String cacheSize(String value) => _isRu ? 'Размер: $value' : 'Size: $value';
  String cacheBooks(int count) => booksCount(count);
  String get clearCardCache =>
      _isRu ? 'Очистить кэш карточек' : 'Clear card cache';
  String get clearCardCacheConfirm => _isRu
      ? 'Удалить обложки и сведения о книгах без скачанных файлов? Скачанные книги и главы, избранное, история и прогресс сохранятся.'
      : 'Remove covers and details for books without downloaded files? Downloaded books and chapters, favorites, history, and progress will be kept.';
  String get downloadedBooksPreserved =>
      _isRu ? 'Скачанные книги не удаляются' : 'Downloaded books are preserved';
  String get clearCacheSafetyHint => _isRu
      ? 'Незавершённые загрузки также сохранятся.'
      : 'Partial downloads will also be kept.';
  String cacheCleared(int count, String size) {
    return _isRu
        ? 'Кэш очищен: ${cacheBooks(count)}, $size'
        : 'Cache cleared: ${cacheBooks(count)}, $size';
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
  String get appUpdates => _isRu ? 'Обновления' : 'Updates';
  String get appUpdatesHint =>
      _isRu ? 'Проверить новую версию' : 'Check for a new version';
  String get checkingUpdates =>
      _isRu ? 'Проверяю обновления...' : 'Checking for updates...';
  String get updateAvailableTitle =>
      _isRu ? 'Доступно обновление' : 'Update available';
  String updateAvailableMessage(String version, String size) {
    return _isRu
        ? 'Доступна версия $version. Размер обновления: $size.'
        : 'Version $version is available. Update size: $size.';
  }

  String get updateNow => _isRu ? 'Обновить' : 'Update';
  String get skipUpdate => _isRu ? 'Пропустить версию' : 'Skip this version';
  String get updateLater => _isRu ? 'Позже' : 'Later';
  String get updateReleaseNotes => _isRu ? 'Что нового' : 'What is new';
  String get updateNotesLinkFailed => _isRu
      ? 'Не удалось открыть ссылку. Проверьте, установлен ли браузер.'
      : 'Could not open the link. Check that a browser is installed.';
  String get updateNotesTruncated => _isRu
      ? 'Показана часть описания. Полный текст доступен на странице релиза.'
      : 'Part of the description is shown. Read the full text on the release page.';
  String get updateNotesRemoteHint => _isRu
      ? 'Вверх и вниз — прокрутка. Вправо — переход к ссылкам.'
      : 'Up and down to scroll. Right to focus links.';
  String updateNotesAlert(String kind) => switch (kind) {
    'TIP' => _isRu ? 'Совет' : 'Tip',
    'IMPORTANT' => _isRu ? 'Важно' : 'Important',
    'WARNING' => _isRu ? 'Предупреждение' : 'Warning',
    'CAUTION' => _isRu ? 'Внимание' : 'Caution',
    _ => _isRu ? 'Примечание' : 'Note',
  };
  String get updateDownloadZip => _isRu ? 'Скачать ZIP' : 'Download ZIP';
  String get updateOpenReleases =>
      _isRu ? 'Открыть страницу релизов' : 'Open releases page';
  String get updateManualDownloadHint => _isRu
      ? 'Не удалось надёжно определить тип установки Windows. Выберите подходящий файл на странице релизов; приложение не будет заменено автоматически.'
      : 'The Windows installation type could not be determined reliably. Choose the matching file on the releases page; this app will not be replaced automatically.';
  String get updatePortableHint => _isRu
      ? 'Будет скачан и проверен ZIP-архив. Затем закройте Словофон и распакуйте архив в новую папку. Не удаляйте папки с пользовательскими данными и скачанными книгами.'
      : 'The ZIP archive will be downloaded and verified. Then close Slovofon and extract it into a new folder. Keep your user-data and downloaded-book folders.';
  String get updateInstallerHint => _isRu
      ? 'После проверки файла откроется установщик. Следуйте его инструкциям; настройки, прогресс и скачанные книги сохраняются.'
      : 'After the file is verified, the installer will open. Follow its instructions; settings, progress and downloaded books are preserved.';
  String get updatePortableReady => _isRu
      ? 'Архив проверен; открыта папка загрузки. Закройте Словофон и распакуйте ZIP в новую папку.'
      : 'The archive is verified and its folder is open. Close Slovofon and extract the ZIP into a new folder.';
  String get updateSkipFailed => _isRu
      ? 'Не удалось сохранить пропуск версии. Повторите попытку или нажмите «Позже».'
      : 'Could not save the skipped version. Try again or choose Later.';
  String get updateReleasePageFailed => _isRu
      ? 'Не удалось открыть страницу релизов. Повторите попытку.'
      : 'Could not open the releases page. Try again.';
  String get noUpdatesAvailable =>
      _isRu ? 'Обновлений нет' : 'No updates available';
  String get updateCheckFailed =>
      _isRu ? 'Не удалось проверить обновления' : 'Update check failed';
  String get updateCheckFailedMessage => _isRu
      ? 'Проверьте соединение и нажмите «Повторить».'
      : 'Check your connection and tap Retry.';
  String get updateDownloading =>
      _isRu ? 'Скачиваю обновление...' : 'Downloading update...';
  String get updatePreparingTitle =>
      _isRu ? 'Проверка и запуск обновления' : 'Verifying and starting update';
  String updateDownloadProgress(String downloaded, String total, String speed) {
    return _isRu
        ? '$downloaded из $total · $speed/с'
        : '$downloaded of $total · $speed/s';
  }

  String get updateDownloadFailed =>
      _isRu ? 'Не удалось скачать обновление' : 'Update download failed';
  String get updateDownloadFailedMessage => _isRu
      ? 'Проверьте соединение и нажмите «Повторить».'
      : 'Check your connection and tap Retry.';
  String get updateInstallerStarted => _isRu
      ? 'Установщик обновления открыт'
      : 'The update installer has been opened';
  String get updateInstallFailed =>
      _isRu ? 'Не удалось запустить обновление' : 'Could not start the update';
  String get updateInstallFailedMessage => _isRu
      ? 'Не удалось подготовить или открыть файл обновления. Проверьте разрешения системы и нажмите «Повторить». Приложение не будет закрыто автоматически.'
      : 'The update file could not be prepared or opened. Check system permissions and choose Retry. The app will not close automatically.';
  String get updateInstallPermissionRequired => _isRu
      ? 'Разрешите установку APK для Словофона и нажмите «Обновить» ещё раз.'
      : 'Allow APK installs for Slovofon, then tap Update again.';
  String get updateUnsupportedPlatform => _isRu
      ? 'Для этой платформы нет подходящего файла обновления'
      : 'No suitable update file is available for this platform';
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

  String get sourceStreamingDisabled => _isRu
      ? 'Воспроизведение из этого источника отключено в настройках'
      : 'Streaming from this source is disabled in settings';
  String get downloadMetadataUnavailableTitle =>
      _isRu ? 'Данные книги недоступны' : 'Book details unavailable';
  String get downloadMetadataUnavailable => _isRu
      ? 'Откройте книгу через поиск, чтобы восстановить её данные. Скачанные файлы сохранены.'
      : 'Open the book from search to restore its details. Downloaded files are preserved.';
  String get sourceDownloadDisabled => _isRu
      ? 'Загрузка из этого источника отключена в настройках'
      : 'Downloads from this source are disabled in settings';
  String get savedBookNotFound =>
      _isRu ? 'Книга не найдена в библиотеке' : 'Book not found in the library';
  String get savedBookMediaUnavailable => _isRu
      ? 'Нет сохранённых аудиоглав. Найдите книгу в источнике.'
      : 'No saved audio chapters. Find the book in a source.';
  String get savedBookPlaybackError =>
      _isRu ? 'Не удалось начать воспроизведение' : 'Could not start playback';
  String get cacheClearFailed => _isRu
      ? 'Не удалось очистить кэш. Попробуйте ещё раз.'
      : 'Could not clear the cache. Please try again.';
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
  String get addToLater => _isRu ? 'Отложить' : 'Listen later';
  String get removeFromLater =>
      _isRu ? 'Убрать из «Позже»' : 'Remove from listen later';
  String get bookActions => _isRu ? 'Действия с книгой' : 'Book actions';
  String get deleteDownloaded =>
      _isRu ? 'Удалить скачанное' : 'Delete downloaded';
  String get downloadQueuedMessage =>
      _isRu ? 'Книга добавлена в загрузки' : 'Book added to downloads';
  String get mockDataNotice => _isRu
      ? 'Каркас работает на локальных mock data. Источники будут подключены отдельным слоем.'
      : 'This scaffold uses local mock data. Sources will be wired through a separate layer.';
}
