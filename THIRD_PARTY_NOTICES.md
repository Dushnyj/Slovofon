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

Package: audio_service
Version: 0.18.18
License: MIT
URL: https://pub.dev/packages/audio_service
Purpose: Background audio service, Android media notification, lock screen controls, and media button integration.

Package: crypto
Version: 3.0.7
License: BSD-3-Clause
URL: https://pub.dev/packages/crypto
Purpose: SHA-256 hashing for source request signatures generated at runtime.

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

## 3. Icons

Текущие иконки:

```text
Icon set: Lucide Static
Version: 1.16.0
License: ISC
URL: https://lucide.dev
Source package: https://www.npmjs.com/package/lucide-static
Files:
- assets/icons/**/*.svg
Purpose: Checked-in SVG UI icons for navigation, book metadata, player controls, download states, and system actions.

Icon set: Flutter Material Icons
License: Provided through Flutter/Material icon font distribution
URL: https://api.flutter.dev/flutter/material/Icons-class.html
Files:
- Runtime Material icons, used where Flutter widgets render built-in icons before a dedicated SVG asset is wired.
Purpose: Temporary fallback icons during UI scaffolding.
```

## 4. Fonts

По умолчанию использовать системные шрифты Flutter/платформы, если владелец не утвердит другой шрифт.

Никогда не включать font files без проверки лицензии.

## 5. Source logos

Не использовать официальные логотипы источников без разрешения. Для источников использовать текстовые chips, цвет источника и generic source icon.
