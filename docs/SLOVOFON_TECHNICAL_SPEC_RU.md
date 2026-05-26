# SLOVOFON_TECHNICAL_SPEC_RU.md — техническое задание Словофон / Slovofon

**Название продукта:** Словофон / Slovofon.  
**Целевые платформы:** Android-смартфоны, Android-планшеты, Android TV, Windows 10+, Windows 11.  
**Основной стек:** Flutter + Dart.  
**Основной исполнитель:** Codex, работающий поэтапно и строго по данному ТЗ.  
**Назначение документа:** описать продукт, архитектуру, интерфейсы, UX, источники, плеер, загрузки, ассеты, безопасность, прокси, тестирование и порядок реализации так подробно, чтобы Codex мог разрабатывать приложение с нуля без хаотичных решений.

**Имя файла в репозитории:** `docs/SLOVOFON_TECHNICAL_SPEC_RU.md`.

Связанные документы:

- `AGENTS.md` — постоянные правила Codex, подтверждения, Git, версии, релизы и запреты;
- `docs/ARCHITECTURE.md` — архитектура, слои, модули и потоки данных;
- `docs/BUILD_RELEASE.md` — bootstrap, сборка, установщики, артефакты, GitHub Release;
- `docs/SECURITY.md` — секреты, API, прокси, пользовательские данные, логи;
- `docs/THEMING.md` — цвета, темы, контраст, ThemePreviewScreen;
- `docs/SOURCES.md` — подробная спецификация источников и адаптеров.

Это ТЗ описывает продукт и поведение приложения. Правила выполнения, опасные действия, Git/GitHub, версии и релизы фиксируются в `AGENTS.md` и профильных документах.


---

## 1. Суть продукта

Нужно разработать новое кроссплатформенное приложение для поиска, прослушивания и оффлайн-загрузки аудиокниг из нескольких источников.

Приложение должно быть не просто аудиоплеером, а единым клиентом-агрегатором:

- поиск аудиокниг по нескольким источникам;
- поиск по названию, автору, чтецу, циклу/серии;
- объединение одинаковых книг из разных источников;
- выбор конкретной версии книги: источник, чтец, длительность, статус доступа;
- онлайн-прослушивание;
- оффлайн-загрузка книги целиком или отдельных глав;
- восстановление последней позиции после закрытия приложения, выгрузки из памяти или перезагрузки устройства;
- постоянный мини-плеер внутри приложения;
- полноэкранный плеер с главами, таймером сна, скоростью, закладками и прогрессом;
- Android-плеер в шторке уведомлений и на экране блокировки;
- Windows mini-player в стиле маленького закрепляемого плеера;
- гибкие настройки источников, тем, языка, прокси, загрузок и плеера;
- удобство управления на телефоне, планшете, Android TV и Windows;
- поддержка управления кнопками, мышкой, клавиатурой, пультом, свайпами и жестами.

Главный принцип продукта:

> Пользователь думает о книге, а не об источнике. Источники являются техническим слоем, но приложение должно показывать их понятно и управляемо.

---

## 2. Что уже есть как reference implementation

К проекту приложен архив сайта `Book.zip`. Его нельзя считать готовой кодовой базой нового приложения, но его нужно использовать как эталон поведения источников.

В архиве есть важные части:

```text
Book/
├─ app.js
├─ server.py
├─ index.html
├─ styles.css
├─ assets/
│  ├─ logo.svg
│  ├─ favicon.svg
│  └─ icons/
│     ├─ author.svg
│     ├─ mic.svg
│     ├─ clock.svg
│     ├─ calendar.svg
│     ├─ published.svg
│     ├─ audio-year.svg
│     ├─ rating.svg
│     ├─ series.svg
│     └─ star.svg
├─ server_sources/
│  ├─ akniga.py
│  ├─ baza_knig.py
│  ├─ izib.py
│  ├─ knigavuhe.py
│  ├─ knigoblud.py
│  └─ yakniga.py
└─ sources/client/
   ├─ registry.js
   ├─ akniga.js
   ├─ baza_knig.js
   ├─ izib.js
   ├─ knigavuhe.js
   ├─ knigoblud.js
   └─ yakniga.js
```

Codex должен использовать эти файлы как справочник:

- `server_sources/*.py` — текущая серверная логика источников, API, медиа-валидация, специальные методы получения треков, headers, fallback;
- `sources/client/*.js` — текущие клиентские парсеры, нормализация карточек, деталей книги, глав, циклов, статусов доступа;
- `assets/icons/*.svg` — стиль иконок, который можно использовать как основу для новой дизайн-системы;
- `styles.css` — референс цветов, скруглений, карточек, чипов, светлой/тёмной темы.

Код сайта не переносить слепо. Его нужно переписать в архитектуру нового приложения.

---

## 3. Целевые платформы и минимальные требования

### 3.1 Android

Поддержать:

- обычные смартфоны;
- планшеты;
- Android TV;
- управление сенсором, жестами, экранными кнопками, аппаратными кнопками, Bluetooth-наушниками и пультом.

Рекомендация:

- `minSdk`: Android 8.0 / API 26, если зависимости и media service позволяют;
- `targetSdk`: актуальный стабильный target SDK на момент сборки и публикации;
- поддержка 32-bit/64-bit ABI по требованиям выбранных Flutter-зависимостей;
- приложение должно корректно работать на устройствах с маленьким экраном, большим экраном, планшетом и ТВ.

Android-особенности:

- media notification;
- lock screen media controls;
- Bluetooth/headset media buttons;
- audio focus;
- реакция на звонки;
- реакция на отключение наушников;
- background playback;
- foreground service для активного воспроизведения и при необходимости для активных загрузок;
- runtime-разрешение уведомлений на новых версиях Android;
- без лишних storage permissions: скачанные файлы хранить в app-specific storage, если пользователь не выбрал внешнюю папку через системный picker.

### 3.2 Android TV

Android TV — не растянутая мобильная версия. Нужен отдельный adaptive layout:

- крупные карточки;
- фокусная навигация;
- D-pad управление;
- кнопка Back;
- play/pause с пульта;
- перемотка с пульта;
- безопасные отступы от краёв ТВ;
- минимум мелкого текста;
- отдельная логика поиска, желательно с поддержкой системного голосового ввода, если доступно.

### 3.3 Windows

Поддержать:

- Windows 10+ 64-bit;
- Windows 11;
- мышь;
- клавиатуру;
- media keys;
- системный трей;
- mini-player поверх окон;
- выбор папки загрузок;
- автозапуск по настройке пользователя.

Windows UI не должен копировать мобильный интерфейс один в один. Нужен desktop-layout:

- левая навигационная панель;
- верхняя строка поиска;
- центральная область контента;
- правая панель деталей/текущей книги, если хватает ширины;
- нижний плеер;
- отдельный Windows mini-player.

---

## 4. Технологический стек

### 4.1 Основной стек

Использовать Flutter + Dart.

Рекомендуемые зависимости:

