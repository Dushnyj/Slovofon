# Windows installers — проверка текущих исходников

Дата: 2026-09-06. Версия исходников: **0.0.7+7**.
Начальный commit задачи: `5f76574846fd658cef4a4aead3214cdfd593f5ad`.
Публичные файлы предыдущих GitHub Releases не заменялись.

## Автоматические проверки

| Проверка | Результат |
| --- | --- |
| `dart format --output=none --set-exit-if-changed .` | PASS, 269 файлов, без изменений |
| `flutter analyze` | PASS, no issues |
| `flutter test --reporter expanded` | **1568 PASS, 20 SKIP, 0 FAIL** |
| Targeted installer contracts + update URL | **13 PASS** |
| PowerShell AST всех `tools/windows/*.ps1` | PASS |
| WiX UI/localization XML и codepage RU/EN | PASS |
| Release workflow YAML | PASS |
| Inno 6.7.2, неустанавливаемый preview на заглушках | PASS, тёмный и светлый варианты |
| Inno production-ветка, `ISCC /O-` | PASS, создание setup-файлов отключено |

Контрактные тесты не выполняют установку. Для генератора WiX создаются отдельные
минимальные PE fixtures без imports; проверяются IDs/GUID, XML escaping, версии,
marker/ARP, исключение PDB, запрет output внутри bundle и реальный junction к
контрольному temp-файлу. Junction не обходится, контрольный файл остаётся целым.

Во время проверки исправлены также ошибки первого варианта изменений:
сравнение публичной версии с четырьмя полями FileVersion, неподдерживаемый Pascal
helper `LastDelimiter` (найден реальной компиляцией Inno), первоначальный test harness
с неверной кодировкой stdout PowerShell и одна lint-ошибка конкатенации строк.
Итоговые проверки выше выполнялись после исправлений.

Локальные логи, не входящие в Git:

```text
artifacts/installer-preview/20260906/analyze-02.log
artifacts/installer-preview/20260906/full-suite.log
artifacts/installer-preview/20260906/contract-tests-final.log
artifacts/installer-preview/20260906/format.log
artifacts/installer-preview/20260906/compile-03.log
artifacts/installer-preview/20260906/compile-light-final.log
artifacts/installer-preview/20260906/compile-dark-final.log
artifacts/installer-preview/20260906/compile-production-no-output.log
artifacts/installer-preview/20260906/windows-debug-build.log
```

## Визуальная проверка Setup

Проверялось реальное native-окно Inno Setup, а не HTML-макет. Preview собран с
отдельным AppId и блокировкой установки; payload — неисполняемые заглушки.

- Тёмная тема: выбор режима, выбор языка, приветствие, папка установки,
  группа меню «Пуск», необязательный ярлык, сводка и отмена до установки.
- Светлая тема: выбор режима/языка, английская локализация приветствия и поле пути;
  фирменная графика и контраст проверены без изменения темы Windows.
- Проверено правильное значение per-user папки: `%LocalAppData%\Programs\Slovofon`.
- Исправлена подмена фирменной картинки встроенной тёмной картинкой Inno:
  задан отдельный `WizardImageFileDynamicDark`.
- Удалена непрозрачная подложка маленького значка; используется исходный PNG.
- Заголовок, тексты, поле пути и нижние кнопки не обрезаются при проверенном размере.
- Escape открывает диалог отмены; после выхода установка не выполняется.

## Что ещё не подтверждено

1. **MSI не скомпилирован и не проверен визуально:** WiX отсутствует локально.
   Запрошено согласие на WiX 6.0.2 + UI/Util только в тестовой папке, без изменения
   системы/PATH; до его получения инструменты не скачивались. XML/fixtures и сверка
   native bindings с исходниками WiX v6.0.2 не заменяют компиляцию и запуск мастера.
2. **Не выполнялись реальная установка, обновление, repair, rollback и удаление**
   через Installed Apps / Programs and Features. Наличие правильного installer
   metadata проверено по исходникам/генерируемому XML, но не по факту установки.
3. Не проверены 150/200% DPI, UAC/all-users запуск и uninstall при открытом приложении.
   Пользовательские настройки Windows ради этих проверок не менялись.
4. `flutter build windows --debug` остановился с `Unable to find suitable Visual Studio
   toolchain`. Системные компоненты не устанавливались. Это отдельная проблема
   локального Flutter toolchain; Inno preview с установленным компилятором собрался.
5. Встроенное обновление **MSI не автоматизировано**. Setup теперь безопасно
   останавливается при обнаружении MSI, вместо создания второй установки.

Реальные install/uninstall/upgrade проверки должны проводиться на тестовых данных
в чистой Windows VM после отдельного согласования. Матрица сценариев и команды:
[BUILD_RELEASE.md — Windows installer](BUILD_RELEASE.md#8-windows-installer).

## Текущий итог

Исходники Setup и MSI, упаковка и документация доработаны. Setup имеет подтверждённый
native-предпросмотр; MSI имеет пока только code/fixture validation. Это **не утверждение
о готовности обоих установщиков к публичному релизу**. Версия не менялась, подпись,
release-сборка приложения, Git tag, push и GitHub Release не выполнялись.
