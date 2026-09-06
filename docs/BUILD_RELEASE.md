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
14. создаёт новый GitHub Release; опубликованный релиз не перезаписывается.
```

Android signing secrets обязательны для release workflow. Windows signing secrets опциональны: если их нет, Windows artifacts собираются, но остаются unsigned и Windows может показать `Unknown Publisher`.

#### Неизменяемость release tag и artifacts

До дорогих build jobs и повторно перед публикацией `tools/release/ReleaseGuard.ps1`
сверяет remote tag с точным commit, из которого workflow собирает приложение.
Для annotated tag сравнивается peeled commit, а не SHA объекта тега. Отсутствующий
tag допустим только до создания; ошибка чтения origin или несовпадение SHA останавливает
workflow. Ручной запуск на другой ветке с той же версией не может заменить binaries
существующего тега. Все release-запуски репозитория сериализованы одной concurrency group.

`gh release upload --clobber` не используется. Существующий GitHub Release останавливает
публикацию, включая повторный запуск с тем же SHA: для нового содержимого нужен новый
утверждённый version/build/tag. Workflow самовольно не переносит и не удаляет теги.

#### App-local MSVC runtime для Windows

Windows `Release`/`Profile` bundle включает redistributable MSVC DLL из выбранного
Visual Studio toolset через стандартный CMake `InstallRequiredSystemLibraries`.
DLL копируются рядом с `Slovofon.exe`, а не в системные каталоги. Системная установка
VC++ Redistributable и права администратора для этого не нужны. Windows 10+ использует
системный UCRT; debug CRT не распространяется как release dependency.

Общий bundle является единственным входом для Inno Setup, WiX MSI и portable ZIP,
поэтому все три формата получают одинаковые runtime DLL. Перед упаковкой workflow,
локальный главный build script и WiX source generator запускают проверку реальных
PE import tables EXE/DLL, включая транзитивные зависимости MSVC:

```powershell
./tools/windows/Assert-WindowsRuntime.ps1 -BundleDir build/windows/x64/runner/Release
```

Проверка завершается ошибкой при отсутствующем/пустом runtime DLL или некорректном PE.
Inno дополнительно отклоняет source bundle без базовых x64 CRT DLL. Финальная проверка
release всё равно включает запуск setup/MSI/portable в чистой Windows VM без Visual
Studio и предварительно установленного VC++ Redistributable; import-validation не
подменяет такой smoke test.

### 5.3 Канал обновлений приложения

По явному решению владельца от 2026-09-05 Android и Windows проверяют обновления
напрямую через публичный GitHub Releases репозитория **Dushnyj/Slovofon**. Серверный
signed manifest больше не используется. URL репозитория и signing identity Android
при этом не меняются.

```text
Latest stable API: https://api.github.com/repos/Dushnyj/Slovofon/releases/latest
Страница релизов: https://github.com/Dushnyj/Slovofon/releases
Файл релиза:      https://github.com/Dushnyj/Slovofon/releases/download/<tag>/<file>
```

Клиент делает публичные HTTPS-запросы без GitHub token, авторизации, cookies, SSH-данных
или других секретов. Нельзя подменять владельца/репозиторий настройкой из ответа API.

Контракт проверки:

1. Получить latest release указанного репозитория; draft и prerelease не являются
   stable-обновлением. Отсутствие опубликованного release не означает сетевую ошибку;
   ошибки сети/API и rate limit не должны превращаться в «обновлений нет».
2. Прочитать публичную версию из `tag_name` формата `vMAJOR.MINOR.PATCH` и сравнить
   с текущей версией. GitHub `id` release/asset не является Android versionCode или
   build number; из этих идентификаторов номер сборки не вычисляется.
3. Выбрать совместимый artifact именно этого release по имени, версии, платформе,
   архитектуре и типу. Переходить к другому release или произвольному внешнему файлу
   при отсутствии подходящего artifact нельзя. Автоматическая установка поддерживает
   только Android `Slovofon-v<version>-android-universal-release.apk` и Windows
   `Slovofon-v<version>-windows-x64-setup.exe`. ABI APK, AAB, MSI, portable ZIP и MSIX
   не являются fallback для auto updater: они могут публиковаться для ручной загрузки,
   но текущий автоматический installer handler их не запускает.
4. Для выбранного artifact обязателен SHA256: использовать валидный `digest` API
   вида `sha256:<64 hex>`. Если digest не предоставлен, получить `SHA256SUMS.txt`
   **из того же release** и найти точную запись имени выбранного artifact. Нельзя
   подставлять checksum другой версии или продолжать установку без корректного hash.
5. Скачать `browser_download_url` из этого release непосредственно с GitHub.
   Допускаются только проверенные HTTPS redirects к разрешённым GitHub asset/CDN
   hosts; перенаправление на произвольный host или HTTP не разрешается.
6. Перед открытием APK/установщика вычислить SHA256 фактически скачанного файла и
   сравнить с ожидаемым. Несовпадение запрещает установку.

Источник доверия update metadata — фиксированный GitHub repository через HTTPS.
SHA256 проверяет целостность файла, но не является отдельной Ed25519-подписью
издателя. Отказ от серверной подписи согласован владельцем; переход к GitHub не
создаёт и не переносит signing keys, не меняет подпись APK/AAB или Windows signing
config. Подробная граница доверия описана в `docs/SECURITY.md`, раздел 12.

При ошибке GitHub нет fallback к старому серверу, зеркалу или unsigned скачиванию
без SHA256. Старые stable/beta `latest.json` и готовность `SlovofonBot` не являются
условием работы текущего updater. Автопроверка использует только stable; новый beta
канал не добавляется этим переходом.

Android открывает системный APK installer после проверки файла, пользователь
подтверждает установку. Windows также запускает совместимый installer только после
согласия пользователя. `SHA256SUMS.txt` формируется workflow **после** окончательной
подписи APK/EXE/MSI и упаковки ZIP и прикрепляется вместе с artifacts. Существующий
release workflow уже публикует необходимые файлы и checksum list; отдельный backend
или manifest signing job для этого контракта не нужен.

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
```

