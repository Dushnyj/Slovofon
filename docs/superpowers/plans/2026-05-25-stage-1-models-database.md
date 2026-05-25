# Stage 1 Models And Database Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Slovofon Stage 1 domain models and the first Drift database schema.

**Architecture:** Keep UI mock models untouched and add real domain models under `lib/domain/models/`. Add Drift under `lib/data/database/` with schema version 1, explicit table names from the technical spec, and a Flutter database connection helper. Store list/json fields as text in SQLite for now; typed repositories and mappers come in later stages.

**Tech Stack:** Flutter, Dart, Drift, SQLite via `sqlite3_flutter_libs`, `path_provider`, `build_runner`.

---

### Task 1: Stage 1 RED Tests

**Files:**
- Create: `test/domain/stage1_models_test.dart`
- Create: `test/data/app_database_test.dart`

- [ ] **Step 1: Write model tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/models.dart';

void main() {
  test('Book and BookVersion separate logical book from source version', () {
    final now = DateTime.utc(2026, 5, 25);

    final book = Book(
      id: 'book-1',
      normalizedTitle: 'master and margarita',
      displayTitle: 'Мастер и Маргарита',
      authors: const ['Михаил Булгаков'],
      createdAt: now,
      updatedAt: now,
    );

    final version = BookVersion(
      id: 'version-1',
      bookId: book.id,
      sourceId: 'akniga',
      sourceBookId: '123',
      title: 'Мастер и Маргарита',
      normalizedTitle: book.normalizedTitle,
      authors: book.authors,
      narrators: const ['Чтец 1', 'Чтец 2'],
      accessType: AccessType.free,
      playbackAccess: PlaybackAccess.streamAndDownload,
      isFull: true,
      isAccessibleForFree: true,
      canStream: true,
      canDownload: true,
      createdAt: now,
      updatedAt: now,
    );

    expect(version.bookId, book.id);
    expect(version.sourceId, 'akniga');
    expect(version.narrators, hasLength(2));
    expect(version.isFull, isTrue);
  });

  test('PlaybackProgress clamps percent to safe display range', () {
    final progress = PlaybackProgress(
      bookId: 'book-1',
      bookVersionId: 'version-1',
      currentPositionMs: 1500,
      maxReachedGlobalPositionMs: 1500,
      totalDurationMs: 1000,
      listenedDurationMs: 1500,
      percent: 150,
      isFinished: false,
      lastPlayedAt: DateTime.utc(2026, 5, 25),
    );

    expect(progress.clampedPercent, 100);
  });

  test('AppSettings exposes Stage 1 appearance defaults', () {
    const settings = AppSettings.defaults();

    expect(settings.themeMode, AppThemeMode.system);
    expect(settings.languageCode, 'ru');
    expect(settings.compactCards, isFalse);
    expect(settings.showSourceOnCards, isTrue);
    expect(settings.animationsMode, AppAnimationsMode.full);
  });
}
```

- [ ] **Step 2: Write database tests**

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('schema starts at version 1', () {
    expect(db.schemaVersion, 1);
  });

  test('stores core Stage 1 records', () async {
    final now = DateTime.utc(2026, 5, 25);

    await db.into(db.books).insert(
          BooksCompanion.insert(
            id: 'book-1',
            normalizedTitle: 'master and margarita',
            displayTitle: 'Мастер и Маргарита',
            authorsJson: '["Михаил Булгаков"]',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db.into(db.bookVersions).insert(
          BookVersionsCompanion.insert(
            id: 'version-1',
            bookId: 'book-1',
            sourceId: 'akniga',
            sourceBookId: '123',
            title: 'Мастер и Маргарита',
            normalizedTitle: 'master and margarita',
            authorsJson: '["Михаил Булгаков"]',
            narratorsJson: '["Чтец"]',
            accessType: 'free',
            playbackAccess: 'streamAndDownload',
            isFull: const Value(true),
            isAccessibleForFree: const Value(true),
            canStream: const Value(true),
            canDownload: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db.into(db.chapters).insert(
          ChaptersCompanion.insert(
            id: 'chapter-1',
            bookVersionId: 'version-1',
            sourceId: 'akniga',
            index: 0,
            title: 'Глава 1',
            normalizedTitle: 'glava 1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db.into(db.audioTracks).insert(
          AudioTracksCompanion.insert(
            id: 'track-1',
            chapterId: 'chapter-1',
            sourceId: 'akniga',
            index: 0,
            mediaRef: 'resolver:track-1',
          ),
        );

    await db.into(db.playbackSessions).insert(
          PlaybackSessionsCompanion.insert(
            id: 'default',
            activeBookId: const Value('book-1'),
            activeBookVersionId: const Value('version-1'),
            activeSourceId: const Value('akniga'),
            activeChapterId: const Value('chapter-1'),
            positionMs: const Value(1200),
            updatedAt: now,
          ),
        );

    await db.into(db.playbackProgressEntries).insert(
          PlaybackProgressEntriesCompanion.insert(
            bookId: 'book-1',
            bookVersionId: 'version-1',
            currentChapterId: const Value('chapter-1'),
            currentPositionMs: const Value(1200),
            totalDurationMs: const Value(5000),
            listenedDurationMs: const Value(1200),
            percent: const Value(24),
            lastPlayedAt: now,
          ),
        );

    await db.into(db.downloadTasks).insert(
          DownloadTasksCompanion.insert(
            id: 'download-1',
            bookId: 'book-1',
            bookVersionId: 'version-1',
            chapterId: const Value('chapter-1'),
            sourceId: 'akniga',
            type: 'chapter',
            status: 'queued',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db.into(db.bookmarks).insert(
          BookmarksCompanion.insert(
            id: 'bookmark-1',
            bookId: 'book-1',
            bookVersionId: 'version-1',
            chapterId: 'chapter-1',
            positionMs: 1200,
            title: 'Важное место',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db.into(db.appSettingsRows).insert(
          AppSettingsRowsCompanion.insert(
            id: 'default',
            themeMode: const Value('system'),
            languageCode: const Value('ru'),
            accentColor: const Value('default'),
            updatedAt: now,
          ),
        );

    expect(await db.select(db.books).get(), hasLength(1));
    expect(await db.select(db.bookVersions).get(), hasLength(1));
    expect(await db.select(db.chapters).get(), hasLength(1));
    expect(await db.select(db.audioTracks).get(), hasLength(1));
    expect(await db.select(db.playbackSessions).get(), hasLength(1));
    expect(await db.select(db.playbackProgressEntries).get(), hasLength(1));
    expect(await db.select(db.downloadTasks).get(), hasLength(1));
    expect(await db.select(db.bookmarks).get(), hasLength(1));
    expect(await db.select(db.appSettingsRows).get(), hasLength(1));
  });
}
```

