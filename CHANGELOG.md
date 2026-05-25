# Changelog

Формат основан на Keep a Changelog, версии — Semantic Versioning.

## [Unreleased]

### Added
- Добавлен Stage 3 UI на mock data: главная, поиск, карточка книги, библиотека, загрузки, настройки, мини-плеер и полный плеер.
- Добавлены маршруты `/book/:bookId` и `/player` для mock-карточки книги и полноэкранного плеера.
- Расширены mock data книгами, версиями, главами, закладками, полками библиотеки и состояниями загрузок.
- Добавлены Stage 3 widget-тесты для навигации, поиска, карточки книги, full player, библиотеки, загрузок и настроек.
- Добавлены Stage 2 дизайн-токены: semantic colors, spacing, radii, focus/hover/selected states и минимальные 48dp размеры интерактивных контролов.
- Добавлены общие UI-компоненты Stage 2: primary/secondary/quiet buttons, source/access chips, `ChapterTile`, loading/empty/error placeholders.
- Добавлены draft app icon SVG и полный Lucide-based SVG icon inventory для nav, book, player, downloads и system групп.
- Добавлен единый `AppIcon`/`AppIconAssets` слой для локальных Lucide SVG в пользовательском интерфейсе.
- Расширен `ThemePreviewScreen` превью для Stage 2 компонентов, chapter tile, state variants и focus/state colors.
- Добавлены Stage 2 тесты для дизайн-системы, ассетов и reusable компонентов.
- Добавлены доменные модели Stage 1: `Book`, `BookVersion`, `Chapter`, `AudioTrack`, `PlaybackSession`, `PlaybackProgress`, `DownloadTask`, `Bookmark` и `AppSettings`.
- Добавлена Drift/SQLite схема версии 1 с обязательными таблицами для книг, источников, воспроизведения, загрузок, закладок, истории поиска, настроек, proxy profiles и source settings.
- Добавлены тесты Stage 1 для доменных моделей и in-memory Drift database.
- Описана схема release signing для Android и Windows: хранение ключей вне Git, будущие GitHub Secrets, временное восстановление ключей в CI и правила компрометации.
- Добавлен безопасный шаблон `android/key.properties.example` для будущей Android release-подписи.
- GitHub Actions CI теперь собирает Android debug APK и Windows debug bundle, публикуя их как временные Actions artifacts.
- Добавлен GitHub Actions CI workflow для проверки `flutter pub get --enforce-lockfile`, форматирования, `flutter analyze` и `flutter test`.
- Добавлены `LICENSE` с Apache License 2.0 и `NOTICE` для обязательного attribution notice проекта.
- Инициализирован стартовый Flutter/Dart-каркас проекта `slovofon` с версией `0.0.1+1`.
- Добавлены `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`, базовая структура `lib/`, стартовый widget test.
- Добавлены базовые слои приложения: bootstrap, router, локализация, тема, semantic color tokens, mock data и shell-навигация.
- Добавлена стартовая структура `assets/` для app assets, icons и l10n, подключённая в `pubspec.yaml`.
- Добавлен внутренний `ThemePreviewScreen` для проверки базовых кнопок, chips, карточек, input, progress и state colors.
- Добавлен главный PowerShell-скрипт `tools/slovofon.ps1` с командами `bootstrap`, `check`, `doctor`, `get`, `format`, `analyze`, `test`, `build`, `version`, `release`, `clean`.
- Сгенерированы стартовые Android и Windows платформенные файлы Flutter.
- Android `applicationId` и namespace зафиксированы как `com.slovofon.app`; Android display name локализован: `Словофон` для `ru`, `Slovofon` по умолчанию.
- Windows executable/metadata приведены к `Slovofon` и `Slovofon Team`.
- Подготовлен комплект проектной документации для старта разработки Slovofon.
- Зафиксирована структура обязательных документов: `AGENTS.md`, `docs/SLOVOFON_TECHNICAL_SPEC_RU.md`, `docs/ARCHITECTURE.md`, `docs/BUILD_RELEASE.md`, `docs/SECURITY.md`, `docs/THEMING.md`, `docs/SOURCES.md`.
- Зафиксировано название продукта: `Словофон` для русской локализации и `Slovofon` для остальных локализаций.
- Зафиксирован репозиторий: `https://github.com/Dushnyj/Slovofon.git`.
- Зафиксированы правила версионности, сборки, релизов, источников, безопасности, прокси, тем и ассетов.

### Changed
- `SlovofonShell` получил adaptive layout: bottom navigation для компактных экранов и navigation rail для широких окон.
- Пользовательский UI переведён с временных `Icons.*` glyphs Material на локальные Lucide SVG assets.
- Заменены временные одинаковые download-state SVG на осмысленную Lucide-карту: download, loader, queued, checked, trash, retry, error, pause и resume.
- Логическое имя технического ТЗ изменено с `auralib_technical_spec_ru.md` на `docs/SLOVOFON_TECHNICAL_SPEC_RU.md`.
- Убрано рабочее имя `Auralib` из технического ТЗ.

### Security
- Расширены правила для signing secrets: Android `.jks`, Windows `.pfx`, GitHub Secrets и CI cleanup.
- Зафиксирован запрет на хранение приватных API secrets в клиенте.
- Зафиксировано правило: generated SIGN/token не сохранять и не логировать.
