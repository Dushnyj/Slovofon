# Changelog

Формат основан на Keep a Changelog, версии — Semantic Versioning.

## [Unreleased]

### Fixed
- Автопроверка обновлений снова показывает доступную версию при каждом новом запуске приложения: `Пропустить` скрывает обновление только в текущей сессии и больше не сохраняется на диск.
- Android Media3 service больше не останавливает играющую книгу при смахивании приложения из списка последних; если воспроизведение уже остановлено, session и notification очищаются.

## [0.0.4] - 2026-06-02

### Fixed
- Ручная проверка обновлений и скачивание обновления теперь показывают понятное сообщение о проблеме сети с кнопкой `Повторить`, без технических `SocketException`/HTTP-текстов.
- Сетевые ошибки update-flow вынесены в отдельную нормализацию и покрыты тестом, чтобы пользовательские сообщения оставались локализованными и безопасными.

## [0.0.3] - 2026-06-02

### Fixed
- Исправлена внутренняя константа версии приложения: `AppVersion` теперь синхронизирован с `VERSION` и `pubspec.yaml`, поэтому обновление `0.0.2` больше не должно бесконечно определяться как новое после установки следующего патча.
- `tools/slovofon.ps1 version` теперь обновляет `lib/app/app_version.dart`, а release workflow проверяет совпадение версии до сборки.
- Окно обновления показывает простой текст, размер файла, прогресс скачивания и скорость без технического описания проверки подписи/sha256.
- Android updater проверяет разрешение на установку APK до скачивания и открывает системные экраны без отдельного task, чтобы возврат из настроек не сбрасывал пользовательский контекст.

## [0.0.2] - 2026-06-02

### Added
- Добавлен полный GitHub Actions release workflow: signed Android APK/AAB, Windows portable ZIP, Inno Setup installer, WiX MSI, `SHA256SUMS.txt` и публикация GitHub Release.
- Windows release теперь готовит отдельные `setup.exe` и `msi.msi` artifacts в дополнение к portable ZIP.
- Android release workflow восстанавливает upload keystore из GitHub Secrets во временный runner path и проверяет APK-подписи через `apksigner verify`.

### Changed
- Версия приложения поднята до `0.0.2+2` для проверки update manifest, скачивания APK и установки обновления поверх `0.0.1`.

## [0.0.1] - 2026-06-01

