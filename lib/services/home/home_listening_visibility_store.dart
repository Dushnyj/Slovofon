import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/storage/atomic_json_file.dart';
import '../audio/audio_state.dart';

abstract interface class HomeListeningVisibilityPersistence {
  Future<Set<String>> loadHiddenKeys();

  Future<void> saveHiddenKeys(Set<String> keys);
}

class MemoryHomeListeningVisibilityPersistence
    implements HomeListeningVisibilityPersistence {
  Set<String> _hiddenKeys = {};

  @override
  Future<Set<String>> loadHiddenKeys() async {
    return {..._hiddenKeys};
  }

  @override
  Future<void> saveHiddenKeys(Set<String> keys) async {
    _hiddenKeys = {...keys};
  }
}

class FileHomeListeningVisibilityPersistence
    implements HomeListeningVisibilityPersistence {
  FileHomeListeningVisibilityPersistence(this.file);

  final File file;

  static Future<FileHomeListeningVisibilityPersistence> create() async {
    final appSupportDirectory = await getApplicationSupportDirectory();
    return FileHomeListeningVisibilityPersistence(
      File(p.join(appSupportDirectory.path, 'home_hidden_books.json')),
    );
  }

  @override
  Future<Set<String>> loadHiddenKeys() async {
    final decoded = await AtomicJsonFile(file).read();
    if (decoded is! List) {
      return {};
    }
    return {
      for (final value in decoded)
        if (value is String && value.trim().isNotEmpty) value,
    };
  }

  @override
  Future<void> saveHiddenKeys(Set<String> keys) async {
    await AtomicJsonFile(file).write(keys.toList()..sort());
  }
}

class HomeListeningVisibilityStore extends ChangeNotifier {
  HomeListeningVisibilityStore(this._persistence);

  final HomeListeningVisibilityPersistence _persistence;
  Set<String> _hiddenKeys = {};
  bool _isLoaded = false;
  Future<void>? _loadFuture;
  bool _disposed = false;

  bool get isLoaded => _isLoaded;

  bool isHidden(String key) {
    return _hiddenKeys.contains(key);
  }

  Future<void> load() => _loadFuture ??= _load();

  Future<void> _load() async {
    _hiddenKeys = await _persistence.loadHiddenKeys();
    _isLoaded = true;
    if (!_disposed) notifyListeners();
  }

  Future<void> hide(String key) async {
    await load();
    if (!_hiddenKeys.add(key)) {
      return;
    }
    if (!_disposed) notifyListeners();
    await _persistence.saveHiddenKeys({..._hiddenKeys});
  }

  Future<void> show(String key) async {
    await load();
    if (!_hiddenKeys.remove(key)) {
      return;
    }
    if (!_disposed) notifyListeners();
    await _persistence.saveHiddenKeys({..._hiddenKeys});
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

String homeListeningBookKeyFor(AudioPlaybackBook book) {
  return '${book.sourceId}:${book.versionId}';
}

final homeListeningVisibilityStoreProvider =
    ChangeNotifierProvider<HomeListeningVisibilityStore>((ref) {
      final store = HomeListeningVisibilityStore(
        MemoryHomeListeningVisibilityPersistence(),
      );
      unawaited(store.load());
      return store;
    });
