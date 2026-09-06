import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/sources/source_access_policy.dart';
import 'package:slovofon/services/sources/source_access_policy_provider.dart';
import 'package:slovofon/services/sources/source_settings_store.dart';
import 'package:slovofon/sources/source_models.dart';

void main() {
  final remote = AudioMediaSource.url(
    Uri.parse('https://media.example.invalid/chapter.mp3'),
    headers: const {'Authorization': 'synthetic-never-in-error'},
  );

  test('default and absent source settings permit both operations', () async {
    final store = _store();
    final policy = SourceAccessPolicy(store);
    for (final sourceId in [...defaultSourceIds, 'unknown-source']) {
      for (final operation in SourceAccessOperation.values) {
        await policy.ensureRemoteAllowed(sourceId, operation);
      }
    }
    expect(store.settingsFor('unknown-source'), isNull);
  });

  for (final operation in SourceAccessOperation.values) {
    test('${operation.name} denial is independent of the other flag', () async {
      final store = _store();
      await store.setMediaPermissions(
        'izib',
        allowStreaming: operation != SourceAccessOperation.streaming,
        allowDownload: operation != SourceAccessOperation.download,
      );
      final policy = SourceAccessPolicy(store);
      await expectLater(
        policy.ensureRemoteAllowed('izib', operation),
        throwsA(_denial(operation)),
      );
      final other = SourceAccessOperation.values.firstWhere(
        (value) => value != operation,
      );
      await policy.ensureRemoteAllowed('izib', other);
      await policy.ensureRemoteAllowed('akniga', operation);
    });

    test('${operation.name} awaits persisted denial hydration', () async {
      final persistence = _DelayedPersistence();
      final store = SourceSettingsStore(persistence);
      addTearDown(store.dispose);
      final policy = SourceAccessPolicy(store);
      var finished = false;
      final access = policy.ensureRemoteAllowed('izib', operation);
      final expectation = expectLater(access, throwsA(_denial(operation)));
      final observedCompletion = access.then<void>(
        (_) => finished = true,
        onError: (Object _, StackTrace _) => finished = true,
      );
      await Future<void>.value();
      expect(finished, isFalse);
      persistence.loaded.complete({
        'izib': _settings(allowStreaming: false, allowDownload: false),
      });
      await expectation;
      await observedCompletion;
      expect(finished, isTrue);
      expect(persistence.loadCount, 1);
    });

    test('${operation.name} reads changes without recreating policy', () async {
      final store = _store();
      final policy = SourceAccessPolicy(store);
      await policy.ensureRemoteAllowed('izib', operation);
      await store.setMediaPermissions(
        'izib',
        allowStreaming: false,
        allowDownload: false,
      );
      await expectLater(
        policy.ensureRemoteAllowed('izib', operation),
        throwsA(_denial(operation)),
      );
      await store.setMediaPermissions(
        'izib',
        allowStreaming: true,
        allowDownload: true,
      );
      await policy.ensureRemoteAllowed('izib', operation);
    });
  }

  test('search-disabled source can still stream and download', () async {
    final persistence = MemorySourceSettingsPersistenceStore();
    await persistence.save(
      _settings().copyWith(isEnabled: false, useInGlobalSearch: false),
    );
    final store = _store(persistence);
    final policy = SourceAccessPolicy(store);
    for (final operation in SourceAccessOperation.values) {
      await policy.ensureRemoteAllowed('izib', operation);
    }
    expect(store.enabledSearchSourceIds, isNot(contains('izib')));
  });

  for (final source in [
    AudioMediaSource.file('C:\\synthetic-fixture\\chapter.mp3'),
    AudioMediaSource.asset('audio/chapter.mp3'),
  ]) {
    test('effective ${source.type.name} bypasses streaming denial', () async {
      final store = _store();
      await store.setMediaPermissions('izib', allowStreaming: false);
      final chapter = _chapter(source: source, original: remote);
      await SourceAccessPolicy(store).ensurePlaybackAllowed(_book(), chapter);
    });

    test(
      '${source.type.name} needs no remote permission for local copy',
      () async {
        final store = _store();
        await store.setMediaPermissions('izib', allowDownload: false);
        await SourceAccessPolicy(
          store,
        ).ensureDownloadAllowed(_book(), _chapter(source: source));
      },
    );
  }

  test('mixed book permits local chapter but denies remote chapter', () async {
    final local = _chapter(
      source: AudioMediaSource.file('C:\\synthetic-fixture\\chapter.mp3'),
      original: remote,
    );
    final online = _chapter(source: remote);
    final book = _book(chapters: [local, online]);
    final store = _store();
    await store.setMediaPermissions('izib', allowStreaming: false);
    final policy = SourceAccessPolicy(store);
    await policy.ensurePlaybackAllowed(book, local);
    await expectLater(
      policy.ensurePlaybackAllowed(book, online),
      throwsA(_denial(SourceAccessOperation.streaming)),
    );
  });

  test(
    'download checks remote original even when old offline overlay exists',
    () async {
      final store = _store();
      await store.setMediaPermissions('izib', allowDownload: false);
      await expectLater(
        SourceAccessPolicy(store).ensureDownloadAllowed(
          _book(),
          _chapter(
            source: AudioMediaSource.file('C:\\synthetic-fixture\\missing.mp3'),
            original: remote,
          ),
        ),
        throwsA(_denial(SourceAccessOperation.download)),
      );
    },
  );

  test(
    'isDownloaded metadata alone cannot bypass remote playback guard',
    () async {
      final store = _store();
      await store.setMediaPermissions('izib', allowStreaming: false);
      await expectLater(
        SourceAccessPolicy(store).ensurePlaybackAllowed(
          _book(),
          _chapter(source: remote).copyWith(isDownloaded: true),
        ),
        throwsA(_denial(SourceAccessOperation.streaming)),
      );
    },
  );

  test('missing media cannot bypass a denial before remote refresh', () async {
    final store = _store();
    await store.setMediaPermissions(
      'izib',
      allowStreaming: false,
      allowDownload: false,
    );
    final policy = SourceAccessPolicy(store);
    await expectLater(
      policy.ensurePlaybackAllowed(_book(), _chapter()),
      throwsA(_denial(SourceAccessOperation.streaming)),
    );
    await expectLater(
      policy.ensureDownloadAllowed(_book(), _chapter()),
      throwsA(_denial(SourceAccessOperation.download)),
    );
  });

  test(
    'local playback does not depend on settings storage availability',
    () async {
      final persistence = _DelayedPersistence();
      final store = SourceSettingsStore(persistence);
      addTearDown(store.dispose);
      await SourceAccessPolicy(store).ensurePlaybackAllowed(
        _book(),
        _chapter(source: AudioMediaSource.asset('audio/chapter.mp3')),
      );
      expect(persistence.loadCount, 0);
    },
  );

  test(
    'unavailable persistence cannot fall back to allow-all remote access',
    () async {
      final persistence = _DelayedPersistence();
      final store = SourceSettingsStore(persistence);
      addTearDown(store.dispose);
      final failedLoad = StateError('synthetic persistence failure');
      final expectation = expectLater(
        SourceAccessPolicy(
          store,
        ).ensureRemoteAllowed('izib', SourceAccessOperation.streaming),
        throwsA(same(failedLoad)),
      );
      persistence.loaded.completeError(failedLoad);
      await expectation;
    },
  );

  test('denial retains source, operation and safe localizable code', () async {
    final store = _store();
    await store.setMediaPermissions('izib', allowStreaming: false);
    try {
      await SourceAccessPolicy(
        store,
      ).ensurePlaybackAllowed(_book(), _chapter(source: remote));
      fail('Remote playback should be denied.');
    } on SourceAccessDeniedException catch (error) {
      expect(error, isA<SourceException>());
      expect(error.sourceId, 'izib');
      expect(error.operation, SourceAccessOperation.streaming);
      expect(error.code, 'source_streaming_disabled');
      expect(error.message, error.code);
      expect(error.toString(), isNot(contains('media.example.invalid')));
      expect(error.toString(), isNot(contains('synthetic-never-in-error')));
      expect(error.cause, isNull);
    }
  });

  test(
    'provider stays stable while policy observes settings changes',
    () async {
      final store = SourceSettingsStore(MemorySourceSettingsPersistenceStore());
      final container = ProviderContainer(
        overrides: [sourceSettingsStoreProvider.overrideWith((ref) => store)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        sourceAccessPolicyProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final policy = subscription.read();
      await policy.ensureRemoteAllowed('izib', SourceAccessOperation.streaming);
      await store.setMediaPermissions('izib', allowStreaming: false);
      expect(container.read(sourceAccessPolicyProvider), same(policy));
      await expectLater(
        policy.ensureRemoteAllowed('izib', SourceAccessOperation.streaming),
        throwsA(_denial(SourceAccessOperation.streaming)),
      );
    },
  );
}

SourceSettingsStore _store([SourceSettingsPersistenceStore? persistence]) {
  final store = SourceSettingsStore(
    persistence ?? MemorySourceSettingsPersistenceStore(),
  );
  addTearDown(store.dispose);
  return store;
}

SourceSettings _settings({
  bool allowStreaming = true,
  bool allowDownload = true,
}) {
  return SourceSettings(
    sourceId: 'izib',
    updatedAt: DateTime.utc(2026, 1, 1),
    allowStreaming: allowStreaming,
    allowDownload: allowDownload,
  );
}

Matcher _denial(SourceAccessOperation operation) {
  return isA<SourceAccessDeniedException>()
      .having((error) => error.operation, 'operation', operation)
      .having((error) => error.sourceId, 'sourceId', 'izib');
}

AudioPlaybackChapter _chapter({
  AudioMediaSource? source,
  AudioMediaSource? original,
}) {
  return AudioPlaybackChapter(
    id: 'chapter',
    index: 0,
    title: 'Synthetic chapter',
    duration: const Duration(minutes: 3),
    mediaSource: source,
    originalMediaSource: original,
  );
}

AudioPlaybackBook _book({List<AudioPlaybackChapter> chapters = const []}) {
  return AudioPlaybackBook(
    id: 'book',
    versionId: 'version',
    sourceId: 'izib',
    title: 'Synthetic book',
    author: 'Author',
    narrator: 'Narrator',
    sourceName: 'Izib',
    chapters: chapters,
  );
}

class _DelayedPersistence implements SourceSettingsPersistenceStore {
  final loaded = Completer<Map<String, SourceSettings>>();
  int loadCount = 0;

  @override
  Future<Map<String, SourceSettings>> load() {
    loadCount++;
    return loaded.future;
  }

  @override
  Future<void> save(SourceSettings settings) async {}
}
