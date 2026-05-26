# Changelog

Формат основан на Keep a Changelog, версии — Semantic Versioning.

## [Unreleased]

### Added
- Добавлен Stage 7 `IzibSourceConnector`: первый реальный источник через GraphQL API Izib, runtime SIGN generation, поиск, details, files -> chapters/audio tracks, resolveMedia/download через media allowlist и health check.
- Добавлены Stage 7 тесты Izib для GraphQL client/signing, mapper, source connector, allowlist validation и безопасной обработки API ошибок без раскрытия SIGN.
- Добавлен Stage 6 `SourceConnector` framework: общий контракт источников, `SearchRequest`, `BookSearchResult`, `BookVersionDetails`, `ResolvedMedia`, `SourceCapabilities`, `SourceHealth`, `SourceException` и агрегирующий `SourceSearchResponse`.
- Добавлен `SourceRegistry` как единая точка доступа к источникам: регистрация коннекторов, защита от duplicate ids, фильтрация enabled/requested sources, агрегация частичных ошибок поиска, capabilities map и health checks.
- Добавлены `SourceMediaPolicy` и `SourceMediaValidator`: проверка media allowlist, запрет URL с credentials, запрет non-http схем и явное разрешение local asset/file media только для mock/local источников.
- Добавлены shared parser helpers для источников: нормализация whitespace/title, парсинг чисел/годов/длительности и безопасное разрешение URI.
- Добавлен `MockSourceConnector.yakniga()` поверх текущих Stage 3/4 mock data для тестируемой интеграции search/details/chapters/audio tracks/resolveMedia без сети.
- Добавлены Stage 6 unit-тесты для registry, media validator, parser helpers и mock connector.
- Добавлен Stage 5 `DownloadManager`: очередь загрузок глав и книг, ограничение параллельности, pause/resume/cancel/retry/delete, прогресс, скорость и восстановление прерванных задач после перезапуска как resumable.
- Добавлены `DownloadClient`, `FileDownloadStorage` и `DownloadPersistenceStore`: скачивание URL/file/asset media sources, `.part` файлы, Range/resume, атомарное завершение файла, `metadata.json` и Drift-сохранение `DownloadTask`.
- Добавлено подключение оффлайн-файлов к плееру: скачанные главы подставляются в `AudioPlaybackBook` как `AudioMediaSource.file`, без удаления истории, избранного, закладок и прогресса при удалении аудио.
- Добавлены Stage 5 тесты для загрузки главы/книги, pause/resume по `.part`, cancel/delete, restart recovery и обновления статусов главы без потери playback progress.
- Добавлен Stage 4 `PlaybackController`: `AudioEngine` abstraction, playback state, play/pause/seek, speed, chapter switching, progress calculation, session restore and sleep timer behavior.
- `PlaybackController` теперь слушает runtime snapshots от audio backend: позицию, ready/buffering/completed/error states и автоматически переходит к следующей главе при завершении текущей.
- Добавлен `JustAudioEngine` поверх `just_audio` с URL/file/asset media source API и Windows backend через `just_audio_windows`.
- Добавлен Android/system-media слой `SlovofonAudioHandler` поверх Flutter-пакета `audio_service` для metadata, notification/lock screen/media button команд.
- Добавлен `PlaybackPersistenceStore` на Drift для сохранения и восстановления `PlaybackSession` и `PlaybackProgress` без уменьшения max reached progress.
- Добавлен локальный сгенерированный `assets/audio/stage4_mock_chapter.wav` fixture на 45 минут, чтобы mock playback мог открыть реальный audio asset без сети и не завершал главу сразу после старта с сохраненной позиции.
- Добавлен in-memory `AudioEngine` и switching engine для тестируемого Stage 4 ядра и mock UI без реальных media URL.
- Добавлены Stage 4 unit-тесты для playback controls, runtime backend states, progress persistence, chapter navigation, session restore, sleep timer, `JustAudioEngine`, `SlovofonAudioHandler` и local audio fixture.
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
- Порядок реализации реальных источников изменён: Stage 7 — Izib, Stage 8 — Akniga, Stage 9 — Yakniga, Knigavuhe, Knigoblud и Baza Knig.
- Экран загрузок теперь показывает реальные задачи `DownloadManager` по разделам активные/очередь/ошибки/завершённые вместо mock-очереди.
- Главная, поиск, библиотека, карточка книги и полный плеер теперь вызывают реальные действия загрузки книги/главы через `DownloadManager`.
- Bootstrap приложения подключает app-specific storage для книг и общий Drift persistence для плеера и загрузок.
- Мини-плеер и полный плеер теперь читают состояние через единый `PlaybackController`, а не напрямую из статичных mock-полей.
- Внутренний app-level audio service переименован в `PlaybackController`, чтобы не конфликтовать с Flutter-пакетом `audio_service`.
- Главная, поиск и библиотека получили более плотные book cards: процент прослушивания поверх обложки, прогресс под обложкой, metadata с иконками и icon-only действия для избранного, загрузки, запуска и информации.
- Карточка "Продолжить прослушивание" переработана с крупной обложкой, процентом прогресса, metadata и быстрыми icon-only действиями.
- Мини-плеер снизу стал компактнее и информативнее: тонкая полоса прогресса, обложка, глава, позиция и процент прослушивания.
- Полный плеер переработан под мобильный сценарий: вкладки заменены на dots, controls собраны в одну строку, добавлены chapter count, download book action, sleep timer и единая нижняя панель прогресса.
- Карточки загрузок получили обложки, автора, чтеца, год и компактные иконки для download/downloading/cancel/delete/resume/retry состояний.
- Chapter tile в полном плеере теперь показывает icon-only действие скачивания или удаления скачанной главы.
- `SlovofonShell` получил adaptive layout: bottom navigation для компактных экранов и navigation rail для широких окон.
- Пользовательский UI переведён с временных `Icons.*` glyphs Material на локальные Lucide SVG assets.
- Заменены временные одинаковые download-state SVG на осмысленную Lucide-карту: download, loader, queued, checked, trash, retry, error, pause и resume.
- Логическое имя технического ТЗ изменено с `auralib_technical_spec_ru.md` на `docs/SLOVOFON_TECHNICAL_SPEC_RU.md`.
- Убрано рабочее имя `Auralib` из технического ТЗ.

### Fixed
- Исправлен размер SVG search icon внутри `TextField`, чтобы prefix icon не растягивался на Android.
- Исправлена отрисовка Lucide SVG icons в Flutter UI через явный `ColorFilter`.
- Исправлено подключение SVG icons из подпапок `assets/icons/*` в `pubspec.yaml`.
- Lucide stroke/fill параметры продублированы на shape-элементы SVG для стабильного Android-рендера.
- Основные action-кнопки mock UI заменены на icon-only controls с tooltip вместо громоздких текстовых кнопок.

### Security
- Добавлена source-level media validation: реальные коннекторы обязаны отдавать media только через allowlist домены, без произвольных URL и без credentials в URL.
- Расширены правила для signing secrets: Android `.jks`, Windows `.pfx`, GitHub Secrets и CI cleanup.
- Зафиксирован запрет на хранение приватных API secrets в клиенте.
- Зафиксировано правило: generated SIGN/token не сохранять и не логировать.
