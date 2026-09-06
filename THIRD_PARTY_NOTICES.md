# THIRD_PARTY_NOTICES.md

Этот файл должен содержать сведения о сторонних библиотеках, ассетах, иконках, шрифтах и других компонентах, используемых в Slovofon.

До добавления реальных зависимостей список является шаблоном. Codex обязан обновлять этот файл при добавлении стороннего компонента.

Лицензия самого проекта Slovofon указана в `LICENSE`. Attribution notice проекта указан в `NOTICE`.

## 1. Правила

Нельзя использовать:

- случайные картинки из интернета;
- hotlink assets по URL;
- ассеты с неясной лицензией;
- copyrighted logos источников без разрешения;
- платные/закрытые библиотеки без подтверждения владельца.

Можно использовать:

- open-source Flutter/Dart packages с понятной лицензией;
- собственные SVG;
- Material Symbols / Material Icons в рамках условий лицензии;
- Lucide-подобные open-source SVG, если лицензия совместима;
- ассеты из текущего reference-проекта `Book.zip`, если они принадлежат владельцу проекта.

## 2. Flutter / Dart dependencies

Текущие зависимости:

```text
Package: Flutter SDK
Version: Provided by local Flutter installation
License: BSD-3-Clause
URL: https://flutter.dev
Purpose: Cross-platform application framework and Material widgets.

Package: flutter_localizations
Version: Provided by local Flutter SDK
License: BSD-3-Clause
URL: https://api.flutter.dev/flutter/flutter_localizations/flutter_localizations-library.html
Purpose: Flutter localization delegates for supported platform widgets.

Package: go_router
Version: 17.2.3
License: BSD-3-Clause
URL: https://pub.dev/packages/go_router
Purpose: Declarative routing and shell navigation.

Package: flutter_riverpod
Version: 3.3.1
License: MIT
URL: https://pub.dev/packages/flutter_riverpod
Purpose: Application state container and dependency scope.

Package: flutter_svg
Version: 2.3.0
License: MIT
URL: https://pub.dev/packages/flutter_svg
Purpose: Future SVG icon and vector asset rendering.

Package: intl
Version: 0.20.2
License: BSD-3-Clause
URL: https://pub.dev/packages/intl
Purpose: Internationalization utilities.

Package: drift
Version: 2.31.0
License: MIT
URL: https://pub.dev/packages/drift
Purpose: SQLite persistence layer and typed database access.

Package: sqlite3
Version: 2.9.4
License: MIT
URL: https://pub.dev/packages/sqlite3
Purpose: Native SQLite bindings used transitively by Drift on Flutter platforms.

Package: sqlite3_flutter_libs
Version: 0.5.40
License: MIT
URL: https://pub.dev/packages/sqlite3_flutter_libs
Purpose: Bundled SQLite native libraries for Android, iOS, macOS, Linux, and Windows Flutter builds.

Package: path
Version: 1.9.1
License: BSD-3-Clause
URL: https://pub.dev/packages/path
Purpose: Cross-platform file path construction for local database files.

Package: path_provider
Version: 2.1.5
License: BSD-3-Clause
URL: https://pub.dev/packages/path_provider
Purpose: Locate platform-specific application support directories.

Package: just_audio
Version: 0.10.5
License: MIT
URL: https://pub.dev/packages/just_audio
Purpose: Cross-platform audio playback engine for chapters, seeking, playback speed, local files, assets, and media URLs.

Package: just_audio_windows
Version: 0.2.3
License: MIT
URL: https://pub.dev/packages/just_audio_windows
Purpose: Windows platform implementation for `just_audio` using WinRT MediaPlayer.

Package: audio_session
Version: 0.2.3
License: MIT
URL: https://pub.dev/packages/audio_session
Purpose: Android/iOS/macOS audio focus/session configuration for speech-style playback and interruptions.

Package: crypto
Version: 3.0.7
License: BSD-3-Clause
URL: https://pub.dev/packages/crypto
Purpose: Hashing for source request signatures and Akniga CryptoJS-compatible MD5 KDF generated at runtime.

Package: html
Version: 0.15.6
License: BSD-3-Clause
URL: https://pub.dev/packages/html
Purpose: HTML parsing for source connectors such as Akniga search/details pages.

Package: pointycastle
Version: 4.0.0
License: MIT
URL: https://pub.dev/packages/pointycastle
Purpose: AES-CBC block cipher used for Akniga ajax/bid request hash generation compatible with CryptoJS passphrase mode.

Package: flutter_lints
Version: 6.0.0
License: BSD-3-Clause
URL: https://pub.dev/packages/flutter_lints
Purpose: Static analysis lint rules for Flutter code.

Package: build_runner
Version: 2.15.0
License: BSD-3-Clause
URL: https://pub.dev/packages/build_runner
Purpose: Dart code generation runner for generated database code.

Package: drift_dev
Version: 2.31.0
License: MIT
URL: https://pub.dev/packages/drift_dev
Purpose: Drift schema/code generation for typed SQLite tables.
```

