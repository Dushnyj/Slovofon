# Slovofon v0.0.1

Первый публичный технический релиз Slovofon.

## Главное
- Реальные источники аудиокниг: Izib, Akniga, Yakniga, Knigavuhe, Knigoblud и Baza Knig.
- Поиск, карточки книг, библиотека, загрузки, мини-плеер и полный плеер.
- Воспроизведение через `just_audio`, Android Media3 notification/lock screen и восстановление позиции.
- Загрузки глав и книг с offline metadata/cache.
- Настройки темы, языка, источников и публичные ссылки проекта.
- Автообновления через подписанный Ed25519 manifest и проверку `sha256`.

## Безопасность релиза
- Android APK/AAB подписаны release/upload key.
- Update manifest подписывается Ed25519 на стороне SlovofonBot.
- Windows portable build в этом релизе не подписан: Windows может показать предупреждение `Unknown Publisher`.
