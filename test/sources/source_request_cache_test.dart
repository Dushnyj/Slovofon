import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/sources/source_request_cache.dart';

void main() {
  test(
    'shares in-flight requests, expires and evicts least recently used',
    () async {
      var now = DateTime.utc(2026);
      final cache = SourceRequestCache<String, int>(
        clock: () => now,
        maxEntries: 2,
      );
      var calls = 0;
      Future<int> load() async => ++calls;
      final a = cache.getOrLoad('a', load);
      expect(identical(a, cache.getOrLoad('a', load)), isTrue);
      expect(await a, 1);
      await cache.getOrLoad('b', load);
      await cache.getOrLoad('a', load);
      await cache.getOrLoad('c', load);
      expect(await cache.getOrLoad('b', load), 4);
      now = now.add(const Duration(minutes: 5));
      expect(await cache.getOrLoad('b', load), 5);
    },
  );

  test(
    'failed invalidated request cannot remove a newer replacement',
    () async {
      final cache = SourceRequestCache<String, int>();
      final old = Completer<int>();
      final pending = cache.getOrLoad('book', () => old.future);
      final oldFailure = expectLater(pending, throwsStateError);
      cache.remove('book');
      expect(await cache.getOrLoad('book', () async => 2), 2);
      old.completeError(StateError('fixture'));
      await oldFailure;
      expect(await cache.getOrLoad('book', () async => 3), 2);
    },
  );

  test('failure is retried instead of being cached', () async {
    final cache = SourceRequestCache<String, int>();
    await expectLater(
      cache.getOrLoad('a', () async => throw StateError('fixture')),
      throwsStateError,
    );
    expect(await cache.getOrLoad('a', () async => 1), 1);
  });
}
