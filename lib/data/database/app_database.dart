import 'package:drift/drift.dart';

part 'app_database.g.dart';

@DataClassName('BookRow')
class Books extends Table {
  TextColumn get id => text()();
  TextColumn get normalizedTitle => text()();
  TextColumn get displayTitle => text()();
  TextColumn get authorsJson => text()();
  TextColumn get seriesTitle => text().nullable()();
  RealColumn get seriesNumber => real().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get bestCoverUrl => text().nullable()();
  TextColumn get bestLocalCoverPath => text().nullable()();
  TextColumn get bestDescription => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('BookVersionRow')
class BookVersions extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get sourceId => text()();
  TextColumn get sourceBookId => text()();
  TextColumn get sourceUrl => text().nullable()();
  TextColumn get title => text()();
  TextColumn get normalizedTitle => text()();
  TextColumn get authorsJson => text()();
  TextColumn get narratorsJson => text()();
  TextColumn get translatorsJson => text().withDefault(const Constant('[]'))();
  TextColumn get seriesTitle => text().nullable()();
  RealColumn get seriesNumber => real().nullable()();
  TextColumn get genresJson => text().withDefault(const Constant('[]'))();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  TextColumn get description => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get localCoverPath => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get durationText => text().nullable()();
  IntColumn get publishedYear => integer().nullable()();
  IntColumn get audioYear => integer().nullable()();
  RealColumn get ratingValue => real().nullable()();
  IntColumn get ratingCount => integer().nullable()();
  TextColumn get accessType => text()();
  TextColumn get playbackAccess => text()();
  BoolColumn get isFull => boolean().withDefault(const Constant(false))();
  BoolColumn get isFragment => boolean().withDefault(const Constant(false))();
  BoolColumn get isPaid => boolean().withDefault(const Constant(false))();
  BoolColumn get isSubscription =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isAccessibleForFree =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get canStream => boolean().withDefault(const Constant(false))();
  BoolColumn get canDownload => boolean().withDefault(const Constant(false))();
  TextColumn get rawSourceDataJson => text().nullable()();
  DateTimeColumn get lastResolvedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ChapterRow')
class Chapters extends Table {
  TextColumn get id => text()();
  TextColumn get bookVersionId => text()();
  TextColumn get sourceId => text()();
  TextColumn get sourceBookId => text().nullable()();
  TextColumn get sourceChapterId => text().nullable()();
  IntColumn get index => integer()();
  TextColumn get title => text()();
  TextColumn get normalizedTitle => text()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get streamRef => text().nullable()();
  TextColumn get cachedStreamUrl => text().nullable()();
  DateTimeColumn get cachedStreamUrlUpdatedAt => dateTime().nullable()();
  DateTimeColumn get cachedStreamUrlExpiresAt => dateTime().nullable()();
  TextColumn get audioFormat => text().nullable()();
  TextColumn get mimeType => text().nullable()();
  TextColumn get rawSourceDataJson => text().nullable()();
  TextColumn get localPath => text().nullable()();
  IntColumn get fileSizeBytes => integer().nullable()();
  TextColumn get downloadStatus => text().withDefault(const Constant('none'))();
  RealColumn get downloadProgress => real().withDefault(const Constant(0))();
  IntColumn get playbackPositionMs =>
      integer().withDefault(const Constant(0))();
  BoolColumn get isFinished => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AudioTrackRow')
class AudioTracks extends Table {
  TextColumn get id => text()();
  TextColumn get chapterId => text()();
  TextColumn get sourceId => text()();
  IntColumn get index => integer()();
  TextColumn get title => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get mediaRef => text()();
  TextColumn get directUrl => text().nullable()();
  TextColumn get headersJson => text().nullable()();
  TextColumn get format => text().nullable()();
  TextColumn get mimeType => text().nullable()();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  TextColumn get rawSourceDataJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SourceRow')
class Sources extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get host => text()();
  TextColumn get color => text().nullable()();
  TextColumn get capabilitiesJson => text().withDefault(const Constant('{}'))();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SourceHealthRow')
class SourceHealthRows extends Table {
  @override
  String get tableName => 'source_health';