```text
UI / routing / state:
- go_router
- flutter_riverpod или riverpod
- freezed + json_serializable, если Codex уверенно поддерживает codegen
- flutter_localizations
- intl

Database / storage:
- drift
- sqlite3_flutter_libs
- path_provider
- path
- flutter_secure_storage для чувствительных настроек, proxy credentials и потенциальных source credentials

Network:
- dio
- html
- crypto
- convert

Audio:
- отдельная абстракция AudioEngine
- Android: app-level PlaybackController + audio_service + just_audio либо другой совместимый стек
- Windows: app-level PlaybackController + just_audio с Windows backend; если стек нестабилен, реализовать WindowsAudioEngine через альтернативный пакет или platform channel

Downloads:
- собственный DownloadManager поверх dio
- поддержка Range/resume, headers, proxy, atomic temp files

Desktop:
- window_manager
- tray_manager или совместимая альтернатива
- hotkey_manager или platform channel для global hotkeys

Assets:
- flutter_svg
```

Важно: конкретные версии зависимостей Codex должен подбирать на момент реализации. Если пакет не поддерживает нужную платформу, нельзя ломать архитектуру. Нужно заменить реализацию внутри соответствующего adapter/service, сохранив интерфейс.

### 4.2 Главный архитектурный принцип

UI не должен содержать бизнес-логику источников, загрузок, плеера, прокси или базы.

Запрещено:

- делать HTTP-запросы к источникам прямо из виджетов;
- хранить raw audio URL в UI-состоянии как источник истины;
- смешивать парсинг источников с экранами;
- скачивать файлы из UI-компонентов;
- хранить секреты, токены, proxy passwords в обычных настройках;
- логировать sensitive headers, SIGN, cookies, generated tokens, full media URLs, proxy credentials.

Разрешено:

- UI вызывает use case или notifier;
- use case обращается к repository/service;
- service обращается к SourceConnector, Database, DownloadManager, PlaybackController / AudioService layer.

---

## 5. Предлагаемая структура проекта

Codex должен создать проект примерно такой структуры:

```text
lib/
├─ main.dart
├─ app/
│  ├─ app.dart
│  ├─ router.dart
│  ├─ bootstrap.dart
│  ├─ lifecycle/
│  ├─ localization/
│  └─ theme/
│
├─ core/
│  ├─ constants/
│  ├─ errors/
│  ├─ logging/
│  ├─ network/
│  ├─ platform/
│  ├─ security/
│  ├─ storage/
│  └─ utils/
│
├─ domain/
│  ├─ models/
│  │  ├─ book.dart
│  │  ├─ book_version.dart
│  │  ├─ chapter.dart
│  │  ├─ audio_track.dart
│  │  ├─ source.dart
│  │  ├─ playback_session.dart
│  │  ├─ playback_progress.dart
│  │  ├─ download_task.dart
│  │  ├─ bookmark.dart
│  │  ├─ app_settings.dart
│  │  └─ search.dart
│  ├─ repositories/
│  └─ usecases/
│
├─ data/
│  ├─ database/
│  ├─ repositories/
│  ├─ mappers/
│  └─ cache/
│
├─ sources/
│  ├─ source_connector.dart
│  ├─ source_registry.dart
│  ├─ source_capabilities.dart
│  ├─ source_health.dart
│  ├─ common/
│  │  ├─ html_helpers.dart
│  │  ├─ duration_parser.dart
│  │  ├─ media_url_validator.dart
│  │  ├─ people_parser.dart
│  │  ├─ rating_parser.dart
│  │  └─ text_normalizer.dart
│  ├─ akniga/
│  ├─ baza_knig/
│  ├─ izib/
│  ├─ knigavuhe/
│  ├─ knigoblud/
│  └─ yakniga/
│
├─ services/
│  ├─ audio/
│  ├─ downloads/
│  ├─ media_proxy/
│  ├─ proxy/
│  ├─ source_health/
│  ├─ sync/
│  └─ app_lifecycle/
│
├─ features/
│  ├─ home/
│  ├─ search/
│  ├─ book_details/
│  ├─ library/
│  ├─ downloads/
│  ├─ player/
│  ├─ settings/
│  ├─ source_settings/
│  └─ onboarding/
│
└─ ui/
   ├─ adaptive/
   ├─ components/
   ├─ cards/
   ├─ buttons/
   ├─ icons/
   ├─ dialogs/
   ├─ sheets/
   ├─ empty_states/
   └─ gestures/

assets/
├─ app/
│  ├─ logo.svg
│  ├─ icon_foreground.svg
│  └─ splash.svg
├─ icons/
│  ├─ nav/
│  ├─ book/
│  ├─ player/
│  ├─ downloads/
│  ├─ source/
│  └─ system/
└─ l10n/
```

---

## 6. Модель данных

### 6.1 Почему нужно разделить Book и BookVersion

В источниках одна и та же книга может встречаться много раз:

- разные сайты;
- разные чтецы;
- разные длительности;
- разные обложки;
- разные наборы глав;
- полная версия или фрагмент;
- бесплатная, платная, подписочная, неизвестная;
- один источник может отдавать несколько озвучек одной книги.

Поэтому обязательно разделить:

- `Book` — логическая книга;
- `BookVersion` — конкретная версия книги из конкретного источника.

### 6.2 Book

```text
Book
- id
- normalizedTitle
- displayTitle
- authors[]
- seriesTitle
- seriesNumber
- year
- bestCoverUrl
- bestLocalCoverPath
- bestDescription
- createdAt
- updatedAt
```

### 6.3 BookVersion

```text
BookVersion
- id
- bookId
- sourceId
- sourceBookId
- sourceUrl
- title
- normalizedTitle
- authors[]
- narrators[]
- translators[]
- seriesTitle
- seriesNumber
- genres[]
- tags[]
- description
- coverUrl
- localCoverPath
- durationMs
- durationText
- publishedYear
- audioYear
- ratingValue
- ratingCount
- accessType
- playbackAccess
- isFull
- isFragment
- isPaid
- isSubscription
- isAccessibleForFree
- canStream
- canDownload
- rawSourceDataJson
- lastResolvedAt
- createdAt
- updatedAt
```

### 6.4 Chapter

```text
Chapter
- id
- bookVersionId
- sourceId
- sourceBookId
- sourceChapterId
- index
- title
- normalizedTitle
- durationMs
- streamRef
- cachedStreamUrl
- cachedStreamUrlUpdatedAt
- cachedStreamUrlExpiresAt
- audioFormat
- mimeType
- rawSourceDataJson
- localPath
- fileSizeBytes
- downloadStatus
- downloadProgress
- playbackPositionMs
- isFinished
- createdAt
- updatedAt
```

### 6.5 AudioTrack

Не все источники отдают “главы” как настоящие главы. Иногда есть один большой файл, иногда треки, иногда файл получается только после дополнительного resolver-запроса.

```text
AudioTrack
- id
- chapterId
- sourceId
- index
- title
- durationMs
- mediaRef
- directUrl
- headersJson
- format
- mimeType
- expiresAt
- rawSourceDataJson
```

### 6.6 PlaybackSession

```text
PlaybackSession
- id
- activeBookId
- activeBookVersionId
- activeSourceId
- activeChapterId
- positionMs
- speed
- volume
- isPlaying
- playerPageIndex
- sleepTimerRemainingMs
- sleepTimerMode
- updatedAt
```

