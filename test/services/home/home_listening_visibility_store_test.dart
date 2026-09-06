import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/home/home_listening_visibility_store.dart';

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('slovofon-home-test-');
    file = File('${directory.path}/home_hidden_books.json');
  });
  tearDown(() async => directory.delete(recursive: true));

  test('truncated optional visibility JSON cannot block startup', () async {
    await file.writeAsString('["unfinished"');
    final store = HomeListeningVisibilityStore(
      FileHomeListeningVisibilityPersistence(file),
    );
    await store.load();
    expect(store.isLoaded, isTrue);
    expect(store.isHidden('unfinished'), isFalse);
    expect(await file.readAsString(), '["unfinished"');
    store.dispose();
  });
  test('hide before initial load preserves stored hidden entries', () async {
    final persistence = FileHomeListeningVisibilityPersistence(file);
    await persistence.saveHiddenKeys({'old'});
    final store = HomeListeningVisibilityStore(persistence);
    await store.hide('new');
    expect(store.isHidden('old'), isTrue);
    expect(await persistence.loadHiddenKeys(), {'old', 'new'});
    await store.show('new');
    expect(await persistence.loadHiddenKeys(), {'old'});
    store.dispose();
  });
}
