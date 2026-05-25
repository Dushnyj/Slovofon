# Stage 2 Design System And Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Slovofon Stage 2 by adding design tokens, common UI components, app icon draft, Lucide-based SVG icon inventory, an `AppIcon` access layer, and tests.

**Architecture:** Keep Flutter Material 3 as the base, extend it with project tokens under `lib/app/theme/`, keep reusable UI widgets under `lib/ui/components/`, and route checked-in SVG usage through `lib/ui/icons/AppIcon`. Add SVG assets under the existing `assets/` scaffold without replacing platform launcher icons until the owner explicitly approves the final icon.

**Tech Stack:** Flutter, Material 3, ThemeExtension, SVG assets, widget and filesystem tests.

---

### Task 1: RED Tests

**Files:**
- Create: `test/app/theme/stage2_design_system_test.dart`
- Create: `test/assets/stage2_assets_test.dart`
- Create: `test/ui/stage2_components_test.dart`

- [ ] **Step 1: Add design-system tests**

Write tests asserting that light/dark/AMOLED themes expose color, spacing, radii, and focus tokens; button minimum sizes are at least 48 dp; and semantic state colors have readable foregrounds.

- [ ] **Step 2: Add asset inventory tests**

Write tests asserting that the app icon draft files and all required Stage 2 SVG icons exist, use 24x24 `currentColor` stroke icons, include Lucide source comments, do not hotlink remote content, keep download-state glyphs visually distinct, and prevent user-facing app UI from using temporary `Icons.*` Material glyphs.

- [ ] **Step 3: Add component tests**

Write tests asserting that common buttons, source chips, chapter tiles, and empty/error/loading states render with expected labels and semantics.

- [ ] **Step 4: Run RED**

Run:

```powershell
flutter test test/app/theme/stage2_design_system_test.dart test/assets/stage2_assets_test.dart test/ui/stage2_components_test.dart
```

Expected: FAIL because Stage 2 tokens, components, and SVG assets are incomplete.

### Task 2: Design Tokens And Theme

**Files:**
- Modify: `lib/app/theme/app_color_tokens.dart`
- Create: `lib/app/theme/app_spacing_tokens.dart`
- Create: `lib/app/theme/app_radii_tokens.dart`
- Create: `lib/app/theme/app_focus_tokens.dart`
- Modify: `lib/app/theme/app_theme.dart`

- [ ] **Step 1: Add token extensions**

Add semantic colors, spacing, radii, and focus tokens as `ThemeExtension`s with `copyWith` and `lerp`.

- [ ] **Step 2: Add component theme styles**

Set button, icon button, chip, card, list tile, tooltip, snackbar, bottom sheet, navigation, and focus/hover colors through `ThemeData` and token extensions.

- [ ] **Step 3: Run design-system tests**

Run:

```powershell
flutter test test/app/theme/stage2_design_system_test.dart
```

Expected: PASS.

### Task 3: Components

**Files:**
- Create: `lib/ui/components/app_buttons.dart`
- Create: `lib/ui/components/app_chips.dart`
- Create: `lib/ui/components/chapter_tile.dart`
- Create: `lib/ui/icons/app_icons.dart`
- Modify: `lib/ui/components/state_placeholder.dart`
- Modify: `lib/features/theme_preview/theme_preview_screen.dart`

- [ ] **Step 1: Add common buttons and chips**

Create typed wrappers for primary/secondary/quiet buttons and source/access chips using existing Flutter controls, theme tokens, and `AppIconAssets`.

- [ ] **Step 2: Add chapter tile and state variants**

Create a reusable `ChapterTile` and named constructors for empty/error/loading placeholders.

- [ ] **Step 3: Expand ThemePreviewScreen**

Add previews for common buttons, source/access chips, chapter tiles, snackbar/dialog/bottom sheet previews, download states, player controls, and focus/hover samples.

- [ ] **Step 4: Run component tests**

Run:

```powershell
flutter test test/ui/stage2_components_test.dart
```

Expected: PASS.

### Task 4: SVG Assets

**Files:**
- Create: `assets/app/app_icon_draft.svg`
- Create: `assets/app/android_adaptive_icon_foreground.svg`
- Create: all SVG files listed in `docs/SLOVOFON_TECHNICAL_SPEC_RU.md` section 23.2 under `assets/icons/`

- [ ] **Step 1: Add icon draft**

Create an original open-book plus audio-wave SVG draft. Do not replace Android or Windows platform launcher icons yet.

- [ ] **Step 2: Add required icon inventory**

Copy coherent 24x24 rounded stroke SVG icons from Lucide Static v1.16.0 using `fill="none"`, `stroke="currentColor"`, `stroke-width="2"`, `stroke-linecap="round"`, and `stroke-linejoin="round"`. Each checked-in SVG must keep license attribution and a source comment with the Lucide icon name.

- [ ] **Step 3: Run asset tests**

Run:

```powershell
flutter test test/assets/stage2_assets_test.dart
```

Expected: PASS.

### Task 5: Docs And Verification

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `THIRD_PARTY_NOTICES.md`
- Modify: `assets/README.md`

- [ ] **Step 1: Update changelog**

Add an Unreleased entry for Stage 2 design-system tokens, components, app icon draft, Lucide SVG icon set, and `AppIcon` UI wiring. Document Lucide Static in third-party notices and record icon semantics in `assets/README.md`.

- [ ] **Step 2: Verify**

Run:

```powershell
./tools/slovofon.ps1 format
./tools/slovofon.ps1 analyze
./tools/slovofon.ps1 test
./tools/slovofon.ps1 check
./tools/slovofon.ps1 build -Target android -Configuration debug
./tools/slovofon.ps1 build -Target windows -Configuration debug
```

Expected: all commands pass.