После перезапуска приложения:

- сессия должна восстановиться;
- мини-плеер должен показаться, если есть активная книга;
- воспроизведение не должно стартовать автоматически;
- пользователь нажимает Play и продолжает с сохранённого места.

### 6.7 PlaybackProgress

```text
PlaybackProgress
- bookId
- bookVersionId
- currentChapterId
- currentPositionMs
- maxReachedGlobalPositionMs
- totalDurationMs
- listenedDurationMs
- percent
- isFinished
- lastPlayedAt
```

Процент считать от суммарной длительности всех глав:

```text
listenedMs = sum(durationMs of fully finished previous chapters) + currentChapterPositionMs
percent = listenedMs / totalDurationMs * 100
```

Если пользователь вернулся назад и переслушивает, общий максимальный прогресс не должен уменьшаться, пока пользователь явно не нажал “Сбросить прогресс”.

### 6.8 DownloadTask

```text
DownloadTask
- id
- bookId
- bookVersionId
- chapterId nullable
- sourceId
- type: book | chapter | cover | metadata
- status: queued | running | paused | completed | failed | canceled
- priority
- progress
- downloadedBytes
- totalBytes
- speedBytesPerSecond
- errorCode
- errorMessage
- retryCount
- createdAt
- updatedAt
```

### 6.9 Bookmark

```text
Bookmark
- id
- bookId
- bookVersionId
- chapterId
- positionMs
- title
- note
- createdAt
- updatedAt
```

### 6.10 SearchHistory

```text
SearchHistory
- id
- query
- searchKind
- filtersJson
- createdAt
- lastUsedAt
- usageCount
```

---

## 7. Локальная база данных

Использовать SQLite через Drift или совместимый слой.

Обязательные таблицы:

```text
books
book_versions
chapters
audio_tracks
sources
source_health
playback_sessions
playback_progress
download_tasks
favorites
bookmarks
search_history
settings
proxy_profiles
source_settings
app_logs optional
```

Требования:

- миграции обязательны с первой версии;
- нельзя удалять пользовательские данные при обновлении схемы;
- все пути к локальным файлам хранить относительными к app data root, если возможно;
- rawSourceDataJson хранить для отладки и повторного resolver без повторного парсинга, но не хранить sensitive headers;
- кэшированные stream URL считать временными;
- при 403/404/410 или ошибке воспроизведения пытаться заново resolveMedia.

---

## 8. Источники книг

### 8.1 Текущие источники из архива

Нужно поддержать 6 источников:

```text
1. knigavuhe   — КнигаВУхе
2. izib        — Изибук
3. akniga      — Akniga
4. baza_knig   — Baza Knig
5. knigoblud   — Книгоблуд
6. yakniga     — Yakniga
```

### 8.2 Общий интерфейс SourceConnector

Codex должен реализовать единый контракт:

```dart
abstract class SourceConnector {
  String get id;
  String get name;
  String get host;
  String get color;
  SourceCapabilities get capabilities;

  Future<List<BookSearchResult>> search(SearchRequest request);
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref);
  Future<List<Chapter>> getChapters(SourceBookRef ref);
  Future<List<AudioTrack>> getAudioTracks(SourceBookRef ref);
  Future<ResolvedMedia> resolveMedia(Chapter chapter, MediaResolvePurpose purpose);
  Future<SourceHealth> checkHealth();
}
```

`MediaResolvePurpose`:

```text
playback
download
probe
```

### 8.3 SourceCapabilities

```text
SourceCapabilities
- supportsSearch
- supportsSearchByTitle
- supportsSearchByAuthor
- supportsSearchByNarrator
- supportsSearchBySeries
- supportsDetails
- supportsChapters
- supportsSeries
- supportsRating
- supportsDescription
- supportsDirectAudio
- supportsDownload
- supportsFragments
- supportsPaidItems
- requiresSpecialHeaders
- requiresMediaProxy
- hasTemporaryUrls
- hasApiSignature
- hasHtmlParser
- hasGraphQlApi
```

### 8.4 SearchRequest

```text
SearchRequest
- query
- kind: all | title | author | narrator | series
- page
- pageSize
- sourceIds[]
- onlyFull
- onlyFree
- onlyDownloadable
- includeFragments
- includePaid
- includeUnknownAccess
- groupDuplicates
```

### 8.5 BookSearchResult

```text
BookSearchResult
- sourceId
- sourceName
- sourceBookId
- sourceUrl
- title
- authors[]
- narrators[]
- seriesTitle
- seriesNumber
- coverUrl
- durationMs
- durationText
- year
- ratingValue
- ratingCount
- accessType
- isFull
- isFragment
- isPaid
- isAccessibleForFree
- canStream
- canDownload
- confidenceScore
- rawSourceDataJson
```

### 8.6 Особенности каждого источника

#### Yakniga

Из архива:

- GraphQL endpoint;
- API-режим предпочтителен;
- главы приходят через структуру chapters;
- fileUrl обычно можно использовать как media source;
- media URL должен валидироваться по allowlist;
- есть авторы, чтецы, серии, rating, price/access flags.

Реализовать первым реальным источником.

#### Izib

Из архива:

- GraphQL API;
- SIGN генерируется на месте;
- есть package key, body signature;
- есть поиск, получение книги, серия, files;
- HTML/XSPlayer может быть fallback.

Важно по безопасности:

- SIGN, package-derived key и любые временные токены генерировать внутри `IzibConnector`;
- не хранить SIGN в базе;
- не логировать SIGN, body hash, headers;
- если появится настоящий закрытый API secret, его нельзя безопасно спрятать в клиентском приложении. В таком случае нужен внешний backend/gateway.

#### Akniga

Из архива:

- HTML поиск;
- book id / bid;
- ajax/bid contract;
- security key из страницы;
- CryptoJS/AES-подобная логика;
- отдельный resolver tracks;
- audio может требовать Referer/headers;
- media hosts через allowlist.

Реализовывать после Yakniga и Izib.

#### Baza Knig

Из архива:

- HTML поиск;
- strDecode;
- PlayerJS-подобные структуры;
- media через abooka host/fallback;
- нужен fallback host resolver;
- может требовать Referer/Origin.

#### Knigavuhe

Из архива:

- HTML поиск;
- BookPlayer;
- может быть LitRes trial;
- нужна cookie/new design настройка;
- поддерживать full/fragment/limited access.

#### Knigoblud

Из архива:

- HTML поиск;
- KB.playerInit;
- audio через audioknigi-like hosts;
- может быть LitRes trial;
- нужна строгая media validation.

### 8.7 Порядок переноса источников

Не реализовывать все источники сразу.

Рекомендуемый порядок:

```text
1. Yakniga
2. Izib
3. Knigavuhe
4. Knigoblud
5. Baza Knig
6. Akniga
```

Для каждого источника Codex должен сделать:

- connector class;
- parser/resolver tests;
- source health check;
- media validation;
- search mapping;
- details mapping;
- chapters mapping;
- resolveMedia mapping;
- обработку ошибок;
- mock fixture для тестов.

