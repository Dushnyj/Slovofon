import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/app_settings.dart';
import 'package:slovofon/domain/models/audio_book.dart';
import 'package:slovofon/services/bookmarks/bookmark_store.dart';
import 'package:slovofon/services/library/library_store.dart';
import 'package:slovofon/services/settings/app_settings_store.dart';
import 'package:slovofon/services/sources/source_settings_store.dart';

import '../services/audio/playback_shutdown_test.dart' show shutdownBook;

void main() {
  test('settings drain includes edits queued behind hydration', () async {
    final persistence = _Settings();
    final store = AppSettingsStore(persistence);
    addTearDown(store.dispose);
    final edit = store.setLanguageCode('uk');
    var drained = false;
    final drain = store.flushPendingWrites().then((_) => drained = true);
    await Future<void>.delayed(Duration.zero);
    expect(drained, isFalse);
    persistence.loadGate.complete(const AppSettings.defaults());
    await persistence.saveStarted.future;
    expect(drained, isFalse);
    persistence.saveGate.complete();
    await Future.wait([edit, drain]);
    expect(store.settings.languageCode, 'uk');
  });

  test('favorite drain waits for accepted durable edit', () async {
    final persistence = _Library();
    final store = LibraryStore(persistence);
    addTearDown(store.dispose);
    final edit = store.toggleFavorite(_book);
    var drained = false;
    final drain = store.flushPendingWrites().then((_) => drained = true);
    await persistence.started.future;
    expect(drained, isFalse);
    persistence.gate.complete();
    await Future.wait([edit, drain]);
    expect(store.isFavorite(_book), isTrue);
  });

  test('bookmark drain waits for accepted durable edit', () async {
    final persistence = _Bookmarks();
    final store = BookmarkStore(persistence);
    addTearDown(store.dispose);
    final edit = store.add(
      book: shutdownBook,
      chapterId: 'one',
      positionMs: 42,
    );
    var drained = false;
    final drain = store.flushPendingWrites().then((_) => drained = true);
    await persistence.started.future;
    expect(drained, isFalse);
    persistence.gate.complete();
    await Future.wait([edit, drain]);
    expect(store.entries.single.positionMs, 42);
  });

  test('source drain waits for every save in a multi-source edit', () async {
    final persistence = _Sources();
    final store = SourceSettingsStore(persistence);
    final edit = store.setEnabledSources({'izib'});
    var drained = false;
    final drain = store.flushPendingWrites().then((_) => drained = true);
    await persistence.started.future;
    expect(drained, isFalse);
    // Disposing listeners must not suppress or interrupt the accepted writes.
    store.dispose();
    persistence.gate.complete();
    await Future.wait([edit, drain]);
    expect(persistence.saves, defaultSourceIds.length);
  });
}

class _Settings extends MemoryAppSettingsPersistenceStore {
  final loadGate = Completer<AppSettings>();
  final saveStarted = Completer<void>();
  final saveGate = Completer<void>();
  @override
  Future<AppSettings?> load() => loadGate.future;
  @override
  Future<void> save(AppSettings settings, {required DateTime updatedAt}) async {
    saveStarted.complete();
    await saveGate.future;
    await super.save(settings, updatedAt: updatedAt);
  }
}

class _Library extends MemoryLibraryPersistenceStore {
  final started = Completer<void>();
  final gate = Completer<void>();
  @override
  Future<void> saveFavorite(LibraryBookEntry entry) async {
    started.complete();
    await gate.future;
    await super.saveFavorite(entry);
  }
}

class _Bookmarks extends MemoryBookmarkPersistence {
  final started = Completer<void>();
  final gate = Completer<void>();
  @override
  Future<void> save(PlaybackBookmark bookmark) async {
    started.complete();
    await gate.future;
    await super.save(bookmark);
  }
}

class _Sources extends MemorySourceSettingsPersistenceStore {
  final started = Completer<void>();
  final gate = Completer<void>();
  int saves = 0;
  @override
  Future<void> save(SourceSettings settings) async {
    if (++saves == 1) {
      started.complete();
      await gate.future;
    }
    await super.save(settings);
  }
}

const _book = AudioBook(
  id: 'book',
  title: 'Book',
  author: 'Author',
  narrator: 'Reader',
  sourceId: 'izib',
  sourceName: 'Source',
  durationLabel: '1 h',
  chapterCount: 1,
  progress: 0,
  access: BookAccess.free,
);
