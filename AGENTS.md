# AGENTS.md — постоянные правила Codex для проекта Slovofon / Словофон

Этот файл должен лежать в корне репозитория `Slovofon` и является обязательной инструкцией для Codex и любых ИИ-агентов, работающих над проектом.

Codex обязан читать этот файл перед началом любой задачи и сверяться с ним при изменении архитектуры, зависимостей, версии, сборки, установщика, Git/GitHub, источников, плеера, загрузок, ассетов, безопасности, тем и пользовательских данных.

Если правило из этого файла конфликтует с временной просьбой в чате, Codex обязан остановиться и уточнить у владельца проекта. Если правило из этого файла конфликтует с техническим ТЗ, то правила безопасности, версионности, сборки, Git/GitHub, секретов, критических действий и пользовательских данных из `AGENTS.md` имеют приоритет.

---

## 0. Карта документации и зоны ответственности

Codex должен использовать документы так:

```text
AGENTS.md                              — постоянные правила Codex, запреты, подтверждения, Git, версии, релизы
docs/SLOVOFON_TECHNICAL_SPEC_RU.md     — продуктово-техническое ТЗ: функции, UX, платформы, MVP
docs/ARCHITECTURE.md                   — архитектура, слои, модули, сервисы, модели, data flow
docs/BUILD_RELEASE.md                  — bootstrap, сборка, версии, артефакты, установщики, GitHub Release
docs/SECURITY.md                       — секреты, API, токены, прокси, пользовательские данные, логи
docs/THEMING.md                        — цвета, темы, контраст, ThemePreviewScreen
docs/SOURCES.md                        — источники, адаптеры, SourceConnector, media allowlist
CHANGELOG.md                           — история изменений по версиям
THIRD_PARTY_NOTICES.md                 — сторонние библиотеки, ассеты, иконки, лицензии
README.md                              — краткое описание и быстрый старт
VERSION                                — текущая публичная версия
```

Если информация оказалась не в том файле, Codex должен перенести её в правильный документ, обновить ссылки и кратко объяснить перенос в отчёте.

---

## 1. Идентичность проекта

### 1.1 Название продукта

Приложение называется:

- для русской локализации: **Словофон**;
- для английской, казахской, белорусской, украинской и любых других локализаций: **Slovofon**.

Внутреннее техническое имя проекта, пакета, репозитория, исполняемых файлов и сборочных артефактов: **Slovofon**.

Запрещено без подтверждения владельца менять:

- название продукта;
- написание `Словофон`;
- написание `Slovofon`;
- package/application id;
- publisher/manufacturer;
- app icon concept;
- versioning scheme;
- GitHub repository URL.

### 1.2 Технические имена

Использовать следующие значения, пока владелец проекта явно не утвердит другие:

```text
Repository: https://github.com/Dushnyj/Slovofon.git
Dart package name: slovofon
Flutter project name: slovofon
Android applicationId: com.slovofon.app
Windows executable name: Slovofon.exe
Windows AppUserModelID: Slovofon.App
Product name: Slovofon
Russian display name: Словофон
Default display name: Slovofon
Publisher / Manufacturer: Slovofon Team
Copyright: Copyright © Slovofon Team
```

Если позже появится юридическое лицо, ИП или другой официальный производитель, Codex должен спросить владельца и только после подтверждения заменить `Slovofon Team` в установщиках, metadata, Windows resources и документации.

---

## 2. Git, GitHub и репозиторий

### 2.1 Основной репозиторий

Основной удалённый репозиторий проекта:

```text
https://github.com/Dushnyj/Slovofon.git
```

После создания проекта Codex должен инициализировать полноценный Git-репозиторий и настроить remote:

```bash
git init
git remote add origin https://github.com/Dushnyj/Slovofon.git
```

Если репозиторий на GitHub ещё не существует, Codex может создать его только если:

1. GitHub CLI (`gh`) установлен;
2. пользователь авторизован в GitHub CLI;
3. владелец проекта подтвердил видимость репозитория: public или private;
4. владелец подтвердил действие создания репозитория.

Codex не должен молча создавать публичный репозиторий. Если видимость не указана, обязательно спросить.

