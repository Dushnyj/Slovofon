# Changelog

Формат основан на Keep a Changelog, версии — Semantic Versioning.

## [Unreleased]

### Added
- Добавлен GitHub Actions CI workflow для проверки `flutter pub get --enforce-lockfile`, форматирования, `flutter analyze` и `flutter test`.
- Добавлены `LICENSE` с Apache License 2.0 и `NOTICE` для обязательного attribution notice проекта.
- Инициализирован стартовый Flutter/Dart-каркас проекта `slovofon` с версией `0.0.1+1`.
- Добавлены `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`, базовая структура `lib/`, стартовый widget test.
- Добавлены базовые слои приложения: bootstrap, router, локализация, тема, semantic color tokens, mock data и shell-навигация.
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
- Логическое имя технического ТЗ изменено с `auralib_technical_spec_ru.md` на `docs/SLOVOFON_TECHNICAL_SPEC_RU.md`.
- Убрано рабочее имя `Auralib` из технического ТЗ.

### Security
- Зафиксирован запрет на хранение приватных API secrets в клиенте.
- Зафиксировано правило: generated SIGN/token не сохранять и не логировать.
