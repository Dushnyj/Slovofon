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
channel wait is bounded to two seconds. Window width, orientation, screen density,
and lack of touch alone never select TV.

## Launcher art

`drawable/tv_banner.xml` and `drawable-ru/tv_banner.xml` are self-contained 16:9
vector banners using the existing book/wave artwork and localized product name.
`android/tools/Generate-TvBanner.ps1` regenerates the outlined wordmarks from an installed
Windows Segoe UI font without distributing a font or adding a build dependency.
The app icon itself is unchanged; default non-Russian name remains Slovofon.

## Input ownership

MainActivity does not intercept Back or D-pad. Flutter embedding/navigation and
the TV Flutter focus shell remain responsible for directional selection and Back.
Native media controls continue through the existing Media3 session/receiver and
shared playback bridge (including its existing 30-second hardware seek interval).
Do not add a second Activity or Flutter handler for the same hardware media event
without proving that it cannot dispatch twice. Foreground/background remote keys,
focus restoration and Back-to-launcher need actual device/emulator smoke checks;
manifest/source tests alone do not prove those behaviors.

## Tests

- `test/core/platform/app_device_profile_test.dart`: mocked real MethodChannel
  serialization, safe fallbacks, timeout, non-Android behavior, provider override.
- `test/platform/android_tv_contract_test.dart`: static launcher/resources and
  channel-registration-before-entrypoint contract (not native runtime evidence).
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

## Verification status (2026-09-06)

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

Native instrumentation remains **NOT EXECUTED**: a usable emulator hypervisor was unavailable,
and the owner declined its installation. No further emulators are being started
for this iteration. Phone/TV visual and real-device behavior checks are delegated
to the owner; code/widget verification remains separate from those checks.

Use the Russian [manual device checklist](MANUAL_DEVICE_QA_RU.md). A Debug APK may
not update an existing release signed with a different key. Use a spare/test device
without a conflicting installation; do not uninstall the user's application or
clear its data to make the test install succeed. Use the prepared universal QA APK
identified above and delivered with the final verification report.
