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

Для Izib, Akniga и похожих источников:

- генерировать SIGN/token непосредственно перед запросом;
- извлечённые security keys источников использовать только для текущего сетевого контракта;
- не сохранять в базе;
- не писать в UI;
- не логировать;
- не включать в crash/debug reports;
- маскировать в debug: `SIGN: ***`, `security_ls_key: ***`;
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

Metadata boundary для HTML-источников (2026-09-05): `SourceMetadataPolicy` применяется в Akniga/Baza Knig/Knigavuhe/Knigoblud clients, включая injected transport, и повторно в общем `SourceMetadataTransport` перед каждым native HTTP request. `sourceBookId`/`sourceUri` из deeplink не могут выбирать произвольный host. Отклоняются credentials, схемы вне http/https, protocol-relative book IDs и hosts вне source allowlist. Разрешённый исходный URL не даёт разрешения на redirect к другому host: каждый Location проверяется до отправки запроса, automatic redirects отключены, лимит переходов — 5. Ошибка не содержит полный URL/credentials. Для локальных HTTP fixtures тесты передают отдельную явную policy; production defaults остаются source-only.

Существующие session cookies HTML-транспортов остаются только в памяти, без записи на диск и логирования. Cookie scope учитывает host-only/Domain, Path, Secure и срок действия (Max-Age имеет приоритет над Expires). Domain cookie отклоняется, если домен не соответствует выдавшему её host или выходит за metadata policy источника; разрешённые alias redirects не теряют session-контекст.

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

## 12. Обновления и публичная инфраструктура

### 12.1 Текущий updater: GitHub Releases + SHA256

По явному решению владельца от 2026-09-05 update metadata и файлы берутся напрямую
из публичного **Dushnyj/Slovofon** через HTTPS. Единственный discovery endpoint:

```text
https://api.github.com/repos/Dushnyj/Slovofon/releases/latest
```

Источник доверия — этот фиксированный GitHub repository и HTTPS transport, а не
серверный Ed25519 manifest. SHA256 обязателен для проверки целостности, но hash и
metadata размещены у того же издателя на GitHub: это не независимая подпись
издателя. Отказ от прежней серверной подписи согласован владельцем.

Требования к текущему клиенту:

- Не принимать другой owner/repository, arbitrary release URL или файл из ответа,
  не принадлежащий выбранному release. Версия tag и имя artifact должны совпадать.
- Автоматически устанавливать только Android universal release APK или Windows
  x64 `setup.exe` установленной схемы именования. ABI APK/AAB/MSI/ZIP/MSIX не
  подставляются вместо отсутствующего поддерживаемого installer; их возможная
  публикация для ручной загрузки не разрешает автоматический запуск.
- Не использовать draft/prerelease как stable update. GitHub release/asset ID
  нельзя интерпретировать как build number.
- Выполнять запросы без GitHub token, credentials, cookies и Authorization headers.
  Публичный API rate limit обрабатывается как ошибка/повтор, а не повод добавить
  токен в приложение или переключиться на старый сервер.
- Разрешать download только из GitHub release assets с проверкой каждого HTTPS
  redirect к разрешённым GitHub CDN hosts. HTTP downgrade, URL с credentials и
  произвольный внешний redirect запрещены.
- Получать ожидаемый SHA256 из валидного `digest` выбранного API asset
  (`sha256:<64 hex>`). При отсутствии digest использовать точную запись имени
  artifact в `SHA256SUMS.txt` **того же release**; checksum другого релиза или
  неопределённое/неоднозначное соответствие не принимаются.
- Не устанавливать файл без валидного ожидаемого SHA256. Перед запуском вычислить
  hash скачанных bytes; несовпадение блокирует установку.
- Ограничить filename одним безопасным basename внутри временной update-папки.
  Release metadata не может задавать абсолютный путь или выход через `..`.
- Не делать fallback к серверному `latest.json`, зеркалу, unsigned manifest или
  загрузке без hash при ошибке GitHub. Ошибки API/сети не подменять успешным
  результатом «обновлений нет».

Android APK/AAB продолжает подписываться прежним утверждённым upload/release key;
системная проверка package/signing certificate при установке не отключается.
Windows signing config и certificates этим переходом не меняются. Открытие APK
или запуск Windows installer по-прежнему требует согласия пользователя.

### 12.2 Публичные ссылки и секреты

В клиенте допустимы только публичные HTTPS product/API/repository URLs. Ссылки на
сайт продукта или контакты не делают соответствующий host разрешённым transport
для обновлений. Updater использует только GitHub-контракт раздела 12.1.

Запрещено встраивать или коммитить:

```text
IP/VPS address
SSH login/password/key
BOT_TOKEN
GITHUB_TOKEN
database credentials
private update/signing keys
```

### 12.3 Исторический Ed25519 manifest — legacy

Серверный update manifest с key id `slovofon-updates-2026-06` относится к старому
updater. Текущий GitHub updater не читает этот manifest, не использует его подпись
и не обращается к старому серверу как к fallback. Это изменение не является
изменением Android APK signing и не затрагивает подпись сетевых источников книг.

Private keys старой схемы остаются вне клиента, Git, CI logs и release artifacts.
Переход не разрешает удалять, читать, переносить, ротировать или загружать эти ключи.
Старые установленные клиенты могут продолжать пользоваться прежним сервером;
отключать его или менять конфигурацию `SlovofonBot` без отдельной команды нельзя.

---

## 13. Зависимости

Все сторонние зависимости и ассеты должны быть отражены в `THIRD_PARTY_NOTICES.md`.
