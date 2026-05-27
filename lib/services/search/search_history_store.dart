import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../sources/sources.dart';

final searchHistoryStoreProvider = Provider<SearchHistoryStore>((ref) {
  return SearchHistoryStore();
});

class SearchHistoryEntry {
  const SearchHistoryEntry({
    required this.query,
    required this.kind,
    required this.lastUsedAt,
    required this.usageCount,
  });

  final String query;
  final SearchKind kind;
  final DateTime lastUsedAt;
  final int usageCount;

  Map<String, Object?> toJson() {
    return {
      'query': query,
      'kind': kind.name,
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

    if (query is! String || query.trim().isEmpty || lastUsedAt == null) {
      return null;
    }

    return SearchHistoryEntry(
      query: query.trim(),
      kind: SearchKind.values.firstWhere(
        (kind) => kind.name == kindName,
        orElse: () => SearchKind.title,
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
    final file = await _fileFactory();
    if (!await file.exists()) {
      return const [];
    }

    late final Object? decoded;
    try {
      final raw = await file.readAsString();
      decoded = jsonDecode(raw);
    } catch (_) {
      return const [];
    }
    if (decoded is! List) {
      return const [];
    }

    final entries = [
      for (final item in decoded) ?SearchHistoryEntry.fromJson(item),
    ];
    entries.sort((left, right) => right.lastUsedAt.compareTo(left.lastUsedAt));
    return List.unmodifiable(entries);
  }

  Future<List<SearchHistoryEntry>> record(String query, SearchKind kind) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return load();
    }

    final now = DateTime.now();
    final existing = await load();
    final key = _key(normalizedQuery, kind);
    final entries = <SearchHistoryEntry>[
      SearchHistoryEntry(
        query: normalizedQuery,
        kind: kind,
        lastUsedAt: now,
        usageCount:
            (existing
                    .where((entry) => _key(entry.query, entry.kind) == key)
                    .firstOrNull
                    ?.usageCount ??
                0) +
            1,
      ),
      for (final entry in existing)
        if (_key(entry.query, entry.kind) != key) entry,
    ].take(20).toList();

    await _save(entries);
    return List.unmodifiable(entries);
  }

  Future<void> _save(List<SearchHistoryEntry> entries) async {
    final file = await _fileFactory();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode([for (final entry in entries) entry.toJson()]),
      flush: true,
    );
  }

  static String _key(String query, SearchKind kind) {
    return '${kind.name}:${query.trim().toLowerCase()}';
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
