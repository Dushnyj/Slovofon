# Изображения README

Галерея обновлена 2026-09-06 для исходников `0.0.7+7`.

| Файл | Происхождение |
| --- | --- |
| `slovofon-icon.png` | Побайтовая копия существующего Android launcher icon из `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`; концепция иконки не менялась |
| `windows-home.png` | Настоящие Flutter-виджеты, профиль Windows, 1440×900, тёмная тема |
| `windows-settings.png` | Настройки Windows, 1440×900, тёмная тема |
| `android-settings.png` | Настройки Android phone, 390×844, светлая тема |
| `android-appearance.png` | Панель оформления Android phone, 390×844, светлая тема |
| `android-tv-home.png` | Главная с TV-профилем, 1280×720, тёмная тема |

## Что показывают снимки

Снимки получены через [desktop_design_visual_test.dart](../../../test/ui/desktop_design_visual_test.dart)
на текущих production-виджетах. Везде системный и пользовательский масштабы — 100%.
Используются локальные mock-книги и нейтральные обложки-заглушки; реальные история,
библиотека, сетевые изображения и пользовательские файлы в галерею не попадали.
PNG не ретушировались и не перерисовывались после захвата.

Это Flutter-rendered fixtures, **не нативные Android-скриншоты**. Harness загружает
установленные Windows Segoe UI / Georgia вместо тестового Ahem; на Android шрифт,
системная клавиатура, поля и оболочка могут выглядеть иначе. Файлы шрифтов не
распространяются. Снимки не доказывают работу настоящего пульта или фонового аудио.

## Воспроизведение

В Windows, после `flutter pub get`, запустите из корня репозитория:

```powershell
$env:SLOVOFON_VISUAL_DIR = Join-Path (Get-Location) 'artifacts/readme/windows'
$env:SLOVOFON_VISUAL_PLATFORM = 'windows'
$env:SLOVOFON_VISUAL_TELEVISION = '0'
$env:SLOVOFON_VISUAL_FILTER = 'dark'
$env:SLOVOFON_VISUAL_SIZES = '1440x900'
$env:SLOVOFON_VISUAL_APP_SCALES = '1'
$env:SLOVOFON_VISUAL_SYSTEM_SCALES = '1'
$env:SLOVOFON_VISUAL_WORKSPACE = '1'
$env:SLOVOFON_VISUAL_PAGE_FILTER = '=home,=settings'
flutter test --no-pub test/ui/desktop_design_visual_test.dart
```

Для телефона поменяйте выходную папку, platform на `android`, filter на `light`,
размер на `390x844`, page filter на `=settings,=appearance`. Для TV используйте
отдельную выходную папку, platform `android`, television `1`, filter `dark`,
размер `1280x720`, page filter `=home`. Запускайте варианты последовательно.

После захвата проверьте PNG и верните переменные процесса в исходное состояние
либо закройте этот терминал. Перед обычным полным `flutter test` переменные
`SLOVOFON_VISUAL_*` не должны включать opt-in захваты. Исходные полные журналы и
JSON-проверки хранятся в локальной QA-папке задачи, а в Git включены только
шесть перечисленных изображений и этот документ.

Лицензии существующих компонентов: [THIRD_PARTY_NOTICES.md](../../../THIRD_PARTY_NOTICES.md).