---

## 9. Безопасность API, токенов и “скрытие” логики

Важно понимать: если приложение распространяется пользователю, любой embedded secret можно извлечь из APK/EXE. Поэтому:

### 9.1 Что можно хранить в клиенте

Можно хранить:

- публичные host URLs;
- публичные GraphQL operation names;
- алгоритм генерации подписи, если это не настоящий секрет, а часть публичного клиента;
- source id;
- allowlist хостов;
- статические UI-цвета источников.

### 9.2 Что нельзя хранить как plain secret

Нельзя хранить в открытом виде:

- приватные API keys;
- реальные закрытые токены;
- proxy passwords;
- пользовательские credentials;
- session cookies пользователя;
- remote gateway secret.

### 9.3 Как обращаться с generated tokens

Для Izib и похожих источников:

- генерировать токен/подпись непосредственно перед запросом;
- не сохранять подпись в базе;
- не показывать в UI;
- не логировать;
- не включать в crash reports;
- в debug logs маскировать: `SIGN: ***`.

### 9.4 Если понадобится настоящий скрытый секрет

Если какой-либо источник потребует настоящий private secret, его нельзя безопасно спрятать в Android/Windows клиенте. Нужно:

- вынести запросы в собственный backend/gateway;
- клиент обращается к backend;
- backend хранит секреты;
- backend применяет rate limit;
- backend не проксирует произвольные URL;
- backend валидирует source id и book/chapter ids.

В MVP желательно избегать собственного backend и использовать только runtime-generated signatures, если они не являются приватным секретом.

---

## 10. MediaProxyService

### 10.1 Зачем нужен media proxy

Некоторые источники требуют:

- специальные headers;
- Referer;
- Origin;
- Range;
- fallback media host;
- обновление временных ссылок;
- скрытие raw media URL от UI;
- единое поведение для Android и Windows.

Поэтому архитектурно нужен `MediaProxyService`.

### 10.2 Режимы работы

Поддержать два режима:

```text
DirectMediaMode
- плеер получает direct URL + headers

LocalProxyMode
- приложение поднимает localhost proxy
- плеер получает http://127.0.0.1:<port>/media/<token>
- proxy сам достаёт реальный media URL через SourceConnector.resolveMedia()
```

Даже если первая версия играет direct URL, интерфейс `MediaProxyService` должен быть заложен сразу.

### 10.3 Требования к локальному proxy

- слушать только `127.0.0.1`;
- использовать случайный свободный порт;
- использовать одноразовые или сессионные токены;
- не принимать произвольный внешний URL от UI;
- принимать только internal media token, связанный с chapterId/sourceId;
- проверять source allowlist;
- поддерживать HTTP Range;
- поддерживать HEAD, если нужно;
- пробрасывать Content-Type, Content-Length, Accept-Ranges;
- уметь отдавать локально скачанный файл;
- уметь проксировать удалённый файл с нужными headers;
- уметь заново resolveMedia при 403/404/410;
- не логировать полный audio URL.

---

## 11. Прокси внутри приложения

### 11.1 Цель

Пользователь должен иметь возможность включить прокси прямо внутри приложения для обхода региональных блокировок или недоступности отдельных источников.

### 11.2 Типы прокси

Поддержать:

```text
- Без прокси
- Системный прокси
- HTTP proxy
- HTTPS proxy, если библиотека поддерживает
- SOCKS5 proxy
```

### 11.3 Область применения

```text
- Прокси выключен
- Прокси для всех источников
- Прокси только для выбранных источников
- Прокси только для media/audio
- Прокси только если прямое подключение не работает
```

### 11.4 Настройки proxy profile

```text
ProxyProfile
- id
- name
- type: http | socks5 | system
- host
- port
- username nullable
- password secure nullable
- useForMetadata
- useForMedia
- useForDownloads
- sourceIds[]
- testUrl/sourceHealthMode
```

Пароль хранить только в secure storage.

### 11.5 Проверка прокси

В настройках нужна кнопка “Проверить прокси”.

Проверка должна показывать:

- подключение успешно/ошибка;
- примерное время ответа;
- доступность выбранных источников через прокси;
- доступность media URL, если возможно через source health probe.

### 11.6 Proxy fallback

Режим “использовать прокси только если источник недоступен напрямую”:

1. пробуем direct;
2. если timeout, blocked, DNS error, 403/451 или configured source error — пробуем proxy;
3. результат кэшируем на короткое время;
4. в UI показываем “работает через прокси”.

---

## 12. Поиск и дедупликация

### 12.1 Виды поиска

Поиск должен поддерживать:

```text
- Всё
- Название
- Автор
- Чтец
- Цикл/серия
```

Если конкретный источник не поддерживает точный поиск по выбранному типу, connector должен:

- выполнить общий поиск;
- отфильтровать результаты локально по нормализованным полям;
- пометить confidenceScore.

### 12.2 Экран поиска

На мобильном:

- заголовок “Поиск”;
- большое поле ввода;
- кнопка поиска или action на клавиатуре;
- история поиска;
- быстрые фильтры;
- кнопка расширенных фильтров.

На Windows:

- строка поиска сверху;
- фильтры слева или сверху;
- результаты в центре;
- переключатель “список/плитка/компактно”.

На TV:

- крупная строка поиска;
- поддержка системного голосового ввода, если возможно;
- история запросов крупными кнопками;
- ввод с пульта должен быть минимально болезненным.

### 12.3 Фильтры

```text
Источники
Тип поиска
Только полные
Только бесплатные
Только скачиваемые
Показывать фрагменты
Показывать платные
Показывать неизвестный доступ
Группировать одинаковые книги
Сортировка: релевантность, название, длительность, год, источник, рейтинг
```

### 12.4 Дедупликация

Нужно реализовать два режима:

```text
- Показывать все версии отдельно
- Группировать одинаковые книги
```

Группировка должна учитывать:

- normalizedTitle;
- авторов;
- чтеца;
- серию;
- номер в серии;
- год;
- длительность;
- похожесть строк;
- source confidence.

Сгруппированная карточка должна показывать:

```text
Название
Автор
Лучший/выбранный чтец
Количество версий
Количество источников
Лучшая версия
Кнопка “Все версии”
```

Внутри карточки книги должен быть блок “Другие версии”.

---

## 13. Главная страница

### 13.1 Мобильная главная

Блоки:

```text
- Продолжить
- Начатые книги
- Скачанные для оффлайна
- Избранное
- Позже
- Последние поиски
- Рекомендации/новое, если источник поддерживает
```

Первый блок “Продолжить” должен быть крупным:

```text
[обложка с процентом]
Название
Автор/чтец
Глава 03 · 01:25:10
Продолжить с 34%
[Play]
```

### 13.2 Windows главная

- крупный блок “Продолжить”;
- сетка начатых книг;
- отдельная колонка/панель текущего плеера;
- быстрый доступ к загрузкам.

### 13.3 TV главная

- первый ряд “Продолжить”;
- второй ряд “Скачанные”;
- третий ряд “Избранное”;
- крупные карточки;
- фокус на последней книге.

---

