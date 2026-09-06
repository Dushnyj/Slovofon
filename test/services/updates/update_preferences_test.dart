import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:slovofon/services/updates/update_preferences.dart';

void main() {
  group('MemoryUpdatePreferences', () {
    test('remembers only the latest validated key', () async {
      final preferences = MemoryUpdatePreferences();
      expect(await preferences.readSkippedVersion(), isNull);
      await preferences.saveSkippedVersion('0.0.8+');
      expect(await preferences.readSkippedVersion(), '0.0.8+');
      await preferences.saveSkippedVersion('0.0.9+7');
      expect(await preferences.readSkippedVersion(), '0.0.9+7');
      expect(await MemoryUpdatePreferences().readSkippedVersion(), isNull);
      await expectLater(
        preferences.saveSkippedVersion('invalid'),
        throwsArgumentError,
      );
      expect(await preferences.readSkippedVersion(), '0.0.9+7');
    });
  });

  group('FileUpdatePreferences', () {
    late Directory directory;
    late File file;
    FileUpdatePreferences store() =>
        FileUpdatePreferences(directoryProvider: () async => directory);

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'slovofon-update-prefs-',
      );
      file = File(p.join(directory.path, FileUpdatePreferences.fileName));
    });

    tearDown(() async {
      final resolved = await directory.resolveSymbolicLinks();
      final temp = await Directory.systemTemp.resolveSymbolicLinks();
      if (!p.equals(p.dirname(resolved), temp) ||
          !p.basename(resolved).startsWith('slovofon-update-prefs-')) {
        throw StateError(
          'Refusing to remove a directory outside the exact temp fixture',
        );
      }
      await directory.delete(recursive: true);
    });

    test(
      'missing preference is read-only, including a missing parent',
      () async {
        expect(await store().readSkippedVersion(), isNull);
        expect(await directory.list().toList(), isEmpty);
        final missing = Directory(p.join(directory.path, 'missing'));
        expect(
          await FileUpdatePreferences(
            directoryProvider: () async => missing,
          ).readSkippedVersion(),
          isNull,
        );
        expect(await missing.exists(), isFalse);
      },
    );

    test(
      'persists the latest skip across fresh instances without side files',
      () async {
        final sentinel = await File(
          p.join(directory.path, 'books-sentinel'),
        ).writeAsString('unrelated data');
        await store().saveSkippedVersion('0.0.8+');
        expect(await store().readSkippedVersion(), '0.0.8+');
        await store().saveSkippedVersion('0.0.9+7');
        expect(await store().readSkippedVersion(), '0.0.9+7');
        expect(jsonDecode(await file.readAsString()), {
          'schema': 1,
          'skippedVersion': '0.0.9+7',
        });
        expect(await sentinel.readAsString(), 'unrelated data');
        expect(await directory.list().toList(), hasLength(2));
      },
    );

    test(
      'creates only its own file in a newly created support directory',
      () async {
        final missing = Directory(p.join(directory.path, 'support'));
        final preferences = FileUpdatePreferences(
          directoryProvider: () async => missing,
        );
        await preferences.saveSkippedVersion('0.0.8+7');
        expect(await preferences.readSkippedVersion(), '0.0.8+7');
        expect(
          (await missing.list().toList()).map(
            (entry) => p.basename(entry.path),
          ),
          [FileUpdatePreferences.fileName],
        );
      },
    );

    test('corrupt, malformed and oversized preferences stay untouched', () async {
      final payloads = <List<int>>[
        utf8.encode('{'),
        [0xff, 0xfe, 0xfd],
        utf8.encode('null'),
        utf8.encode('[]'),
        utf8.encode('{"schema":2,"skippedVersion":"0.0.8+"}'),
        utf8.encode('{"schema":1,"skippedVersion":42}'),
        utf8.encode('{"schema":1,"skippedVersion":"not a version"}'),
        utf8.encode(' ' * (FileUpdatePreferences.maxFileBytes + 1)),
        utf8.encode(
          '{"schema":1,"skippedVersion":"0.0.8+","padding":"${'x' * FileUpdatePreferences.maxFileBytes}"}',
        ),
      ];
      for (final payload in payloads) {
        await file.writeAsBytes(payload);
        expect(await store().readSkippedVersion(), isNull);
        expect(await file.readAsBytes(), payload);
        expect(await directory.list().toList(), hasLength(1));
      }
    });

    test(
      'serializes separate instances and reads even with delayed path lookup',
      () async {
        final delayedPath = Completer<Directory>();
        final slow = FileUpdatePreferences(
          directoryProvider: () => delayedPath.future,
        );
        final first = slow.saveSkippedVersion('0.0.8+1');
        final second = store().saveSkippedVersion('0.0.8+2');
        final read = store().readSkippedVersion();
        delayedPath.complete(directory);
        await Future.wait([first, second]);
        expect(await read, '0.0.8+2');
        final operations = <Future<void>>[];
        for (var build = 3; build <= 20; build++) {
          operations.add(store().saveSkippedVersion('0.0.8+$build'));
          operations.add(
            store().readSkippedVersion().then((value) {
              expect(value, '0.0.8+$build');
            }),
          );
        }
        await Future.wait(operations);
        expect(await store().readSkippedVersion(), '0.0.8+20');
        expect(await directory.list().toList(), hasLength(1));
      },
    );

    test(
      'invalid keys never touch storage or overwrite the previous skip',
      () async {
        await store().saveSkippedVersion('0.0.8+7');
        final original = await file.readAsBytes();
        for (final invalid in [
          '',
          '0.0.8',
          '0.0.8+-1',
          '0.0.8+01',
          '00.0.8+',
          '0.0.8+7\n',
          '0.0.8+ ',
          '0.0.8+beta',
          'v0.0.8+',
          '0.0.8-rc.1+',
          '1000000000.0.8+',
          '0.0.8+9223372036854775808',
          'x' * 100000,
        ]) {
          await expectLater(
            store().saveSkippedVersion(invalid),
            throwsArgumentError,
          );
          expect(await file.readAsBytes(), original);
        }
        var pathLookups = 0;
        final invalidStore = FileUpdatePreferences(
          directoryProvider: () async {
            pathLookups++;
            return directory;
          },
        );
        await expectLater(
          invalidStore.saveSkippedVersion('../escape'),
          throwsArgumentError,
        );
        expect(pathLookups, 0);
      },
    );

    test(
      'write errors propagate and do not poison subsequent operations',
      () async {
        await store().saveSkippedVersion('0.0.8+1');
        final original = await file.readAsBytes();
        const denied = FileSystemException('synthetic permission denied');
        final failing = FileUpdatePreferences(
          directoryProvider: () async => throw denied,
        );
        await expectLater(
          failing.saveSkippedVersion('0.0.8+2'),
          throwsA(same(denied)),
        );
        expect(await file.readAsBytes(), original);
        await store().saveSkippedVersion('0.0.8+3');
        expect(await store().readSkippedVersion(), '0.0.8+3');
        expect(await directory.list().toList(), hasLength(1));
      },
    );

    test(
      'a non-file destination and a non-directory provider fail safely',
      () async {
        final conflict = await Directory(file.path).create();
        final sentinel = await File(
          p.join(conflict.path, 'must-stay'),
        ).writeAsString('safe');
        expect(await store().readSkippedVersion(), isNull);
        await expectLater(
          store().saveSkippedVersion('0.0.8+'),
          throwsA(isA<FileSystemException>()),
        );
        expect(await sentinel.readAsString(), 'safe');
        final invalidParent = await File(
          p.join(directory.path, 'not-a-directory'),
        ).writeAsString('safe parent');
        final blocked = FileUpdatePreferences(
          directoryProvider: () async => Directory(invalidParent.path),
        );
        await expectLater(
          blocked.saveSkippedVersion('0.0.8+'),
          throwsA(isA<FileSystemException>()),
        );
        expect(await invalidParent.readAsString(), 'safe parent');
      },
    );
  });
}
