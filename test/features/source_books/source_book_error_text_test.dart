import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/features/source_books/source_book_error_text.dart';
import 'package:slovofon/sources/source_models.dart';

void main() {
  final strings = AppStrings.forLocale(const Locale('ru'));

  test('maps failed host lookup to a localized no-internet message', () {
    final text = sourceBookErrorText(
      strings: strings,
      sourceId: 'baza_knig',
      error: const SocketException('Failed host lookup: baza-knig.top'),
    );

    expect(text.title, 'Нет соединения с интернетом');
    expect(text.message, contains('Wi-Fi'));
    expect(text.message, contains('мобильную сеть'));
  });

  test('maps source network errors to a source-specific message', () {
    final text = sourceBookErrorText(
      strings: strings,
      sourceId: 'baza_knig',
      error: const SourceException(
        sourceId: 'baza_knig',
        kind: SourceErrorKind.network,
        message: 'HTTP 503',
      ),
    );

    expect(text.title, 'Источник «База книг» недоступен');
    expect(text.message, contains('Повторите попытку'));
  });
}