### Added
- Добавлена система автообновлений: приложение проверяет stable manifest, показывает `Обновить`/`Пропустить`, скачивает asset, проверяет `sha256` и открывает системную установку APK/Windows installer.
- Добавлена Ed25519-подпись update manifest: `SlovofonBot` подписывает `latest.json`, а приложение отвергает unsigned/tampered manifest до скачивания обновления.
- Android release signing подключён к внешнему `android/key.properties`; release-сборка больше не fallback-ится на debug key.
- В настройках добавлены публичные ссылки проекта: сайт, GitHub приложения, Telegram-бот поддержки, Telegram-канал, Telegram-чат и stable manifest канала обновлений.
- Зафиксирована схема будущей проверки обновлений через `https://slovofon-updates.duckdns.org`: stable/beta manifest, `no_release`/`available`, обязательная проверка `sha256` перед установкой и запрет на хранение секретов в клиенте.
- Добавлен Stage 9 `YaknigaSourceConnector`: public GraphQL search/details, chapters через `chapters.collection`, `fileUrl` как direct media source, `User-Agent`/`Referer` headers, media allowlist и health check.
- Добавлены Stage 9 тесты Yakniga для GraphQL client/transport, mapper, source connector, media headers и optional live smoke-test против `yakniga.org`.
- Добавлен Stage 9 `KnigavuheSourceConnector`: HTML search/details, `BookPlayer` playlist parser, media headers, allowlist для `*.knigavuhe.org` и разрешённых LitRes trial URL, health check и optional live smoke-test.
- Добавлен Stage 9 `KnigobludSourceConnector`: HTML search/details, `KB.playerInit` playlist parser, media headers, allowlist для `*.audioknigi.xyz` и разрешённых LitRes trial URL, health check и optional live smoke-test.
- Добавлен Stage 9 `BazaKnigSourceConnector`: HTML search/details, `Playerjs(file: [...])` parser, media headers, allowlist для `*.abooka.casa`, фильтрация неразрешённых fallback-hosts и optional live smoke-test.
- Yakniga, Knigavuhe, Knigoblud и Baza Knig зарегистрированы в default `SourceRegistry`; экран поиска теперь отправляет запрос во все включённые реальные источники.
- Добавлен Stage 8 `AknigaSourceConnector`: HTML search/details parser, `book id`/`bid`, `ajax/bid` track resolver, LiveStreet security key extraction, CryptoJS/OpenSSL-compatible AES-CBC request hash, Referer/media headers и media allowlist для `*.akniga.club`/`*.audioknigi.xyz`.
- Добавлены Stage 8 тесты Akniga для security encoder, HTML mapper, client/transport, source connector, media headers, cookie session behavior и optional live smoke-test против `akniga.org`.
- Akniga зарегистрирован в default `SourceRegistry`; экран поиска теперь отправляет запрос во все включённые источники, а не только в Izib.
- Добавлен `SourceCatalogService` как app-level слой над `SourceRegistry`: поиск источников, загрузка details/chapters, resolveMedia и сборка `AudioBook`/`AudioPlaybackBook` для UI, плеера и загрузок без прямых HTTP-вызовов из widgets.
- Добавлен экран source book details для реальных книг Izib: обложка, авторы, чтецы, жанр, описание, главы, запуск книги/главы в плеере и действия загрузки через существующий `DownloadManager`.
- Добавлен `SearchHistoryStore` для сохранения истории поисковых запросов с типом поиска: название, автор, чтец или цикл.
- Добавлен `LibraryStore` с Drift persistence для избранного: сохранённые через поиск источников книги появляются в библиотеке и переживают перезапуск приложения.
- Добавлены Stage 7 widget/service-тесты для end-to-end пути Izib в приложении: поиск, карточка, details, запуск playback, full player metadata/chapters и отображение реальных source download tasks без fallback на mock-книги.
- Добавлен Stage 7 `IzibSourceConnector`: первый реальный источник через GraphQL API Izib, runtime SIGN generation, поиск, details, files -> chapters/audio tracks, resolveMedia/download через media allowlist и health check.
- Добавлены Stage 7 тесты Izib для GraphQL client/signing, mapper, source connector, allowlist validation и безопасной обработки API ошибок без раскрытия SIGN.
- Добавлен Stage 6 `SourceConnector` framework: общий контракт источников, `SearchRequest`, `BookSearchResult`, `BookVersionDetails`, `ResolvedMedia`, `SourceCapabilities`, `SourceHealth`, `SourceException` и агрегирующий `SourceSearchResponse`.
- Добавлен `SourceRegistry` как единая точка доступа к источникам: регистрация коннекторов, защита от duplicate ids, фильтрация enabled/requested sources, агрегация частичных ошибок поиска, capabilities map и health checks.
- Добавлены `SourceMediaPolicy` и `SourceMediaValidator`: проверка media allowlist, запрет URL с credentials, запрет non-http схем и явное разрешение local asset/file media только для mock/local источников.
- Добавлены shared parser helpers для источников: нормализация whitespace/title, парсинг чисел/годов/длительности и безопасное разрешение URI.
- Добавлен `MockSourceConnector.yakniga()` поверх текущих Stage 3/4 mock data для тестируемой интеграции search/details/chapters/audio tracks/resolveMedia без сети.
- Добавлены Stage 6 unit-тесты для registry, media validator, parser helpers и mock connector.
- Добавлен Stage 5 `DownloadManager`: очередь загрузок глав и книг, ограничение параллельности, pause/resume/cancel/retry/delete, прогресс, скорость и восстановление прерванных задач после перезапуска как resumable.
- Добавлены `DownloadClient`, `FileDownloadStorage` и `DownloadPersistenceStore`: скачивание URL/file/asset media sources, `.part` файлы, Range/resume, атомарное завершение файла, `metadata.json` и Drift-сохранение `DownloadTask`.
- Добавлено подключение оффлайн-файлов к плееру: скачанные главы подставляются в `AudioPlaybackBook` как `AudioMediaSource.file`, без удаления истории, избранного, закладок и прогресса при удалении аудио.
- Добавлены Stage 5 тесты для загрузки главы/книги, pause/resume по `.part`, cancel/delete, restart recovery и обновления статусов главы без потери playback progress.
- Добавлен Stage 4 `PlaybackController`: `AudioEngine` abstraction, playback state, play/pause/seek, speed, chapter switching, progress calculation, session restore and sleep timer behavior.
- `PlaybackController` теперь слушает runtime snapshots от audio backend: позицию, ready/buffering/completed/error states и автоматически переходит к следующей главе при завершении текущей.
- Добавлен `JustAudioEngine` поверх `just_audio` с URL/file/asset media source API и Windows backend через `just_audio_windows`.
- Добавлен Android/system-media слой на native AndroidX Media3: `SlovofonMediaSessionService`, `SlovofonMediaSessionPlayer` и Dart `AndroidMediaSessionEngine` синхронизируют metadata/state с `PlaybackController` и возвращают notification/lock screen/media button команды в app-level playback.
- Добавлен `PlaybackPersistenceStore` на Drift для сохранения и восстановления `PlaybackSession` и `PlaybackProgress` без уменьшения max reached progress.
- Добавлен локальный сгенерированный `assets/audio/stage4_mock_chapter.wav` fixture на 45 минут, чтобы mock playback мог открыть реальный audio asset без сети и не завершал главу сразу после старта с сохраненной позиции.
- Добавлен in-memory `AudioEngine` и switching engine для тестируемого Stage 4 ядра и mock UI без реальных media URL.
- Добавлены Stage 4 unit-тесты для playback controls, runtime backend states, progress persistence, chapter navigation, session restore, sleep timer, `JustAudioEngine`, Android Media3 session facade и local audio fixture.
- Добавлен Stage 3 UI на mock data: главная, поиск, карточка книги, библиотека, загрузки, настройки, мини-плеер и полный плеер.
- Добавлены маршруты `/book/:bookId` и `/player` для mock-карточки книги и полноэкранного плеера.
- Расширены mock data книгами, версиями, главами, закладками, полками библиотеки и состояниями загрузок.
- Добавлены Stage 3 widget-тесты для навигации, поиска, карточки книги, full player, библиотеки, загрузок и настроек.
- Добавлены Stage 2 дизайн-токены: semantic colors, spacing, radii, focus/hover/selected states и минимальные 48dp размеры интерактивных контролов.
- Добавлены общие UI-компоненты Stage 2: primary/secondary/quiet buttons, source/access chips, `ChapterTile`, loading/empty/error placeholders.
- Добавлены draft app icon SVG и полный Lucide-based SVG icon inventory для nav, book, player, downloads и system групп.
- Добавлен единый `AppIcon`/`AppIconAssets` слой для локальных Lucide SVG в пользовательском интерфейсе.
- Расширен `ThemePreviewScreen` превью для Stage 2 компонентов, chapter tile, state variants и focus/state colors.
- Добавлены Stage 2 тесты для дизайн-системы, ассетов и reusable компонентов.
- Добавлены доменные модели Stage 1: `Book`, `BookVersion`, `Chapter`, `AudioTrack`, `PlaybackSession`, `PlaybackProgress`, `DownloadTask`, `Bookmark` и `AppSettings`.
- Добавлена Drift/SQLite схема версии 1 с обязательными таблицами для книг, источников, воспроизведения, загрузок, закладок, истории поиска, настроек, proxy profiles и source settings.
- Добавлены тесты Stage 1 для доменных моделей и in-memory Drift database.
- Описана схема release signing для Android и Windows: хранение ключей вне Git, будущие GitHub Secrets, временное восстановление ключей в CI и правила компрометации.
- Добавлен безопасный шаблон `android/key.properties.example` для будущей Android release-подписи.
- GitHub Actions CI теперь собирает Android debug APK и Windows debug bundle, публикуя их как временные Actions artifacts.
- Добавлен GitHub Actions CI workflow для проверки `flutter pub get --enforce-lockfile`, форматирования, `flutter analyze` и `flutter test`.
- Добавлены `LICENSE` с Apache License 2.0 и `NOTICE` для обязательного attribution notice проекта.
- Инициализирован стартовый Flutter/Dart-каркас проекта `slovofon` с версией `0.0.1+1`.
- Добавлены `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`, базовая структура `lib/`, стартовый widget test.
- Добавлены базовые слои приложения: bootstrap, router, локализация, тема, semantic color tokens, mock data и shell-навигация.
- Добавлена стартовая структура `assets/` для app assets, icons и l10n, подключённая в `pubspec.yaml`.
- Добавлен внутренний `ThemePreviewScreen` для проверки базовых кнопок, chips, карточек, input, progress и state colors.
- Добавлен главный PowerShell-скрипт `tools/slovofon.ps1` с командами `bootstrap`, `check`, `doctor`, `get`, `format`, `analyze`, `test`, `build`, `version`, `release`, `clean`.
- Сгенерированы стартовые Android и Windows платформенные файлы Flutter.
- Android `applicationId` и namespace зафиксированы как `com.slovofon.app`; Android display name локализован: `Словофон` для `ru`, `Slovofon` по умолчанию.
- Windows executable/metadata приведены к `Slovofon` и `Slovofon Team`.
- Подготовлен комплект проектной документации для старта разработки Slovofon.
- Зафиксирована структура обязательных документов: `AGENTS.md`, `docs/SLOVOFON_TECHNICAL_SPEC_RU.md`, `docs/ARCHITECTURE.md`, `docs/BUILD_RELEASE.md`, `docs/SECURITY.md`, `docs/THEMING.md`, `docs/SOURCES.md`.
- Зафиксировано название продукта: `Словофон` для русской локализации и `Slovofon` для остальных локализаций.
- Зафиксирован репозиторий: `https://github.com/Dushnyj/Slovofon.git`.
- Зафиксированы правила версионности, сборки, релизов, источников, безопасности, прокси, тем и ассетов.

