# ARCHITECTURE.md — архитектура Slovofon / Словофон

Этот документ описывает внутреннюю архитектуру приложения. Обязательные правила Codex находятся в `AGENTS.md`, продуктовые требования — в `docs/SLOVOFON_TECHNICAL_SPEC_RU.md`.

---

## 1. Главный принцип

Slovofon разрабатывается как единое ядро с разными оболочками:

```text
Core / Domain / Services / Data / Sources — общие для всех платформ
Android UI                              — оболочка для смартфонов и планшетов
Android TV UI                           — оболочка для ТВ и пульта
Windows UI                              — desktop-оболочка
Windows mini-player                     — отдельная компактная оболочка над PlaybackController
```

Нельзя делать три разных приложения с разной бизнес-логикой. Android, Android TV и Windows должны использовать одни и те же модели, репозитории, источники, плеер, загрузки, прогресс и настройки.

---

## 2. Слои приложения

```text
lib/
├─ app/          — запуск, роутинг, lifecycle, локализация, тема
├─ core/         — общие утилиты, ошибки, network, security, storage, platform
├─ domain/       — модели, use cases, интерфейсы репозиториев
├─ data/         — database, repository implementations, cache, mappers
├─ sources/      — SourceConnector и адаптеры источников
├─ services/     — audio, downloads, media_proxy, proxy, source_health
├─ features/     — экраны и state конкретных фич
└─ ui/           — переиспользуемые компоненты, adaptive widgets, dialogs, cards
```

Зависимости направлены вниз:

```text
UI -> feature controller/notifier -> use case -> repository/service -> data/source/network
```

Запрещено:

- UI напрямую обращается к HTTP источника;
- UI напрямую скачивает файл;
- source parser импортирует UI;
- PlaybackController зависит от конкретного экрана;
- DownloadManager зависит от конкретной карточки книги.

---

## 3. Основные сервисы

### 3.1 PlaybackController / AudioService layer

Единый источник истины для воспроизведения.

В коде приложения сервис состояния называется `PlaybackController`, чтобы не
конфликтовать с Flutter-пакетом `audio_service`. Пакет `audio_service`
используется только для системной Android/media-интеграции: foreground service,
notification, lock screen и media buttons.

Обязанности:

- восстановить последнюю сессию;
- играть онлайн и оффлайн;
- слушать runtime-состояние audio backend: позицию, загрузку, буферизацию, завершение и ошибку;
- переключать главы;
- хранить текущую позицию;
- считать прогресс;
- сохранять PlaybackSession и PlaybackProgress в локальную базу без уменьшения максимального достигнутого прогресса;
- управлять скоростью;
- управлять таймером сна;
- отдавать состояние mini-player/full-player/notification/Windows mini-player;
- реагировать на media buttons;
- безопасно переходить между локальным файлом и онлайн URL.

### 3.2 DownloadManager

Единый источник истины для загрузок.

Обязанности:

- очередь задач;
- скачивание главы;
- скачивание книги целиком;
- пауза/продолжение;
- повтор ошибок;
- удаление скачанного;
- atomic temp files;
- resume через Range, если поддерживается сервером;
- обновление статусов в базе;
- восстановление задач после перезапуска.

Текущая реализация Stage 5:

- `DownloadManager` живёт в `lib/services/downloads/download_manager.dart`;
- `DownloadClient` открывает `AudioMediaSource.url`, `AudioMediaSource.file` и `AudioMediaSource.asset`, передаёт headers, поддерживает Range для URL/file/asset и отдаёт поток байт в manager;
- `FileDownloadStorage` хранит книги в app-specific папке `books/<sourceId>_<bookVersionId>/`, пишет `metadata.json`, скачивает главы в `chapters/NNN.part` и после успеха атомарно переименовывает в финальный файл;
- `DriftDownloadPersistenceStore` сохраняет `DownloadTask`, обновляет `Chapter.localPath`, `Chapter.fileSizeBytes`, `downloadStatus` и `downloadProgress`, а при рестарте переводит `running` задачи в `paused`;
- удаление скачанного аудио удаляет только offline files/tasks и не трогает PlaybackSession, PlaybackProgress, избранное, закладки и историю;
- UI получает состояние через `downloadManagerProvider`; widgets не скачивают файлы напрямую.

