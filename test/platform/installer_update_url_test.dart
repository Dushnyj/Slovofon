import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Windows installer exposes only the fixed GitHub release update URL',
    () {
      final source = File(
        'installer/windows/inno/Slovofon.iss',
      ).readAsLinesSync();
      var inSetup = false;
      final updateUrls = <String>[];
      for (final rawLine in source) {
        final line = rawLine.trim();
        if (line.isEmpty || line.startsWith(';') || line.startsWith('#')) {
          continue;
        }
        if (line.startsWith('[') && line.endsWith(']')) {
          inSetup = line.toLowerCase() == '[setup]';
          continue;
        }
        if (!inSetup) continue;
        final delimiter = line.indexOf('=');
        if (delimiter < 0) continue;
        if (line.substring(0, delimiter).trim().toLowerCase() ==
            'appupdatesurl') {
          updateUrls.add(line.substring(delimiter + 1).trim());
        }
      }

      expect(updateUrls, hasLength(1));
      final uri = Uri.parse(updateUrls.single);
      expect(uri.scheme, 'https');
      expect(uri.host, 'github.com');
      expect(uri.path, '/Dushnyj/Slovofon/releases');
      expect(uri.userInfo, isEmpty);
      expect(uri.query, isEmpty);
      expect(uri.fragment, isEmpty);
    },
  );
}