## 14. Карточки книг

### 14.1 Маленькая карточка

Используется в списках, поиске, библиотеке.

Показывать:

- обложку;
- процент прослушивания поверх обложки, если книга начата;
- название;
- автор;
- чтец;
- длительность;
- год;
- источник;
- статус: полная/фрагмент/платная/подписка/неизвестно;
- иконку избранного;
- иконку скачать/удалить;
- индикатор оффлайн.

Кнопки скачивания/удаления делать иконками:

```text
↓  скачать
✓  скачано
⏳ в очереди
◌  скачивается
!  ошибка
🗑 удалить скачанное
```

В Flutter вместо emoji использовать SVG/Icons.

### 14.2 Большая карточка книги

Структура:

```text
Верх:
- обложка
- название
- автор
- чтец
- длительность
- год
- источник
- доступ

Действия:
- Слушать / Продолжить / Сначала
- Скачать / Удалить скачанное
- Избранное
- Позже
- Поделиться, если реализовано

Контент:
- описание
- информация
- главы
- другие версии
- похожие/серия
```

Кнопка “Слушать” меняет текст:

```text
Новая книга       -> Слушать
Есть прогресс     -> Продолжить
Прослушана        -> Сначала
Источник недоступен -> Недоступно / Сменить источник
```

---

## 15. Библиотека

Разделы:

```text
Все
Слушаю
Избранное
Позже
Скачанные
Прослушано
Закладки
История
```

Сортировки:

```text
Последнее прослушивание
Дата добавления
Название
Автор
Чтец
Прогресс
Скачанные сначала
Источник
```

Фильтры:

```text
Источник
Скачано/не скачано
Начато/не начато
Прослушано/не прослушано
Полная/фрагмент
```

Жесты в библиотеке на Android:

- свайп вправо: добавить/убрать из избранного;
- свайп влево: скачать или удалить скачанное, в зависимости от состояния;
- долгое нажатие: контекстное меню;
- destructive actions обязательно через undo/snackbar или подтверждение.

На Windows:

- правый клик открывает context menu;
- Delete может удалять только после подтверждения;
- Enter открывает книгу;
- Space управляет воспроизведением, если фокус не в поле ввода.

---

## 16. Экран загрузок

Нужен отдельный экран “Загрузки”.

Разделы:

```text
Активные
В очереди
Завершённые
Ошибки
Скачанные книги
```

Для каждой задачи показывать:

- название книги;
- глава или “книга целиком”;
- источник;
- прогресс;
- скорость загрузки;
- осталось времени;
- размер скачано/всего;
- статус;
- ошибка, если есть.

Действия:

```text
Пауза
Продолжить
Отмена
Повторить
Удалить файл
Удалить книгу
Скачать недостающие главы
Очистить завершённые
```

На Android активные загрузки должны переживать закрытие UI. Если OS убила процесс, при следующем запуске задачи должны восстановиться как paused/failed/resumable.

---

## 17. Оффлайн-загрузка

### 17.1 Что можно скачать

Пользователь может скачать:

- книгу целиком;
- отдельную главу;
- только обложку и метаданные;
- недостающие главы;
- повторить ошибочные главы.

### 17.2 Формат файлов

Не привязываться только к mp3.

Правило:

```text
Сохранять исходный формат, если он поддерживается плеером.
Если источник отдаёт mp3 — сохранить mp3.
Если m4a/ogg/aac — сохранить исходный файл.
Не транскодировать в MVP.
```

### 17.3 Структура хранения

```text
/app_data/books/
  /<sourceId>_<bookVersionId>/
    metadata.json
    cover.jpg или cover.webp
    chapters/
      001.mp3
      002.m4a
      003.ogg
```

`metadata.json` нужен для оффлайн-доступа без источника:

```json
{
  "bookId": "...",
  "bookVersionId": "...",
  "sourceId": "yakniga",
  "title": "...",
  "authors": [],
  "narrators": [],
  "chapters": []
}
```

### 17.4 Алгоритм загрузки главы

```text
1. Пользователь нажимает иконку download.
2. DownloadManager создаёт DownloadTask.
3. SourceConnector.resolveMedia(chapter, download) возвращает ResolvedMedia.
4. Проверяем allowlist URL.
5. Скачиваем во временный .part файл.
6. Поддерживаем Range/resume, если сервер позволяет.
7. После успешной загрузки атомарно переименовываем файл.
8. Обновляем localPath и downloadStatus.
9. Обновляем UI.
```

### 17.5 Удаление

Удалить можно:

- всю книгу;
- отдельную главу;
- только прослушанные главы;
- кэш обложек;
- кэш поиска;
- ошибочные временные файлы.

Удаление скачанного аудио не должно удалять историю, избранное, закладки и прогресс.

---

## 18. Плеер

### 18.1 Общая логика

Плеер должен быть отдельным сервисом, не связанным напрямую с экраном.

```text
PlaybackController / AudioService layer
- restoreLastSession()
- play(bookVersionId, chapterId, positionMs)
- pause()
- stop()
- seek(positionMs)
- seekRelative(deltaMs)
- nextChapter()
- previousChapter()
- setSpeed(speed)
- setSleepTimer(mode)
- addBookmark()
- switchSourceVersion()
```

UI, Android notification, lock screen, headset buttons, Windows mini-player и hotkeys должны обращаться к одному и тому же app-level `PlaybackController`. Flutter-пакет `audio_service` использовать как системный media/background adapter, а не как место для UI-логики.

### 18.2 Мини-плеер внутри приложения

Мини-плеер показывается над нижней навигацией на мобильном и внизу окна на Windows.

Показывать:

- обложка;
- название;
- текущая глава;
- Play/Pause;
- Next;
- тонкая полоска прогресса;
- источник/оффлайн состояние по необходимости.

Если активной книги нет — мини-плеер скрыт.

Если книга на паузе — мини-плеер остаётся.

После перезапуска приложения мини-плеер восстанавливается, если есть PlaybackSession.

### 18.3 Полноэкранный плеер

На мобильном плеер открывается по тапу на мини-плеер.

Плеер состоит из свайп-страниц:

```text
1. Сейчас играет
2. Главы
3. Закладки
4. Информация
```

Индикатор страниц обязателен.

#### Страница “Сейчас играет”

Показывать:

- обложка;
- процент прослушивания;
- название;
- автор;
- чтец, если хватает места;
- номер текущей главы;
- `глава N / всего`;
- кнопка скачать книгу;
- прогресс главы;
- текущее время главы;
- длительность главы;
- прогресс книги;
- оставшееся время книги;
- скорость;
- предыдущая глава;
- назад 15/30 сек;
- Play/Pause;
- вперёд 15/30 сек;
- следующая глава;
- таймер сна;
- закладка;
- меню “ещё”.

#### Страница “Главы”

Каждая глава:

- номер;
- название;
- длительность;
- статус “сейчас”;
- статус прослушано/частично/не начато;
- иконка play;
- иконка download/delete;
- progress для текущей главы.

Долгое нажатие:

```text
Слушать отсюда
Скачать главу
Удалить скачанное
Отметить прослушанной
Сбросить прогресс главы
Добавить закладку на начало главы
```