### 3.3 SourceRegistry

Хранит все доступные источники и настройки их включения.

Обязанности:

- зарегистрировать коннекторы;
- применить source settings;
- вызвать поиск по нескольким источникам;
- объединить ошибки;
- отдать capabilities;
- запускать health checks.

### 3.4 ProxyManager

Управляет proxy profiles внутри приложения.

Обязанности:

- выбрать direct/system/http/socks5;
- применить proxy к metadata/media/downloads;
- поддержать source-specific proxy;
- проверить прокси;
- не менять системный proxy Windows/Android;
- не хранить proxy password вне secure storage.

### 3.5 MediaProxyService

Локальный proxy-layer для воспроизведения и загрузок проблемных источников.

Обязанности:

- слушать только `127.0.0.1`;
- выдавать плееру локальный URL по internal media token;
- не принимать произвольный внешний URL;
- поддерживать Range/HEAD;
- подставлять headers/Referer/Origin;
- проверять media allowlist;
- отдавать локальные файлы;
- обновлять временные media URLs при 403/404/410.

---

## 4. Основные модели

`Book` — логическая книга.  
`BookVersion` — конкретная версия из конкретного источника.  
`Chapter` — пользовательская глава в интерфейсе.  
`AudioTrack` — реальный аудиофайл/поток.  
`PlaybackSession` — активная книга и позиция для восстановления.  
`PlaybackProgress` — прогресс по книге и главам.  
`DownloadTask` — загрузка книги, главы, обложки или metadata.

Разделение `Book` и `BookVersion` обязательно, потому что одна книга может быть найдена на нескольких источниках с разными чтецами, длительностями, обложками и статусами доступа.

---

## 5. Потоки данных

### 5.1 Поиск

```text
SearchScreen
-> SearchController
-> SearchBooksUseCase
-> SourceRegistry.search()
-> SourceConnector.search()
-> normalize BookSearchResult
-> DeduplicationService
-> SearchRepository cache/history
-> UI results
```

### 5.2 Открытие книги

```text
BookDetailsScreen
-> BookDetailsController
-> GetBookDetailsUseCase
-> SourceConnector.getBookDetails()
-> SourceConnector.getChapters()
-> Database upsert Book/BookVersion/Chapter
-> UI details
```

### 5.3 Воспроизведение

```text
User taps Play
-> PlaybackController.play(bookVersionId, chapterId, position)
-> check localPath
-> if local exists: play local file
-> else SourceConnector.resolveMedia(playback)
-> MediaProxyService or direct URL
-> AudioEngine
-> AudioEngine snapshots update position/buffering/completed/error
-> persist PlaybackSession/Progress
-> update mini-player/full-player/notification
```

### 5.4 Загрузка

```text
User taps Download
-> DownloadManager.enqueueBook/enqueueChapter()
-> use already resolved AudioMediaSource from book/chapter
-> SourceConnector.resolveMedia(download) when real source connectors are attached
-> validate media allowlist at source/media boundary
-> download to .part file
-> verify size/content
-> atomic rename
-> update Chapter.localPath
-> update DownloadTask completed
-> offlinePlaybackBook overlays local files as AudioMediaSource.file
```

---

## 6. Adaptive UI

Mobile: bottom navigation, mini-player, full-player через tap/swipe, жесты.  
Tablet: two-pane layout, список слева, детали справа.  
Windows: sidebar, top search, center content, right inspector, bottom player, mini-player.  
Android TV: focus navigation, D-pad, крупные карточки, TV player.

---

## 7. Правила расширения

Новая фича — отдельный feature module.  
Новый источник — новая папка `sources/<source_id>/` и реализация `SourceConnector`.  
Платформенное поведение — через abstraction layer, а не `if (Platform.is...)` во всех виджетах.