Рекомендуемая команда после подтверждения владельца:

```bash
gh repo create Dushnyj/Slovofon --public --source . --remote origin --push
```

или для приватного репозитория:

```bash
gh repo create Dushnyj/Slovofon --private --source . --remote origin --push
```

### 2.2 Ветки

Рекомендуемая структура веток:

```text
main       — стабильная ветка, релизы и теги
dev        — текущая разработка
feature/*  — отдельные крупные задачи
fix/*      — исправления
release/*  — подготовка релиза, если нужно
```

Для одиночной разработки допускается работать в `main`, но перед release-сборкой обязательно проверить статус, тесты, changelog и теги.

### 2.3 Коммиты

Codex должен делать осмысленные коммиты небольшими логическими порциями.

Формат сообщений коммитов:

```text
type(scope): краткое описание
```

Типы:

```text
feat      новая функция
fix       исправление
refactor  рефакторинг без изменения поведения
ui        изменения интерфейса
docs      документация
build     сборка, скрипты, зависимости
ci        CI/CD
chore     обслуживание
security  безопасность
release   подготовка релиза
```

Примеры:

```text
feat(player): add playback session restore
ui(theme): add contrast-safe snackbar styles
build(release): add unified build script
```

### 2.4 Push

Codex может выполнять `git push` только если пользователь явно поручил вести проект через GitHub или выполнить задачу с пушем.

Перед push Codex обязан проверить:

```bash
git status
flutter analyze
flutter test
```

Если проверки не могут быть выполнены, Codex обязан описать причину в отчёте.

### 2.5 Теги и GitHub Releases

Git tag для релиза:

```text
v0.0.1
v0.0.2
v0.1.0
```

Codex не должен создавать tag/release без явной команды владельца на релиз.

При создании релиза Codex обязан:

1. обновить версию;
2. обновить `CHANGELOG.md`;
3. собрать артефакты;
4. проверить имена файлов;
5. создать Git tag;
6. создать GitHub Release;
7. прикрепить артефакты сборки;
8. добавить release notes из changelog.

Рекомендуемая команда GitHub CLI:

```bash
gh release create v0.0.1 artifacts/* --title "Slovofon v0.0.1" --notes-file RELEASE_NOTES.md
```

Если GitHub CLI недоступен, Codex должен подготовить файлы и инструкции, но не имитировать успешный релиз.

### 2.6 CHANGELOG

В репозитории обязателен файл:

```text
CHANGELOG.md
```

Формат:

```markdown
# Changelog

## [0.0.1] - YYYY-MM-DD

### Added
- ...

### Changed
- ...

### Fixed
- ...

### Security
- ...
```

Codex обязан обновлять changelog при значимых изменениях и перед каждым релизом.

---

## 3. Версионность

### 3.1 Формат версии

Использовать Semantic Versioning:

```text
MAJOR.MINOR.PATCH
```

Стартовая версия:

```text
0.0.1
```

В `pubspec.yaml` использовать:

```yaml
version: 0.0.1+1
```

Где:

- `0.0.1` — публичная версия приложения;
- `+1` — build number / Android versionCode.

### 3.2 Правила изменения версии

До стабильного публичного релиза использовать ветку `0.x.x`.

Рекомендуемый roadmap версий:

