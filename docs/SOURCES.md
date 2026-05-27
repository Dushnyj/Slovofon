# SOURCES.md — источники аудиокниг и адаптеры Slovofon

Этот документ описывает источники, SourceConnector и правила работы с API/HTML/media. Обязательные правила Codex находятся в `AGENTS.md`, безопасность — в `docs/SECURITY.md`.

---

## 1. Reference implementation

К проекту приложен архив сайта `Book.zip`. Его использовать как эталон поведения источников, но не переносить слепо.

Важные части:

```text
server.py
server_sources/
sources/client/
assets/icons/
styles.css
```

`server_sources/*.py` — серверная логика источников, API, медиа-валидация, специальные методы получения треков, headers, fallback.

`sources/client/*.js` — клиентские парсеры, нормализация карточек, деталей книги, глав, циклов, статусов доступа.

---

## 2. Поддерживаемые источники

```text
knigavuhe
izib
akniga
baza_knig
knigoblud
yakniga
```

Каждый источник реализуется через `SourceConnector`.

---

## 3. SourceConnector

Статус реализации на 2026-05-27: базовый framework Stage 6 реализован в `lib/sources/`, реальные connector-ы Stage 7/8 — Izib и Akniga. Приложение использует их в UI-пути поиска, карточки источника, плеера и загрузок через `SourceCatalogService`.

```dart
abstract class SourceConnector {
  String get id;
  String get name;
  String get host;
  String get color;
  SourceCapabilities get capabilities;
  SourceMediaPolicy get mediaPolicy;

  Future<List<BookSearchResult>> search(SearchRequest request);
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref);
  Future<List<Chapter>> getChapters(SourceBookRef ref);
  Future<List<AudioTrack>> getAudioTracks(SourceBookRef ref);
  Future<ResolvedMedia> resolveMedia(Chapter chapter, MediaResolvePurpose purpose);
  Future<SourceHealth> checkHealth();
}
```

Файлы Stage 6:

```text
lib/sources/source_connector.dart        — единый интерфейс SourceConnector
lib/sources/source_models.dart           — SearchRequest, BookSearchResult, SourceHealth, ResolvedMedia, errors
lib/sources/source_registry.dart         — регистрация источников, search aggregation, capabilities, health checks
lib/sources/source_media_validator.dart  — проверка media allowlist и URL safety
lib/sources/source_parser_helpers.dart   — общие чистые parser helpers
lib/sources/mock/mock_source_connector.dart — локальный mock connector для тестов без сети
lib/sources/sources.dart                 — public barrel export
```

Файлы Stage 7 Izib:

```text
lib/sources/izib/izib_signer.dart          — package key и runtime SIGN generation
lib/sources/izib/izib_graphql_client.dart  — GraphQL transport/client и безопасная обработка API ошибок
lib/sources/izib/izib_mapper.dart          — нормализация search/details/files в доменные source модели
lib/sources/izib/izib_source_connector.dart — SourceConnector для search/details/chapters/tracks/resolveMedia/health
test/sources/izib/                         — fixture-based тесты без live network и без хранения SIGN
```

Файлы Stage 7 app integration:

```text
lib/services/sources/source_catalog_service.dart  — app-level mapping из SourceConnector в UI/playback модели
lib/services/sources/source_catalog_provider.dart — Riverpod providers для SourceRegistry и SourceCatalogService
lib/features/search/search_screen.dart            — реальный source-поиск вместо mock-only выдачи
lib/features/source_books/                        — details экран реальной source-книги
test/services/sources/                            — service tests для SourceCatalogService
test/ui/stage7_izib_app_integration_test.dart     — widget flow: search -> details -> playback/downloads
```

Файлы Stage 8 Akniga:

```text
lib/sources/akniga/akniga_security.dart          — CryptoJS/OpenSSL-compatible AES-CBC hash для ajax/bid
lib/sources/akniga/akniga_client.dart            — HTML/ajax transport, LiveStreet key extraction, cookies/session, headers
lib/sources/akniga/akniga_mapper.dart            — HTML/details/ajax tracks -> source domain models
lib/sources/akniga/akniga_source_connector.dart  — SourceConnector для search/details/chapters/tracks/resolveMedia/health
test/sources/akniga/                             — fixture-based тесты и optional live smoke-test
```

`MediaResolvePurpose`:

```text
playback
download
probe
```

---

## 4. SourceCapabilities

```text
supportsSearch
supportsSearchByTitle
supportsSearchByAuthor
supportsSearchByNarrator
supportsSearchBySeries
supportsDetails
supportsChapters
supportsSeries
supportsRating
supportsDescription
supportsDirectAudio
supportsDownload
supportsFragments
supportsPaidItems
requiresSpecialHeaders
requiresMediaProxy
hasTemporaryUrls
hasApiSignature
hasHtmlParser
hasGraphQlApi
```

---

## 5. Порядок реализации источников

```text
1. Izib
2. Akniga
3. Yakniga
4. Knigavuhe
5. Knigoblud
6. Baza Knig
```

---

## 6. Особенности источников

### Yakniga

GraphQL, API-режим предпочтителен, главы через `chapters.collection`, `fileUrl` как media source, есть авторы/чтецы/серии/rating/price/access flags.

### Izib

GraphQL API, SIGN генерируется на месте, package key/body signature, поиск/книга/серия/files, HTML/XSPlayer fallback. SIGN не хранить и не логировать.

