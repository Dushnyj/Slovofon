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

Signing secrets также нельзя хранить в Git, release artifacts, debug export, crash reports, screenshots, CI logs или issue descriptions.

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

## 11. Release signing secrets

Release signing keys подтверждают, что сборка действительно выпущена владельцем Slovofon. Поэтому они относятся к критическим секретам проекта.

### 11.1 Android

Android release-сборки требуют signing key:

```text
slovofon-upload.jks
```

Назначение:

```text
подписывать Android App Bundle для Google Play
подписывать release APK для внешнего распространения, если такой канал будет утверждён
обеспечивать возможность обновления приложения тем же package id: com.slovofon.app
```

Локально ключ хранится вне репозитория, например:

```text
%USERPROFILE%\Documents\Slovofon\secrets\android\slovofon-upload.jks
```

Локальные пароли и путь к ключу задаются в:

```text
android/key.properties
```

Этот файл запрещено коммитить. В Git хранится только безопасный шаблон:

```text
android/key.properties.example
```

Будущие GitHub Secrets:

```text
ANDROID_UPLOAD_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_PASSWORD
ANDROID_KEY_ALIAS
```

### 11.2 Windows

Windows release-сборки должны подписываться перед публичным распространением, чтобы пользователь видел корректного publisher и чтобы снизить риск SmartScreen/Defender warning.

Варианты:

```text
PFX code signing certificate
Azure Trusted Signing / Azure Artifact Signing
self-signed certificate только для dev/test
```

Если используется PFX:

```text
slovofon-code-signing.pfx
```

Локальное хранение:

```text
%USERPROFILE%\Documents\Slovofon\secrets\windows\slovofon-code-signing.pfx
```

Будущие GitHub Secrets:

```text
WINDOWS_SIGNING_CERTIFICATE_BASE64
WINDOWS_SIGNING_CERTIFICATE_PASSWORD
```

Если используется Azure Trusted Signing / Azure Artifact Signing, приватный ключ не хранится файлом в репозитории или GitHub Secrets. В CI должны храниться только минимально необходимые credentials/OIDC configuration для доступа к signing service.

### 11.3 Правила CI

Release workflow должен:

- восстанавливать ключи только во временную папку runner;
- создавать signing config только на время job;
- не печатать секреты, base64, пароли и приватные пути в logs;
- не прикреплять ключи к artifacts;
- не кэшировать signing files;
- удалять временные signing files после завершения job, если cleanup возможен;
- падать с ошибкой, если нужного секрета нет, вместо fallback на debug signing.

### 11.4 Компрометация ключа

Если Android key, Windows certificate, пароль или GitHub Secret могли утечь:

1. остановить release workflow;
2. удалить/rotate соответствующие GitHub Secrets;
3. проверить Git history, Actions logs, artifacts и локальные машины;
4. для Android следовать процедуре reset/upload key replacement в выбранном магазине;
5. для Windows отозвать certificate или отключить compromised signing identity у provider;
6. выпустить security note в changelog/release notes, если был затронут публичный релиз.

---

## 12. Зависимости

Все сторонние зависимости и ассеты должны быть отражены в `THIRD_PARTY_NOTICES.md`.
