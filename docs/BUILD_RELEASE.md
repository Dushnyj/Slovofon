# BUILD_RELEASE.md — сборка, версии, установщики и релизы Slovofon

Этот документ описывает bootstrap, сборку, релизы, GitHub, версии, установщики и имена артефактов. Обязательные правила поведения Codex находятся в `AGENTS.md`.

---

## 1. Версия проекта

Использовать Semantic Versioning:

```text
MAJOR.MINOR.PATCH
```

Стартовая версия:

```text
0.0.1
```

Файлы версии:

```text
VERSION
pubspec.yaml
CHANGELOG.md
```

`pubspec.yaml`:

```yaml
version: 0.0.1+1
```

Версия меняется только по прямой команде, при подготовке релиза или если задача явно требует bump version.

---

## 2. Roadmap версий

```text
0.0.1 -> стартовый каркас проекта, документация, базовая архитектура
0.0.2 -> исправления стартового каркаса
0.1.0 -> первый UI MVP на mock/local data
0.2.0 -> плеер + восстановление позиции + прогресс
0.3.0 -> загрузки/offline
0.4.0 -> первые реальные источники
0.5.0 -> Android notification/lock screen
0.6.0 -> Windows mini-player
0.7.0 -> Android TV
1.0.0 -> первый стабильный публичный релиз
```

---

## 3. Главный скрипт проекта

Главный скрипт:

```text
tools/slovofon.ps1
```

Опционально:

```text
tools/slovofon.sh
```

Команды:

```text
bootstrap       проверить и подготовить окружение
check           проверить зависимости и состояние проекта
doctor          расширенная диагностика окружения
get             flutter pub get
format          dart format .
analyze         flutter analyze
test            flutter test
build           собрать Android, Windows или оба таргета
version         показать или изменить версию
release         подготовить релизные артефакты, tag и GitHub Release после подтверждения
clean           безопасная очистка build/cache без удаления пользовательских данных
```

Примеры:

```powershell
./tools/slovofon.ps1 bootstrap
./tools/slovofon.ps1 check
./tools/slovofon.ps1 build -Target android
./tools/slovofon.ps1 build -Target windows
./tools/slovofon.ps1 build -Target all
./tools/slovofon.ps1 version -Set 0.1.0 -BuildNumber 10
./tools/slovofon.ps1 release -Version 0.1.0 -Target all
```

Скрипт не должен спрашивать версию при каждой сборке.

---

## 4. Bootstrap после клонирования

После клонирования:

```powershell
./tools/slovofon.ps1 bootstrap
```

Проверить:

```text
Git
GitHub CLI optional
Flutter SDK
Dart SDK
Android SDK
Android platform tools
Android build tools
Android licenses
Java/JDK для Android-сборки
Visual Studio Build Tools / Desktop development with C++ для Windows Flutter
Windows SDK
Inno Setup или другой утверждённый installer tool
PowerShell version
наличие pub packages
наличие l10n/generated files
наличие нужных asset files
```

Можно автоматически делать `flutter pub get`. Нельзя молча устанавливать системные компоненты. Перед установкой Visual Studio Build Tools, Android SDK, JDK, Inno Setup или изменением PATH нужно спросить пользователя.

---

## 5. GitHub

Репозиторий:

```text
https://github.com/Dushnyj/Slovofon.git
```

Codex не должен молча создавать публичный репозиторий. Для создания нужен подтверждённый `public`/`private`.

### 5.1 GitHub Actions CI

Основной workflow:

```text
.github/workflows/ci.yml
```

CI запускается на `push` и `pull_request` для `main`, а также вручную через `workflow_dispatch`.

Проверки:

```text
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
flutter build windows --debug
```

Workflow использует Flutter `3.44.0` stable и минимальные права `contents: read`.

Debug-сборки публикуются как временные GitHub Actions artifacts:

```text
Slovofon-v<version>-android-universal-debug.apk
Slovofon-v<version>-windows-x64-debug
```

Эти artifacts не являются release-сборкой, не подписываются, не создают Git tag и не публикуются в GitHub Release.

### 5.2 GitHub Actions release

Основной release workflow:

```text
.github/workflows/release.yml
```

Запуск:

```text
workflow_dispatch
push tag v*
```

Release workflow делает полный публичный релиз:

```text
1. проверяет VERSION, pubspec.yaml и `lib/app/app_version.dart`;
2. выполняет dart format, flutter analyze и flutter test;
3. восстанавливает Android upload keystore из GitHub Secrets во временный файл runner;
4. собирает signed Android universal APK, ABI APKs и AAB;
5. проверяет APK через apksigner verify;
6. собирает Windows release bundle;
7. при наличии Windows PFX secrets подписывает Slovofon.exe;
8. собирает Windows portable ZIP;
9. собирает Windows setup.exe через Inno Setup;
10. собирает Windows MSI через WiX Toolset 6.0.2;
11. при наличии Windows PFX secrets подписывает setup.exe и MSI;
12. считает SHA256SUMS.txt;
13. создаёт tag, если workflow запущен вручную и tag ещё отсутствует;
14. создаёт или обновляет GitHub Release.
```

Android signing secrets обязательны для release workflow. Windows signing secrets опциональны: если их нет, Windows artifacts собираются, но остаются unsigned и Windows может показать `Unknown Publisher`.

### 5.3 Канал обновлений приложения

Клиентское приложение должно использовать только публичные HTTPS-домены, без IP, SSH-данных, bot token, GitHub token или других секретов.

Публичные URL обновлений:

```text
Base:   https://slovofon-updates.duckdns.org
Stable: https://slovofon-updates.duckdns.org/v1/channels/stable/latest.json
Beta:   https://slovofon-updates.duckdns.org/v1/channels/beta/latest.json
```

Базовая логика клиента:

```text
1. Android и Windows по умолчанию проверяют канал stable.
2. status == no_release означает, что публичного обновления нет.
3. status == available означает, что клиент сравнивает version/build с текущей сборкой.
4. mandatory == true означает обязательное обновление.
5. assets выбираются по platform/arch/kind.
6. Перед доверием manifest обязательно проверить Ed25519 signature через встроенный public key.
7. Перед установкой или запуском файла обязательно проверить sha256.
```

Android без Google Play не может обновиться полностью бесшовно: клиент может скачать APK, проверить `sha256` и открыть системный установщик, а пользователь подтвердит установку. Windows-клиент может скачать installer/MSIX/portable artifact, проверить `sha256` и запускать установку только после явного согласия пользователя.

Серверная публикация выполняется ботом `Dushnyj/SlovofonBot`: он опрашивает GitHub Releases, зеркалирует подходящие artifacts в `updates/v1/files/`, считает `sha256`, подписывает manifest Ed25519, атомарно обновляет `latest.json` для `stable` и `beta`, а затем публикует сообщение в Telegram-канал. В клиентский manifest не попадают `GITHUB_TOKEN`, `BOT_TOKEN`, SSH/IP, Ed25519 private key или другие приватные данные.

Текущий формат manifest:

```json
{
  "schema": 2,
  "app": "slovofon",
  "channel": "stable",
  "status": "available",
  "version": "0.0.2",
  "build": 2,
  "published_at": "2026-06-01T12:00:00Z",
  "mandatory": false,
  "release_url": "https://github.com/Dushnyj/Slovofon/releases/tag/v0.0.2",
  "release_notes": "Release notes",
  "signature": {
    "alg": "ed25519",
    "key_id": "slovofon-updates-2026-06",
    "value": "..."
  },
  "assets": [
    {
      "platform": "android",
      "arch": "universal",
      "kind": "apk",
      "url": "https://slovofon-updates.duckdns.org/v1/files/Slovofon-v0.0.2-android-universal-release.apk",
      "file_name": "Slovofon-v0.0.2-android-universal-release.apk",
      "sha256": "...",
      "size": 12345678
    }
  ]
}
```

---

## 6. Подпись релизов и секреты

Release-подпись нужна отдельно от debug-сборок:

- Android debug APK подписывается временным debug-ключом Flutter/Android SDK автоматически.
- Android release APK/AAB должен быть подписан release/upload key.
- Windows debug bundle не подписывается.
- Windows release installer/MSIX/portable EXE должен быть подписан перед публичным распространением.

Codex не должен создавать, менять, загружать, удалять или ротировать signing keys без явной команды владельца.

### 6.1 Где хранить ключи

Ключи и сертификаты не хранятся в Git.

Локальное защищённое хранилище владельца проекта:

```text
%USERPROFILE%\Documents\Slovofon\secrets\android\slovofon-upload.jks
%USERPROFILE%\Documents\Slovofon\secrets\windows\slovofon-code-signing.pfx
C:\Secrets\Slovofon\updates\update-manifest-ed25519-private.pem
```

Допустимые альтернативы:

```text
password manager с attachment support
зашифрованный внешний носитель
защищённое корпоративное хранилище секретов
Azure Trusted Signing / Azure Artifact Signing для Windows
```

Обязательна offline backup-копия Android key. Потеря Android signing/upload key может заблокировать нормальные обновления приложения или потребовать процедуры reset в магазине.

### 6.2 Что хранится в Git

В Git можно хранить только шаблоны и инструкции:

```text
android/key.properties.example
docs/BUILD_RELEASE.md
docs/SECURITY.md
.gitignore
```

В Git запрещено хранить:

```text
android/key.properties
*.jks
*.keystore
*.pfx
*.p12
*.pem
*.key
пароли
base64 secret values
```

### 6.3 Android signing

Основной вариант для будущего релиза:

```text
Google Play: AAB + upload key + Play App Signing
Внешнее распространение APK: release APK подписывается тем же утверждённым release/upload key
```

Планируемый файл ключа:

```text
slovofon-upload.jks
```

Планируемый alias:

```text
slovofon-upload
```

Локальный файл настроек Gradle:

```text
android/key.properties
```

Он создаётся владельцем из шаблона:

```text
android/key.properties.example
```

Структура файла:

```properties
storeFile=C:\\Users\\<user>\\Documents\\Slovofon\\secrets\\android\\slovofon-upload.jks
storePassword=<keystore-password>
keyAlias=slovofon-upload
keyPassword=<key-password>
```

`android/key.properties` не коммитится.

GitHub Actions secrets для Android release:

```text
ANDROID_UPLOAD_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_PASSWORD
ANDROID_KEY_ALIAS
```

Release workflow `.github/workflows/release.yml`:

1. брать `ANDROID_UPLOAD_KEYSTORE_BASE64` из GitHub Secrets;
2. декодировать keystore во временный путь runner, например `$RUNNER_TEMP/slovofon-upload.jks`;
3. создавать `android/key.properties` на runner только на время job;
4. запускать `flutter build appbundle --release` и/или `flutter build apk --release`;
5. переименовывать итоговые artifacts по правилам проекта;
6. не печатать секреты, пароли, base64 или путь к постоянному локальному key storage в логах;
7. удалять временный keystore/key.properties в конце job, если job дошёл до cleanup.

### 6.4 Windows signing

Для Windows есть три режима:

```text
dev/test: self-signed certificate, только для локальной проверки
public direct download: trusted code signing certificate или Azure Trusted Signing / Azure Artifact Signing
Microsoft Store / MSIX Store flow: подпись по правилам Store submission
```

Для публичного EXE/installer предпочтительно использовать trusted code signing, иначе Windows будет показывать `Unknown Publisher`, а SmartScreen может блокировать или пугать пользователя.

Для MSIX подпись является обязательной частью установки: publisher в package manifest должен соответствовать certificate subject.

Планируемый файл сертификата, если выбран PFX-вариант:

```text
slovofon-code-signing.pfx
```

GitHub Actions secrets для Windows PFX signing:

```text
WINDOWS_SIGNING_CERTIFICATE_BASE64
WINDOWS_SIGNING_CERTIFICATE_PASSWORD
```

Release workflow с PFX:

1. декодировать PFX во временный путь runner;
2. импортировать или передать его в signing tool только на время job;
3. подписать `Slovofon.exe`, installer `.exe`, `.msi` и/или `.msix`;
4. использовать timestamp server, если это поддерживает выбранный signing tool;
5. не печатать пароль, base64 или thumbprint с привязкой к приватному хранилищу в логах;
6. удалить временный PFX после signing.

Предпочтительный будущий вариант для публичного Windows-релиза:

```text
Azure Trusted Signing / Azure Artifact Signing
```

В этом варианте приватный ключ не попадает в GitHub Secrets как файл. Release workflow получает право подписи через Azure identity/credentials, а подпись выполняется управляемым сервисом.

### 6.5 Когда включать release signing

### 6.5 Update manifest signing

Manifest обновлений подписывается Ed25519:

```text
Private key: C:\Secrets\Slovofon\updates\update-manifest-ed25519-private.pem
Public key:  C:\Secrets\Slovofon\updates\update-manifest-ed25519-public.pem
Key id:      slovofon-updates-2026-06
```

На VPS private key хранится вне Git, например:

```text
/opt/slovofon-bot/data/update-manifest-ed25519-private.pem
```

Переменные бота:

```env
UPDATE_MANIFEST_PRIVATE_KEY_FILE=/app/data/update-manifest-ed25519-private.pem
UPDATE_MANIFEST_KEY_ID=slovofon-updates-2026-06
```

Клиент хранит только public key и отвергает unsigned/tampered manifest до выбора asset и до проверки `sha256`.

### 6.6 Когда включать release signing

Release signing включается только после отдельного подтверждения владельца проекта.

Перед включением нужно утвердить:

```text
Android distribution path: Google Play AAB, direct APK или оба
Windows distribution path: setup.exe, portable.zip, MSIX, Store или несколько вариантов
Windows signing provider: PFX certificate или Azure Trusted Signing
место хранения master backup ключей
набор GitHub Secrets
процедуру восстановления/ротации
```

---

## 7. Имена артефактов

Формат:

```text
Slovofon-v<version>-<platform>-<arch>-<type>.<ext>
```

Запрещены неясные имена:

```text
app-release.apk
setup.exe
build.zip
runner.exe
install.exe
```

Android:

```text
Slovofon-v0.0.1-android-universal-release.apk
Slovofon-v0.0.1-android-arm64-v8a-release.apk
Slovofon-v0.0.1-android-armeabi-v7a-release.apk
Slovofon-v0.0.1-android-x86_64-release.apk
Slovofon-v0.0.1-android-release.aab
```

Windows:

```text
Slovofon-v0.0.1-windows-x64-setup.exe
Slovofon-v0.0.1-windows-x64-portable.zip
Slovofon-v0.0.1-windows-x64-msi.msi
Slovofon-v0.0.1-windows-x64-msix.msix
```

Артефакты:

```text
artifacts/v<version>/
```

---

## 8. Windows installer

Режимы:

```text
Just me / Только для меня
All users / Для всех пользователей
```

Пути:

```text
All users: %ProgramFiles%\Slovofon
Just me:   %LocalAppData%\Programs\Slovofon
```

Metadata:

```text
Application name: Slovofon
Application version: <version>
Publisher: Slovofon Team
Manufacturer: Slovofon Team
Executable: Slovofon.exe
Start menu folder: Slovofon
Desktop shortcut: optional checkbox
Launch after install: optional checkbox
```

Установщик не должен без согласия добавлять автозапуск, менять associations, firewall, system proxy или удалять пользовательские данные.

---

## 9. Android package

```text
applicationId: com.slovofon.app
```

Display name:

```text
ru: Словофон
other locales: Slovofon
```

Ожидаемые permissions:

```text
INTERNET
ACCESS_NETWORK_STATE
FOREGROUND_SERVICE
FOREGROUND_SERVICE_MEDIA_PLAYBACK
POST_NOTIFICATIONS, если требуется Android-версией
WAKE_LOCK, только если обосновано playback/download behavior
```

Storage permissions избегать.

---

## 10. Release checklist

```text
1. VERSION совпадает с pubspec.yaml и `lib/app/app_version.dart`.
2. Android versionCode увеличен.
3. Windows metadata обновлена.
4. CHANGELOG.md обновлён.
5. dart format выполнен.
6. flutter analyze выполнен.
7. flutter test выполнен.
8. ThemePreviewScreen проверен в light/dark.
9. Нет white-on-white / black-on-black проблем.
10. Нет hardcoded secrets.
11. Нет sensitive данных в логах.
12. Артефакты названы по правилам.
13. Установщик Windows предлагает Program Files для all-users и LocalAppData для just-me.
14. Android display name локализован.
15. Git status чистый или изменения объяснены.
16. Git tag создан только после подтверждения.
17. GitHub Release создан только после подтверждения.
18. Android release подписан утверждённым release/upload key.
19. Windows release artifacts подписаны утверждённым certificate/provider, если распространяются публично.
20. Signing secrets не попали в Git, логи, artifacts или crash/debug reports.
```