```text
0.0.1 -> стартовый каркас проекта, базовая архитектура
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

Codex не имеет права самовольно переходить к `1.0.0` или менять `MAJOR` без подтверждения владельца.

### 3.3 Кто меняет версию

Codex должен уметь менять версию через унифицированный build/release script, но менять версию только:

- по прямой команде пользователя;
- при подготовке релиза;
- если задача явно требует bump version.

В обычных задачах Codex не должен каждый раз менять версию.

### 3.4 Файлы версии

В репозитории должны быть:

```text
pubspec.yaml
CHANGELOG.md
VERSION
```

`VERSION` содержит только публичную версию:

```text
0.0.1
```

При release-сборке обновлять:

- `VERSION`;
- `pubspec.yaml`;
- Android build metadata;
- Windows resource metadata;
- installer metadata;
- `CHANGELOG.md`;
- release notes.

---

## 4. Единый build/bootstrap/release script

### 4.1 Главный скрипт

В проекте должен быть единый главный скрипт для обслуживания проекта:

```text
tools/slovofon.ps1
```

Дополнительно можно создать bash-обёртку для Linux/macOS:

```text
tools/slovofon.sh
```

Но главный поддерживаемый скрипт для Windows-разработки — `tools/slovofon.ps1`.

### 4.2 Назначение скрипта

Скрипт должен уметь:

```text
bootstrap       проверить и подготовить окружение
check           проверить зависимости и состояние проекта
doctor          расширенная диагностика окружения
get             выполнить flutter pub get
format          форматирование
analyze         flutter analyze
test            flutter test
build           собрать Android, Windows или оба таргета
version         показать или изменить версию
release         подготовить релизные артефакты, tag и GitHub Release после подтверждения
clean           безопасная очистка build/cache без удаления пользовательских данных
```

Примеры:

```powershell
./tools/slovofon.ps1 check
./tools/slovofon.ps1 bootstrap
./tools/slovofon.ps1 build -Target android
./tools/slovofon.ps1 build -Target windows
./tools/slovofon.ps1 build -Target all
./tools/slovofon.ps1 build -Target all -Configuration release
./tools/slovofon.ps1 version -Set 0.1.0 -BuildNumber 10
./tools/slovofon.ps1 release -Version 0.1.0 -Target all
```

### 4.3 Ввод версии

Скрипт не должен спрашивать версию при каждой сборке.

Версия меняется только если:

```text
- пользователь передал -Version или -Set;
- пользователь запустил release;
- пользователь явно выбрал bump version в интерактивном режиме.
```

Если версия не указана, build использует текущую версию из `VERSION`/`pubspec.yaml`.

### 4.4 Проверка окружения после клонирования

После клонирования репозитория на другом ПК пользователь должен иметь возможность выполнить:

```powershell
./tools/slovofon.ps1 bootstrap
```

Скрипт должен проверить:

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

### 4.5 Автоматическая установка зависимостей

Правило:

- проектные зависимости Flutter/Dart можно докачивать через `flutter pub get` автоматически;
- системные компоненты нельзя устанавливать молча;
- большие компоненты нельзя скачивать молча;
- перед установкой системных компонентов скрипт должен спросить пользователя.

Пример поведения:

```text
Не найден Visual Studio Build Tools.
Он нужен для сборки Windows-версии.
Установить через winget? [Y/N]
```

```text
Не найден Android SDK Platform 35.
Он нужен для Android-сборки.
Установить через sdkmanager? [Y/N]
```

Если автоматическая установка невозможна, скрипт должен вывести понятные ручные инструкции.

### 4.6 Что скрипт не должен делать без спроса

Скрипт не должен без подтверждения:

- устанавливать Visual Studio Build Tools;
- устанавливать Android Studio;
- устанавливать JDK;
- менять системный PATH;
- принимать Android licenses;
- устанавливать Inno Setup;
- создавать GitHub repo;
- делать push;
- создавать release;
- удалять build artifacts старых релизов;
- удалять пользовательские данные;
- удалять скачанные книги;
- менять версию.

---

## 5. Сборочные артефакты и имена файлов

### 5.1 Общий формат

Все финальные артефакты сборки должны называться:

```text
Slovofon-v<version>-<platform>-<arch>-<type>.<ext>
```

Пример:

```text
Slovofon-v0.0.1-windows-x64-setup.exe
```

Запрещено отдавать пользователю файлы с неясными именами:

```text
app-release.apk
setup.exe
build.zip
runner.exe
install.exe
```

### 5.2 Android artifacts

```text
Slovofon-v0.0.1-android-universal-release.apk
Slovofon-v0.0.1-android-arm64-v8a-release.apk
Slovofon-v0.0.1-android-armeabi-v7a-release.apk
Slovofon-v0.0.1-android-x86_64-release.apk
Slovofon-v0.0.1-android-release.aab
```

Для Android TV, если отдельный build/flavor:

```text
Slovofon-v0.0.1-android-tv-universal-release.apk
Slovofon-v0.0.1-android-tv-release.aab
```

### 5.3 Windows artifacts

```text
Slovofon-v0.0.1-windows-x64-setup.exe
Slovofon-v0.0.1-windows-x64-portable.zip
Slovofon-v0.0.1-windows-x64-msix.msix
```

На первом этапе достаточно:

```text
Slovofon-v0.0.1-windows-x64-setup.exe
Slovofon-v0.0.1-windows-x64-portable.zip optional
```

### 5.4 Artifacts directory

Release-артефакты складывать в:

```text
artifacts/v<version>/
```

Пример:

```text
artifacts/v0.0.1/Slovofon-v0.0.1-windows-x64-setup.exe
artifacts/v0.0.1/Slovofon-v0.0.1-android-universal-release.apk
```

`artifacts/` можно не хранить в Git, но release artifacts должны прикрепляться к GitHub Release.

---

## 6. Windows installer

### 6.1 Почему не только `%LocalAppData%`

`%LocalAppData%\Programs\Slovofon` удобен для установки “только для текущего пользователя” без прав администратора. Но классический вариант для установки “для всех пользователей” — `C:\Program Files\Slovofon`.

Для Slovofon нужно поддержать оба режима.

### 6.2 Режимы установки

Installer должен предлагать режим установки, если выбранный installer framework это поддерживает:

```text
Just me / Только для меня
All users / Для всех пользователей
```

Пути по умолчанию:

```text
All users: %ProgramFiles%\Slovofon
Just me:   %LocalAppData%\Programs\Slovofon
```

Если installer запущен без прав администратора и пользователь выбрал `All users`, installer должен запросить elevation или предложить переключиться на `Just me`.

### 6.3 Базовая информация установщика

```text
Application name: Slovofon
Application version: <version>
Publisher: Slovofon Team
Manufacturer: Slovofon Team
Executable: Slovofon.exe
Start menu folder: Slovofon
Default all-users install folder: %ProgramFiles%\Slovofon
Default per-user install folder: %LocalAppData%\Programs\Slovofon
Desktop shortcut: optional checkbox
Launch after install: optional checkbox
```

### 6.4 Обязательные пункты установщика

Установщик должен предлагать:

```text
- выбрать режим установки: только для меня / для всех пользователей, если возможно;
- выбрать папку установки;
- создать ярлык на рабочем столе;
- создать ярлык в меню Пуск;
- запустить Slovofon после установки;
- не удалять пользовательские данные при обновлении;
- при uninstall отдельно спросить про удаление пользовательских данных.
```

### 6.5 Что установщик не должен делать без спроса

Установщик не должен без явного согласия пользователя:

- добавлять автозапуск с Windows;
- менять file associations;
- менять системные proxy/system settings;
- создавать firewall rules;
- запускать background service;
- удалять пользовательские данные при обновлении;
- удалять папку загрузок при uninstall;
- удалять настройки, прогресс, закладки и историю.

### 6.6 Uninstall

Пользовательские данные сохранять по умолчанию.

Если uninstall предлагает удалить данные, checkbox должен быть выключен по умолчанию и иметь понятный текст:

```text
Удалить пользовательские данные Slovofon: настройки, историю, прогресс, закладки и скачанные аудиокниги.
```

---

## 7. Android package и metadata

### 7.1 Application ID

Использовать:

```text
com.slovofon.app
```

Изменение `applicationId` после начала разработки запрещено без подтверждения владельца.

### 7.2 Display name

```text
ru: Словофон
other locales: Slovofon
```

### 7.3 Permissions

Добавлять только реально необходимые permissions.

Ожидаемые permissions:

```text
INTERNET
ACCESS_NETWORK_STATE
FOREGROUND_SERVICE
FOREGROUND_SERVICE_MEDIA_PLAYBACK
POST_NOTIFICATIONS, если требуется Android-версией
WAKE_LOCK, только если обосновано playback/download behavior
```

Storage permissions избегать. Скачанные книги хранить в app-specific storage. Для внешней пользовательской папки использовать системный picker/SAF, если потребуется.

---

## 8. Цвета, темы и защита от “белый текст на белом фоне”

### 8.1 Главная проблема

В приложении нельзя допускать ситуации, когда на одном устройстве/эмуляторе цвета выглядят нормально, а на другом фоне текст, кнопки, snackbar, dialog, notification-like blocks или bottom sheets становятся нечитаемыми: например белый текст на белом фоне или чёрный текст на чёрном фоне.

### 8.2 Жёсткие правила темы

Codex обязан использовать единую дизайн-систему и semantic colors.

Запрещено:

- массово использовать `Colors.white` и `Colors.black` напрямую в widgets;
- задавать цвет текста без понимания цвета фона;
- задавать background у snackbar/dialog/card без соответствующего foreground;
- использовать разные несвязанные палитры для экранов;
- делать отдельные “ручные” цвета для light/dark без проверки контраста;
- полагаться на системные дефолты, если компонент кастомный.

Обязательно:

- использовать `ThemeData` и `ColorScheme`;
- использовать пары `primary/onPrimary`, `surface/onSurface`, `error/onError`, `secondary/onSecondary`;
- для кастомных цветов иметь функцию подбора контрастного foreground;
- все UI-компоненты брать цвета из `AppTheme`, `AppColorTokens` или `Theme.of(context).colorScheme`;
- все состояния кнопок иметь readable foreground/background;
- snackbar, dialogs, bottom sheets, menu, tooltip, chips и cards должны иметь явно заданные цвета через theme extensions;
- accent color должен пересчитывать related on-colors;
- в тёмной, светлой и AMOLED теме все компоненты должны быть проверены.

### 8.3 Theme preview screen

Codex должен создать внутренний экран/страницу предпросмотра темы:

```text
ThemePreviewScreen
```

На нём должны отображаться:

```text
- кнопки всех типов;
- icon buttons;
- chips;
- cards;
- book cards;
- chapter tiles;
- snackbar preview;
- dialog preview;
- bottom sheet preview;
- text fields;
- progress bars;
- download states;
- player controls;
- error/warning/success states;
- source chips;
- TV focus state;
- Windows hover/focus state.
```

Перед релизом Codex обязан проверить ThemePreviewScreen в:

```text
- light theme;
- dark theme;
- AMOLED theme, если есть;
- каждом акцентном цвете;
- увеличенном размере шрифта;
- compact/normal card mode.
```

### 8.4 Контраст

Минимальное правило:

- обычный текст должен иметь достаточный контраст относительно фона;
- вторичный текст должен оставаться читаемым;
- disabled элементы должны выглядеть disabled, но не исчезать полностью;
- selected/focused states должны быть видимы на TV и Windows.

Если Codex генерирует новый компонент, он обязан проверить его в light/dark теме.

### 8.5 Android notification colors

Android media notification использует системные стили. Codex не должен пытаться насильно сделать кастомную нотификацию, которая ломается на разных Android-оболочках, если стандартная MediaStyle решает задачу лучше.

Для notification/lock screen:

- использовать стандартный media session / media notification style;
- передавать корректные metadata: title, artist/author, chapter, artwork;
- не использовать кастомные белые/чёрные тексты на неизвестном системном фоне.

---

## 9. Критические действия: когда Codex обязан спросить

Codex обязан остановиться и спросить владельца перед любым действием ниже.

### 9.1 Удаление или риск потери данных

Спрашивать перед:

- удалением базы данных;
- удалением миграций;
- удалением папки загрузок;
- удалением скачанных книг;
- удалением пользовательских настроек;
- удалением закладок, истории, прогресса;
- сбросом local storage;
- изменением схемы базы, которое может привести к потере данных;
- массовым переименованием файлов, влияющим на сохранённые пути;
- `git clean -fdx`;
- `git reset --hard`;
- удалением ветки;
- force push.

### 9.2 Изменение идентичности приложения

Спрашивать перед изменением:

- названия `Словофон` / `Slovofon`;
- package/application id;
- publisher/manufacturer;
- app icon concept;
- product description;
- versioning scheme;
- installer naming scheme;
- GitHub repository URL.

### 9.3 Архитектура

Спрашивать перед:

- сменой Flutter/Dart на другой стек;
- заменой архитектуры source connectors;
- удалением MediaProxyService из архитектуры;
- удалением поддержки Android TV;
- удалением поддержки Windows mini-player;
- заменой локальной базы;
- добавлением собственного backend/gateway;
- добавлением телеметрии/аналитики/crash reporting;
- добавлением авторизации/аккаунтов;
- добавлением sync-сервера.

### 9.4 Зависимости и код из сети

Спрашивать перед:

- добавлением крупной зависимости;
- добавлением зависимости с неясной лицензией;
- копированием кода из интернета;
- использованием сетевых ассетов;
- добавлением платных/закрытых библиотек;
- добавлением native-кода, который требует сложной сборки.

Маленькие стандартные Flutter/Dart зависимости можно добавлять без вопроса, если они очевидны, имеют нормальную лицензию и прямо нужны для ТЗ. Codex обязан кратко объяснить, зачем зависимость добавлена.

### 9.5 Безопасность и секреты

Спрашивать перед:

- хранением любого токена;
- добавлением API key;
- изменением алгоритма подписи источника;
- логированием network headers;
- сохранением cookies/session;
- добавлением proxy credentials;
- отправкой debug logs наружу;
- созданием remote endpoint;
- отключением allowlist media hosts.

### 9.6 Релиз и публикация

Спрашивать перед:

- созданием release-сборки;
- подписанием APK/AAB;
- изменением signing config;
- публикацией в магазин;
- созданием installer release;
- изменением сертификатов;
- созданием GitHub Release;
- созданием Git tag;
- удалением старых release artifacts.

---

## 10. Общие правила работы Codex

### 10.1 Перед началом задачи

Codex обязан:

1. прочитать `AGENTS.md`;
2. прочитать основное ТЗ, если оно есть: `docs/SLOVOFON_TECHNICAL_SPEC_RU.md`;
3. проверить текущую структуру проекта;
4. понять, какие файлы будут изменены;
5. проверить `git status`;
6. не выполнять destructive actions без вопроса.

### 10.2 Во время работы

Codex должен:

- работать маленькими логическими шагами;
- сохранять архитектуру;
- не смешивать UI и бизнес-логику;
- не делать временные костыли без TODO и объяснения;
- писать код так, чтобы его можно было тестировать;
- обновлять документацию при изменении поведения;
- держать локализацию отдельно от UI-кода;
- использовать единую дизайн-систему;
- использовать единые компоненты вместо копирования UI;
- сохранять платформенные отличия через abstraction layer.

### 10.3 После изменения кода

Codex обязан запускать, если проект уже позволяет:

```bash
dart format .
flutter analyze
flutter test
```

При изменении Android:

```bash
flutter build apk --debug
```

При изменении Windows:

```bash
flutter build windows --debug
```

Если команда невозможна из-за отсутствия окружения, Codex обязан явно написать, что именно не удалось запустить и почему.

### 10.4 Отчёт после задачи

В конце задачи Codex должен кратко сообщить:

- что сделано;
- какие файлы изменены;
- какие команды проверки запущены;
- какие проверки не удалось запустить;
- какие есть риски;
- нужен ли bump версии;
- нужен ли push/release;
- следующие шаги.

---

## 11. Архитектура

### 11.1 Запрещено

Запрещено:

- делать HTTP-запросы к источникам из widgets;
- скачивать файлы из widgets;
- хранить raw network state внутри UI как источник истины;
- смешивать source parser и UI-компоненты;
- хранить secrets в обычном JSON/settings;
- логировать SIGN, cookies, proxy password, полный media URL;
- создавать отдельную несовместимую бизнес-логику для Android и Windows;
- дублировать модели для разных платформ без причины;
- ломать обратную совместимость базы без миграции.

### 11.2 Обязательно

Обязательно:

- UI вызывает use case / notifier / controller;
- use case работает с repository/service;
- source logic находится в `sources/`;
- player logic находится в `services/audio/`;
- downloads logic находится в `services/downloads/`;
- proxy logic находится в `services/proxy/`;
- media proxy logic находится в `services/media_proxy/`;
- database logic находится в `data/database/`;
- общие UI-компоненты находятся в `ui/`;
- feature screens находятся в `features/`.

### 11.3 Один источник истины

```text
AudioService       — состояние воспроизведения
DownloadManager    — состояние загрузок
SourceRegistry     — доступ к источникам
SettingsRepository — настройки
ThemeController    — тема и акцентный цвет
ProxyManager       — прокси
```

---

## 12. Источники, API и секреты

### 12.1 Поддерживаемые источники

Проект должен поддерживать источники:

```text
knigavuhe
izib
akniga
baza_knig
knigoblud
yakniga
```

Каждый источник реализуется через `SourceConnector`.

### 12.2 API keys, SIGN и generated tokens

Правила:

- runtime generated SIGN/token генерировать только в connector/service;
- не хранить generated SIGN/token в базе;
- не логировать generated SIGN/token;
- не показывать generated SIGN/token в UI;
- не включать generated SIGN/token в crash/debug reports;
- headers с sensitive значениями маскировать.

Если появится настоящий приватный API secret, его нельзя безопасно хранить в клиентском приложении. Нужно спросить владельца и рассмотреть backend/gateway.

### 12.3 Media allowlist

Для каждого источника должны быть allowlist домены для metadata и media. Нельзя проксировать или скачивать произвольный URL.

---

## 13. Прокси внутри приложения

### 13.1 Требования

Приложение должно поддерживать встроенные настройки прокси:

```text
Без прокси
Системный прокси
HTTP proxy
SOCKS5 proxy
```

Область применения:

```text
Прокси для всех источников
Прокси только для выбранных источников
Прокси только для media/audio
Прокси только для metadata
Прокси только если direct не работает
```

### 13.2 ProxyProfile

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
```

