import 'package:slovofon/services/search/search_history_store.dart';
import 'package:slovofon/sources/sources.dart';

class MemorySearchHistoryStore extends SearchHistoryStore {
  final _entries = <SearchHistoryEntry>[];

  @override
  Future<List<SearchHistoryEntry>> load() async {
    return List.unmodifiable(_entries);
  }

  @override
  Future<List<SearchHistoryEntry>> record(String query, SearchKind kind) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return load();
    }

    final key = _key(normalizedQuery, kind);
    var usageCount = 1;
    for (final entry in _entries) {
      if (_key(entry.query, entry.kind) == key) {
        usageCount = entry.usageCount + 1;
        break;
      }
    }

    _entries.removeWhere((entry) => _key(entry.query, entry.kind) == key);
    _entries.insert(
      0,
      SearchHistoryEntry(
        query: normalizedQuery,
        kind: kind,
        lastUsedAt: DateTime.now(),
        usageCount: usageCount,
      ),
    );
    if (_entries.length > 20) {
      _entries.removeRange(20, _entries.length);
    }
    return load();
  }

  String _key(String query, SearchKind kind) {
    return '${kind.name}:${query.trim().toLowerCase()}';
  }
}