  TextColumn get sourceId => text()();
  TextColumn get status => text().withDefault(const Constant('unknown'))();
  IntColumn get latencyMs => integer().nullable()();
  TextColumn get errorCode => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get checkedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {sourceId};
}

@DataClassName('PlaybackSessionRow')
class PlaybackSessions extends Table {
  TextColumn get id => text()();
  TextColumn get activeBookId => text().nullable()();
  TextColumn get activeBookVersionId => text().nullable()();
  TextColumn get activeSourceId => text().nullable()();
  TextColumn get activeChapterId => text().nullable()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  RealColumn get speed => real().withDefault(const Constant(1))();
  RealColumn get volume => real().withDefault(const Constant(1))();
  BoolColumn get isPlaying => boolean().withDefault(const Constant(false))();
  IntColumn get playerPageIndex => integer().withDefault(const Constant(0))();
  IntColumn get sleepTimerRemainingMs => integer().nullable()();
  TextColumn get sleepTimerMode => text().withDefault(const Constant('off'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PlaybackProgressRow')
class PlaybackProgressEntries extends Table {
  @override
  String get tableName => 'playback_progress';

  TextColumn get bookId => text()();
  TextColumn get bookVersionId => text()();
  TextColumn get currentChapterId => text().nullable()();
  IntColumn get currentPositionMs => integer().withDefault(const Constant(0))();
  IntColumn get maxReachedGlobalPositionMs =>
      integer().withDefault(const Constant(0))();
  IntColumn get totalDurationMs => integer().withDefault(const Constant(0))();
  IntColumn get listenedDurationMs =>
      integer().withDefault(const Constant(0))();
  RealColumn get percent => real().withDefault(const Constant(0))();
  BoolColumn get isFinished => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastPlayedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {bookId, bookVersionId};
}

@DataClassName('DownloadTaskRow')
class DownloadTasks extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get bookVersionId => text()();
  TextColumn get chapterId => text().nullable()();
  TextColumn get sourceId => text()();
  TextColumn get type => text()();
  TextColumn get status => text()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  RealColumn get progress => real().withDefault(const Constant(0))();
  IntColumn get downloadedBytes => integer().withDefault(const Constant(0))();
  IntColumn get totalBytes => integer().nullable()();
  IntColumn get speedBytesPerSecond =>
      integer().withDefault(const Constant(0))();
  TextColumn get errorCode => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('FavoriteRow')
class Favorites extends Table {
  TextColumn get bookId => text()();
  TextColumn get bookVersionId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {bookId};
}

@DataClassName('BookmarkRow')
class Bookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get bookVersionId => text()();
  TextColumn get chapterId => text()();
  IntColumn get positionMs => integer()();
  TextColumn get title => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SearchHistoryRow')
class SearchHistoryRows extends Table {
  @override
  String get tableName => 'search_history';

  TextColumn get id => text()();
  TextColumn get query => text()();
  TextColumn get searchKind => text()();
  TextColumn get filtersJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastUsedAt => dateTime()();
  IntColumn get usageCount => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AppSettingsRow')
class AppSettingsRows extends Table {
  @override
  String get tableName => 'settings';

  TextColumn get id => text()();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  TextColumn get languageCode => text().withDefault(const Constant('ru'))();
  TextColumn get accentColor => text().withDefault(const Constant('default'))();
  RealColumn get textScale => real().withDefault(const Constant(1))();
  BoolColumn get compactCards => boolean().withDefault(const Constant(false))();
  BoolColumn get showSourceOnCards =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showPercentOnCovers =>
      boolean().withDefault(const Constant(true))();
  TextColumn get animationsMode => text().withDefault(const Constant('full'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ProxyProfileRow')
class ProxyProfiles extends Table {
  @override
  String get tableName => 'proxy_profiles';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get host => text().nullable()();
  IntColumn get port => integer().nullable()();
  TextColumn get username => text().nullable()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SourceSettingsRow')
class SourceSettingsRows extends Table {
  @override
  String get tableName => 'source_settings';

  TextColumn get sourceId => text()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  BoolColumn get useInGlobalSearch =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get allowStreaming =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get allowDownload => boolean().withDefault(const Constant(true))();
  TextColumn get proxyMode => text().withDefault(const Constant('auto'))();
  IntColumn get timeoutMs => integer().nullable()();
  IntColumn get resultLimit => integer().nullable()();
  TextColumn get extraJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {sourceId};
}

@DriftDatabase(
  tables: [
    Books,
    BookVersions,
    Chapters,
    AudioTracks,
    Sources,
    SourceHealthRows,
    PlaybackSessions,
    PlaybackProgressEntries,
    DownloadTasks,
    Favorites,
    Bookmarks,
    SearchHistoryRows,
    AppSettingsRows,
    ProxyProfiles,
    SourceSettingsRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) => migrator.createAll(),
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
