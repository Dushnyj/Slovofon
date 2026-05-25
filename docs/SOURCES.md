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
1. Yakniga
2. Izib
3. Knigavuhe
4. Knigoblud
5. Baza Knig
6. Akniga
```

---

## 6. Особенности источников

### Yakniga

GraphQL, API-режим предпочтителен, главы через `chapters.collection`, `fileUrl` как media source, есть авторы/чтецы/серии/rating/price/access flags.

### Izib

GraphQL API, SIGN генерируется на месте, package key/body signature, поиск/книга/серия/files, HTML/XSPlayer fallback. SIGN не хранить и не логировать.

### Akniga

HTML поиск, book id/bid, ajax/bid contract, security key из страницы, CryptoJS/AES-подобная логика, resolver tracks, Referer/headers, media allowlist.

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