### Changed
- Вкладка "О приложении" упрощена до версии, номера сборки, сайта проекта, GitHub, Telegram-канала и Telegram-бота поддержки; GitHub/Telegram получили брендовые иконки.
- Из вкладки поиска убран отдельный фильтр источников: выбор источников остаётся в настройках и напрямую управляет `SourceRegistry`; фильтр сортировки стал рабочим.
- Главная теперь показывает список всех начатых книг из сохранённого прогресса, сортируя их по последней дате прослушивания сверху вниз.
- Карточки на главной можно смахнуть влево, чтобы скрыть книгу только с главной страницы без удаления сохранённого прогресса, избранного или скачанных файлов.
- Карточки книг на главной, в поиске и библиотеке унифицированы под нормализованные source metadata: название до двух строк с ellipsis, авторы/чтецы максимум по два значения, цветная локализованная подпись источника и номер книги в цикле с поддержкой дробных номеров вроде `21.1`.
- Экран поиска после запуска запроса открывает отдельный экран результатов с кнопкой назад, количеством найденных книг и списком карточек без повторного показа строки поиска и фильтров.
- Фильтры поиска переведены на compact selectors: multi-select полей поиска (`Название`, `Автор`, `Чтец`, `Цикл`) и multi-select источников вместо ряда отдельных chips.
- Настройки источников теперь реальные: каждый источник можно включать и выключать, а `SourceRegistry` использует сохранённые настройки.
- Мини-плеер стал компактнее и показывает обложку, книгу, главу, время текущей главы, процент всей книги и цветную подпись источника.
- Полный плеер получил более плотный now-playing layout: обложка увеличена, автор и чтец вынесены в отдельные строки с иконками, длительность главы отображается как `1:29:00`, а sleep timer pill скрывается, когда таймер отключён.
- Полный плеер теперь использует общий download action для всей книги с circular progress/cancel/delete состояниями, показывает источник, цикл и год, а автор/чтец/цикл открывают поиск с нужным фильтром.
- Search/home/library copy и source chips обновлены под шесть реальных источников: Izib, Akniga, Yakniga, Knigavuhe, Knigoblud и Baza Knig.
- Маршруты source-книг теперь кодируют `sourceBookId` через `Uri.encodeComponent`, чтобы HTML-источники с `/` в id открывались из поиска, главной, библиотеки и плеера.
- Карточки книг и глав получили единый borderless icon-action стиль: play/pause, info, favorite, download/delete/retry больше не используют квадратные outlined-кнопки.
- Favorite-состояние теперь синхронизируется с активной карточкой на главной; выбранное избранное отображается заполненным красным сердцем.
- Play с карточки поиска остаётся на экране поиска, показывает loading только до старта текущей книги и затем переключается в pause для активного аудио.
- Download-кнопки на карточках и главах теперь используют единый круговой прогресс с крестиком отмены внутри; в загрузках убрано дублирование кнопок удаления.
- Экран поиска переключён с mock-выдачи на реальный поиск через `SourceCatalogService`; пустое состояние теперь показывает готовность к поиску по источникам.
- Поиск больше не запускается на каждый ввод символа: запрос выполняется только по search action/кнопке, сохраняется в историю и фильтруется по выбранному полю так, чтобы все слова запроса совпадали как префиксы слов результата независимо от порядка.
- Полный плеер, мини-плеер, карточки и экран загрузок теперь сохраняют и показывают metadata реального источника: `sourceBookId`, cover URL, описание, жанр, год, source URL, автора и чтеца.
- Порядок реализации реальных источников изменён: Stage 7 — Izib, Stage 8 — Akniga, Stage 9 — Yakniga, Knigavuhe, Knigoblud и Baza Knig.
- Экран загрузок теперь группирует реальные задачи `DownloadManager` по книгам в разделах активные/очередь/ошибки/завершённые; список глав раскрывается внутри карточки книги, а сама карточка показывает общие действия pause/resume/retry/delete для всей книги.
- Экран source book details теперь по умолчанию показывает первые 5 глав и раскрывает остальные по кнопке.
- Карточка результата Izib показывает локальный circular loading вместо кнопки play/download, пока приложение загружает details/chapters/media; после постановки в очередь download-кнопка становится круговым прогрессом с отменой всей книги.
- Главная скрывает плашку "Найдите книгу в Izib", если уже есть активная книга для продолжения прослушивания.
- Главная, поиск, библиотека, карточка книги и полный плеер теперь вызывают реальные действия загрузки книги/главы через `DownloadManager`.
- Bootstrap приложения подключает app-specific storage для книг и общий Drift persistence для плеера, загрузок и избранного.
- Мини-плеер и полный плеер теперь читают состояние через единый `PlaybackController`, а не напрямую из статичных mock-полей.
- Внутренний app-level audio service переименован в `PlaybackController`, чтобы отделить состояние приложения от платформенных media adapters.
- Главная, поиск и библиотека получили более плотные book cards: процент прослушивания поверх обложки, прогресс под обложкой, metadata с иконками и icon-only действия для избранного, загрузки, запуска и информации.
- Карточка "Продолжить прослушивание" переработана с крупной обложкой, процентом прогресса, metadata и быстрыми icon-only действиями.
- Мини-плеер снизу стал компактнее и информативнее: тонкая полоса прогресса, обложка, глава, позиция и процент прослушивания.
- Полный плеер переработан под мобильный сценарий: вкладки заменены на dots, controls собраны в одну строку, добавлены chapter count, download book action, sleep timer и единая нижняя панель прогресса.
- Карточки загрузок получили обложки, автора, чтеца, год и компактные иконки для download/downloading/cancel/delete/resume/retry состояний.
- Chapter tile в полном плеере теперь показывает icon-only действие скачивания или удаления скачанной главы.
- `SlovofonShell` получил adaptive layout: bottom navigation для компактных экранов и navigation rail для широких окон.
- Пользовательский UI переведён с временных `Icons.*` glyphs Material на локальные Lucide SVG assets.
- Заменены временные одинаковые download-state SVG на осмысленную Lucide-карту: download, loader, queued, checked, trash, retry, error, pause и resume.
- Логическое имя технического ТЗ изменено с `auralib_technical_spec_ru.md` на `docs/SLOVOFON_TECHNICAL_SPEC_RU.md`.
- Убрано рабочее имя `Auralib` из технического ТЗ.

