# Кроссплатформенная проверка качества — 2026-09-06

## Точка возврата и границы

Перед изменениями создан локальный commit `29441ef3fc6986e3c745a83c7218815773438afd`.
Публичная версия остаётся `0.0.6+6`. Эта задача не является релизом: без push,
tag, публикации, установщика или смены signing config. Пользовательские данные
не сбрасываются; legacy-пути книг не переименовываются.

Локальные коммиты реализации после точки возврата:

- `da14d91f8c51105abdba6434294278b23d7e9d7c` — playback, downloads,
  источники, durable data и регрессионные тесты;
- `f7349e00191383bcb18f662de0ccc66948171194` — Android TV capability,
  packaging и native unknown-duration seeking;
- `94ded52cc29e520f6017d192764aa52e555a7b6b` — TV/phone/Windows UI,
  focus, ошибки плеера и UI-регрессии. Финальные Debug-артефакты соответствуют
  этому состоянию исходников; последующая фиксация отчёта меняет только документы.

После отказа пользователя от изменения системных компонентов эмуляторы не
запускаются. Android phone и Android TV проверяются по коду и автоматическими
тестами; визуальную и аппаратную проверку на устройствах выполняет пользователь
по [чеклисту](MANUAL_DEVICE_QA_RU.md). Debug-сборка/контрактные тесты не заменяют
фактическую работу на устройстве. Windows проверяется также в работающем приложении.

## Реализованные направления

| Область | Исправления |
| --- | --- |
| Плеер | Paused load без старого playWhenReady; подписка на just_audio errorStream; production без simulator fallback; сохранение позиции после неудачного restore/retry; владение decoder snapshots и отмена устаревших async действий; безопасная публикация/освобождение Android media session; сбой metadata не блокирует звук. |
| Native Android | Media3 unknown duration соответствует TIME_UNSET и не обнуляет перемотку; канал device profile регистрируется до Dart entrypoint; optional touchscreen/leanback и launcher banner. |
| Загрузки | Согласованность размера/Range; сохранение существующего final при ошибке finalize; сериализация сохранений; ожидание hydration; уникальная source/version identity; защита активного metadata при cache clear; безопасные legacy-пути; корректная скорость после resume. |
| Библиотека/закладки | Durable metadata на главной после очистки card cache; отсутствие подстановки чужой mock-книги в сохранённых деталях; устойчивое чтение повреждённых необязательных metadata без очистки БД. |
| Источники | Ограничение тел ответов/обложек по размеру и времени; запрет автоматических GraphQL redirects; корректные usable renditions Izib, fragment/narrator Akniga; ограниченный fallback других озвучек; runtime media permissions. |
| Phone UI | Переносы при 75–200%, цели касания 48 dp, keyboard-safe выбор фильтра, сохранение выбора полки при повороте, рабочий «Позже», отсутствие бесконечного spinner пустого плеера; порядок поисковых запросов защищён от late history write. |
| TV UI | Отдельный shell/theme/transport, D-pad/Select, явный focus, предсказуемый переход заголовок карточки → действия, overscan-поля для всех маршрутов/диалогов. Общий controller, без второго плеера. |
| Windows UI | Сохранены desktop layout/min-size; добавлены локальные команды плеера и реальные сохранённые детали. |

## Проверки и доказательства

Журналы, PNG и QA JSON сохраняются отдельно от исходников:
`C:/Users/PC/.codex/visualizations/2026/09/05/01a07115-2662-76a0-ad60-8edae9ea73ac/cross-platform-quality/`.

- `tv-focused-02.log`: 15/15 TV widget-проверок, включая D-pad/Select, возврат
  домой, действия карточки и transport, capability vs width, 960×540/1280×720,
  light/dark и 100/200%.
- `mobile-focused-02.log`: 88/88 mobile/search/details проверок. Первый прогон
  выявил реальные overflow metadata, исправленные до повторного успешного прогона.
- `tv-saved-focused-01.log`: все 16 SavedBookDetails cases прошли; три выявленные
  TV focus-проблемы исправлены и подтверждены отдельным `tv-focused-02.log`.
- `tv-final-render/`: 24 PNG основных экранов на 960×540, light/dark, 100/200%;
  четыре параметрических прогона без Flutter layout exceptions. Это
  Flutter-rendered fixtures, **не снимки нативного окна и не реальные книги**.
- Итоговая Windows fixture-матрица: **206 PNG** в light/dark —
  `windows-final-populated/` (100, 900×600 и 200% текста),
  `windows-final-wide-02/` (98, 1920×1000 и 100%),
  `windows-final-empty/` (8 настоящих пустых состояний, 900×600 и 200%).
  Все сценарии прошли автоматические layout/exception-проверки; визуально
  просмотрены репрезентативные экраны, а не каждый из 206 снимков.
  Последние журналы populated/wide — `windows-final-populated-verified.log`
  и `windows-final-wide-02-verified.log`. Контраст Focus повторно просмотрен
  после исправления. Эти fixtures не подменяют native Windows QA ниже.
- `full-suite-final.log`: **1556 PASS / 20 SKIP**, без ошибок, после всех правок.
  Предыдущий полный зелёный прогон — `full-suite-02.log`, 1551 PASS; затем добавлены
  четыре focus-регрессии и один table-driven contrast test. Пропуски относятся
  к opt-in visual/live проверкам; Android instrumentation этим прогоном не запускалась.
- `analyze-final-02.log`: `flutter analyze --no-pub` — **No issues found**.
- `windows-focus-final-02.log`: 20/20 shell/card/playback keyboard tests;
  `theme-preview-final.log`: контраст preview Focus ≥4.5:1 в light/dark/AMOLED
  при 100/200%, с проверкой реально построенного виджета.