Исторические ключи серверного update manifest не нужны текущему updater; их статус
и правило сохранения описаны отдельно в разделе 6.5.

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

### 6.5 Историческая серверная подпись manifest — legacy

До перехода на прямые GitHub Releases бот `Dushnyj/SlovofonBot` зеркалировал файлы,
подписывал Ed25519 manifest и публиковал stable/beta `latest.json` на старом update
сервере. Key id этой схемы — `slovofon-updates-2026-06`.

В текущем updater эта схема **не используется и не является fallback**. Старая
серверная конфигурация может оставаться необходимой ранее установленным версиям
клиента; её остановка не входит в изменение нового клиента.

Переход не разрешает читать, удалять, ротировать, перемещать или загружать
исторические private keys в GitHub Secrets. Ключи и их backup сохраняются на прежних
местах вне Git до отдельного решения владельца. Не нужно создавать новый Ed25519
ключ или включать manifest signing job для прямого GitHub updater.

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

### Форматы и мастер установки

Изменения этого раздела относятся к текущим исходникам. Уже опубликованные
установщики не изменяются задним числом.

| Возможность | Setup EXE — основной вариант | MSI — управляемая установка |
| --- | --- | --- |
| Движок | Inno Setup 6.7.2 в CI, минимум 6.6 | WiX Toolset 6.0.2 + UI/Util 6.0.2 |
| Оформление | Современные системные элементы, светлая/тёмная тема Windows, Segoe UI, фирменный знак | Светлый штатный Windows Installer UI, Segoe UI, фирменный знак |
| Режим | Только для меня / для всех пользователей | Для всех пользователей, с правами администратора |
| Язык | Русский и английский в мастере | Русский в release workflow; английский выбирается при сборке |
| Папка | Выбор, предыдущая папка при обновлении | Выбор, восстановление предыдущей папки |
| Ярлыки | «Пуск»; рабочий стол — по желанию | «Пуск»; рабочий стол — по желанию |
| Завершение | Запуск без повышенных прав по отмеченной пользователем галочке | Аналогично, через WixUnelevatedShellExec |

Галочки создания ярлыка рабочего стола и запуска программы изначально выключены.
Существующий выбор ярлыка восстанавливается при обновлении. Программа не запускается
после silent install, а MSI также не запускает её после repair/remove и при ожидаемой
перезагрузке. MSI остаётся per-machine: переключение scope в одном MSI и между
установленными экземплярами не имитируется небезопасной заменой `ALLUSERS`.

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

### Удаление, обновление и защита данных

Оба формата используют штатную регистрацию удаления Windows, показывая название,
версию, издателя, значок и ссылки на GitHub. Поддерживаются:

- Windows 11: **Параметры → Приложения → Установленные приложения → Slovofon → Удалить**;
- Windows 10: **Параметры → Приложения → Приложения и возможности**;
- **Панель управления → Программы и компоненты**.

Удаляются только файлы программы, установленные ярлыки и записи установщика.
Книги, настройки, история, прогресс и закладки **сохраняются**; массовой очистки
AppData или внешних папок в установщиках нет. Удаление пользовательской библиотеки
не является скрытой частью uninstall; специальный режим полной очистки здесь
не реализован.

