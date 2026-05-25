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

---

## 6. Имена артефактов

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
Slovofon-v0.0.1-windows-x64-msix.msix
```

Артефакты:

```text
artifacts/v<version>/
```

---

## 7. Windows installer

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

## 8. Android package

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

## 9. Release checklist

```text
1. VERSION совпадает с pubspec.yaml.
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
```