Статус на 2026-05-26: реализован как первый реальный источник Stage 7. Используется GraphQL endpoint `https://api.izib.uk/graphql/`, SIGN генерируется внутри `IzibGraphQlClient` на каждый body, media URL валидируются через `SourceMediaPolicy` до playback/download. Поиск Izib не отдаёт `files`, поэтому доступ в search results остаётся `unknown` до загрузки details.

Media allowlist Izib на 2026-05-26:

```text
metadata: izib.uk, api.izib.uk
cover:    izib.uk
media:    izib.uk, *.audioknigi.xyz
```

`*.audioknigi.xyz` нужен для реальных URL глав, которые Izib возвращает в `files.mobile/full` (`r4.audioknigi.xyz`, `r7.audioknigi.xyz` и аналогичные поддомены). Произвольные hosts и URL с credentials по-прежнему запрещены.

App integration на 2026-05-27:

- `SearchScreen` выполняет поиск по включённым источникам Izib и Akniga через `SourceCatalogService`;
- поиск запускается только по search action/кнопке, сохраняется в историю и фильтруется в приложении по выбранному полю: название, автор, чтец или цикл;
- фильтр требует, чтобы все слова запроса совпадали как префиксы слов результата независимо от порядка, например `Дыхание зоны` и `зоны дыхание`;
- source details экран загружает details, chapters и playback media перед стартом книги/главы;
- source details показывает первые 5 глав длинной книги по умолчанию и раскрывает остальные по действию пользователя;
- `PlaybackController` получает `AudioPlaybackBook` с `sourceId=izib`, `sourceBookId`, cover URL, description, genre, year/source URL и главами;
- `DownloadManager` принимает те же source playback books для загрузки книги или главы;
- `LibraryStore` сохраняет избранные source-книги в Drift и отдаёт тот же статус сердцу на карточке поиска и библиотеке;
- карточка результата показывает play/download loading только во время загрузки details/media, а активная загрузка отображается как круговой прогресс с отменой всей книги;
- экран загрузок группирует source download tasks по книгам, даёт общие pause/resume/retry/delete действия для книги, а главы показывает только внутри раскрытой карточки;
- UI не вызывает `IzibSourceConnector` напрямую.

### Akniga

HTML поиск, book id/bid, ajax/bid contract, security key из страницы, CryptoJS/AES-подобная логика, resolver tracks, Referer/headers, media allowlist.

Статус на 2026-05-27: реализован как второй реальный источник Stage 8. Используется HTML search/details с `https://akniga.org/search/books/page{page}/?q={q}`, `article[data-bid]`/`.bookpage--chapters[data-bid]` для `bid`, `LIVESTREET_SECURITY_KEY` из страницы и `POST https://akniga.org/ajax/bid/{bid}`. Транспорт хранит cookies между page GET и ajax POST, потому что `ajax/bid` требует session-like контекст.

Media allowlist Akniga на 2026-05-27:

```text
metadata: akniga.org, www.akniga.org
cover:    akniga.org, www.akniga.org
media:    akniga.org, *.akniga.club, *.audioknigi.xyz
```

Особенности:

- request body `ajax/bid` содержит `bid`, `hash` и `security_ls_key`;
- `hash` генерируется на runtime через OpenSSL-compatible MD5 KDF + AES-CBC/PKCS7, совместимо с CryptoJS passphrase mode;
- LiveStreet security key не хранится в базе и не выводится в UI/logs;
- `resolveMedia` отдаёт direct URL с `User-Agent`, `Accept` и `Referer`;
- fixture-тесты не ходят в сеть, optional live smoke-test включается только через `SLOVOFON_LIVE_SOURCE_TESTS=1`.

### Baza Knig

HTML поиск, strDecode, PlayerJS-подобные структуры, abooka host/fallback, Referer/Origin.

### Knigavuhe

HTML поиск, BookPlayer, LitRes trial, cookie/new design, full/fragment/limited access.

### Knigoblud

HTML поиск, `KB.playerInit`, audioknigi-like hosts, LitRes trial, строгая media validation.

---

## 7. Media validation

Для каждого источника должны быть allowlist домены:

```text
metadata hosts
media hosts
cover hosts, если нужно
```

Реализованная Stage 6 проверка:

```text
- URL media разрешены только со схемой http/https;
- URL с userInfo/credentials запрещены;
- host должен совпадать с mediaHosts или быть subdomain разрешённого host;
- file/asset media запрещены по умолчанию и разрешаются только через allowLocalMedia;
- validator вызывается на source/media boundary до playback/download использования.
```

При 403/404/410:

```text
1. invalidate cached media URL;
2. вызвать resolveMedia заново;
3. если не удалось — показать понятную ошибку;
4. предложить повторить/сменить источник/включить прокси.
```

---

## 8. Source Health Monitor

Проверять host, тестовый поиск, тестовую книгу, главы, resolveMedia, HEAD/Range если безопасно.

Stage 6 содержит модель `SourceHealth`, `SourceHealthStatus` и `SourceRegistry.checkHealth()`. Реальные сетевые проверки конкретных источников добавляются вместе с соответствующим connector, начиная с Izib.

Статусы:

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

---

## 9. Тесты источников

Для каждого источника нужны parser fixtures, search/details/chapter/media tests. Реальные сетевые тесты должны быть optional.

Stage 6 тесты:

```text
test/sources/source_registry_test.dart
test/sources/source_media_validator_test.dart
test/sources/source_parser_helpers_test.dart
test/sources/mock_source_connector_test.dart
```
