import 'dart:async';
import 'dart:collection';
import 'dart:isolate';

import 'source_models.dart';
import 'source_search_cancellation.dart';

/// Small, bounded queue of one-shot parsing isolates. Only a top-level parser
/// and its data payload cross the boundary, never a connector or HTTP client.
/// Isolate.exit transfers the mapped result without copying a DOM back to UI.
class SourceParserWorker {
  SourceParserWorker({this.concurrency = 2, this.maxPending = 32})
    : assert(concurrency > 0),
      assert(maxPending > 0);

  static final shared = SourceParserWorker();
  final int concurrency;
  final int maxPending;
  final Queue<_ParserJob> _pending = Queue();
  int _active = 0;

  Future<T> run<T>(
    Object? Function(Object?) parser,
    Object? payload, {
    String debugLabel = 'source-parser',
  }) {
    final cancellation = SourceSearchCancellation.current;
    cancellation?.throwIfCancelled();
    if (_pending.length >= maxPending) {
      return Future.error(StateError('Source parser queue is full.'));
    }
    final job = _ParserJob(parser, payload, debugLabel);
    job.unlink = cancellation?.addListener(() {
      _pending.remove(job);
      job.isolate?.kill(priority: Isolate.immediate);
      if (!job.result.isCompleted) {
        job.result.completeError(const SourceSearchCancelled());
      }
    });
    _pending.add(job);
    _drain();
    return job.result.future.then((value) => value as T);
  }

  void _drain() {
    while (_active < concurrency && _pending.isNotEmpty) {
      final job = _pending.removeFirst();
      if (job.result.isCompleted) continue;
      _active++;
      unawaited(_run(job));
    }
  }

  Future<void> _run(_ParserJob job) async {
    final port = ReceivePort();
    final subscription = port.listen((message) {
      if (job.result.isCompleted) return;
      if (message is _ParserResult) {
        if (message.error != null) {
          job.result.completeError(
            message.error!,
            StackTrace.fromString(message.stack ?? ''),
          );
        } else {
          job.result.complete(message.value);
        }
      } else {
        job.result.completeError(
          RemoteError('Source parsing worker terminated: $message', ''),
        );
      }
    });
    try {
      job.isolate = await Isolate.spawn(
        _parseInIsolate,
        (port.sendPort, job.parser, job.payload),
        onError: port.sendPort,
        onExit: port.sendPort,
        debugName: job.debugLabel,
      );
      if (job.result.isCompleted) {
        job.isolate!.kill(priority: Isolate.immediate);
      }
      await job.result.future;
    } on Object catch (error, stack) {
      if (!job.result.isCompleted) job.result.completeError(error, stack);
    } finally {
      job.unlink?.call();
      job.isolate?.kill(priority: Isolate.immediate);
      await subscription.cancel();
      port.close();
      _active--;
      _drain();
    }
  }
}

class _ParserJob {
  _ParserJob(this.parser, this.payload, this.debugLabel);

  final Object? Function(Object?) parser;
  final Object? payload;
  final String debugLabel;
  final Completer<Object?> result = Completer();
  Isolate? isolate;
  void Function()? unlink;
}

class _ParserResult {
  const _ParserResult({this.value, this.error, this.stack});

  final Object? value;
  final Object? error;
  final String? stack;
}

void _parseInIsolate((SendPort, Object? Function(Object?), Object?) message) {
  final (port, parser, payload) = message;
  _ParserResult result;
  try {
    result = _ParserResult(value: parser(payload));
  } on Object catch (error, stack) {
    result = _ParserResult(
      error: error is SourceException
          ? SourceException(
              sourceId: error.sourceId,
              kind: error.kind,
              message: error.message,
              // Preserve diagnostics as data, never transfer an arbitrary
              // exception cause's object graph from the parsing isolate.
              cause: error.cause?.toString(),
            )
          : RemoteError(error.toString(), stack.toString()),
      stack: stack.toString(),
    );
  }
  Isolate.exit(port, result);
}