### Fixed
- Android Media3 notification/lock screen provider теперь помечает все audiobook controls как compact actions и добавляет Stop-команду: предыдущая глава, назад 30 секунд, play/pause, stop, вперёд 30 секунд, следующая глава.
- Bottom sheet фильтров поиска больше не переполняется над мини-плеером/нижней навигацией: списки выбора стали ограниченными по высоте, прокручиваемыми, а кнопка применения остаётся закреплённой снизу.
- Карточки поиска больше не считают одинаковыми разные результаты с похожими названием и автором: active/loading/playback state привязывается только к точным `sourceBookId`/`versionId`/стабильным id, поэтому запуск одной версии не включает пачку соседних карточек.
- Запуск книги из поиска, библиотеки и главной продолжает её с сохранённой главы и позиции, если по книге уже есть `PlaybackProgress`.
- `PlaybackController` больше не откатывает автозапуск source-книги в `paused`, если audio backend после `play()` присылает поздний `idle`/`ready` snapshot с `isPlaying=false`; карточка и мини-плеер остаются в активном play-состоянии до подтверждённой паузы, ошибки или завершения.
- Knigavuhe дополнительно нормализует год и рейтинг из данных страницы, включая fallback на год добавления и рейтинг из likes/dislikes, когда aggregate rating отсутствует.
- Baza Knig очищает служебные пометки озвучки вроде `(альтернативная озвучка)` из имени чтеца, убирает служебный префикс `Скачать аудиокнигу`/автора из live-заголовков и принимает `archive.org/download/*.mp3` как строгий media fallback для страниц, где источник отдаёт такой PlayerJS playlist.
- Baza Knig помечен как источник с временными media URL: восстановление сессии обновляет playback metadata через `SourceCatalogService`, а неизвестная длительность главы дообновляется из `just_audio`, чтобы UI-позиция не застывала на `00:00`.
- Knigoblud извлекает автора из emoji/meta-блоков, а цикл и номер книги в цикле — из блока серии на странице details.
- Akniga HTTP transport сохраняет cookies между page GET и `ajax/bid` POST, как session в reference implementation; без этого живой `ajax/bid` возвращал не-JSON ответ.
- Последняя активная книга теперь восстанавливается после обновления/перезапуска приложения: `PlaybackController` сохраняет metadata активной книги и bootstrap поднимает `PlaybackSession` без автозапуска аудио.
- Экран загрузок после перезапуска больше не деградирует до `izib-book-*`: `DownloadManager` восстанавливает контекст книги, обложку, автора, чтеца, главы и media metadata из сохранённого `metadata.json`.
- Карточки поиска и библиотеки теперь подписаны на runtime-состояние плеера: после паузы `Pause` сразу меняется на `Play`, а не остаётся старой иконкой.
- Кнопки play/download на карточках библиотеки для сохранённых Izib-книг снова активны и загружают реальные source details перед запуском или постановкой в загрузки.
- Исправлен Izib GraphQL transport: JSON body теперь отправляется как UTF-8 bytes, поэтому кириллические запросы вроде `дыхание зоны` не падают в `HttpClientRequest.write`.
- Исправлена media allowlist для Izib: реальные главы с hosts вида `r4.audioknigi.xyz` теперь проходят source validation и открывают карточку/плейлист без `mediaValidation` ошибки.
- Иконки на карточке результата Izib теперь выполняют действия: избранное переключает состояние, загрузка ставит книгу в `DownloadManager`, play загружает реальные главы и открывает плеер.
- Активное избранное теперь отображается красным сердцем на карточках поиска/библиотеки, а библиотека сразу читает тот же `LibraryStore`, что и кнопка избранного.
- Play loading на карточке результата Izib теперь сбрасывается сразу после успешного старта playback и не остаётся крутиться поверх уже запущенного мини-плеера.
- Download loading на карточке результата Izib больше не маскирует активную загрузку: для queued/downloading показывается прогресс-кольцо с отменой и удалением скачанных частей всей книги.
- Экран загрузок больше не показывает частично известный размер как полный размер книги: до получения всех totals отображается скачано / размер уточняется.
- Source book details получил дополнительный нижний safe padding, чтобы блок информации и кнопки не залезали под системную навигацию Android.
- Открытие source-карточки из поиска теперь использует stack navigation; системная кнопка Back и правый свайп возвращают на прошлый экран, а не закрывают приложение.
- Поиск теперь показывает ошибку источника, если все подключённые источники вернули failure, вместо ложного состояния "Ничего не найдено".
- Главная и production `PlaybackController` больше не стартуют с предзагруженной mock-книгой "Мастер и Маргарита"; стартовый экран ведёт в реальный поиск источников.
- Библиотека больше не показывает Stage 3 mock-книги как пользовательские сохранённые книги; до добавления книг экран честно пустой и ведёт в поиск источников.
- Исправлен размер SVG search icon внутри `TextField`, чтобы prefix icon не растягивался на Android.
- Исправлена отрисовка Lucide SVG icons в Flutter UI через явный `ColorFilter`.
- Исправлено подключение SVG icons из подпапок `assets/icons/*` в `pubspec.yaml`.
- Lucide stroke/fill параметры продублированы на shape-элементы SVG для стабильного Android-рендера.
- Основные action-кнопки mock UI заменены на icon-only controls с tooltip вместо громоздких текстовых кнопок.

### Security
- Публичные домены Slovofon разрешены только как HTTPS URL; SSH/IP/пароли/tokens/bot credentials не должны попадать в клиент, Git, Basic Memory, CI logs или release artifacts.
- Добавлена source-level media validation: реальные коннекторы обязаны отдавать media только через allowlist домены, без произвольных URL и без credentials в URL.
- Расширены правила для signing secrets: Android `.jks`, Windows `.pfx`, GitHub Secrets и CI cleanup.
- Зафиксирован запрет на хранение приватных API secrets в клиенте.
- Зафиксировано правило: generated SIGN/token не сохранять и не логировать.
