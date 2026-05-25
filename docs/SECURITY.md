# SECURITY.md — безопасность Slovofon

Этот документ описывает безопасность API, токенов, прокси, пользовательских данных, логов и media proxy. Обязательные правила Codex находятся в `AGENTS.md`.

---

## 1. Главный принцип

Slovofon — клиентское приложение. Всё, что зашито в APK/EXE, потенциально можно извлечь. Поэтому приложение не должно содержать настоящих приватных секретов.

Если источник требует настоящий private secret, его нельзя безопасно хранить в клиенте. Нужно остановиться, спросить владельца и рассмотреть backend/gateway.

---

## 2. Что можно хранить в клиенте

Можно хранить:

- публичные host URLs;
- публичные GraphQL operation names;
- source id;
- allowlist доменов;
- алгоритм генерации подписи, если он не является приватным секретом;
- статические UI-цвета источников;
- несекретные capabilities источников.

---

## 3. Что нельзя хранить открыто

Нельзя хранить в обычных настройках, JSON, базе или коде:

- приватные API keys;
- закрытые токены;
- proxy passwords;
- пользовательские credentials;
- session cookies пользователя;
- remote gateway secret;
- signing keys;
- приватные сертификаты;
- полные sensitive headers.

---

## 4. Runtime-generated SIGN/token

Для Izib и похожих источников:

- генерировать SIGN/token непосредственно перед запросом;
- не сохранять в базе;
- не писать в UI;
- не логировать;
- не включать в crash/debug reports;
- маскировать в debug: `SIGN: ***`;
- хранить алгоритм в connector/service, а не в UI.

---

## 5. Proxy credentials

ProxyProfile:

```text
id
name
type: http | socks5 | system
host
port
username nullable
password secure nullable
useForMetadata
useForMedia
useForDownloads
sourceIds[]
```

Пароль хранить только в secure storage. Codex не должен менять системный proxy Windows/Android.

---

## 6. Media allowlist

Для каждого источника должны быть allowlist домены для metadata/media/cover.

Нельзя проксировать или скачивать произвольный URL, переданный из UI.

MediaProxyService принимает только internal token, связанный с sourceId/bookVersionId/chapterId.

---

## 7. MediaProxyService security

Требования:

- слушать только `127.0.0.1`;
- использовать случайный свободный port;
- использовать сессионные/одноразовые media tokens;
- не принимать произвольный внешний URL;
- проверять sourceId и chapterId;
- проверять allowlist;
- поддерживать Range безопасно;
- не логировать полный media URL;
- не отдавать файлы вне разрешённой app data/downloads папки;
- не позволять path traversal;
- очищать просроченные tokens.

---

## 8. Пользовательские данные

Пользовательские данные:

```text
настройки
история поиска
избранное
закладки
прогресс
последняя позиция
скачанные книги
кэш источников
proxy profiles
```

Нельзя удалять без подтверждения. При uninstall данные сохраняются по умолчанию.

---

## 9. Логирование

Логировать можно:

- source id;
- operation;
- HTTP status code;
- duration;
- error type;
- retry count;
- masked URL host/path without query where safe;
- download task id;
- app version;
- platform.

Не логировать:

- полный media URL;
- SIGN;
- Authorization;
- cookies;
- proxy password;
- private tokens;
- raw headers;
- полный body signed requests;
- персональные данные пользователя;
- local full paths, если они могут раскрывать имя пользователя Windows.

---

## 10. Debug export

Экспорт диагностики должен быть anonymized. Он не должен включать proxy passwords, tokens, cookies, raw signed headers, full media URLs, скачанные книги и персональные пути пользователя без маскирования.

---

## 11. Зависимости

Все сторонние зависимости и ассеты должны быть отражены в `THIRD_PARTY_NOTICES.md`.