- `final-fixtures-focused.log`: 56/56 — source/download policy и старые UI-сценарии
  с корректной source/version identity, без возврата демонстрационных metadata.
- `android-universal-debug-verified.log`: универсальный Debug и androidTest APK
  скомпилированы после последних изменений — `BUILD SUCCESSFUL`;
  Android instrumentation **не выполнялась**.
- `windows-debug-build-verified.log`: native Windows Debug пересобран существующим
  CMake/v142 окружением. Это не release/installer и не проверка стандартного
  Flutter Visual Studio discovery.
- Финальный `dart format --output=none --set-exit-if-changed lib test`:
  268 файлов, 0 изменений. `VERSION` / `pubspec.yaml` остаются `0.0.6` / `0.0.6+6`.
- Во время live Windows QA обнаружена отдельная потеря Ctrl+1…5 из-за начального
  фокуса; добавлен regression с обеими настоящими focus-оболочками.
  При повторной проверке pointer navigation выявлена ещё потеря фокуса в родительский
  route scope; оба случая исправлены и подтверждены widget-тестами. Ограничения
  синтетического native-ввода отдельно описаны ниже.

### Подготовленные Debug-артефакты

- Android phone и TV: `artifacts/qa/Slovofon-v0.0.6-android-universal-debug.apk`,
  231 683 371 байт; ABI `arm64-v8a`, `armeabi-v7a`, `x86_64`.
- SHA-256: `e95b3c39b85dcbca086f660908bea77a2d3c4511cb5e7517be7cc9834f1f6154`.
  Контрольная сумма также записана в
  `artifacts/qa/SHA256SUMS-cross-platform-debug.txt`.
- `android-verified-signature.log`: `apksigner verify` — PASS, APK v2,
  один signer; конфигурация Debug-подписи не менялась.
- `android-verified-badging.log`: package `com.slovofon.app`, версия `0.0.6`,
  versionCode 6, min SDK 24, target SDK 36, обычный и leanback launchers,
  optional touchscreen/leanback, русское имя `Словофон`.
- Windows: `build/windows-desktop-design-debug/runner/Debug/Slovofon.exe`.
  Это локальная Debug-сборка вместе с соседними DLL и `data`, не установщик
  и не переносимый одиночный EXE. После последней пересборки приложение
  повторно запущено: главная, данные книги, источник и пауза на 00:53 сохранены.

### Windows: фактическая визуальная проверка

Проверено нативное окно `build/windows-desktop-design-debug/runner/Debug/Slovofon.exe`
через Computer Use, а не только Flutter fixtures. Снимки находятся в истории
инструментальных действий этой задачи; пользовательские данные не сбрасывались.

- Главная с текущей книгой и соседними главами; библиотека с двумя реальными книгами;
  сохранённая загрузка 64/64; карточка книги с реальными metadata и главами.
- Реальный поиск из существующей истории: 15 результатов, полноширинные строки,
  чтец отдельно от автора, история и источники без пустой полосы.
- Попытка уменьшить окно ниже минимума: получено 902×632 внешних пикселя,
  то есть 900×600 client при текущем 100% DPI. Высота и ширина ограничиваются;
  остаётся desktop rail, а не мобильная нижняя навигация.
- Обычное окно 1283×752 и развёрнутое 1920×1032; настройки используют доступную
  ширину и прокрутку, элементы не накладываются.
- Реально применены 75%, 100%, 200% текста; при 200% и минимальном окне проверены
  светлая тема, настройки, полный плеер, главы и диалог таймера. Escape закрывает
  таймер. Исходные 100% и системная тема восстановлены.
- Название источника читаемо в dock и полном плеере; управление не перекрывается
  большими подписями. Эти наблюдения не означают проверки всех DPI/мониторов.
- Native Play/Pause действительно меняет состояние и двигает позицию главы;
  после проверки восстановлены пауза и исходные 00:53. Прослушивание звука
  через аудиовыход инструмента не проверялось.
- Native Ctrl-сочетания через этот способ синтетического ввода **не подтверждены**:
  Ctrl+Right действует как обычная стрелка; Ctrl+A также не выделяет текст в
  стандартном EditableText, тогда как обычная клавиша вводит символ. Поэтому
  это не объявляется ни успешной native-проверкой, ни доказанным дефектом наших
  обработчиков. Вероятна граница передачи modifier state Win32 → Flutter;
  физическая клавиатура требует отдельного подтверждения. Unit/focus регрессии
  проходят с настоящими для Dart key-down/key-up событиями.

## Нереализованные требования и непроверенные условия

Это не заявление о завершении всего ТЗ. Проверенные исправления выше не заменяют:

- собственные `MediaProxyService` / `ProxyManager` (внутренний header proxy
  just_audio не равен проектному proxy-layer);
- отдельное Windows mini-player окно, tray и полноценный контракт системных
  media keys/metadata; текущий dock — часть главного окна, новые shortcuts локальны;
- настоящую отмену HTTP и полную пагинацию UI всех источников;
- enforcement `coverHosts` для обложек (лимит размера не является allowlist);
- TV voice search и проверку физических пультов разных производителей;
- Wi-Fi-only, пользовательскую папку/квоту, automatic retry/backoff downloads;
- ETag/If-Range контроль изменения контента той же длины при resume;
- реальные disk-full, process kill/Doze, входящий звонок, Bluetooth/headset,
  длительное фоновое воспроизведение и обновление установленного приложения.

Эти пункты сохраняются как отдельный backlog, а не скрываются фиктивными
реализациями. Прокси, данные и критические изменения остаются в рамках AGENTS.md.