- [ ] **Step 3: Run tests and verify RED**

Run:

```powershell
flutter test test/domain/stage1_models_test.dart test/data/app_database_test.dart
```

Expected: FAIL because `models.dart` and `app_database.dart` do not exist yet.

### Task 2: Dependencies

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`

- [ ] **Step 1: Add runtime dependencies**

Run:

```powershell
flutter pub add drift sqlite3_flutter_libs path path_provider
```

- [ ] **Step 2: Add code generation dependencies**

Run:

```powershell
flutter pub add --dev build_runner drift_dev
```

### Task 3: Domain Models

**Files:**
- Create: `lib/domain/models/book.dart`
- Create: `lib/domain/models/book_version.dart`
- Create: `lib/domain/models/chapter.dart`
- Create: `lib/domain/models/audio_track.dart`
- Create: `lib/domain/models/playback_session.dart`
- Create: `lib/domain/models/playback_progress.dart`
- Create: `lib/domain/models/download_task.dart`
- Create: `lib/domain/models/bookmark.dart`
- Create: `lib/domain/models/app_settings.dart`
- Create: `lib/domain/models/models.dart`

- [ ] **Step 1: Add immutable model classes**

Create the Stage 1 model files with const constructors, typed enums, and fields from sections 6.2-6.9 and 22.1 of `docs/SLOVOFON_TECHNICAL_SPEC_RU.md`.

- [ ] **Step 2: Run model tests**

Run:

```powershell
flutter test test/domain/stage1_models_test.dart
```

Expected: PASS.

### Task 4: Drift Schema

**Files:**
- Create: `lib/data/database/app_database.dart`
- Create: `lib/data/database/database_connection.dart`
- Generate: `lib/data/database/app_database.g.dart`

- [ ] **Step 1: Add Drift tables**

Add schema version 1 with these tables: `books`, `book_versions`, `chapters`, `audio_tracks`, `sources`, `source_health`, `playback_sessions`, `playback_progress`, `download_tasks`, `favorites`, `bookmarks`, `search_history`, `settings`, `proxy_profiles`, `source_settings`.

- [ ] **Step 2: Generate code**

Run:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3: Run database tests**

Run:

```powershell
flutter test test/data/app_database_test.dart
```

Expected: PASS.

### Task 5: Docs And Verification

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Update changelog**

Add an Unreleased entry for Stage 1 models and Drift schema.

- [ ] **Step 2: Run project checks**

Run:

```powershell
./tools/slovofon.ps1 format
./tools/slovofon.ps1 analyze
./tools/slovofon.ps1 test
./tools/slovofon.ps1 build -Target android -Configuration debug
./tools/slovofon.ps1 build -Target windows -Configuration debug
```

Expected: all commands pass.
