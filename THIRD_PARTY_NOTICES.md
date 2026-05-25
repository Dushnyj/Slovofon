# THIRD_PARTY_NOTICES.md

Этот файл должен содержать сведения о сторонних библиотеках, ассетах, иконках, шрифтах и других компонентах, используемых в Slovofon.

До добавления реальных зависимостей список является шаблоном. Codex обязан обновлять этот файл при добавлении стороннего компонента.

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

Package: flutter_lints
Version: 6.0.0
License: BSD-3-Clause
URL: https://pub.dev/packages/flutter_lints
Purpose: Static analysis lint rules for Flutter code.
```

## 3. Icons

Текущие иконки:

```text
Icon set: Flutter Material Icons
License: Provided through Flutter/Material icon font distribution
URL: https://api.flutter.dev/flutter/material/Icons-class.html
Files:
- Runtime Material icons, no checked-in icon files yet.
Purpose: Temporary navigation, player, book, download, settings, and state icons for the initial scaffold.
```

## 4. Fonts

По умолчанию использовать системные шрифты Flutter/платформы, если владелец не утвердит другой шрифт.

Никогда не включать font files без проверки лицензии.

## 5. Source logos

Не использовать официальные логотипы источников без разрешения. Для источников использовать текстовые chips, цвет источника и generic source icon.
