import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/search/search_history_store.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  test('SearchHistoryStore records and reloads search queries', () async {
    final directory = Directory(
      '${Directory.systemTemp.path}/slovofon-search-history-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    addTearDown(() {
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    });

    final file = File('${directory.path}/history.json');
    final store = SearchHistoryStore(fileFactory: () async => file);

    await store.record('Дыхание зоны', SearchKind.title);
    await store.record('Дыхание зоны', SearchKind.title);
    await store.record('Глуховский', SearchKind.author);

    final history = await store.load();

    expect(history, hasLength(2));
    expect(history.first.query, 'Глуховский');
    expect(history.first.kind, SearchKind.author);
    expect(history.last.query, 'Дыхание зоны');
    expect(history.last.usageCount, 2);
  });
}
