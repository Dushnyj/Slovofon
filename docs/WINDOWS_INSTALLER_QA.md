# Windows installers — проверка текущих исходников

Дата: 2026-09-06. Версия исходников: **0.0.7+7**.
Начальный commit задачи: `5f76574846fd658cef4a4aead3214cdfd593f5ad`.
Продолжение MSI QA после согласования инструментов: `ef1b566` + текущие изменения.
Публичные файлы предыдущих GitHub Releases не заменялись.

## Автоматические проверки

| Проверка | Результат |
| --- | --- |
| `dart format --output=none --set-exit-if-changed .` | PASS, 269 файлов, без изменений |
| `flutter analyze` | PASS, no issues |
| `flutter test --reporter expanded` | **1571 PASS, 20 SKIP, 0 FAIL**, повторный полный прогон после MSI-правок |
| Targeted installer contracts + update URL | **16 PASS** |
| PowerShell AST всех `tools/windows/*.ps1` | PASS |
| WiX UI/localization XML и codepage RU/EN | PASS |
| Release workflow YAML | PASS |
| Inno 6.7.2, неустанавливаемый preview на заглушках | PASS, тёмный и светлый варианты |
| Inno production-ветка, `ISCC /O-` | PASS, создание setup-файлов отключено |
| WiX 6.0.2 + UI/Util 6.0.2, RU/EN MSI preview | PASS, оба языка без warnings/errors |
| Read-only таблицы скомпилированного MSI | PASS, **59 проверок для каждого** RU/EN preview |
| Preview передан в production-валидатор | Ожидаемое отклонение, PASS |

Контрактные тесты не выполняют установку. Для генератора WiX создаются отдельные
минимальные PE fixtures без imports; проверяются IDs/GUID, XML escaping, версии,
marker/ARP, исключение PDB, запрет output внутри bundle и реальный junction к
контрольному temp-файлу. Junction не обходится, контрольный файл остаётся целым.

Во время проверки исправлены также ошибки первого варианта изменений:
сравнение публичной версии с четырьмя полями FileVersion, неподдерживаемый Pascal
helper `LastDelimiter` (найден реальной компиляцией Inno), первоначальный test harness
с неверной кодировкой stdout PowerShell и одна lint-ошибка конкатенации строк.
Итоговые проверки выше выполнялись после исправлений.

При MSI-компиляции обнаружено предупреждение WIX1077 о ссылке `[INSTALLFOLDER]`
в таблице Property. Вместо подавления warning добавлен type-51 action на Finish:
он формирует окончательный путь непосредственно перед opt-in запуском. Условие
`NOT REMOVE` заменено на `REMOVE <> "ALL"`, чтобы исключение необязательного
DesktopFeature не блокировало запуск. Это исправление закреплено XML/compiled
контрактами; настоящий запуск приложения после установки здесь не проверялся.

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
artifacts/installer-preview/msi-20260906/tool-restore.log
artifacts/installer-preview/msi-20260906/compile-03.log
artifacts/installer-preview/msi-20260906/compile-en.log
artifacts/installer-preview/msi-20260906/compile-integrated.log
artifacts/installer-preview/msi-20260906/compiled-contracts-ru.json
artifacts/installer-preview/msi-20260906/compiled-contracts-en.json
artifacts/installer-preview/msi-20260906/msi-tables-03.txt
artifacts/installer-preview/msi-20260906/analyze.log
artifacts/installer-preview/msi-20260906/full-suite.log
artifacts/installer-preview/msi-20260906/contracts.log
artifacts/installer-preview/msi-20260906/format.log
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

## Компиляция и визуальная проверка MSI

После явного согласия владельца WiX 6.0.2 и UI/Util 6.0.2 скачаны только в
`artifacts/installer-preview/msi-20260906/`: локальный `tools/wix.exe`, `nuget/`
и `.wix/extensions/`. Глобальная установка, изменение PATH и системной темы не
выполнялись. Для предпросмотра используется `New-MsiInstallerPreview.ps1`.

- Проверены настоящие окна `msiexec.exe`, не HTML-макет или перерисованный скриншот.
- RU: приветствие, лицензия с выключенным флажком и заблокированным «Далее»,
  включение флажка, папка/ярлык, Browse и его отмена, готовность к установке,
  возврат назад, повторный переход, подтверждение отмены и финальная страница отмены.
- EN: приветствие, лицензия, включение флажка, папка/ярлык, подтверждение отмены,
  финальная страница отмены.
- Русские и английские заголовки, описания, длинный текст сохранения данных и
  нижние кнопки помещаются в штатный размер окна при текущем DPI компьютера.
- В RU поле принят путь с пробелами и кириллицей. Путь и включённый desktop checkbox
  сохранились после «Назад»; снятие флажка и повторное «Далее» работают.
- «Установить» не нажималась. Все окна preview закрыты; выбранная тестовая папка
  не создана. Установленные продукты, книги и настройки не изменялись.
- Preview получает отдельные ProductCode/UpgradeCode/component GUID и registry
  searches. В скомпилированных Install/Admin/AdvtExecuteSequence guard типа 19
  имеет Condition `1` и sequence 799, перед CostInitialize 800. Execute не запускался.
- `Test-MsiInstaller.ps1` читает MSI через `OpenDatabase(path, 0)`. Проверены ARP,
  x64/language, UI sequence, Finish/type-51/type-65, desktop feature, major upgrade,
  отсутствие широкого удаления данных и обязательные preview guards. SHA-256 до
  и после read-only проверки совпадает; это не install/uninstall smoke test.

Проверенные native preview (тестовые, не для распространения):

```text
RU: artifacts/installer-preview/8e1e03e338974c08934edcb0e927806e/Slovofon-v0.0.7-windows-x64-msi-preview.msi
EN: artifacts/installer-preview/22c216db77d9469d8bc5f3e1c596a219/Slovofon-v0.0.7-windows-x64-msi-preview.msi
```

## Что ещё не подтверждено

1. **Не выполнялись реальная установка, обновление, repair, rollback и удаление**
   через Installed Apps / Programs and Features. Наличие правильного installer
   metadata проверено также в скомпилированном MSI, но не по факту установки.
2. Не проверены 150/200% DPI, UAC/all-users запуск и uninstall при открытом приложении.
   Пользовательские настройки Windows ради этих проверок не менялись.
3. `flutter build windows --debug` в первом проходе остановился с `Unable to find suitable Visual Studio
   toolchain`. Системные компоненты не устанавливались. Это отдельная проблема
   локального Flutter toolchain; Inno preview с установленным компилятором собрался.
4. Встроенное обновление **MSI не автоматизировано**. Setup теперь безопасно
   останавливается при обнаружении MSI, вместо создания второй установки.

Реальные install/uninstall/upgrade проверки должны проводиться на тестовых данных
в чистой Windows VM после отдельного согласования. Матрица сценариев и команды:
[BUILD_RELEASE.md — Windows installer](BUILD_RELEASE.md#8-windows-installer).

## Текущий итог

Исходники Setup и MSI, упаковка и документация доработаны. Оба установщика имеют
подтверждённую компиляцию preview и native-предпросмотр; для MSI дополнительно
проверены таблицы готового пакета. Это **не утверждение о завершении реального
install/upgrade/uninstall QA или готовности к публичному релизу**. Версия не менялась, подпись,
release-сборка приложения, Git tag, push и GitHub Release не выполнялись.
