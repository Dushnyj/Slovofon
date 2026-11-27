import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../sources/sources.dart';
import '../../core/storage/atomic_json_file.dart';

final searchHistoryStoreProvider = Provider<SearchHistoryStore>((ref) {
  return SearchHistoryStore();
});

class SearchHistoryEntry {
  const SearchHistoryEntry({
    required this.query,
    required this.kind,
    this.kinds = const {},
    this.sort = SearchSort.relevance,
    required this.lastUsedAt,
    required this.usageCount,
  });

  final String query;
  final SearchKind kind;
  final Set<SearchKind> kinds;
  final SearchSort sort;
  final DateTime lastUsedAt;
  final int usageCount;

  Set<SearchKind> get effectiveKinds =>
      SearchRequest(query: query, kind: kind, kinds: kinds).effectiveKinds;

  Map<String, Object?> toJson() {
    return {
      'query': query,
      'kind': kind.name,
      if (kinds.isNotEmpty)
        'kinds': kinds.map((kind) => kind.name).toList()..sort(),
      'sort': sort.name,
      'lastUsedAt': lastUsedAt.toIso8601String(),
      'usageCount': usageCount,
    };
  }

  static SearchHistoryEntry? fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }

    final query = value['query'];
    final kindName = value['kind'];
    final lastUsedAt = DateTime.tryParse(value['lastUsedAt']?.toString() ?? '');
    final usageCount = value['usageCount'];
    final rawKinds = value['kinds'];

    if (query is! String || query.trim().isEmpty || lastUsedAt == null) {
      return null;
    }

    return SearchHistoryEntry(
      query: query.trim(),
      kind: SearchKind.values.firstWhere(
        (kind) => kind.name == kindName,
        orElse: () => SearchKind.title,
      ),
      kinds: rawKinds is List
          ? Set.unmodifiable(
              SearchKind.values.where((kind) => rawKinds.contains(kind.name)),
            )
          : const {},
      sort: SearchSort.values.firstWhere(
        (sort) => sort.name == value['sort'],
        orElse: () => SearchSort.relevance,
      ),
      lastUsedAt: lastUsedAt,
      usageCount: usageCount is int ? usageCount : 1,
    );
  }
}

class SearchHistoryStore {
  SearchHistoryStore({Future<File> Function()? fileFactory})
    : _fileFactory = fileFactory ?? _defaultFile;

  final Future<File> Function() _fileFactory;

  Future<List<SearchHistoryEntry>> load() async {
    return _decode(await AtomicJsonFile(await _fileFactory()).read());
  }

  static List<SearchHistoryEntry> _decode(Object? decoded) {
    if (decoded is! List) {
      return const [];
    }

    final entries = [
      for (final item in decoded) ?SearchHistoryEntry.fromJson(item),
    ];
    entries.sort((left, right) => right.lastUsedAt.compareTo(left.lastUsedAt));
    return List.unmodifiable(entries);
  }

  Future<List<SearchHistoryEntry>> record(
    String query,
    SearchKind kind, {
    Set<SearchKind> kinds = const {},
    SearchSort sort = SearchSort.relevance,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return load();
    }

    final key = _key(normalizedQuery, kind, kinds, sort);
    final frozenKinds = Set<SearchKind>.unmodifiable(kinds);
    return _update(
      (existing) => [
        SearchHistoryEntry(
          query: normalizedQuery,
          kind: kind,
          kinds: frozenKinds,
          sort: sort,
          lastUsedAt: DateTime.now(),
          usageCount:
              (existing
                      .where((entry) => _entryKey(entry) == key)
                      .firstOrNull
                      ?.usageCount ??
                  0) +
              1,
        ),
        for (final entry in existing)
          if (_entryKey(entry) != key) entry,
      ].take(20).toList(growable: false),
    );
  }

  Future<List<SearchHistoryEntry>> delete(
    String query,
    SearchKind kind, {
    Set<SearchKind> kinds = const {},
    SearchSort sort = SearchSort.relevance,
  }) async {
    final key = _key(query, kind, kinds, sort);
    return _update(
      (existing) => [
        for (final entry in existing)
          if (_entryKey(entry) != key) entry,
      ],
    );
  }

  Future<List<SearchHistoryEntry>> _update(
    List<SearchHistoryEntry> Function(List<SearchHistoryEntry>) change,
  ) async {
    final storage = AtomicJsonFile(await _fileFactory());
    return storage.update((decoded) {
      final entries = List<SearchHistoryEntry>.unmodifiable(
        change(_decode(decoded)),
      );
      return (
        value: [for (final entry in entries) entry.toJson()],
        result: entries,
      );
    });
  }

  static String _entryKey(SearchHistoryEntry entry) =>
      _key(entry.query, entry.kind, entry.kinds, entry.sort);

  static String _key(
    String query,
    SearchKind kind,
    Set<SearchKind> kinds,
    SearchSort sort,
  ) {
    final names = SearchRequest(
      query: query,
      kind: kind,
      kinds: kinds,
    ).effectiveKinds.map((kind) => kind.name).toList()..sort();
    return '${names.join(',')}:${sort.name}:${query.trim().toLowerCase()}';
  }

  static Future<File> _defaultFile() async {
    late final Directory directory;
    try {
      directory = await getApplicationSupportDirectory();
    } catch (_) {
      directory = Directory(p.join(Directory.systemTemp.path, 'slovofon'));
    }
    return File(p.join(directory.path, 'search_history.json'));
  }
}
