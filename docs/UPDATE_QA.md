# Проверка встроенного обновления

Дата: 2026-09-06. Исходная точка до доработок: `49c4f67535b5796af7aa3023a52c9405fc696add`.
Версия исходников остаётся `0.0.7+7`. Публикация и установка обновления этим
проходом не выполняются.

## Что исправлено

- `MaterialApp.router.builder` находится выше Navigator. Прежняя автопроверка
  обращалась к нему через контекст gate и молча теряла ошибку открытия диалога.
  Теперь gate использует overlay корневого Navigator; Windows/TV theme и
  масштаб текста сохраняются. Отдельный widget regression повторяет эту
  топологию, а не только показывает диалог из обычного `Scaffold`.
- Сервис объединяет одновременные запросы метаданных, но отдельно применяет
  политику пропущенных версий для ручной и автоматической проверки. UI coordinator
  предотвращает повторные окна, в том числе при позднем автоматическом ответе
  после ручной проверки.
- Автопроверка: запуск, возврат из фона, четыре часа непрерывного активного
  состояния; cooldown — 30 минут. Ответ, пришедший в фоне, можно показать после
  возврата. Ручная проверка не ограничена cooldown и показывает пропущенную версию.
- `Пропустить версию` сохраняется отдельно от базы в `update-preferences.json`;
  `Позже` не сохраняет пропуск. Повреждённый файл настроек не переписывается
  чтением; ошибка записи не выдаётся за успешный пропуск.
- Выбор Windows-пакета определяется регистрацией **именно текущего executable**:
  Inno user/machine, MSI или portable. Регистрация другой копии не меняет тип
  portable. Неоднозначный результат даёт только ручную страницу GitHub Releases.
  WinAPI/registry/MSI-чтение выполняется вне UI-потока; ответ имеет таймаут,
  завершение после закрытия окна отбрасывается, зависшее системное чтение не
  приводит к накоплению новых worker-потоков.
- Setup получает прежние scope и каталог; MSI запускает штатный интерактивный
  мастер. Перед передачей управления сохраняется позиция воспроизведения;
  ошибка сохранения блокирует запуск, а не закрывает приложение с потерей позиции.
- Portable ZIP только скачивается, проверяется и показывается в папке.
  Распаковка пользователем — в новую папку после закрытия приложения.
  Автоматической перезаписи работающего приложения нет.
- SHA-256, размер, версия, имя файла и допустимые URL проверяются для всех
  поддерживаемых форматов. Неподходящие файлы и неверные редиректы не запускаются.

## Воспроизводимые проверки

```powershell
flutter analyze --no-pub
flutter test --no-pub test/services/updates test/ui/update_prompt_test.dart test/ui/desktop_dialog_resize_test.dart --reporter expanded
flutter test --no-pub --reporter expanded
```

Обычные тесты используют отдельные временные каталоги, mock HTTP/installer и
synthetic metadata. Они не скачивают публичный установщик, не запускают его и
не меняют настоящий профиль пользователя.

`windows/runner/tests/windows_installation_policy_test.cpp` проверяет чистую
классификацию регистрации и пути. `windows_installation_task_test.cpp` —
single-flight, таймаут, поздний ответ, ошибки запуска/доставки и закрытие окна.
Оба подключены к Release workflow и компилируются локально
с C++17, `/W4 /WX /UNDEBUG`. WinAPI-часть дополнительно проверяется компиляцией;
это не имитация установленного продукта через запись в registry.

Для читаемых визуальных fixtures на Windows используются уже установленные
Segoe UI fonts, без загрузки ассетов:

```powershell
$env:UPDATE_PROMPT_CAPTURE_DIR = Join-Path $PWD 'artifacts/update-inspection-20260906/prompt-fixtures'
flutter test --no-pub test/ui/update_prompt_test.dart --reporter expanded
Remove-Item Env:\UPDATE_PROMPT_CAPTURE_DIR
```

Проверяются диалоги phone/desktop/TV в light/dark при тексте 200%, длинное описание,
доступность кнопок, повтор после ошибки, Back во время загрузки, Skip/Later,
возврат после APK permission, смена foreground/background и параллельные запросы.
Это **отрисовка настоящих Flutter widgets в тестовой среде**, не Android/TV
device QA и не native Windows install/upgrade.