Обновление делается тем же форматом и в том же режиме установки. Setup обнаруживает
MSI по неизменному UpgradeCode (включая старые выпуски без нового registry marker);
MSI проверяет записи Setup для текущего пользователя и всей машины. При конфликте
установка останавливается с объяснением, без автоматического удаления другой копии.
Для смены формата/режима пользователь сначала удаляет старую программу через Windows,
сохраняя данные. Установка для другого Windows-пользователя не переносит его библиотеку.

Встроенный updater пока скачивает **Setup EXE**, не MSI. Если приложение установлено
через MSI, скачанный Setup остановится с инструкцией использовать MSI из того же
GitHub Release. Это защита от дубликатов, **не автоматическое MSI-обновление**.

Setup запрещает downgrade по зарегистрированной версии и по версии EXE в выбранной
папке; четвёртое поле Flutter build number не мешает переустановке той же публичной
версии. MSI сохраняет UpgradeCode и component GUID; MajorUpgrade выполняется внутри
rollback-транзакции, распознавая также старый английский пакет. Принудительное
завершение приложения и безусловная перезагрузка не используются.

### Общая локальная упаковка и CI

После отдельного согласования release-сборки и получения полного release bundle:

```powershell
./tools/windows/Build-WindowsInstallers.ps1 `
  -BundleDir build/windows/x64/runner/Release -Format All -Culture ru-RU
