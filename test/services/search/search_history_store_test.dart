import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/search/search_history_store.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  test(
    'concurrent stores preserve exact fields and sort without lost writes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'slovofon-history-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/history.json');
      // An old entry didn't serialize fields or sort.
      await file.writeAsString(
        '[{"query":"Кузнецов","kind":"narrator","lastUsedAt":"2026-01-01T00:00:00Z","usageCount":1}]',
      );
      final left = SearchHistoryStore(fileFactory: () async => file);
      final right = SearchHistoryStore(fileFactory: () async => file);
      const kinds = {SearchKind.narrator, SearchKind.series};
      await Future.wait([
        left.record(
          'Кузнецов',
          SearchKind.all,
          kinds: kinds,
          sort: SearchSort.year,
        ),
        right.record(
          ' КУЗНЕЦОВ ',
          SearchKind.all,
          kinds: kinds,
          sort: SearchSort.year,
        ),
        left.record('Кузнецов', SearchKind.all, kinds: kinds),
        right.record('Кузнецов', SearchKind.narrator),
      ]);
      final entries = await right.load();
      expect(entries, hasLength(3));
      expect(
        entries
            .singleWhere((entry) => entry.sort == SearchSort.year)
            .usageCount,
        2,
      );
      expect(
        entries
            .singleWhere((entry) => entry.kind == SearchKind.narrator)
            .effectiveKinds,
        {SearchKind.narrator},
      );
      await left.delete(
        'Кузнецов',
        SearchKind.all,
        kinds: kinds,
        sort: SearchSort.year,
      );
      expect(await right.load(), hasLength(2));
    },
  );

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

  test('SearchHistoryStore deletes one query without clearing history', () async {
    final directory = Directory(
      '${Directory.systemTemp.path}/slovofon-search-history-delete-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    addTearDown(() {
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    });

    final file = File('${directory.path}/history.json');
    final store = SearchHistoryStore(fileFactory: () async => file);

    await store.record('Дыхание зоны', SearchKind.title);
    await store.record('Грошев', SearchKind.author);

    final remaining = await store.delete('Дыхание зоны', SearchKind.title);

    expect(remaining, hasLength(1));
    expect(remaining.single.query, 'Грошев');
    expect((await store.load()).single.query, 'Грошев');
  });
}