## Результаты текущего прохода

Журналы: `artifacts/update-improvements-20260906/`.

| Проверка | Подтверждение |
| --- | --- |
| Статический анализ | `analyze-final.log`: `No issues found` |
| Полный Flutter suite | `full-suite-final.log`: **1700 PASS / 20 SKIP / 0 FAIL**, после исправления strict checkpoint |
| Форматирование | `format-final.log`: `dart format --output=none --set-exit-if-changed .`, без изменений |
| Реальный PlaybackController + updater | `playback-checkpoint-tests.log`: **8 PASS**, ошибки записи session/progress, очередь и повтор |
| Диалоги с читаемыми шрифтами | `prompt-tv-fixed.log`: **27 PASS**, включая D-pad-доступ к длинным notes |
| Нативные policies | `native-policy.log`: оба C++ EXE теста PASS; WinAPI source и FlutterWindow OBJ скомпилированы с `/W4 /WX` |
| Windows Debug | `windows-debug-cmake.log`: существующий CMake/v142 build, exit 0; `Slovofon.exe` с metadata `0.0.7+7` |
| Android Debug | `android-debug-final.log`: universal APK собран, exit 0; эмуляторы и установка не запускались |
| Настоящий GitHub API | `live-github-metadata.log`: **1 PASS** через production `UpdateClient`, приняты release `0.0.6` и четыре файла APK/MSI/ZIP/Setup с валидными ожидаемыми SHA-256 |

20 пропусков полного suite — opt-in live/visual проверки, не упавшие тесты.
Отдельный live metadata probe читает только публичные метаданные и при необходимости
`SHA256SUMS.txt`, не скачивает бинарные пакеты и не вызывает установщик.
Наблюдение о latest `0.0.6` относится к моменту проверки, не является постоянной
версией репозитория. Локальная `0.0.7` этим проходом не публиковалась.

Android build выводит предупреждение Flutter о будущей совместимости Kotlin Gradle
Plugin у `audio_session` и `url_launcher_android`. Текущая сборка успешна; зависимости
и signing configuration в рамках updater-задачи не менялись.

Стандартная команда `flutter build windows --debug --no-pub` отдельно проверена:
`windows-debug-standard.log` содержит `Unable to find suitable Visual Studio toolchain`.
Это не исправлялось установкой системных компонентов. Использован ранее настроенный
локальный CMake-каталог, без изменения исходников Flutter или маскировки discovery:

```powershell
& 'C:\Program Files\CMake\bin\cmake.exe' --build build/windows-desktop-design-debug --config Debug --target INSTALL -- /m:2
```

Debug bundle: `build/windows-desktop-design-debug/runner/Debug/`. В данном CMake
проекте `INSTALL` копирует результат **в этот build-каталог**, а не устанавливает
приложение в Windows и не меняет Installed Apps.

В code review дополнительно найдено, что обычный `flushPlayback()` поглощал ошибки
записи. Добавлен отдельный `requireSuccess: true` для updater; восемь regression
tests используют настоящий controller, а не только callback, искусственно
бросающий исключение. Обычное best-effort автосохранение оставлено совместимым.

## Граница подтверждения

Не выполнялись реальный переход между двумя опубликованными версиями, установка,
UAC/SmartScreen, отмена/rollback установщика, repair и uninstall на данных владельца.
Достоверный end-to-end upgrade нужно отдельно проверить в Windows VM на выпусках
с различающимися версиями: Setup user/machine, MSI, portable, нестандартный путь,
открытое приложение, отмена, отсутствие дубликатов Installed Apps и сохранность
позиции, настроек, истории и скачанных книг.

Android использует прежний системный APK installer; его разрешение/повтор проверяются
через mock channel. Эмуляторы и физические Android/TV устройства здесь не запускались.
Приложение **не утверждает, что обновление установлено**, только что установщик
открыт либо проверенный ZIP доступен. Тихой установки и принудительного перезапуска нет.
