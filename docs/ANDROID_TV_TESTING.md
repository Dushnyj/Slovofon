# Android TV native capability and packaging contract

One application ID/APK remains available to phones and TVs. The main launcher
retains `LAUNCHER` and adds `LEANBACK_LAUNCHER`; both leanback and touchscreen
features are optional. No orientation lock, permissions, versions, dependencies
or signing changes are introduced for TV.

## Device identity

`com.slovofon.app/device_profile` / `getDeviceProfile` returns:

```text
isTelevision: Boolean = UI_MODE_TYPE_TELEVISION OR FEATURE_LEANBACK
uiModeType: Int
hasLeanbackFeature: Boolean
hasTouchscreen: Boolean
```

The app-level Flutter engine registers the handler **before** its Dart entrypoint,
so detection also works before an Activity attaches and after Activity recreation.
No Activity reference is retained. Flutter bootstrap uses `AppDeviceProfile.detect`
and overrides `appDeviceProfileProvider` before `runApp`. Non-Android, malformed,
missing or failed optional-channel responses have a safe non-TV fallback; the
channel wait is bounded to ten seconds, allowing a slow cold-start engine to
respond without incorrectly selecting the tablet UI. Window width, orientation, screen density,
and lack of touch alone never select TV.

## Launcher art

The 2026-09-07 Unreleased resources reuse the approved emblem in
`assets/app/slovofon_icon.png`, not an alternate icon concept:

- `mipmap-anydpi-v26/ic_launcher.xml` supplies adaptive foreground/background
  layers on Android 8+, avoiding the legacy icon's extra white launcher wrapper.
  Existing density-specific PNGs remain the Android 7 fallback.
- `drawable/tv_banner.xml`, `drawable-ru/tv_banner.xml` and their `-v26` variants
  combine the same emblem with an outlined localized wordmark. Explicit 160x90 dp
  bounds preserve 16:9 independently of the source bitmap's pixel dimensions;
  API 26+ uses proportional insets, with a compatible API 24-25 fallback.
- `android/tools/Generate-LauncherAssets.ps1` and `Generate-TvBanner.ps1`
  regenerate these resources. The wordmark uses an installed Windows Segoe UI
  font; no font or new runtime dependency is distributed.

