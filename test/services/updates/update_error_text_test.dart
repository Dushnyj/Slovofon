import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/services/updates/update_client.dart';
import 'package:slovofon/services/updates/update_error_text.dart';
import 'package:slovofon/services/updates/update_installer.dart';

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

  for (final locale in ['ru', 'en']) {
    for (final error in <Object>[
      const UpdateInstallException(
        r'Cannot flush C:\Fixture\state.json: connection refused',
      ),
      const ProcessException(
        r'C:\Fixture\Slovofon-setup.exe',
        ['/DIR=C:\\Fixture\\private-folder'],
        'network is unreachable',
        740,
      ),
      PlatformException(
        code: 'install_failed',
        message: 'connection refused',
        details: r'C:\Fixture\private-folder',
      ),
    ]) {
      test(
        '$locale ${error.runtimeType} is installer failure, not networking',
        () {
          final localized = AppStrings.forLocale(Locale(locale));
          final text = updateDownloadErrorText(
            strings: localized,
            error: error,
          );
          expect(text.title, localized.updateInstallFailed);
          expect(text.message, localized.updateInstallFailedMessage);
          expect(text.title, isNot(localized.noInternetTitle));
          final displayed = '${text.title}\n${text.message}';
          for (final sensitive in [
            'C:\\Fixture',
            'private-folder',
            '/DIR=',
            '740',
            'install_failed',
            'connection refused',
            'network is unreachable',
          ]) {
            expect(displayed, isNot(contains(sensitive)));
          }
        },
      );
    }
  }
}
