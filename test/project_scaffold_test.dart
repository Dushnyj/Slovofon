import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stage 0 asset scaffold is present and declared', () {
    final requiredDirectories = [
      'assets/app',
      'assets/icons/nav',
      'assets/icons/book',
      'assets/icons/player',
      'assets/icons/downloads',
      'assets/icons/source',
      'assets/icons/system',
      'assets/l10n',
    ];

    for (final directory in requiredDirectories) {
      expect(
        Directory(directory).existsSync(),
        isTrue,
        reason: '$directory must exist for the Stage 0 scaffold.',
      );
    }

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets:'));
    expect(pubspec, contains('assets/app/'));
    expect(pubspec, contains('assets/icons/'));
    expect(pubspec, contains('assets/l10n/'));
  });
}