#### Страница “Закладки”

Показывать:

- время;
- глава;
- заметка;
- кнопка перейти;
- кнопка удалить.

Добавление:

- короткое нажатие на bookmark icon — создать закладку без заметки;
- долгое нажатие — открыть ввод заметки.

#### Страница “Информация”

Показывать:

- источник;
- доступ;
- авторы;
- чтецы;
- год;
- длительность;
- описание;
- другие версии;
- кнопка “Открыть карточку книги”;
- кнопка “Проверить источник”.

### 18.4 Скорость

Поддержать:

```text
0.5x
0.75x
1.0x
1.1x
1.25x
1.5x
1.75x
2.0x
2.5x
3.0x optional
```

Настройки:

- скорость по умолчанию;
- запоминать скорость для каждой книги;
- запоминать скорость глобально;
- отдельная скорость для чтеца/книги optional later.

### 18.5 Перемотка

Настройки:

```text
Назад: 5 / 10 / 15 / 30 / 60 сек
Вперёд: 10 / 15 / 30 / 60 сек
```

По умолчанию можно поставить назад 30 и вперёд 30, как на текущих скринах.

### 18.6 Таймер сна

Таймер сна должен уменьшаться только когда книга реально играет.

Если книга на паузе — таймер останавливается.  
Если книга снова играет — таймер продолжается.  
Если приложение закрыли и открыли — remaining time восстановить, но не запускать таймер, пока пользователь не нажал Play.

Режимы:

```text
Выкл.
10 мин
20 мин
30 мин
40 мин
50 мин
60 мин
70 мин
80 мин
90 мин
100 мин
До конца главы
Пользовательское время
```

Дополнительно:

- продлить таймер на 10/15/30 минут;
- плавное затухание громкости в конце;
- остановить в конце главы;
- optional: встряхнуть телефон для продления таймера.

---

## 19. Android media integration

На Android обязательно реализовать:

- плеер в шторке уведомлений;
- управление на экране блокировки;
- Bluetooth/headset buttons;
- play/pause;
- previous/next chapter;
- rewind/forward;
- обложка;
- название книги;
- текущая глава;
- автор;
- корректный audio focus;
- pause при отключении наушников, если включено в настройках;
- поведение при звонке;
- foreground service для playback.

Notification actions должны быть настраиваемыми, но базово:

```text
-30
Play/Pause
+30
Next
Stop optional
```

Если глава скачана, воспроизводить локальный файл.  
Если не скачана и интернет есть, играть онлайн.  
Если не скачана и интернета нет, показать понятную ошибку.

---

## 20. Windows mini-player

Нужно реализовать отдельный режим mini-player.

### 20.1 Поведение

- маленькое окно справа снизу;
- можно перемещать мышью;
- можно закрепить поверх всех окон;
- можно открепить;
- можно свернуть в трей;
- можно открыть полное приложение;
- должен сохранять последнюю позицию и размер;
- должен работать независимо от основного окна.

### 20.2 Содержимое

Мини-режим:

```text
[обложка] Play/Pause  Название
```

Компактный режим:

```text
Название книги
Глава 03 · 12:44 / 21:16
-30   Play/Pause   +30   Next
1.25x   Timer   Offline/Online
```

Расширенный режим:

```text
Обложка
Название
Глава
Прогресс
Скорость
Таймер
Источник
Play controls
```

### 20.3 Горячие клавиши Windows

Настраиваемые:

```text
Space                 Play/Pause, если фокус не в input
Ctrl + Right          Следующая глава
Ctrl + Left           Предыдущая глава
Alt + Right           +30 сек
Alt + Left            -30 сек
Ctrl + Up             Увеличить скорость
Ctrl + Down           Уменьшить скорость
Ctrl + Shift + M      Показать/скрыть mini-player
```

Media keys клавиатуры должны управлять PlaybackController / AudioService layer.

---

## 21. Управление жестами, мышью, клавиатурой и пультом

### 21.1 Android gestures

Общие правила:

- жесты должны ускорять работу, но все действия должны быть доступны и кнопками;
- destructive action не должен происходить без Undo/подтверждения;
- жесты должны быть отключаемыми в настройках, если пользователь не хочет свайпы.

Рекомендуемые жесты:

```text
Мини-плеер:
- tap: открыть полный плеер
- swipe up: открыть полный плеер
- swipe down: свернуть/скрыть полный плеер

Полный плеер:
- horizontal swipe: страницы Сейчас играет / Главы / Закладки / Информация
- vertical swipe down: закрыть full player до mini-player

Карточка книги:
- tap: открыть книгу
- swipe right: избранное/убрать из избранного
- swipe left: скачать/удалить скачанное
- long press: меню действий

Глава:
- tap: слушать
- swipe left: скачать/удалить
- swipe right: отметить прослушанной или добавить закладку, если включено
- long press: меню главы

Библиотека:
- pull to refresh для обновления данных/источников
```

### 21.2 Windows mouse/keyboard

- hover states для кнопок;
- right click context menu;
- drag mini-player;
- wheel над прогрессом optional для seek;
- keyboard navigation;
- focus outline видимый.

### 21.3 Android TV remote

- все элементы фокусируемы;
- фокус визуально очевиден;
- D-pad left/right/up/down;
- OK/select;
- Back;
- Play/Pause;
- next/previous, если пульт поддерживает;
- long press optional не должен быть единственным способом действия.

---

## 22. Настройки

Настройки должны быть разделены на группы.

### 22.1 Внешний вид

```text
Тема: системная / светлая / тёмная / AMOLED optional
Акцентный цвет
Размер текста
Компактные карточки
Показывать процент на обложках
Показывать источник на карточках
Показывать рейтинг на карточках
Анимации: полные / уменьшенные / выключены
```

### 22.2 Язык приложения

Поддержать:

```text
Русский
English
Қазақша
Беларуская
Українська
```

Важно: это язык интерфейса, а не язык результатов источников.

### 22.3 Источники

Для каждого источника:

```text
Включён/выключен
Приоритет
Использовать в общем поиске
Разрешить онлайн-прослушивание
Разрешить скачивание
Использовать прокси: авто / всегда / никогда
Таймаут
Лимит результатов
Проверить источник
Сбросить кэш источника
```

### 22.4 Какие книги показывать

```text
Полные бесплатные
Бесплатные фрагменты
Платные фрагменты
Подписка
Доступ неизвестен
Недоступные для прослушивания
```

### 22.5 Плеер

```text
Скорость по умолчанию
Запоминать скорость для каждой книги
Перемотка назад
Перемотка вперёд
Автопауза при отключении наушников
Продолжать после звонка
Показывать mini-player при запуске
Открывать последнюю книгу при запуске
```

### 22.6 Таймер сна

```text
Таймер идёт только при воспроизведении
Плавное затухание
Продление таймера
Встряхнуть для продления
Значение продления
```

### 22.7 Загрузки

```text
Только по Wi-Fi
Параллельные загрузки: 1/2/3
Папка загрузок
Скачивать обложки
Скачивать metadata.json
Скачивать только недостающие главы
Автоудаление прослушанных глав
Лимит места
Очистить кэш
Очистить временные файлы
```

