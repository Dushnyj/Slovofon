import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/sources/source_html_parser.dart';
import 'package:slovofon/sources/source_models.dart';
import 'package:slovofon/sources/source_parser_worker.dart';
import 'package:slovofon/sources/source_search_cancellation.dart';

void main() {
  test('parser executes in a named worker and returns its DTO', () async {
    final worker = SourceParserWorker();
    final result = await worker.run<(String?, Object?)>(_identity, {
      'title': 'Книга',
      'ids': [1, 2],
    }, debugLabel: 'fixture-source-parser');
    expect(result.$1, 'fixture-source-parser');
    expect(result.$1, isNot(Isolate.current.debugName));
    expect(result.$2, {
      'title': 'Книга',
      'ids': [1, 2],
    });
  });

  test(
    'worker preserves source parser errors instead of silently returning empty',
    () async {
      await expectLater(
        SourceParserWorker().run<Object?>(_throwSourceError, null),
        throwsA(
          isA<SourceException>()
              .having((error) => error.sourceId, 'source', 'fixture')
              .having((error) => error.kind, 'kind', SourceErrorKind.parser)
              .having(
                (error) => error.message,
                'message',
                'Invalid fixture HTML',
              )
              .having((error) => error.cause, 'cause', 'fixture cause'),
        ),
      );
    },
  );

  test(
    'active worker cancellation kills its CPU task and releases the queue',
    () async {
      final worker = SourceParserWorker(concurrency: 1);
      final started = ReceivePort();
      addTearDown(started.close);
      final cancellation = SourceSearchCancellation();
      final busy = cancellation.run(
        () => worker.run<Object?>(_busyParser, started.sendPort),
      );
      final cancelled = expectLater(
        busy,
        throwsA(isA<SourceSearchCancelled>()),
      );
      await started.first;
      final next = worker.run<(String?, Object?)>(
        _identity,
        'next',
        debugLabel: 'next-parser',
      );
      cancellation.cancel();
      await cancelled;
      expect((await next).$2, 'next');
    },
  );

  test(
    'queued cancellation never starts work and queue capacity is bounded',
    () async {
      final worker = SourceParserWorker(concurrency: 1, maxPending: 1);
      final started = ReceivePort();
      addTearDown(started.close);
      final activeCancellation = SourceSearchCancellation();
      final active = activeCancellation.run(
        () => worker.run<Object?>(_busyParser, started.sendPort),
      );
      final activeCancelled = expectLater(
        active,
        throwsA(isA<SourceSearchCancelled>()),
      );
      await started.first;
      final queuedCancellation = SourceSearchCancellation();
      final queued = queuedCancellation.run(
        () => worker.run<Object?>(_identity, 'queued'),
      );
      final queuedCancelled = expectLater(
        queued,
        throwsA(isA<SourceSearchCancelled>()),
      );
      await expectLater(
        worker.run<Object?>(_identity, 'overflow'),
        throwsStateError,
      );
      queuedCancellation.cancel();
      await queuedCancelled;
      final next = worker.run<(String?, Object?)>(
        _identity,
        'after cancellation',
      );
      activeCancellation.cancel();
      await activeCancelled;
      expect((await next).$2, 'after cancellation');
    },
  );

  test(
    'HTML worker returns mapped source models, including fixed timestamps',
    () async {
      const html = '''
<article data-bid="42">
<h1 class="caption__article-main">Тестовая книга</h1>
</article>''';
      expect(await SourceHtmlParser.aknigaBookId(html), '42');
      final now = DateTime.utc(2026, 9, 8);
      final details = await SourceHtmlParser.details(
        'akniga',
        html,
        const SourceBookRef(sourceId: 'akniga', sourceBookId: 'fixture'),
        now,
      );
      expect(details.version.title, 'Тестовая книга');
      expect(details.version.createdAt, now);
      expect(details.version.updatedAt, now);
      expect(details.ref.sourceId, 'akniga');
    },
  );
}

Object? _identity(Object? value) => (Isolate.current.debugName, value);

Object? _throwSourceError(Object? _) => throw const SourceException(
  sourceId: 'fixture',
  kind: SourceErrorKind.parser,
  message: 'Invalid fixture HTML',
  cause: 'fixture cause',
);

Object? _busyParser(Object? value) {
  (value! as SendPort).send('started');
  // Deliberately CPU-bound and never returns: only killing this test isolate
  // can release the worker slot. No network, files, or user data are involved.
  while (true) {}
}
