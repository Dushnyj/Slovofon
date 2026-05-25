# Stage 3 UI Mock Data Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Slovofon Stage 3 by turning the scaffold into a clickable mock-data UI for home, search, book details, library, downloads, settings, mini-player, and full player.

**Architecture:** Keep Stage 3 as a UI-only layer over local mock data. Do not add real source connectors, downloads, AudioService playback, platform media notifications, Windows mini-player windows, persistence mutations, or user-data deletion. Add richer mock models under `lib/data/mock/`, reusable UI under `lib/ui/components/`, feature screens under `lib/features/`, and routes in `lib/app/router.dart`.

**Tech Stack:** Flutter, Material 3, go_router, existing AppTheme/AppIcon/Lucide SVG assets, widget tests.

---

### Task 1: RED Tests

**Files:**
- Create: `test/ui/stage3_mock_ui_test.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Add Stage 3 navigation tests**

Write widget tests that pump `SlovofonApp`, verify home sections (`Продолжить`, `Начатые`, `Скачанные`, `Рекомендации`), tap a book card, and expect the book details route with `Другие версии` and `Главы`.

- [ ] **Step 2: Add player tests**

Write widget tests that tap the mini-player and expect a full player screen with tabs/pages `Сейчас играет`, `Главы`, `Закладки`, and `Информация`.

- [ ] **Step 3: Add library/download/settings tests**

Write widget tests that navigate to library, downloads, and settings, then expect library categories, download state rows, and settings sections.

- [ ] **Step 4: Run RED**

Run:

```powershell
flutter test test/ui/stage3_mock_ui_test.dart
```

Expected: FAIL because Stage 3 routes and rich mock UI do not exist yet.

### Task 2: Rich Mock Data

**Files:**
- Create: `lib/data/mock/stage3_mock_data.dart`
- Modify: `lib/data/mock/mock_books.dart`

- [ ] **Step 1: Add UI mock models**

Create immutable mock UI classes for `MockBook`, `MockBookVersion`, `MockChapter`, `MockDownloadItem`, `MockBookmark`, and `MockLibraryShelf`. Include fields needed by Stage 3 screens: title, authors, narrator, source, access, duration, year, description, progress, chapters, versions, download states, bookmarks, and shelves.

- [ ] **Step 2: Add seeded mock data**

Create at least four books, one active playback book, a download queue with completed/running/queued/failed states, bookmark examples, and library shelves.

- [ ] **Step 3: Keep existing `AudioBook` compatibility**

Expose `mockBooks` as `List<AudioBook>` derived from the richer mock books so existing Stage 0/2 tests keep passing while new Stage 3 UI can consume `stage3MockBooks`.

### Task 3: Routes And Shared Components

**Files:**
- Modify: `lib/app/router.dart`
- Modify: `lib/ui/adaptive/slovofon_shell.dart`
- Modify: `lib/ui/components/book_card.dart`
- Modify: `lib/ui/components/mini_player_bar.dart`
- Create: `lib/ui/components/book_cover.dart`
- Create: `lib/ui/components/section_header.dart`
- Create: `lib/ui/components/download_status_chip.dart`

- [ ] **Step 1: Add routes**

Add `/book/:bookId` and `/player` routes. Book details must receive a mock book by id and fall back to the active mock book if the id is unknown.

- [ ] **Step 2: Make cards navigable**

Update `BookCard` to accept `onTap`, show richer status chips/icons, and keep semantic labels readable.

- [ ] **Step 3: Make shell adaptive**

Use bottom navigation on compact widths and a side navigation rail on desktop/tablet widths. Keep the mini-player visible above navigation and open `/player` on tap.

### Task 4: Feature Screens

**Files:**
- Modify: `lib/features/home/home_screen.dart`
- Modify: `lib/features/search/search_screen.dart`
- Create: `lib/features/book_details/book_details_screen.dart`
- Modify: `lib/features/library/library_screen.dart`
- Modify: `lib/features/downloads/downloads_screen.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Create: `lib/features/player/full_player_screen.dart`
- Modify: `lib/app/localization/app_strings.dart`

- [ ] **Step 1: Implement Home**

Add `Продолжить`, `Начатые`, `Скачанные`, and `Рекомендации` sections using mock data. Continue card must show chapter, percent, and Play action.

- [ ] **Step 2: Implement Search**

Add a search field, filter chips, sorting chips, result count, grouped/ungrouped mock labels, and navigable results.

- [ ] **Step 3: Implement Book Details**

Add a large book detail screen with cover, metadata, access, actions, description, chapters, other versions, and similar/series mock blocks.

- [ ] **Step 4: Implement Library**

Add category tabs/chips for `Все`, `Слушаю`, `Избранное`, `Позже`, `Скачанные`, `Прослушано`, `Закладки`, and `История`, with mock content in each visible state.

- [ ] **Step 5: Implement Downloads**

Add mock download rows for completed, running, queued, paused, and failed states with the Lucide download-state icons.

- [ ] **Step 6: Implement Settings**

Add realistic Stage 3 settings groups for appearance, sources, player, downloads, proxy, language, and diagnostics; keep actions non-destructive and mock-only.

- [ ] **Step 7: Implement Full Player**

Add full player UI with tabs/pages `Сейчас играет`, `Главы`, `Закладки`, and `Информация`, mock controls, speed, sleep timer, chapter list, bookmarks, and source info.

### Task 5: Docs, Verification, Commit, Push

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Update changelog**

Add an `Unreleased` entry for Stage 3 mock-data UI, routes, adaptive shell, book details, downloads, and full player.

- [ ] **Step 2: Verify locally**

Run:

```powershell
./tools/slovofon.ps1 format
./tools/slovofon.ps1 analyze
./tools/slovofon.ps1 test
./tools/slovofon.ps1 check
./tools/slovofon.ps1 build -Target android -Configuration debug
./tools/slovofon.ps1 build -Target windows -Configuration debug
git diff --check
```

Expected: all commands pass.

- [ ] **Step 3: Commit and push**

Commit:

```powershell
git add -A
git commit -m "ui(mock): complete stage 3"
git push origin main
```

Then watch the GitHub Actions CI run for `main` until it completes.