### 22.8 Прокси

```text
Без прокси
Системный прокси
HTTP proxy
SOCKS5 proxy
Прокси для всех источников
Прокси только для выбранных источников
Прокси только для media
Прокси только при ошибке direct
Проверить прокси
```

### 22.9 Android

```text
Плеер в уведомлении
Плеер на экране блокировки
Кнопки гарнитуры
Поведение при звонке
Останавливать при отключении наушников
Фоновые загрузки
```

### 22.10 Windows

```text
Показывать mini-player
Mini-player поверх окон
Сворачивать в трей
Запускать с Windows
Глобальные горячие клавиши
Папка загрузок
```

### 22.11 Жесты

```text
Свайпы на карточках
Свайпы на главах
Свайп для закрытия плеера
Подтверждать удаление
Показывать Undo после действий
```

---

## 23. Ассеты и иконки

### 23.1 Общие правила

Codex должен создать или подключить аккуратную единую систему иконок.

Правила:

- использовать SVG или Flutter vector icons;
- единый стиль: rounded, 24x24, stroke 2, currentColor;
- иконки должны хорошо смотреться в светлой и тёмной теме;
- не использовать случайные картинки из интернета;
- не hotlink-ить иконки по URL;
- если используются сторонние icon sets, они должны быть open-source и добавлены в зависимости или сохранены в проект с соблюдением лицензии;
- предпочтительно использовать Material Symbols Rounded / Lucide-подобный стиль / собственные SVG;
- существующие `Book/assets/icons/*.svg` использовать как референс и при необходимости перенести.

### 23.2 Нужные группы иконок

```text
assets/icons/nav/
- home.svg
- search.svg
- library.svg
- downloads.svg
- settings.svg

assets/icons/book/
- author.svg
- narrator.svg
- duration.svg
- year.svg
- published_year.svg
- audio_year.svg
- series.svg
- genre.svg
- rating.svg
- source.svg
- language.svg
- full.svg
- fragment.svg
- paid.svg
- free.svg
- subscription.svg
- unknown_access.svg

assets/icons/player/
- play.svg
- pause.svg
- stop.svg
- previous_chapter.svg
- next_chapter.svg
- rewind_10.svg
- rewind_15.svg
- rewind_30.svg
- forward_10.svg
- forward_15.svg
- forward_30.svg
- speed.svg
- sleep_timer.svg
- bookmark.svg
- chapters.svg
- volume.svg
- volume_off.svg
- repeat.svg

assets/icons/downloads/
- download.svg
- downloading.svg
- queued.svg
- downloaded.svg
- delete_download.svg
- retry.svg
- error.svg
- pause_download.svg
- resume_download.svg

assets/icons/system/
- back.svg
- close.svg
- more.svg
- filter.svg
- sort.svg
- refresh.svg
- check.svg
- warning.svg
- info.svg
- proxy.svg
- theme.svg
- accent_color.svg
- language.svg
- trash.svg
- edit.svg
- share.svg
```

### 23.3 App icon

Создать собственный app icon, не копируя чужие бренды.

Идея:

- книга + звуковая волна;
- или открытая книга + нота;
- градиентный фон;
- хорошо читается в маленьком размере;
- adaptive icon для Android;
- `.ico` для Windows.

### 23.4 Иконки источников

Не использовать чужие логотипы без разрешения. Для источников использовать:

- текстовый chip;
- цвет источника;
- короткий код;
- optional generic source icon.

---

## 24. Дизайн-система

### 24.1 Цветовые токены

```text
background
backgroundAlt
surface
surfaceVariant
surfaceElevated
primary
primaryContainer
accent
success
warning
error
textPrimary
textSecondary
textMuted
border
disabled
overlay
```

### 24.2 Темы

```text
System
Light
Dark
AMOLED optional
```

### 24.3 Акцентный цвет

Пользователь выбирает:

```text
Бирюзовый
Синий
Фиолетовый
Зелёный
Оранжевый
Красный
Пользовательский optional
```

Акцент влияет на:

- активные кнопки;
- progress bars;
- выбранную вкладку;
- выделенную главу;
- активный пункт навигации;
- timer badge;
- focus outline на TV/Windows.

### 24.4 Компоненты

Codex должен создать переиспользуемые компоненты:

```text
AppScaffold
AdaptiveScaffold
BottomNavigation
SideNavigation
TvNavigation
BookCardCompact
BookCardLarge
BookCoverProgress
ChapterTile
DownloadIconButton
FavoriteIconButton
SourceChip
StatusChip
RatingView
MiniPlayer
FullPlayer
PlayerControlButton
SettingsTile
SettingsSection
FilterChipGroup
SearchField
EmptyState
ErrorState
LoadingState
ConfirmDialog
UndoSnackbar
```

---

## 25. Ошибки и состояния

### 25.1 Состояния источника

```text
Работает
Работает через прокси
Недоступен
Требует прокси
Ошибка API
Изменилась структура сайта
Не удалось получить главы
Не удалось получить аудио
Слишком много запросов
```

### 25.2 Состояния загрузки

```text
Не скачано
В очереди
Скачивается
Пауза
Скачано
Ошибка
Файл отсутствует
```

### 25.3 Состояния плеера

```text
Нет активной книги
Загрузка главы
Готово
Играет
Пауза
Буферизация
Ошибка воспроизведения
Глава недоступна
Файл повреждён
```

### 25.4 UX ошибок

Сообщения должны быть понятными:

```text
Не удалось открыть источник. Попробовать через прокси?
Глава недоступна. Попробовать обновить ссылку?
Файл был удалён. Скачать заново?
Нет интернета, а глава не скачана.
```

Кнопки:

```text
Повторить
Включить прокси
Сменить источник
Скачать
Удалить запись
Подробнее
```

---

## 26. Source Health Monitor

Нужно реализовать проверку источников.

Для каждого источника:

- проверить host;
- выполнить тестовый поиск;
- открыть тестовую книгу, если есть fixture;
- получить главы;
- resolveMedia для первой доступной главы;
- проверить HEAD/Range, если безопасно;
- сохранить результат.

В настройках показывать:

```text
Akniga      Работает
Yakniga     Работает
Izib        Ошибка API
Baza Knig   Аудио недоступно
```

---

## 27. Локализация

Все UI-строки должны быть вынесены в localization.

Языки:

```text
ru
en
kk
be
uk
```

В MVP можно полностью заполнить русский и английский, остальные языки подготовить структурно, но желательно заполнить базовые строки.

Не смешивать языки в коде. Не писать строки напрямую в виджетах, кроме временных debug/TODO.

---

## 28. Accessibility и удобство

Требования:

- минимальный touch target 48x48 dp;
- поддержка увеличенного системного шрифта;
- достаточный контраст;
- screen reader labels для основных кнопок;
- все иконки-кнопки должны иметь tooltip/semantics;
- focus outline для Windows/TV;
- не полагаться только на цвет;
- анимации должны учитывать reduce motion;
- destructive actions должны иметь Undo/confirm.

---

## 29. Логирование и диагностика

