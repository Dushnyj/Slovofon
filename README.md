# Slovofon / Словофон

<div align="center">

[![version](https://img.shields.io/badge/version-0.0.1-0969da?style=flat-square)](VERSION)
[![status](https://img.shields.io/badge/status-early%20development-f59e0b?style=flat-square)](#статус)
[![platform](https://img.shields.io/badge/platform-Android%20%7C%20Android%20TV%20%7C%20Windows-2ea44f?style=flat-square)](#платформы)
[![ci](https://img.shields.io/github/actions/workflow/status/Dushnyj/Slovofon/ci.yml?branch=main&label=ci&style=flat-square)](https://github.com/Dushnyj/Slovofon/actions/workflows/ci.yml)
[![code size](https://img.shields.io/github/languages/code-size/Dushnyj/Slovofon?style=flat-square)](https://github.com/Dushnyj/Slovofon)
[![license](https://img.shields.io/github/license/Dushnyj/Slovofon?style=flat-square)](LICENSE)

**Словофон** — кроссплатформенное приложение для поиска, прослушивания и оффлайн-загрузки аудиокниг из нескольких источников.

[Документация](#документация) · [Быстрый старт](#быстрый-старт) · [Разработка](#разработка) · [Лицензия](#лицензия)

</div>

## Статус

Проект находится на раннем этапе разработки: уже подготовлен Flutter-каркас, базовая архитектура, Android/Windows scaffolding, тема, mock data, единый PowerShell-скрипт обслуживания проекта и GitHub Actions CI с debug-сборками Android и Windows.

Публичная версия: **0.0.1**.<br>
Русское название приложения: **Словофон**.<br>
Международное название и техническое имя: **Slovofon**.

## Что делает приложение

Slovofon задуман как единый клиент-агрегатор аудиокниг:

- поиск книг по нескольким источникам;
- выбор версии книги по источнику, чтецу, длительности и доступности;
- онлайн-прослушивание и оффлайн-загрузка;
- восстановление последней позиции после перезапуска;
- mini-player и полноэкранный плеер;
- отдельные режимы интерфейса для Android, Android TV и Windows;
- настройки источников, темы, языка, прокси, загрузок и плеера.

Главный принцип продукта: пользователь думает о книге, а не об источнике.

## Платформы

| Платформа | Цель |
| --- | --- |
| Android | смартфоны и планшеты |
| Android TV | управление пультом и фокусная навигация |
| Windows 10/11 | desktop-layout, mini-player и системная интеграция |

## Быстрый старт

После клонирования репозитория:

```powershell
./tools/slovofon.ps1 bootstrap
./tools/slovofon.ps1 check
```

Запуск базовых проверок:

```powershell
./tools/slovofon.ps1 format
./tools/slovofon.ps1 analyze
./tools/slovofon.ps1 test
```

Сборка debug-версии:

```powershell
./tools/slovofon.ps1 build -Target android -Configuration debug
./tools/slovofon.ps1 build -Target windows -Configuration debug
```

## Разработка

Главный скрипт проекта:

```text
tools/slovofon.ps1
```

Перед началом любой задачи Codex и другие ИИ-агенты обязаны читать `AGENTS.md`.

Значимые изменения должны проходить:

```powershell
./tools/slovofon.ps1 format
./tools/slovofon.ps1 analyze
./tools/slovofon.ps1 test
```

## Документация

| Файл | Назначение |
| --- | --- |
| `AGENTS.md` | постоянные правила Codex, Git/GitHub, версии, релизы и запреты |
| `docs/SLOVOFON_TECHNICAL_SPEC_RU.md` | продуктово-техническое ТЗ |
| `docs/ARCHITECTURE.md` | архитектура, слои, модули и data flow |
| `docs/BUILD_RELEASE.md` | bootstrap, сборка, установщики и релизы |
| `docs/SECURITY.md` | секреты, прокси, пользовательские данные и логи |
| `docs/THEMING.md` | темы, цвета, контраст и ThemePreviewScreen |
| `docs/SOURCES.md` | источники, адаптеры и media allowlist |
| `CHANGELOG.md` | история изменений |
| `THIRD_PARTY_NOTICES.md` | сторонние библиотеки, ассеты и лицензии |

## Репозиторий

[github.com/Dushnyj/Slovofon](https://github.com/Dushnyj/Slovofon)

## Лицензия

Slovofon распространяется по лицензии [Apache License 2.0](LICENSE).

При использовании, изменении или распространении кода необходимо сохранять `LICENSE`, copyright notice и содержимое `NOTICE` в соответствии с условиями Apache-2.0.
