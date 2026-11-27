# Slovofon v0.1.5

В этом выпуске — новый поиск по «Базе книг» и более спокойное сообщение при неполной выдаче.

## Что изменилось

- **«Умный поиск» в «Базе книг».** Название, автор, чтец и цикл используют штатные фильтры сайта, жанр — его каталог. Следующие страницы загружаются по ссылкам самого сайта.
- **Смешанные запросы.** Можно указать название, автора, чтеца, цикл и жанр в одной строке. Приложение сверяет слова по метаданным одной озвучки и не склеивает разные версии книги.
- **Без большого красного баннера.** При частичном сбое уже найденные книги остаются в списке. Вместо баннера — короткое сообщение и возможность повторить запрос. Точные причины и номера страниц видны только в раскрытой диагностике Debug.

**Известное ограничение:** сайт всё ещё может ограничивать отдельные запросы общего поиска по свободному тексту. Страницы фильтров и каталогов догружаются отдельно и не выдаются за продолжение такого запроса.

## Скачать

- **Android, планшеты и Android TV:** [универсальный APK](https://github.com/Dushnyj/Slovofon/releases/download/v0.1.5/Slovofon-v0.1.5-android-universal-release.apk).
- **Windows x64:** [Setup](https://github.com/Dushnyj/Slovofon/releases/download/v0.1.5/Slovofon-v0.1.5-windows-x64-setup.exe) · [MSI](https://github.com/Dushnyj/Slovofon/releases/download/v0.1.5/Slovofon-v0.1.5-windows-x64-msi.msi) · [Portable ZIP](https://github.com/Dushnyj/Slovofon/releases/download/v0.1.5/Slovofon-v0.1.5-windows-x64-portable.zip).

> [!TIP]
> Обновляйте Setup поверх Setup, MSI поверх MSI; portable распаковывайте в новую папку. Настройки, библиотека и прогресс сохраняются.

[Все изменения](https://github.com/Dushnyj/Slovofon/blob/v0.1.5/CHANGELOG.md) · [Помощь с установкой](https://github.com/Dushnyj/Slovofon/blob/v0.1.5/docs/GETTING_STARTED.md) · [Контрольные суммы SHA-256](https://github.com/Dushnyj/Slovofon/releases/download/v0.1.5/SHA256SUMS.txt).
