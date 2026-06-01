import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
    if (!await file.exists()) {
      return {};
    }
    final decoded = jsonDecode(await file.readAsString());
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
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(keys.toList()..sort()), flush: true);
  }
}

class HomeListeningVisibilityStore extends ChangeNotifier {
  HomeListeningVisibilityStore(this._persistence);

  final HomeListeningVisibilityPersistence _persistence;
  Set<String> _hiddenKeys = {};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  bool isHidden(String key) {
    return _hiddenKeys.contains(key);
  }

  Future<void> load() async {
    _hiddenKeys = await _persistence.loadHiddenKeys();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> hide(String key) async {
    if (!_hiddenKeys.add(key)) {
      return;
    }
    notifyListeners();
    await _persistence.saveHiddenKeys(_hiddenKeys);
  }

  Future<void> show(String key) async {
    if (!_hiddenKeys.remove(key)) {
      return;
    }
    notifyListeners();
    await _persistence.saveHiddenKeys(_hiddenKeys);
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
