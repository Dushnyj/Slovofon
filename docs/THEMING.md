# THEMING.md — темы, цвета и защита от проблем контраста

Этот документ описывает дизайн-систему цветов Slovofon. Обязательные правила Codex находятся в `AGENTS.md`.

---

## 1. Главная проблема

Нельзя допускать белый текст на белом фоне, чёрный текст на чёрном фоне, невидимые disabled/focused/selected состояния и другие проблемы контраста.

---

## 2. Жёсткие правила

Запрещено:

- массово использовать `Colors.white` и `Colors.black` напрямую в widgets;
- задавать цвет текста без понимания цвета фона;
- задавать background у snackbar/dialog/card без соответствующего foreground;
- использовать разные несвязанные палитры для экранов;
- делать отдельные ручные цвета для light/dark без проверки контраста;
- полагаться на системные дефолты, если компонент кастомный.

Обязательно:

- использовать `ThemeData` и `ColorScheme`;
- использовать пары `primary/onPrimary`, `surface/onSurface`, `error/onError`, `secondary/onSecondary`;
- для кастомных цветов иметь функцию подбора контрастного foreground;
- все UI-компоненты брать цвета из `AppTheme`, `AppColorTokens` или `Theme.of(context).colorScheme`;
- все состояния кнопок иметь readable foreground/background;
- snackbar, dialogs, bottom sheets, menu, tooltip, chips и cards должны иметь явно заданные цвета через theme extensions;
- accent color должен пересчитывать related on-colors.

---

## 3. Цветовые токены

```text
background
backgroundAlt
surface
surfaceVariant
surfaceElevated
primary
primaryContainer
accent
success
warning
error
textPrimary
textSecondary
textMuted
border
disabled
overlay
focus
hover
selected
```

---

## 4. Темы

```text
System
Light
Dark
AMOLED optional
```

---

## 5. Акцентный цвет

Пользователь выбирает:

```text
Бирюзовый
Синий
Фиолетовый
Зелёный
Оранжевый
Красный
Пользовательский optional
```

Акцент влияет на активные кнопки, progress bars, выбранную вкладку, выделенную главу, навигацию, timer badge, focus outline на TV/Windows.

---

## 6. ThemePreviewScreen

Codex должен создать внутренний экран `ThemePreviewScreen`.

На нём должны быть:

```text
кнопки всех типов
icon buttons
chips
cards
book cards
chapter tiles
snackbar preview
dialog preview
bottom sheet preview
text fields
progress bars
download states
player controls
error/warning/success states
source chips
TV focus state
Windows hover/focus state
```

Перед релизом проверить light/dark/AMOLED, каждый акцентный цвет, увеличенный размер шрифта и compact/normal card mode.

---

## 7. Android notification colors

Для Android notification/lock screen использовать стандартный MediaStyle. Не делать кастомную нотификацию с собственными цветами, если стандартный media session решает задачу лучше.
