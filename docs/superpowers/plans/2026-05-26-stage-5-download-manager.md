# Stage 5 DownloadManager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Stage 5 by adding a real DownloadManager for queued chapter/book downloads, pause/resume/cancel/delete, persisted task state, atomic offline files, metadata, and offline playback sources.

**Architecture:** `DownloadManager` lives under `lib/services/downloads/` and is the single source of truth for download state. UI calls the manager through Riverpod providers; the manager writes `.part` files into app-specific storage, atomically renames completed files, persists task state in Drift, updates chapter download fields, and exposes completed local files back to playback as `AudioMediaSource.file`.

**Tech Stack:** Flutter/Dart, Riverpod, Drift/SQLite, `dart:io`, `path`, `path_provider`, existing `PlaybackController` and mock audio data.

---

### Task 1: RED Tests For Download Core

**Files:**
- Create: `test/services/downloads/download_manager_test.dart`
- Create: `test/services/downloads/download_persistence_test.dart`

- [ ] Write failing tests proving that a chapter download writes a `.part` file, atomically produces the final chapter file, persists `completed`, and returns a file media source for offline playback.
- [ ] Write failing tests proving pause keeps the `.part` file, resume continues from existing bytes, cancel removes the `.part` file, and delete removes only downloaded audio/metadata without touching playback progress.
- [ ] Write failing tests proving app restart recovery converts `running` tasks to `paused`/resumable and keeps `completed` tasks completed.
- [ ] Run `flutter test test/services/downloads` and verify failures are for missing Stage 5 implementation.

### Task 2: Download Models, Storage, Client, Persistence

**Files:**
- Create: `lib/services/downloads/download_models.dart`
- Create: `lib/services/downloads/download_storage.dart`
- Create: `lib/services/downloads/download_client.dart`
- Create: `lib/services/downloads/download_persistence.dart`

- [ ] Implement task snapshots, requests, cancellation token, download client response, safe path sanitization, metadata JSON, atomic file finalization, and Drift persistence mapping.
- [ ] Run `flutter test test/services/downloads` and continue only when Task 1 tests move from missing-symbol failures to behavior failures.

### Task 3: DownloadManager

**Files:**
- Create: `lib/services/downloads/download_manager.dart`
- Create: `lib/services/downloads/download_manager_provider.dart`

- [ ] Implement queue scheduling with bounded concurrency, chapter/book enqueue, missing chapter enqueue, pause/resume/cancel/retry/delete, progress updates, speed calculation, and offline media overlay for `AudioPlaybackBook`.
- [ ] Run `flutter test test/services/downloads` and make all Stage 5 service tests pass.

### Task 4: UI Wiring

**Files:**
- Modify: `lib/features/downloads/downloads_screen.dart`
- Modify: `lib/features/home/home_screen.dart`
- Modify: `lib/features/search/search_screen.dart`
- Modify: `lib/features/book_details/book_details_screen.dart`
- Modify: `lib/features/player/full_player_screen.dart`
- Modify: `lib/ui/components/book_card.dart`
- Modify: `lib/ui/components/download_status_chip.dart`
- Modify: `lib/app/bootstrap.dart`
- Modify: `lib/services/audio/playback_controller_provider.dart`

- [ ] Replace mock-only download actions with real manager actions.
- [ ] Show active, queued, completed, failed, and paused tasks from manager state.
- [ ] Ensure completed downloads are visible as downloaded and can feed local file media source into playback.
- [ ] Run widget tests and update assertions from mock-only queue to real Stage 5 controls.

### Task 5: Docs And Verification

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/SLOVOFON_TECHNICAL_SPEC_RU.md`
- Modify: `THIRD_PARTY_NOTICES.md` only if dependencies change.

- [ ] Document Stage 5 behavior and storage.
- [ ] Run `./tools/slovofon.ps1 format`.
- [ ] Run `./tools/slovofon.ps1 analyze`.
- [ ] Run `./tools/slovofon.ps1 test`.
- [ ] Build Android debug and verify the app still launches.
