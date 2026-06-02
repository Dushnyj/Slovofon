# Slovofon v0.0.2

Проверочный релиз для проверки автообновлений и полного release pipeline.

## Главное
- Версия приложения поднята до `0.0.2+2`, чтобы проверить обновление поверх `0.0.1`.
- GitHub Actions теперь собирает signed Android APK/AAB из GitHub Secrets.
- Windows artifacts теперь включают portable ZIP, Inno Setup installer и MSI.
- Для всех release files формируется `SHA256SUMS.txt`.

## Важно
- Android APK подписан тем же upload key, который должен использоваться дальше постоянно.
- Windows installer/MSI пока без code signing certificate: Windows может показать предупреждение `Unknown Publisher`.
- Android sideload может показывать предупреждение Google Play Protect для неизвестного разработчика; это не ошибка APK-подписи.