Нужен внутренний logger.

Логировать:

- source id;
- operation;
- status code;
- duration;
- error type;
- retry count.

Не логировать:

- полный media URL;
- SIGN;
- Authorization;
- cookies;
- proxy password;
- private tokens.

Для debug можно добавить экран “Диагностика”:

- версия приложения;
- состояние источников;
- размер кэша;
- последние ошибки без sensitive данных;
- экспорт anonymized debug log.

---

## 30. Тестирование

### 30.1 Unit tests

- duration parser;
- text normalizer;
- person parser;
- source URL validators;
- deduplication;
- progress calculation;
- download state transitions;
- sleep timer logic;
- proxy profile selection.

### 30.2 Source tests

Для каждого источника:

- search mapping;
- details mapping;
- chapter parsing;
- media validation;
- resolveMedia;
- fixture-based tests без реального интернета, где возможно.

### 30.3 UI tests

- navigation;
- mini-player visibility;
- player pages swipe;
- library filters;
- settings changes;
- download icon states.

### 30.4 Manual QA сценарии

```text
1. Найти книгу.
2. Открыть карточку.
3. Начать слушать.
4. Закрыть приложение.
5. Открыть приложение.
6. Убедиться, что mini-player восстановился.
7. Нажать Play и продолжить с того же места.
8. Скачать главу.
9. Отключить интернет.
10. Убедиться, что скачанная глава играет offline.
11. Включить таймер сна.
12. Поставить паузу.
13. Убедиться, что таймер не уменьшается.
14. Возобновить play.
15. Убедиться, что таймер продолжается.
```

---

## 31. Порядок разработки для Codex

Codex должен работать поэтапно. Не делать всё сразу.

### Этап 0. Подготовка

```text
- создать Flutter project
- настроить analysis_options
- настроить структуру папок
- добавить базовые зависимости
- добавить тему
- добавить router
- добавить mock data
```

### Этап 1. Модели и база

```text
- Book
- BookVersion
- Chapter
- AudioTrack
- PlaybackSession
- PlaybackProgress
- DownloadTask
- Bookmark
- Settings
- Drift schema
- миграции
```

### Этап 2. Дизайн-система и ассеты

```text
- theme tokens
- app icon draft
- SVG icon set
- common buttons
- chips
- book cards
- chapter tile
- empty/error/loading states
```

### Этап 3. UI на mock data

```text
- Главная
- Поиск
- Результаты поиска
- Карточка книги
- Библиотека
- Загрузки
- Настройки
- Мини-плеер
- Полный плеер
```

### Этап 4. PlaybackController / AudioService

```text
- AudioEngine abstraction
- play/pause/seek
- speed
- chapters
- session restore
- progress calculation
- sleep timer
- runtime backend state: position, buffering, completed, error
- persistence of PlaybackSession and PlaybackProgress
- local audio smoke fixture for real engine verification without network
```

### Этап 5. DownloadManager

```text
- очередь
- скачать главу
- скачать книгу
- пауза/продолжить
- удаление
- offline playback
```

Статус реализации на 2026-05-26: этап 5 реализован в ядре приложения.

```text
- DownloadManager является единым источником истины для загрузок.
- Поддержаны enqueueBook, enqueueMissingChapters, enqueueChapter.
- Поддержаны pause, resume, retry, cancel, deleteChapter, deleteBook.
- Скачивание идёт через .part файл с атомарным rename после успеха.
- Поддержан resume по существующему .part файлу и Range-capable клиент.
- Задачи сохраняются в Drift download_tasks.
- running задачи после перезапуска восстанавливаются как paused/resumable.
- Успешные загрузки обновляют Chapter.localPath, fileSizeBytes, downloadStatus и downloadProgress.
- Удаление скачанного аудио не удаляет историю, избранное, закладки и playback progress.
- Плеер получает оффлайн-главы через AudioMediaSource.file.
- Экран "Загрузки" и icon-only действия на карточках подключены к DownloadManager.
```

### Этап 6. SourceConnector framework

```text
- SourceConnector interface
- SourceRegistry
- SourceCapabilities
- SourceHealth
- shared parser helpers
- media validators
```

### Этап 7. Первый источник Yakniga

```text
- search
- details
- chapters
- resolveMedia
- download
- tests
```

### Этап 8. Izib

```text
- GraphQL
- SIGN generation
- no logging tokens
- search
- details
- files
- tests
```

### Этап 9. Остальные источники

```text
- Knigavuhe
- Knigoblud
- Baza Knig
- Akniga
```

### Этап 10. Android integration

```text
- notification player
- lock screen controls
- headset buttons
- audio focus
- foreground service
```

### Этап 11. Windows integration

```text
- desktop layout
- mini-player
- tray
- media keys
- hotkeys
- folder picker
```

### Этап 12. Android TV

```text
- TV layout
- focus navigation
- remote controls
- TV player
- TV search
```

---

## 32. Правила работы Codex

Codex обязан:

- не ломать архитектуру ради быстрого результата;
- не класть business logic в widgets;
- после каждого этапа запускать format/analyze/tests;
- писать понятные TODO, если что-то зависит от платформы;
- добавлять tests для parser/logic;
- не добавлять случайные зависимости без причины;
- не использовать copyrighted network assets;
- не хранить secrets в коде;
- не логировать sensitive data;
- делать UI адаптивным с самого начала;
- сохранять совместимость mobile/tablet/desktop/TV.

---

## 33. Acceptance criteria для MVP

MVP считается успешным, если:

```text
1. Приложение запускается на Android и Windows.
2. Есть светлая/тёмная тема и акцентный цвет.
3. Есть Главная, Поиск, Карточка книги, Библиотека, Настройки.
4. Есть mini-player и full-player.
5. Есть восстановление последней книги и позиции после перезапуска.
6. Есть подсчёт процента прослушивания по сумме глав.
7. Есть загрузка отдельной главы и книги целиком.
8. Скачанная глава играет без интернета.
9. Есть настройки источников.
10. Есть хотя бы один реальный источник, лучше Yakniga.
11. Есть базовые иконки для автора, чтеца, длительности, года, серии, рейтинга, download/delete, play/pause, перемотки, таймера.
12. На Android работает background playback.
13. На Android есть notification/lock screen controls.
14. На Windows есть хотя бы базовый mini-player или подготовленная архитектура под него.
15. Ошибки источников и загрузок показываются понятно.
```

---

## 34. Финальная цель

Финальное приложение должно ощущаться как полноценный удобный аудиокнижный клиент:

- пользователь быстро находит книгу;
- понимает, какие версии доступны;
- может слушать онлайн;
- может скачать книгу или главы;
- всегда возвращается на то же место;
- видит прогресс на обложке;
- управляет плеером из приложения, шторки, lock screen, клавиатуры, mini-player или пульта;
- может настроить источники, прокси, тему, язык, загрузки и жесты;
- на любом устройстве интерфейс выглядит не как порт, а как родной удобный режим.

Главное техническое правило:

> Источники, плеер, загрузки, прокси и база — это ядро. Android UI, Windows UI и Android TV UI — это разные оболочки над одним ядром.
