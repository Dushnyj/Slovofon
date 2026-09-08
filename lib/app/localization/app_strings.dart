import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'app_catalogs.g.dart';

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

  String get _language => appMessageCatalogs.containsKey(locale.languageCode)
      ? locale.languageCode
      : 'en';

  /// Only unsupported locales fall back to English. Missing keys in a supported
  /// language are programming errors, never silently untranslated UI.
  String _text(String key, [Map<String, Object> arguments = const {}]) {
    final template = appMessageCatalogs[_language]![key];
    if (template == null) {
      throw StateError('Missing localization: $_language.$key');
    }
    return template.replaceAllMapped(RegExp(r'\{([A-Za-z][A-Za-z0-9]*)\}'), (
      match,
    ) {
      final name = match[1]!;
      final value = arguments[name];
      if (value == null) throw ArgumentError('Missing $name for $key');
      return value.toString();
    });
  }

  // Integer cardinal counts. RU/BE/UK share these CLDR categories; English and
  // Kazakh use one only for 1. Kazakh counted nouns remain singular after digits.
  String _cardinal(int count) {
    final n = count.abs();
    if (_language == 'en' || _language == 'kk') return n == 1 ? 'one' : 'many';
    if (n % 100 >= 11 && n % 100 <= 14) return 'many';
    return switch (n % 10) {
      1 => 'one',
      2 || 3 || 4 => 'few',
      _ => 'many',
    };
  }

  String _counted(String key, int count) =>
      _text('$key.${_cardinal(count)}', {'count': count});

  String get appTitle => _text('appTitle');
  String get desktopLibraryLabel => _text('desktopLibraryLabel');
  String get bookProgress => _text('bookProgress');
  String get playbackSource => _text('playbackSource');
  String get settingsPersonalization => _text('settingsPersonalization');
  String get settingsContent => _text('settingsContent');
  String get settingsApplication => _text('settingsApplication');
  String get settingsSections => _text('settingsSections');
  String get bookFragment => _text('bookFragment');
  String get home => _text('home');
  String get search => _text('search');
  String get library => _text('library');
  String get downloads => _text('downloads');
  String get downloadsQueueSubtitle => _text('downloadsQueueSubtitle');
  String get activeDownloads => _text('activeDownloads');
  String get queuedDownloads => _text('queuedDownloads');
  String get completedDownloads => _text('completedDownloads');
  String get failedDownloads => _text('failedDownloads');
  String get downloading => _text('downloading');
  String get queued => _text('queued');
  String get paused => _text('paused');
  String get failed => _text('failed');
  String get unknownSize => _text('unknownSize');
  String downloadChaptersProgress(int completed, int total) => _text(
    'downloadChaptersProgress.${_cardinal(total)}',
    {'completed': completed, 'total': total},
  );

  String get calculatingTotalSize => _text('calculatingTotalSize');
  String booksCount(int count) => _counted('booksCount', count);
  String get settings => _text('settings');
  String navigationTabLabel(String label, int index, int total) {
    return _text('navigationTabLabel', {
      'label': label,
      'index': index,
      'total': total,
    });
  }

  String get themePreview => _text('themePreview');
  String get previousTabs => _text('previousTabs');
  String get nextTabs => _text('nextTabs');
  String get continueListening => _text('continueListening');
  String get searchHistoryEmptyMessage => _text('searchHistoryEmptyMessage');
  String get homeLibraryShortcutMessage => _text('homeLibraryShortcutMessage');
  String get homeDownloadsShortcutMessage =>
      _text('homeDownloadsShortcutMessage');
  String get startedBooks => _text('startedBooks');
  String get offlineDownloads => _text('offlineDownloads');
  String get recommended => _text('recommended');
  String get realSourceHomeTitle => _text('realSourceHomeTitle');
  String get realSourceHomeMessage => _text('realSourceHomeMessage');
  String get openSearch => _text('openSearch');
  String get searchHint => _text('searchHint');
  String get searchByTitle => _text('searchByTitle');
  String get searchByAuthor => _text('searchByAuthor');
  String get searchByNarrator => _text('searchByNarrator');
  String get searchBySeries => _text('searchBySeries');
  String get searchByGenre => _text('searchByGenre');
  String get searchScope => _text('searchScope');
  String get sourceFilter => _text('sourceFilter');
  String get allSources => _text('allSources');
  String get apply => _text('apply');
  String get recentSearches => _text('recentSearches');
  String get deleteSearchHistoryEntry => _text('deleteSearchHistoryEntry');
  String get searchReadyTitle => _text('searchReadyTitle');
  String get searchReadyMessage => _text('searchReadyMessage');
  String sourceDisplayName(String sourceId) {
    return switch (sourceId) {
      'izib' => _text('sourceDisplayName.izib'),
      'akniga' => _text('sourceDisplayName.akniga'),
      'yakniga' => _text('sourceDisplayName.yakniga'),
      'knigavuhe' => _text('sourceDisplayName.knigavuhe'),
      'knigoblud' => _text('sourceDisplayName.knigoblud'),
      'baza_knig' => _text('sourceDisplayName.bazaKnig'),
      _ => sourceId,
    };
  }

  String get searchShortQueryTitle => _text('searchShortQueryTitle');
  String get searchShortQueryMessage => _text('searchShortQueryMessage');
  String get searchingSources => _text('searchingSources');
  String get sourceSearchError => _text('sourceSearchError');
  String get noInternetTitle => _text('noInternetTitle');
  String get noInternetMessage => _text('noInternetMessage');
  String sourceUnavailableTitle(String sourceName) {
    return _text('sourceUnavailableTitle', {'sourceName': sourceName});
  }

  String get sourceUnavailableMessage => _text('sourceUnavailableMessage');
  String get bookDetailsLoadFailedTitle => _text('bookDetailsLoadFailedTitle');
  String bookDetailsLoadFailedMessage(String sourceName) {
    return _text('bookDetailsLoadFailedMessage', {'sourceName': sourceName});
  }

  String bookNotFoundMessage(String sourceName) {
    return _text('bookNotFoundMessage', {'sourceName': sourceName});
  }

  String get noSearchResults => _text('noSearchResults');
  String get noSearchResultsMessage => _text('noSearchResultsMessage');
  String get filteredNoSearchResults => _text('filteredNoSearchResults');
  String sourceResultsCount(int count) => _counted('sourceResultsCount', count);

  String get searchResults => _text('searchResults');
  String partialSearchSources(String names) =>
      _text('partialSearchSources', {'names': names});
  String get partialSearchRetry => _text('partialSearchRetry');

  String get izibSearchSubtitle => _text('izibSearchSubtitle');
  String partialSourceFailures(int count) =>
      _counted('partialSourceFailures', count);

  String get emptyLibrary => _text('emptyLibrary');
  String get librarySourcesMessage => _text('librarySourcesMessage');
  String get emptyListeningShelf => _text('emptyListeningShelf');
  String get emptyListeningShelfMessage => _text('emptyListeningShelfMessage');
  String get emptyFavoritesShelf => _text('emptyFavoritesShelf');
  String get emptyFavoritesShelfMessage => _text('emptyFavoritesShelfMessage');
  String get emptyLaterShelf => _text('emptyLaterShelf');
  String get emptyLaterShelfMessage => _text('emptyLaterShelfMessage');
  String get emptyDownloadedShelf => _text('emptyDownloadedShelf');
  String get emptyDownloadedShelfMessage =>
      _text('emptyDownloadedShelfMessage');
  String get emptyFinishedShelf => _text('emptyFinishedShelf');
  String get emptyFinishedShelfMessage => _text('emptyFinishedShelfMessage');
  String get emptyBookmarksShelf => _text('emptyBookmarksShelf');
  String get emptyBookmarksShelfMessage => _text('emptyBookmarksShelfMessage');
  String get emptyHistoryShelf => _text('emptyHistoryShelf');
  String get emptyHistoryShelfMessage => _text('emptyHistoryShelfMessage');
  String get libraryLoadError => _text('libraryLoadError');
  String get libraryActionError => _text('libraryActionError');
  String get bookmarkUnavailable => _text('bookmarkUnavailable');
  String get emptyDownloads => _text('emptyDownloads');
  String get emptyDownloadsMessage => _text('emptyDownloadsMessage');
  String get appearance => _text('appearance');
  String get sources => _text('sources');
  String selectedSourcesCount(int count) =>
      _counted('selectedSourcesCount', count);

  String get selectAtLeastOneSource => _text('selectAtLeastOneSource');
  String get selectAtLeastOneSearchKind => _text('selectAtLeastOneSearchKind');
  String get sourceSearchEnabled => _text('sourceSearchEnabled');
  String get sourceSearchDisabled => _text('sourceSearchDisabled');

  String get player => _text('player');
  String get proxy => _text('proxy');
  String get openThemePreview => _text('openThemePreview');
  String get previewButtons => _text('previewButtons');
  String get previewChips => _text('previewChips');
  String get previewCards => _text('previewCards');
  String get previewInputs => _text('previewInputs');
  String get previewStates => _text('previewStates');
  String get snackbarPreview => _text('snackbarPreview');
  String get success => _text('success');
  String get warning => _text('warning');
  String get info => _text('info');
  String get free => _text('free');
  String get paid => _text('paid');
  String get subscription => _text('subscription');
  String get unknown => _text('unknown');
  String get enabled => _text('enabled');
  String get disabled => _text('disabled');
  String get play => _text('play');
  String get pause => _text('pause');
  String get resume => _text('resume');
  String get cancel => _text('cancel');
  String get mute => _text('mute');
  String get continuePlayback => _text('continuePlayback');
  String get previousChapter => _text('previousChapter');
  String get rewind15 => _text('rewind15');
  String get forward15 => _text('forward15');
  String get nextChapter => _text('nextChapter');
  String get goToCurrentChapter => _text('goToCurrentChapter');
  String get download => _text('download');
  String get downloadBook => _text('downloadBook');
  String get pauseDownload => _text('pauseDownload');
  String get resumeDownload => _text('resumeDownload');
  String get cancelDownload => _text('cancelDownload');
  String get details => _text('details');
  String get bookDetails => _text('bookDetails');
  String get description => _text('description');
  String get showFullDescription => _text('showFullDescription');
  String get hideDescription => _text('hideDescription');
  String get sourcePage => _text('sourcePage');
  String get sourcePageOpenError => _text('sourcePageOpenError');
  String get genre => _text('genre');
  String get sourceStats => _text('sourceStats');
  String get chapters => _text('chapters');
  String chaptersCount(int count) => _counted('chaptersCount', count);
  String showMoreChapters(int count) => _counted('showMoreChapters', count);

  String get currentAndNextChapters => _text('currentAndNextChapters');
  String chapterPosition(int current, int total) =>
      _text('chapterPosition', {'current': current, 'total': total});
  String get allChapters => _text('allChapters');

  String get collapseChapters => _text('collapseChapters');
  String get otherVersions => _text('otherVersions');
  String get otherNarrations => _text('otherNarrations');
  String get narratorUnknown => _text('narratorUnknown');
  String get series => _text('series');
  String get fullPlayer => _text('fullPlayer');
  String get nowPlaying => _text('nowPlaying');
  String get bookmarks => _text('bookmarks');
  String get addBookmark => _text('addBookmark');
  String get saveBookmark => _text('saveBookmark');
  String get bookmarkAdded => _text('bookmarkAdded');
  String get noBookmarks => _text('noBookmarks');
  String get bookmarkNote => _text('bookmarkNote');
  String get deleteBookmark => _text('deleteBookmark');
  String get deleteBookmarkAction => _text('deleteBookmarkAction');
  String get deleteBookmarkDescription => _text('deleteBookmarkDescription');
  String get bookmarkRemoved => _text('bookmarkRemoved');
  String get information => _text('information');
  String get sleepTimer => _text('sleepTimer');
  String get playbackSpeed => _text('playbackSpeed');
  String get volume => _text('volume');
  String get openFullPlayer => _text('openFullPlayer');
  String get groupedDuplicates => _text('groupedDuplicates');
  String get sort => _text('sort');
  String get sortByRelevance => _text('sortByRelevance');
  String get sortByRating => _text('sortByRating');
  String get sortByYear => _text('sortByYear');
  String get sortByDuration => _text('sortByDuration');
  String get sortByTitle => _text('sortByTitle');
  String get all => _text('all');
  String get filter => _text('filter');
  String get listening => _text('listening');
  String get favorites => _text('favorites');
  String get later => _text('later');
  String get downloaded => _text('downloaded');
  String get finished => _text('finished');
  String get history => _text('history');
  String get language => _text('language');
  String get systemLanguage => _text('systemLanguage');
  String get russianLanguage => 'Русский';
  String get englishLanguage => 'English';
  String get kazakhLanguage => 'Қазақша';
  String get belarusianLanguage => 'Беларуская';
  String get ukrainianLanguage => 'Українська';
  String get diagnostics => _text('diagnostics');
  String get playback => _text('playback');
  String get dataAndDownloads => _text('dataAndDownloads');
  String get cards => _text('cards');
  String get theme => _text('theme');
  String get themeSystem => _text('themeSystem');
  String get themeLight => _text('themeLight');
  String get themeDark => _text('themeDark');
  String get themeAmoled => _text('themeAmoled');
  String get accentColor => _text('accentColor');
  String get accentDefault => _text('accentDefault');
  String get accentGreen => _text('accentGreen');
  String get accentTeal => _text('accentTeal');
  String get accentRed => _text('accentRed');
  String get accentGold => _text('accentGold');
  String get customColor => _text('customColor');
  String get colorPreview => _text('colorPreview');
  String get colorHue => _text('colorHue');
  String get colorSaturation => _text('colorSaturation');
  String get colorBrightness => _text('colorBrightness');
  String get textSize => _text('textSize');
  String get textSizePreview => _text('textSizePreview');
  String get textSizeHint => _text('textSizeHint');
  String get textSizeReset => _text('textSizeReset');
  String get compactCards => _text('compactCards');
  String get showSourceOnCards => _text('showSourceOnCards');
  String get showPercentOnCovers => _text('showPercentOnCovers');
  String get animations => _text('animations');
  String get animationsFull => _text('animationsFull');
  String get animationsReduced => _text('animationsReduced');
  String get animationsOff => _text('animationsOff');
  String get enabledInSearch => _text('enabledInSearch');
  String get openPlayer => _text('openPlayer');
  String get playerSettingsHint => _text('playerSettingsHint');
  String get openDownloads => _text('openDownloads');
  String get downloadsSettingsHint => _text('downloadsSettingsHint');
  String get cacheAndMetadata => _text('cacheAndMetadata');
  String get cacheAndMetadataHint => _text('cacheAndMetadataHint');
  String cacheSize(String value) => _text('cacheSize', {'value': value});
  String cacheBooks(int count) => booksCount(count);
  String get clearCardCache => _text('clearCardCache');
  String get clearCardCacheConfirm => _text('clearCardCacheConfirm');
  String get downloadedBooksPreserved => _text('downloadedBooksPreserved');
  String get clearCacheSafetyHint => _text('clearCacheSafetyHint');
  String cacheCleared(int count, String size) {
    return _text('cacheCleared', {'books': cacheBooks(count), 'size': size});
  }

  String get aboutApp => _text('aboutApp');
  String get aboutAppHint => _text('aboutAppHint');
  String get appVersion => _text('appVersion');
  String get buildNumber => _text('buildNumber');
  String get projectWebsite => _text('projectWebsite');
  String get githubRepository => _text('githubRepository');
  String get telegramSupportBot => _text('telegramSupportBot');
  String get telegramChannel => _text('telegramChannel');
  String get telegramChat => _text('telegramChat');
  String get appUpdates => _text('appUpdates');
  String get appUpdatesHint => _text('appUpdatesHint');
  String get checkingUpdates => _text('checkingUpdates');
  String get updateAvailableTitle => _text('updateAvailableTitle');
  String updateAvailableMessage(String version, String size) {
    return _text('updateAvailableMessage', {'version': version, 'size': size});
  }

  String get updateNow => _text('updateNow');
  String get skipUpdate => _text('skipUpdate');
  String get updateLater => _text('updateLater');
  String get updateReleaseNotes => _text('updateReleaseNotes');
  String get updateNotesLinkFailed => _text('updateNotesLinkFailed');
  String get updateNotesTruncated => _text('updateNotesTruncated');
  String get updateNotesRemoteHint => _text('updateNotesRemoteHint');
  String updateNotesAlert(String kind) => switch (kind) {
    'TIP' => _text('updateNotesAlert.tip'),
    'IMPORTANT' => _text('updateNotesAlert.important'),
    'WARNING' => _text('updateNotesAlert.warning'),
    'CAUTION' => _text('updateNotesAlert.caution'),
    _ => _text('updateNotesAlert.note'),
  };
  String get updateDownloadZip => _text('updateDownloadZip');
  String get updateOpenReleases => _text('updateOpenReleases');
  String get updateManualDownloadHint => _text('updateManualDownloadHint');
  String get updatePortableHint => _text('updatePortableHint');
  String get updateInstallerHint => _text('updateInstallerHint');
  String get updatePortableReady => _text('updatePortableReady');
  String get updateSkipFailed => _text('updateSkipFailed');
  String get updateReleasePageFailed => _text('updateReleasePageFailed');
  String get noUpdatesAvailable => _text('noUpdatesAvailable');
  String get updateCheckFailed => _text('updateCheckFailed');
  String get updateCheckFailedMessage => _text('updateCheckFailedMessage');
  String get updateDownloading => _text('updateDownloading');
  String get updatePreparingTitle => _text('updatePreparingTitle');
  String updateDownloadProgress(String downloaded, String total, String speed) {
    return _text('updateDownloadProgress', {
      'downloaded': downloaded,
      'total': total,
      'speed': speed,
    });
  }

  String get updateDownloadFailed => _text('updateDownloadFailed');
  String get updateDownloadFailedMessage =>
      _text('updateDownloadFailedMessage');
  String get updateInstallerStarted => _text('updateInstallerStarted');
  String get updateInstallFailed => _text('updateInstallFailed');
  String get updateInstallFailedMessage => _text('updateInstallFailedMessage');
  String get updateInstallPermissionRequired =>
      _text('updateInstallPermissionRequired');
  String get updateUnsupportedPlatform => _text('updateUnsupportedPlatform');
  String get updateChannel => _text('updateChannel');
  String get diagnosticsHint => _text('diagnosticsHint');
  String themeModeLabel(String value) {
    return _text('themeModeLabel', {'value': value});
  }

  String textSizeLabel(int percent) {
    return _text('textSizeLabel', {'percent': percent});
  }

  String get sourceStreamingDisabled => _text('sourceStreamingDisabled');
  String get downloadMetadataUnavailableTitle =>
      _text('downloadMetadataUnavailableTitle');
  String get downloadMetadataUnavailable =>
      _text('downloadMetadataUnavailable');
  String get sourceDownloadDisabled => _text('sourceDownloadDisabled');
  String get savedBookNotFound => _text('savedBookNotFound');
  String get savedBookMediaUnavailable => _text('savedBookMediaUnavailable');
  String get savedBookPlaybackError => _text('savedBookPlaybackError');
  String get cacheClearFailed => _text('cacheClearFailed');
  String get retry => _text('retry');
  String get share => _text('share');
  String get shareSlovofonLink => _text('shareSlovofonLink');
  String get shareSourceLink => _text('shareSourceLink');
  String get shareLinkCopied => _text('shareLinkCopied');
  String get addFavorite => _text('addFavorite');
  String get removeFavorite => _text('removeFavorite');
  String get favoriteAdded => _text('favoriteAdded');
  String get favoriteRemoved => _text('favoriteRemoved');
  String get addToLater => _text('addToLater');
  String get removeFromLater => _text('removeFromLater');
  String get bookActions => _text('bookActions');
  String get deleteDownloaded => _text('deleteDownloaded');
  String get downloadQueuedMessage => _text('downloadQueuedMessage');
  String get mockDataNotice => _text('mockDataNotice');

  String chapterNumber(int oneBased, {int minimumDigits = 1}) => _text(
    'chapterNumber',
    {'number': oneBased.toString().padLeft(minimumDigits.clamp(1, 8), '0')},
  );

  String bytesPerSecond(String bytes) =>
      _text('bytesPerSecond', {'bytes': bytes});

  String audioYearLabel(int year) => _text('audioYearLabel', {'year': year});

  String get loading => _text('loading');
  String get disableSleepTimer => _text('disableSleepTimer');
  String get sleepTimerUntilChapterEnd => _text('sleepTimerUntilChapterEnd');
  String minutesLabel(int minutes) =>
      _text('minutesLabel', {'minutes': minutes});
  String peopleAndOthers(String names) =>
      _text('peopleAndOthers', {'names': names});
  String ratingOutOfFive(String rating) =>
      _text('ratingOutOfFive', {'rating': rating});

  /// Compact local units for UI-owned duration labels, not titles from sources.
  String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final hours = duration.inHours;
    if (hours <= 0) return minutesLabel(minutes);
    if (minutes.remainder(60) == 0) {
      return _text('hoursLabel', {'hours': hours});
    }
    return _text('hoursMinutesLabel', {
      'hours': hours,
      'minutes': minutes.remainder(60),
    });
  }

  String formatBytes(int bytes, {int decimals = 1}) {
    final units = [
      'byteUnit',
      'kilobyteUnit',
      'megabyteUnit',
      'gigabyteUnit',
      'terabyteUnit',
    ];
    var value = bytes < 0 ? 0.0 : bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final digits = unit == 0 ? 0 : decimals.clamp(0, 6);
    final number = NumberFormat.decimalPattern(_language)
      ..minimumFractionDigits = digits
      ..maximumFractionDigits = digits;
    return '${number.format(value)} ${_text(units[unit])}';
  }
}