Check **both** the TV home banner and the launcher/app-settings icon. Verify the
approved emblem, full product name in Russian and English, aspect ratio and
unclipped artwork in idle/focused states. Check circular and rounded-square masks
where supported; shape and themed-icon appearance remain launcher-owned. A valid
XML resource or screenshot of only one launcher surface is not sufficient.
See [adaptive icons](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)
and [TV icon/banner requirements](https://developer.android.com/training/tv/get-started/create).

## Input ownership

MainActivity does not intercept Back or D-pad. Flutter embedding/navigation and
the TV Flutter focus shell remain responsible for directional selection and Back.
Native media controls continue through the existing Media3 session/receiver and
shared playback bridge (including its existing 30-second hardware seek interval).
Do not add a second Activity or Flutter handler for the same hardware media event
without proving that it cannot dispatch twice. Foreground/background remote keys,
focus restoration and Back-to-launcher need actual device/emulator smoke checks;
manifest/source tests alone do not prove those behaviors.

## Current presentation and native regression procedure (2026-09-07)

This is the **checklist for the current Unreleased changes**, not a PASS report.
It supersedes earlier top-navigation and experimental poster screenshots. Record the exact
commit or source snapshot, APK hash, Android version, device/AVD, theme, text scale,
physical resolution and density for every run. Do not reuse the historical APK
listed below as evidence for current code.

Run only **one** phone or TV emulator at a time, using an isolated test profile.
Do not clear another profile, release installation or launcher data. Distinguish
physical remote input, hardware-class emulator input, ADB virtual key events and
widget-test key events in the report; a substitute is not silently a native PASS.

Full HD at 1920x1080 / 320 dpi yields 960x540 logical dp; 4K at 3840x2160 /
640 dpi should preserve that composition. Record actual system values rather than
inferring them from an emulator window's size. Never lower density, override DPR
or clamp the user's text scale to make more content fit. If a 4K mode is not
actually available, mark it unverified; a 4K fixture PNG is a separate test.
The design baseline follows [Android TV logical layouts](https://developer.android.com/design/ui/tv/guides/styles/layouts).

The Navigator, shell canvas and full-player background fill the actual viewport;
there is no outer 4% overscan frame or synthetic reduction of MediaQuery.size.
Spacing belongs inside each surface: 16 dp for shell content/navigation, while
the mini-player surface reaches the lower/right content edges and pads its own
controls. Dialogs keep their own bounded inset. Real system safe areas are not
erased. Compare the full framebuffer, not the emulator window border.

| Area | D-pad / native procedure | Expected contract |
| --- | --- | --- |
| Side rail | Move Up/Down through all five destinations, Select each, Right into its content, Left back from the leftmost content item. Repeat with a short viewport and large text. | 56 dp rail, 48 dp controls, 12 dp content gap; selected destination and keyboard focus are distinguishable. No phone bottom navigation. |
| Audiobook cards | Populate at least two rows, including several recordings of the same book and complete metadata. Traverse Left/Right and Up/Down; open a non-first card with Select and return with Back. | One stop per book; a 48x72 dp cover, title, author, narrator, cycle, duration, chapter count, year and rating are shown when available, with role icons. Long metadata wraps instead of disappearing. Source/progress remain in the footer. The neutral surface has a 1 dp resting outline and 2 dp focused outline without tinting source text. |
| Real catalog width | At default text, inspect Home after rail and internal page padding; also inspect Search. Repeat at 200%. | The full-screen viewport has no global percentage inset. Internal 16 dp chrome spacing and page padding leave Home/Search wide enough for two columns with the 360 dp minimum and 12 dp gaps; 200% text reduces this to one. Metadata grows naturally while the cover stays 48x72 dp; one book keeps its normal column width. |
| Source and saved details | Open online and cached/saved books. Switch Chapters / Information tabs; enter the chapter list, scroll, return Up to its active tab, then Back to the originating shelf. | TV rail and Back remain available; focus and scroll do not get trapped. Play, favorite, Later and applicable download actions remain reachable without inline card actions. |
| Scoped search | Open an author or narrator link in details, wait for results, choose a book, then Back. Also test a source failure and retry. | `/scoped-search` accepts completed results instead of remaining on a spinner; the query context and return route remain correct. |
| Search and IME | Enter a query with the TV keyboard; hide IME using Back without submitting, then leave the field directionally. Repeat with submission, filters and an empty result. | Text is retained, the next control has visible focus, dialog/IME handling does not leak focus or hide the completion action. No Tab/mouse workaround is counted as D-pad PASS. |
| Mini-player | Start real audio, wait several seconds, then pause/resume, press OK repeatedly on each 15-second seek action through buffering, and change chapters through a delayed load and book boundaries. Open the full player through its book area. | Time and progress update live, stop advancing while paused, and follow the current chapter. The source name keeps its color on a constant neutral background. Buffering retains the selected seek action and repeated OK presses continue seeking; chapter loading blocks activation without discarding selection. Actual first/last chapter boundaries remain disabled and skipped. Unknown-duration chapters keep relative seeking but not an invalid absolute slider. |
| Full player | Traverse tabs, chapters, speed, timer, volume and bookmark editor; save a bookmark using only the remote after hiding IME. | Focus is visible; vertical arrows leave sliders/editors, while horizontal seek actions adjust position. Bookmark persistence is checked after returning, not inferred from opening the dialog. |
| Settings / downloads | Change theme and custom color, adjust text, open every settings group; expand a download and reach its available actions. | Compact rows do not become narrow posters; active focus, disabled controls and completion actions remain readable. |
| Media keys / lifecycle | Exercise foreground and background Play/Pause/seek, reopen the Activity, and Back to the launcher. | The existing media session owns hardware commands; no double dispatch, unexpected restart or lost progress. UI +/-15 s and existing native hardware seek interval are tested separately. |

Repeat visual checks in light/dark themes and with the chosen purple accent;
include 75%, 100% and 200% text. Save unedited native evidence locally. Do not
publish test-user data, logs or fixtures as genuine README screenshots. Current
test/build/native outcomes belong in the dated QA report with explicit
PASS / FAIL / NOT RUN boundaries; no row above is pre-approved.

## Tests

- `test/core/platform/app_device_profile_test.dart`: mocked real MethodChannel
  serialization, safe fallbacks, timeout, non-Android behavior, provider override.
- `test/platform/android_tv_contract_test.dart`: static launcher/resources and
  channel-registration-before-entrypoint contract (not native runtime evidence).
- `test/platform/android_launcher_icon_contract_test.dart`: adaptive icon resource
  references and the approved emblem; not a rendering test of an OEM launcher.
- `test/ui/television_catalog_density_test.dart`: actual content widths
  791/799/815 dp, DPR 1/2/4, full audiobook metadata, single-stop D-pad traversal,
  details-return focus and the real 200% text scaler.
- `television_foundation_test.dart`, `television_ui_quality_test.dart` and
  `television_search_focus_test.dart`: viewport, route/focus boundaries and IME
  regression contracts. `television_book_details_density_test.dart` and
  `television_player_details_test.dart` cover detail/player geometry and tabs.
- `television_transport_test.dart`, `television_settings_modal_test.dart` and
  `television_downloads_compact_test.dart`: live transport state, settings dialogs
  and download rows. `seek_interval_*_test.dart` cover shared artwork/consumers.
- `SlovofonTvInstrumentation`: Android framework runner, no new test dependency;
  checks 16 TV/touch/leanback signal combinations, actual device capabilities,
  launcher resolution and an installed banner resource, without launching audio
  or opening the user's database. Existing lifecycle runner is unchanged.

For a separately authorized device run, after installing the Debug and androidTest
APKs on a selected test device:

```text
adb -s <serial> shell am instrument -w com.slovofon.app.test/com.slovofon.app.SlovofonTvInstrumentation
```

Run on a phone and TV separately, then launch the app from each actual launcher.
Check directional focus, OK, Back, media play/pause/seek, Activity reopening, and
portrait phone behavior. Do not report these checks passed until executed.

References: [Android TV app packaging](https://developer.android.com/training/tv/get-started/create),
[TV hardware detection](https://developer.android.com/training/tv/get-started/hardware).

## Native seek regression found during the same audit

Before correction, the Media3 facade treated missing source duration (`0`) as a
zero-length timeline item and upper-clamped forward/absolute seek to zero. The
Dart engine already treats nonpositive duration as unknown. Native now reports
`C.TIME_UNSET`, retains the zero lower bound, and applies the upper bound only
once a positive chapter duration is known. The existing hardware seek increment
remains 30 seconds; UI 15-second buttons and chapter navigation are unchanged.

`SlovofonMediaSeekInstrumentation` exercises public Media3 facade methods without
starting an Activity, FlutterEngine, real audio or a database. It checks unknown
duration 0/negative, forward 60 → 90 s, back 90 → 60 s, absolute 120 s and
negative → 0, then a known 75 s upper bound; speed and paused state remain unchanged.

```text
adb -s <serial> shell am instrument -w com.slovofon.app.test/com.slovofon.app.SlovofonMediaSeekInstrumentation
```

## Historical verification status (2026-09-06)

The root-run `android-debug-build02` completed successfully: the application Debug
APK and androidTest APK compile. The final universal application APK was then
successfully rebuilt and verified (`android-universal-debug-verified.log`):

- File: `artifacts/qa/Slovofon-v0.0.6-android-universal-debug.apk`.
- Size: **231683371 bytes**.
- SHA-256: `e95b3c39b85dcbca086f660908bea77a2d3c4511cb5e7517be7cc9834f1f6154`.
- ABIs: `arm64-v8a`, `armeabi-v7a`, `x86_64`; min SDK **24**, target SDK **36**.
- Signature verification: **PASS, APK Signature Scheme v2**
  (`signature/android-verified-signature.log`). Signing configuration is unchanged;
  this is a Debug APK, not a signed release publication.

Compilation and signature verification do **not** mean that either instrumentation
runner or device/remote scenarios passed.

At that checkpoint native instrumentation was **NOT EXECUTED** because a usable
hypervisor was unavailable. This is historical, not the current environment:
on 2026-09-07 the owner authorized native QA with usable WHPX. Only one emulator
(phone or TV) runs at a time. The TV redesign uses a separate Debug AVD with the
already installed API 36 TV image, preserving the earlier release AVD and its data.
Keep instrumentation, widget/render tests, emulator input checks and physical-device
results separate; none implies the others passed.

Use the Russian [manual device checklist](MANUAL_DEVICE_QA_RU.md). A Debug APK may
not update an existing release signed with a different key. Use a spare/test device
without a conflicting installation; do not uninstall the user's application or
clear its data to make the test install succeed. The APK identified above belongs
only to the historical checkpoint; use the artifact identified by the current
run's report when verifying the current presentation.