Пароль хранить только в secure storage.

### 13.3 Проверка прокси

В настройках должна быть кнопка “Проверить прокси”. Проверка показывает:

- успешность подключения;
- время ответа;
- доступность выбранных источников;
- доступность media, если возможно.

Codex не должен менять системный proxy Windows/Android. Прокси применяется только внутри приложения.

---

## 14. Ассеты и иконки

### 14.1 Общие правила

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

### 14.2 Обязательные группы иконок

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

### 14.3 App icon

Создать собственный app icon:

- книга + звуковая волна;
- или открытая книга + play-треугольник;
- без копирования чужих брендов;
- adaptive icon для Android;
- `.ico` для Windows.

---

## 15. Локализация

Все UI-строки должны быть вынесены в localization.

Языки:

```text
ru — Словофон
en — Slovofon
kk — Slovofon
be — Slovofon
uk — Slovofon
```

Название приложения:

- `ru`: `Словофон`;
- все остальные локали: `Slovofon`.

Не писать пользовательские строки напрямую в widgets, кроме временных debug/TODO.

---

## 16. Пользовательские данные

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

Нельзя удалять без подтверждения.

При uninstall данные сохраняются по умолчанию.

При обновлении приложения данные должны мигрировать безопасно.

---

## 17. Release checklist

Перед релизом Codex обязан проверить:

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

---

## 18. Минимальный набор файлов репозитория

После инициализации проекта в корне должны быть:

```text
AGENTS.md
README.md
CHANGELOG.md
VERSION
THIRD_PARTY_NOTICES.md
LICENSE optional until owner confirms
pubspec.yaml
analysis_options.yaml
.gitignore
tools/slovofon.ps1
docs/SLOVOFON_TECHNICAL_SPEC_RU.md
docs/ARCHITECTURE.md
docs/BUILD_RELEASE.md
docs/SECURITY.md
docs/THEMING.md
docs/SOURCES.md
```

Если какого-то файла пока нет, Codex должен создать placeholder с понятным TODO, а не оставлять хаос.

---

## 19. Финальное правило

Slovofon должен разрабатываться как полноценный продукт, а не набор экранов.

Главные постоянные приоритеты:

```text
1. Безопасность данных пользователя.
2. Стабильный плеер и восстановление позиции.
3. Удобство на Android, Android TV и Windows.
4. Чистая архитектура.
5. Читаемые темы и цвета на всех устройствах.
6. Управляемые источники и прокси.
7. Предсказуемые сборки и релизы.
8. Честный changelog и Git history.
```