```

Эту же команду использует release workflow. Можно выбрать `-Format Setup` или `Msi`,
передать `-OutputDir`, `-InnoCompiler`, `-WixCompiler`. MSI UI/Util extensions должны
быть заранее доступны в WiX cache; скрипт не устанавливает инструменты самостоятельно.
Для английского MSI используется `-Culture en-US`; готовый MSI не содержит runtime
переключателя языка. Главный `tools/slovofon.ps1 release` всё ещё является заглушкой:
публикация выполняется согласованным GitHub workflow, а не этой локальной командой.

Упаковка проверяет соответствие EXE файлу `VERSION`, app-local CRT, отсутствие
символических ссылок/junctions в bundle и размещение output вне bundle. Существующие
установщики не перезаписываются. Подпись, SHA-256, тег и публикация — отдельные стадии;
локальная команда не выполняет ни одну из них и не меняет версию.

Фирменные картинки воспроизводятся через `tools/windows/New-InstallerArtwork.ps1`
из существующего launcher icon и собственной геометрии. Новых сетевых ассетов нет.

### Безопасный предпросмотр и проверка

```powershell
./tools/windows/New-InstallerPreview.ps1        # Тема Windows
./tools/windows/New-InstallerPreview.ps1 -Light # Светлый вариант без смены темы ОС
flutter test test/platform/windows_installer_contract_test.dart test/platform/installer_update_url_test.dart
```

Setup preview собирается на неисполняемых заглушках в `artifacts/installer-preview/`,
имеет отдельный AppId и compile-time блокировку `PrepareToInstall`. Это **не релиз**
и не рабочая программа; реальную установку выполнить нельзя. Открытие/отмена мастера
не доказывают корректность установки, удаления или rollback.

Для MSI есть отдельный неустанавливаемый preview на минимальных PE-заглушках:

```powershell
./tools/windows/New-MsiInstallerPreview.ps1 -Culture ru-RU
./tools/windows/New-MsiInstallerPreview.ps1 -Culture en-US
# Только генерация source, без WiX, компиляции или запуска:
./tools/windows/New-MsiInstallerPreview.ps1 -GenerateOnly
```

WiX 6.0.2 и UI/Util 6.0.2 должны быть уже доступны. Можно передать `-WixCompiler`
и `-ExtensionCacheDirectory` (путь к локальной `.wix/extensions`). Скрипт ничего
не скачивает, не меняет PATH и сам не открывает мастер. Каждый preview получает
отдельные ProductCode/UpgradeCode/component GUID, изолированные registry searches
и папку. Безусловный MSI type-19 guard останавливает Install/Admin/Advertise execute
sequences до `CostInitialize`, включая тихий запуск. UI использует реальные исходники
мастера, но установка приложения и регистрация preview запрещены.

При необходимости инструменты можно разместить только в QA-папке, **после согласия
владельца на скачивание**, не устанавливая их глобально:

```powershell
# Выполнять из отдельной папки artifacts/installer-preview/<qa-run>.
# NUGET_PACKAGES задаётся только для текущего процесса; восстановить прежнее значение после работы.
$oldNuget = $env:NUGET_PACKAGES
try {
  $env:NUGET_PACKAGES = Join-Path $PWD 'nuget'
  dotnet tool install wix --version 6.0.2 --tool-path ./tools --add-source https://api.nuget.org/v3/index.json
  ./tools/wix.exe extension add WixToolset.UI.wixext/6.0.2 WixToolset.Util.wixext/6.0.2
} finally { $env:NUGET_PACKAGES = $oldNuget }
# Без -g: extensions находятся в .wix/extensions текущей QA-папки.
```

`New-MsiInstallerPreview.ps1` после компиляции автоматически проверяет таблицы MSI.
`Build-WindowsInstallers.ps1` делает такую же read-only проверку в production-режиме
перед дальнейшим подписанием/публикацией. Отдельный запуск:

```powershell
./tools/windows/Test-MsiInstaller.ps1 -MsiPath <path-to-msi>
./tools/windows/Test-MsiInstaller.ps1 -MsiPath <path-to-msi-preview> -Preview
```

Валидатор открывает базу MSI только для чтения, не создаёт installer session, не
выполняет действия пакета и не меняет реестр. Проверяются identity, ARP/uninstall,
UI sequence, native launch, optional desktop feature и upgrade/rollback sequencing.
Production-проверка отклоняет preview; наличие контрактов не доказывает реальную
установку, работу запуска после неё или удаление через настройки Windows.

Перед выпуском нужно отдельно проверить в чистой Windows VM: оба режима Setup,
MSI с admin/non-admin запуском, пути с пробелами/кириллицей, 100/150/200% DPI,
клавиатуру, ремонт MSI, обновление с предыдущего выпуска, попытку downgrade,
обновление при открытом приложении, отмену/rollback, отсутствие второго пункта
в Installed Apps, удаление через Windows и сохранение тестовых книг/прогресса.
Текущий статус проверок: [WINDOWS_INSTALLER_QA.md](WINDOWS_INSTALLER_QA.md).

---

## 9. Android package

### Проверка foreground playback lifecycle

`SlovofonFlutterEngine` владеет единственным FlutterEngine на уровне процесса.
`MainActivity` подключается к нему и отсоединяет только Activity/UI-specific channels;
закрытие окна не уничтожает Dart isolate, `PlaybackController`, audio engine и media
bridge. Media3 service не имеет `stopWithTask=true`, а активная/buffering сессия
сохраняется при удалении task. Неактивная сессия очищает notification/service.
Это не обещание неубиваемого процесса: Android всё ещё может завершить приложение;
после такого завершения используются обычные сохранение/восстановление состояния.

Native regression runner использует только Android framework, без стороннего test
runner. На отдельном тестовом emulator/device без пользовательских книг:

```powershell
# Debug/instrumentation APKs only; no release signing.
cd android
./gradlew.bat :app:assembleDebug :app:assembleDebugAndroidTest
adb install -r ../build/app/outputs/apk/debug/app-debug.apk
adb install -r ../build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb shell am instrument -w com.slovofon.app.test/com.slovofon.app.SlovofonLifecycleInstrumentation
```

Runner проверяет реальный Activity finish/reopen: Dart продолжает выполняться и
повторно используется тот же engine; также проверяет media keep-alive policy и скорость.
Отдельная ручная device QA обязательна для реального звука и системных callbacks:
play → Home/Back/swipe recent task → notification Pause/Play/Seek → повторное открытие
UI; затем то же для buffering и paused состояния. Source-code substring test для
`onTaskRemoved` не считается доказательством корректного foreground lifecycle.

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

---

## Проверка размеров Windows-окна после Debug-сборки

Основной runner использует 900×600 client DIPs как минимум и стартовые
1280×720 client DIPs; это не внешние размеры вместе с рамкой. Чистая политика
размеров тестируется в `windows/runner/tests/window_size_policy_test.cpp`,
привязка к сообщениям Win32 — `test/platform/window_size_contract_test.dart`.

Для уже запущенного экземпляра доступен `tools/windows/Test-WindowSizing.ps1`
с обязательным `-ProcessId`. Режим `-ReadOnly` только запрашивает геометрию и
MINMAXINFO. Обычный режим проверяет resize/maximize/minimize/restore и в `finally`
восстанавливает исходное placement данного окна. Перед запуском убедиться, что
PID относится к нужной локальной Debug-сборке Slovofon. Скрипт не меняет DPI,
экранные настройки, базу или пользовательские файлы; synthetic same-DPI message
не считается проверкой реального переноса окна между мониторами разного DPI.
Временный DPI-контекст вызывающего потока предотвращает виртуализацию координат
и также восстанавливается в `finally`. Snap-like rectangles и видимые DWM bounds
проверяют геометрию у края, но не заменяют ручную проверку shell Snap Layouts.
