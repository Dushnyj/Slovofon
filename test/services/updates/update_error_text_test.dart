import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/services/updates/update_client.dart';
import 'package:slovofon/services/updates/update_error_text.dart';

void main() {
  final strings = AppStrings.forLocale(const Locale('ru'));

  test('maps update socket failures to a localized no-internet message', () {
    final text = updateDownloadErrorText(
      strings: strings,
      error: const SocketException('Failed host lookup'),
    );

    expect(text.title, 'Нет соединения с интернетом');
    expect(text.message, contains('Wi-Fi'));
    expect(text.message, contains('мобильную сеть'));
  });

  test('keeps technical update failures out of user-facing text', () {
    final text = updateCheckErrorText(
      strings: strings,
      error: const UpdateClientException(
        'Manifest request failed with HTTP 500',
      ),
    );

    expect(text.title, 'Не удалось проверить обновления');
    expect(text.message, isNot(contains('HTTP 500')));
    expect(text.message, contains('Повторить'));
  });
}
