import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/sources/source_access_policy.dart';
import 'package:slovofon/services/sources/source_settings_store.dart';

void main() {
  test('media permissions are persisted and survive a new store', () async {
    final persistence = MemorySourceSettingsPersistenceStore();
    final store = _store(persistence);
    await store.setMediaPermissions(
      'izib',
      allowStreaming: false,
      allowDownload: false,
    );
    final restored = _store(persistence);
    await restored.load();
    expect(restored.settingsFor('izib')?.allowStreaming, isFalse);
    expect(restored.settingsFor('izib')?.allowDownload, isFalse);
    expect(restored.settingsFor('akniga')?.allowStreaming, isTrue);
    expect(restored.settingsFor('akniga')?.allowDownload, isTrue);
  });

  test(
    'permission mutation preserves search settings and the other flag',
    () async {
      final persistence = MemorySourceSettingsPersistenceStore();
      await persistence.save(
        _setting().copyWith(
          isEnabled: false,
          useInGlobalSearch: false,
          priority: 7,
          allowDownload: false,
        ),
      );
      final store = _store(persistence);
      await store.setMediaPermissions('izib', allowStreaming: false);
      final updated = store.settingsFor('izib')!;
      expect(updated.isEnabled, isFalse);
      expect(updated.useInGlobalSearch, isFalse);
      expect(updated.priority, 7);
      expect(updated.allowStreaming, isFalse);
      expect(updated.allowDownload, isFalse);
      expect(updated.updatedAt, DateTime.utc(2026, 2, 2));
    },
  );

  test('global search mutations preserve both media restrictions', () async {
    final persistence = MemorySourceSettingsPersistenceStore();
    final store = _store(persistence);
    await store.setMediaPermissions(
      'izib',
      allowStreaming: false,
      allowDownload: false,
    );
    await store.setSourceEnabled('izib', false);
    await store.setEnabledSources({'izib'});
    final restored = _store(persistence);
    await restored.load();
    final value = restored.settingsFor('izib')!;
    expect(value.isEnabled, isTrue);
    expect(value.allowStreaming, isFalse);
    expect(value.allowDownload, isFalse);
  });

  test('absent permission arguments are a no-op after hydration', () async {
    final persistence = _RecordingPersistence();
    final store = _store(persistence);
    await store.load();
    var notifications = 0;
    store.addListener(() => notifications++);
    await store.setMediaPermissions('izib');
    expect(notifications, 0);
    expect(persistence.saved, isEmpty);
  });

  test('one permission mutation saves and notifies once', () async {
    final persistence = _RecordingPersistence();
    final store = _store(persistence);
    await store.load();
    var notifications = 0;
    store.addListener(() => notifications++);
    await store.setMediaPermissions('izib', allowDownload: false);
    expect(notifications, 1);
    expect(persistence.saved, hasLength(1));
    expect(persistence.saved.single.allowDownload, isFalse);
  });

  test(
    'mutation waits for hydration and does not overwrite persisted flag',
    () async {
      final persistence = _DelayedPersistence();
      final store = _store(persistence);
      final mutation = store.setMediaPermissions('izib', allowDownload: false);
      await Future<void>.value();
      expect(persistence.saved, isEmpty);
      persistence.loaded.complete({
        'izib': _setting().copyWith(allowStreaming: false),
      });
      await mutation;
      expect(persistence.saved.single.allowStreaming, isFalse);
      expect(persistence.saved.single.allowDownload, isFalse);
    },
  );

  test('explicit unknown-source restrictions survive hydration', () async {
    final persistence = MemorySourceSettingsPersistenceStore();
    final store = _store(persistence);
    await store.setMediaPermissions(
      'future-source',
      allowStreaming: false,
      allowDownload: false,
    );
    final restored = _store(persistence);
    final policy = SourceAccessPolicy(restored);
    for (final operation in SourceAccessOperation.values) {
      await expectLater(
        policy.ensureRemoteAllowed('future-source', operation),
        throwsA(
          isA<SourceAccessDeniedException>().having(
            (error) => error.sourceId,
            'sourceId',
            'future-source',
          ),
        ),
      );
    }
    expect(
      restored.settings.map((setting) => setting.sourceId),
      defaultSourceIds,
    );
    expect(restored.enabledSearchSourceIds, isNot(contains('future-source')));
    await policy.ensureRemoteAllowed(
      'another-unknown-source',
      SourceAccessOperation.streaming,
    );
  });
}

SourceSettingsStore _store(SourceSettingsPersistenceStore persistence) {
  final store = SourceSettingsStore(
    persistence,
    clock: () => DateTime.utc(2026, 2, 2),
  );
  addTearDown(store.dispose);
  return store;
}

SourceSettings _setting() {
  return SourceSettings(sourceId: 'izib', updatedAt: DateTime.utc(2026, 1, 1));
}

class _RecordingPersistence extends MemorySourceSettingsPersistenceStore {
  final saved = <SourceSettings>[];

  @override
  Future<void> save(SourceSettings settings) async {
    saved.add(settings);
    await super.save(settings);
  }
}

class _DelayedPersistence extends _RecordingPersistence {
  final loaded = Completer<Map<String, SourceSettings>>();

  @override
  Future<Map<String, SourceSettings>> load() => loaded.future;
}
