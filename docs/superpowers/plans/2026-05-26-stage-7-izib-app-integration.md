# Stage 7 Izib App Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the current app usable end-to-end with the real Izib source: search, book details, chapters, playback, and download actions.

**Architecture:** UI must not call source connectors directly. A `SourceCatalogService` wraps `SourceRegistry` and maps source details into UI/playback models. Screens use Riverpod providers/controllers and existing reusable cards/player/download components.

**Tech Stack:** Flutter, Riverpod, GoRouter, existing `SourceConnector`, `PlaybackController`, `DownloadManager`, and widget/unit tests.

---

### Task 1: Source Catalog Service

**Files:**
- Create: `test/services/sources/source_catalog_service_test.dart`
- Create: `lib/services/sources/source_catalog_service.dart`
- Create: `lib/services/sources/source_catalog_provider.dart`

- [x] **Step 1: Write failing tests**

Cover searching through a registry, loading source book details, preserving Izib metadata, and building an `AudioPlaybackBook` whose chapters contain validated URL media sources.

- [x] **Step 2: Run tests and confirm RED**

Run `flutter test test/services/sources/source_catalog_service_test.dart`.

- [x] **Step 3: Implement source catalog service and providers**

Add `SourceCatalogService`, `SourceBookSnapshot`, default `SourceRegistry([IzibSourceConnector()])`, and mapping from `BookSearchResult`/details/chapters to `AudioBook` and `AudioPlaybackBook`.

- [x] **Step 4: Verify GREEN**

Run `flutter test test/services/sources/source_catalog_service_test.dart`.

### Task 2: Search And Details UI

**Files:**
- Create: `test/ui/stage7_izib_app_integration_test.dart`
- Create: `lib/features/source_books/source_book_details_screen.dart`
- Modify: `lib/features/search/search_screen.dart`
- Modify: `lib/app/router.dart`
- Modify: `lib/ui/components/book_card.dart`
- Modify: `lib/ui/components/book_cover.dart`

- [x] **Step 1: Write failing widget tests**

Cover typing an Izib query, showing source results instead of mock-only results, opening source book details, showing metadata/chapters, pressing play, and seeing the full player playlist.

- [x] **Step 2: Run widget tests and confirm RED**

Run `flutter test test/ui/stage7_izib_app_integration_test.dart`.

- [x] **Step 3: Implement UI integration**

Use `SourceCatalogService` from providers, add `/source-book/:sourceId/:sourceBookId`, display network covers when available, and load `PlaybackController` from source details on play/chapter tap.

- [x] **Step 4: Verify GREEN**

Run `flutter test test/ui/stage7_izib_app_integration_test.dart`.

### Task 3: Player And Download Real-Source Polish

**Files:**
- Modify: `lib/features/player/full_player_screen.dart`
- Modify: `lib/features/downloads/downloads_screen.dart`
- Modify: `lib/domain/models/audio_book.dart`
- Modify: `lib/services/audio/audio_state.dart`
- Modify: `lib/app/localization/app_strings.dart`

- [x] **Step 1: Write failing assertions**

Extend Stage 7 widget tests so the player information page and download queue do not fall back to unrelated mock book data for Izib books.

- [x] **Step 2: Run tests and confirm RED**

Run `flutter test test/ui/stage7_izib_app_integration_test.dart`.

- [x] **Step 3: Implement real-source metadata fallbacks**

Add optional cover/source ids to playback/UI models, make player info use active playback metadata, and make downloads show source task metadata without assuming `MockBook`.

- [x] **Step 4: Verify GREEN**

Run `flutter test test/ui/stage7_izib_app_integration_test.dart`.

### Task 4: Verification And Docs

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `docs/SOURCES.md`
- Modify: `docs/SLOVOFON_TECHNICAL_SPEC_RU.md`
- Modify: `docs/superpowers/plans/2026-05-26-stage-7-izib-app-integration.md`

- [x] **Step 1: Update docs**

Record that Izib is connected to the app UI path, not only the connector layer.

- [x] **Step 2: Run full verification**

Run:

```powershell
./tools/slovofon.ps1 format
./tools/slovofon.ps1 analyze
./tools/slovofon.ps1 test
flutter build apk --debug
```

- [x] **Step 3: Report status**

Report what works in emulator, what remains outside this stage, and whether a commit/push is still needed.