## 3. Android native dependencies

```text
Package: AndroidX Media3 session
Version: 1.10.1
License: Apache-2.0
URL: https://developer.android.com/jetpack/androidx/releases/media3
Purpose: Native Android MediaSessionService, notification, lock screen controls, and media button integration.
```

## 4. Icons

Текущие иконки:

```text
Icon set: Lucide Static
Version: 1.16.0
License: ISC
URL: https://lucide.dev
Source package: https://www.npmjs.com/package/lucide-static
Files:
- assets/icons/**/*.svg
Except:
- assets/icons/system/github.svg
- assets/icons/system/telegram.svg
Purpose: Checked-in SVG UI icons for navigation, book metadata, player controls, download states, and system actions.

Brand mark: GitHub
License/terms: GitHub Logos and Usage
URL: https://github.com/logos
Files:
- assets/icons/system/github.svg
Purpose: Link to the Slovofon GitHub repository on the About screen.

Brand mark: Telegram
License/terms: Telegram brand assets / trademark terms
URL: https://telegram.org
Files:
- assets/icons/system/telegram.svg
Purpose: Retained bundled brand asset; Telegram links have been removed from the About screen.

Icon set: Flutter Material Icons
License: Provided through Flutter/Material icon font distribution
URL: https://api.flutter.dev/flutter/material/Icons-class.html
Files:
- Runtime Material icons, used where Flutter widgets render built-in icons before a dedicated SVG asset is wired.
Purpose: Temporary fallback icons during UI scaffolding.
```

## 5. Fonts

По умолчанию использовать системные шрифты Flutter/платформы, если владелец не утвердит другой шрифт.

Windows desktop presentation использует установленные системные Segoe UI
(UI/текст) и Georgia (wordmark и инициалы обложки). Font files не включаются
в bundle и не загружаются из сети; при отсутствии используется font fallback.

Никогда не включать font files без проверки лицензии.

Android TV launcher banners (`android/app/src/main/res/drawable/tv_banner.xml`
и русская версия `drawable-ru/tv_banner.xml`) используют существующий знак
Slovofon и векторные контуры названия продукта. Проектный генератор
`android/tools/Generate-TvBanner.ps1` использует установленный Segoe UI для
контуров надписи; сами font files не включаются в APK и не скачиваются.

## 6. Source logos

Не использовать официальные логотипы источников без разрешения. Для источников использовать текстовые chips, цвет источника и generic source icon.

## 7. Windows compiler runtime

```text
Component: Microsoft Visual C++ runtime (MSVC redistributable DLLs)
Version: From the Visual Studio toolchain used for the build
License/terms: Microsoft Visual Studio license and the matching REDIST list
URL: https://learn.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files
Files: App-local redistributable runtime DLLs in Windows Profile/Release bundles
Purpose: Run Slovofon and its native plugins on Windows without relying on a preinstalled Visual C++ runtime.
```

CMake `InstallRequiredSystemLibraries` selects the runtime from the installed
compiler toolchain. Debug runtime libraries are not release redistributables
and are not included in the Profile/Release artifact set. The build validates
the runtime DLL import closure before packaging.
