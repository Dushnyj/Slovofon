/// Bounded, short-lived request cache with single-flight loading per key.
/// Successful responses may contain temporary media URLs, so they must expire.
class SourceRequestCache<K, V> {
  SourceRequestCache({
    DateTime Function()? clock,
    this.ttl = const Duration(minutes: 5),
    this.maxEntries = 100,
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Duration ttl;
  final int maxEntries;
  final _entries = <K, _RequestEntry<V>>{};

  Future<V> getOrLoad(K key, Future<V> Function() load) {
    final now = _clock();
    _entries.removeWhere((_, entry) => !now.isBefore(entry.expiresAt));
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      return cached.future;
    }
    while (_entries.isNotEmpty && _entries.length >= maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    late final Future<V> future;
    future = Future<V>.sync(load).catchError((Object error, StackTrace stack) {
      if (identical(_entries[key]?.future, future)) {
        _entries.remove(key);
      }
      Error.throwWithStackTrace(error, stack);
    });
    if (maxEntries > 0) {
      _entries[key] = _RequestEntry(future, now.add(ttl));
    }
    return future;
  }

  void remove(K key) => _entries.remove(key);

  void removeWhere(bool Function(K key) predicate) {
    _entries.removeWhere((key, _) => predicate(key));
  }
}

class _RequestEntry<V> {
  const _RequestEntry(this.future, this.expiresAt);

  final Future<V> future;
  final DateTime expiresAt;
}
