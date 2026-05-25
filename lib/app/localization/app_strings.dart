import 'package:flutter/widgets.dart';

extension AppStringsContext on BuildContext {
  AppStrings get strings => AppStrings.of(this);
}

class AppStrings {
  AppStrings._(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = [
    Locale('ru'),
    Locale('en'),
    Locale('kk'),
    Locale('be'),
    Locale('uk'),
  ];

  static AppStrings of(BuildContext context) {
    return AppStrings._(Localizations.localeOf(context));
  }

  bool get _isRu => locale.languageCode == 'ru';

  String get appTitle => _isRu ? 'Словофон' : 'Slovofon';
  String get home => _isRu ? 'Главная' : 'Home';
  String get search => _isRu ? 'Поиск' : 'Search';
  String get library => _isRu ? 'Библиотека' : 'Library';
  String get downloads => _isRu ? 'Загрузки' : 'Downloads';
  String get settings => _isRu ? 'Настройки' : 'Settings';
  String get themePreview => _isRu ? 'Предпросмотр темы' : 'Theme preview';
  String get continueListening =>
      _isRu ? 'Продолжить прослушивание' : 'Continue listening';
  String get recommended =>
      _isRu ? 'Рекомендации на mock data' : 'Mock recommendations';
  String get searchHint =>
      _isRu ? 'Название, автор или исполнитель' : 'Title, author, or narrator';
  String get emptyLibrary =>
      _isRu ? 'Библиотека пока пуста' : 'Your library is empty';
  String get emptyDownloads =>
      _isRu ? 'Загрузок пока нет' : 'No downloads yet';
  String get appearance => _isRu ? 'Внешний вид' : 'Appearance';
  String get sources => _isRu ? 'Источники' : 'Sources';
  String get player => _isRu ? 'Плеер' : 'Player';
  String get proxy => _isRu ? 'Прокси' : 'Proxy';
  String get openThemePreview =>
      _isRu ? 'Открыть предпросмотр темы' : 'Open theme preview';
  String get previewButtons => _isRu ? 'Кнопки' : 'Buttons';
  String get previewChips => _isRu ? 'Чипы' : 'Chips';
  String get previewCards => _isRu ? 'Карточки' : 'Cards';
  String get previewInputs => _isRu ? 'Поля ввода' : 'Inputs';
  String get previewStates => _isRu ? 'Состояния' : 'States';
  String get snackbarPreview => _isRu ? 'Snackbar' : 'Snackbar';
  String get success => _isRu ? 'Успешно' : 'Success';
  String get warning => _isRu ? 'Внимание' : 'Warning';
  String get info => _isRu ? 'Информация' : 'Info';
  String get free => _isRu ? 'Бесплатно' : 'Free';
  String get play => _isRu ? 'Слушать' : 'Play';
  String get pause => _isRu ? 'Пауза' : 'Pause';
  String get download => _isRu ? 'Скачать' : 'Download';
  String get details => _isRu ? 'Подробнее' : 'Details';
  String get mockDataNotice => _isRu
      ? 'Каркас работает на локальных mock data. Источники будут подключены отдельным слоем.'
      : 'This scaffold uses local mock data. Sources will be wired through a separate layer.';
}
