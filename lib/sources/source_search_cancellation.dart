import 'dart:async';

/// Lifetime of one catalog search. Connectors keep their existing interface;
/// native transports opt in through the scoped zone, never a global client.
class SourceSearchCancellation {
  static final Object _zoneKey = Object();
  static SourceSearchCancellation? get current =>
      Zone.current[_zoneKey] as SourceSearchCancellation?;

  final Set<void Function()> _listeners = {};
  bool _cancelled = false;
  bool _timedOut = false;

  bool get isCancelled => _cancelled;
  bool get isTimedOut => _timedOut;

  void cancel({bool timedOut = false}) {
    if (_cancelled) return;
    _cancelled = true;
    _timedOut = timedOut;
    final listeners = _listeners.toList();
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }

  /// Returns a remover so completed requests never retain clients or widgets.
  void Function() addListener(void Function() listener) {
    if (_cancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void throwIfCancelled() {
    if (_cancelled) throw const SourceSearchCancelled();
  }

  Future<T> run<T>(Future<T> Function() action) {
    throwIfCancelled();
    return runZoned(
      () => wait(Future<T>.sync(action)),
      zoneValues: {_zoneKey: this},
    );
  }

  /// Stop waiting even for an injected/non-cooperative connector. Its late
  /// completion is still handled, but can no longer update a cancelled search.
  Future<T> wait<T>(Future<T> future) {
    final result = Completer<T>();
    final remove = addListener(() {
      if (!result.isCompleted) {
        result.completeError(const SourceSearchCancelled());
      }
    });
    future.then(
      (value) {
        remove();
        if (!result.isCompleted) result.complete(value);
      },
      onError: (Object error, StackTrace stack) {
        remove();
        if (!result.isCompleted) result.completeError(error, stack);
      },
    );
    return result.future;
  }
}

class SourceSearchCancelled implements Exception {
  const SourceSearchCancelled();

  @override
  String toString() => 'Source search was cancelled.';
}
