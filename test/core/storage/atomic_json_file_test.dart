import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/core/storage/atomic_json_file.dart';

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('slovofon-json-test-');
    file = File('${directory.path}/state.json');
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
    'missing and truncated JSON read safely without deleting the original',
    () async {
      expect(await AtomicJsonFile(file).read(), isNull);
      await file.writeAsString('["unfinished"');
      expect(await AtomicJsonFile(file).read(), isNull);
      expect(await file.readAsString(), '["unfinished"');
    },
  );

  test(
    'recovers the last-good backup and preserves a corrupt original on write',
    () async {
      final store = AtomicJsonFile(file);
      await store.write({'revision': 1});
      await store.write({'revision': 2});
      await file.writeAsString('{');
      expect(await store.read(), {'revision': 1});
      await store.write({'revision': 3});
      expect(await store.read(), {'revision': 3});
      expect(jsonDecode(await File('${file.path}.bak').readAsString()), {
        'revision': 1,
      });
      final preserved = await directory
          .list()
          .where((entry) => entry.path.contains('.corrupt.'))
          .toList();
      expect(preserved, hasLength(1));
      expect(await File(preserved.single.path).readAsString(), '{');
    },
  );

  test('separate instances serialize concurrent readers and writers', () async {
    await AtomicJsonFile(file).write({'revision': 0});
    final operations = <Future<void>>[];
    for (var index = 1; index <= 30; index++) {
      operations.add(
        AtomicJsonFile(file).write({'revision': index, 'payload': 'x' * 4096}),
      );
      operations.add(
        AtomicJsonFile(file).read().then((value) {
          expect((value! as Map)['revision'], index);
        }),
      );
    }
    await Future.wait(operations);
    expect((await AtomicJsonFile(file).read() as Map)['revision'], 30);
    expect(
      await directory
          .list()
          .where((entry) => entry.path.contains('.writing.'))
          .toList(),
      isEmpty,
    );
  });

  test(
    'failed encoding does not overwrite the last successful state',
    () async {
      final store = AtomicJsonFile(file);
      await store.write({'revision': 1});
      expect(
        () => store.write(Object()),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
      expect(await store.read(), {'revision': 1});
      await store.write({'revision': 2});
      expect(await store.read(), {'revision': 2});
    },
  );
}
