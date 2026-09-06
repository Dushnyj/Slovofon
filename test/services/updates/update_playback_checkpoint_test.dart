import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/playback_session.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_persistence.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/updates/update_client.dart';
import 'package:slovofon/services/updates/update_installer.dart';
import 'package:slovofon/services/updates/update_manifest.dart';
import 'package:slovofon/services/updates/update_service.dart';

void main() {
  late _CheckpointStore store;
  late PlaybackController controller;
  late List<FlutterErrorDetails> errors;
  FlutterExceptionHandler? previousErrorHandler;

  setUp(() async {
    errors = [];
    previousErrorHandler = FlutterError.onError;
    FlutterError.onError = errors.add;
    store = _CheckpointStore();
    controller = PlaybackController(
      engine: InMemoryAudioEngine(),
      persistence: store,
    );
    await controller.loadBook(_book);
    await controller.seek(const Duration(seconds: 42));
    await controller.flushPlayback(requireSuccess: true);
    store.events.clear();
    errors.clear();
  });

  tearDown(() async {
    store.sessionFailure = null;
    store.progressFailure = null;
    final gate = store.sessionGate;
    if (gate != null && !gate.isCompleted) gate.complete();
    store.sessionGate = null;
    controller.dispose();
    await Future<void>.delayed(Duration.zero);
    FlutterError.onError = previousErrorHandler;
  });

  for (final failSession in [true, false]) {
    test(
      'strict checkpoint surfaces ${failSession ? 'session' : 'progress'} failure without duplicate reporting',
      () async {
        final failure = StateError('synthetic persistence failure');
        if (failSession) {
          store.sessionFailure = failure;
        } else {
          store.progressFailure = failure;
        }
        await expectLater(
          controller.flushPlayback(requireSuccess: true),
          throwsA(same(failure)),
        );
        expect(errors, isEmpty);
        expect(
          store.events,
          failSession
              ? ['session:start']
              : ['session:start', 'session:ok', 'progress:start'],
        );
      },
    );

    test(
      'default checkpoint keeps best-effort ${failSession ? 'session' : 'progress'} error reporting',
      () async {
        final failure = StateError('synthetic persistence failure');
        if (failSession) {
          store.sessionFailure = failure;
        } else {
          store.progressFailure = failure;
        }
        await controller.flushPlayback();
        expect(errors, hasLength(1));
        expect(errors.single.exception, same(failure));
        expect(errors.single.library, 'slovofon playback');
      },
    );

    test(
      'Windows handoff is blocked by real controller ${failSession ? 'session' : 'progress'} failure and retries safely',
      () async {
        final client = _DownloadedFixtureClient();
        final installer = _RecordingInstaller();
        final service = UpdateService(
          client: client,
          installer: installer,
          runtimePlatform: UpdateRuntimePlatform.windows,
          beforeInstall: () => controller.flushPlayback(requireSuccess: true),
        );
        if (failSession) {
          store.sessionFailure = StateError('synthetic session failure');
        } else {
          store.progressFailure = StateError('synthetic progress failure');
        }
        await expectLater(
          service.downloadAndInstall(_updateInfo),
          throwsA(isA<UpdateInstallException>()),
        );
        expect(installer.installCount, 0);
        expect(errors, isEmpty);
        store.sessionFailure = null;
        store.progressFailure = null;
        store.events.clear();
        await service.downloadAndInstall(_updateInfo);
        expect(installer.installCount, 1);
        expect(store.events, [
          'session:start',
          'session:ok',
          'progress:start',
          'progress:ok',
        ]);
        expect(store.lastSession!.positionMs, 42000);
        expect(store.lastProgress!.currentPositionMs, 42000);
        expect(errors, isEmpty);
      },
    );
  }

  test(
    'a failed strict checkpoint does not poison or reorder queued retries',
    () async {
      final failure = StateError('synthetic first save failure');
      final gate = Completer<void>();
      store.sessionFailure = failure;
      store.sessionGate = gate;
      final failed = expectLater(
        controller.flushPlayback(requireSuccess: true),
        throwsA(same(failure)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(store.events, ['session:start']);
      final retry = controller.flushPlayback(requireSuccess: true);
      store.sessionFailure = null;
      store.sessionGate = null;
      gate.complete();
      await failed;
      await retry;
      expect(store.events, [
        'session:start',
        'session:start',
        'session:ok',
        'progress:start',
        'progress:ok',
      ]);
      expect(errors, isEmpty);
      expect(store.lastSession!.positionMs, 42000);
    },
  );

  test(
    'Windows installer cannot start while a real checkpoint is pending',
    () async {
      final gate = Completer<void>();
      store.sessionGate = gate;
      final installer = _RecordingInstaller();
      final service = UpdateService(
        client: _DownloadedFixtureClient(),
        installer: installer,
        runtimePlatform: UpdateRuntimePlatform.windows,
        beforeInstall: () => controller.flushPlayback(requireSuccess: true),
      );
      final update = service.downloadAndInstall(_updateInfo);
      await Future<void>.delayed(Duration.zero);
      expect(store.events, ['session:start']);
      expect(installer.installCount, 0);
      gate.complete();
      await update;
      expect(installer.installCount, 1);
      expect(store.lastProgress!.currentPositionMs, 42000);
    },
  );
}

class _CheckpointStore implements PlaybackPersistenceStore {
  Object? sessionFailure;
  Object? progressFailure;
  Completer<void>? sessionGate;
  final events = <String>[];
  PlaybackSession? lastSession;
  PlaybackProgressSnapshot? lastProgress;

  @override
  Future<PlaybackSession?> loadSession({String id = 'active'}) async =>
      lastSession;

  @override
  Future<List<PlaybackProgressSnapshot>> loadProgress() async => [
    ?lastProgress,
  ];

  @override
  Future<void> saveSession(PlaybackSession session) async {
    events.add('session:start');
    final failure = sessionFailure;
    await sessionGate?.future;
    if (failure != null) throw failure;
    lastSession = session;
    events.add('session:ok');
  }

  @override
  Future<void> saveProgress(PlaybackProgressSnapshot progress) async {
    events.add('progress:start');
    if (progressFailure != null) throw progressFailure!;
    lastProgress = progress;
    events.add('progress:ok');
  }
}

class _DownloadedFixtureClient extends UpdateClient {
  @override
  Future<DownloadedUpdate> downloadAsset(
    UpdateAsset asset, {
    void Function(int downloadedBytes, int? totalBytes)? onProgress,
  }) async => DownloadedUpdate(
    file: File('synthetic-not-created-or-executed.exe'),
    asset: asset,
  );
}

class _RecordingInstaller extends PlatformUpdateInstaller {
  int installCount = 0;

  @override
  Future<void> ensureReadyToInstall() async {}

  @override
  Future<void> install(DownloadedUpdate update) async {
    installCount++;
  }
}

const _book = AudioPlaybackBook(
  id: 'fixture-book',
  versionId: 'fixture-version',
  sourceId: 'fixture',
  sourceName: 'Fixture',
  title: 'Synthetic checkpoint book',
  author: 'Fixture',
  narrator: 'Fixture',
  chapters: [
    AudioPlaybackChapter(
      id: 'fixture-chapter',
      index: 0,
      title: 'Synthetic chapter',
      duration: Duration(minutes: 10),
    ),
  ],
);

final _updateInfo = UpdateInfo(
  manifest: const UpdateManifest(
    schema: 1,
    app: 'slovofon',
    channel: 'stable',
    status: 'available',
    version: '0.0.8',
    build: null,
    publishedAt: null,
    mandatory: false,
    releaseUrl: null,
    releaseNotes: null,
    assets: [],
  ),
  asset: UpdateAsset(
    platform: UpdateAssetPlatform.windows,
    arch: 'x64',
    kind: UpdateAssetKind.installer,
    url: Uri.parse(
      'https://github.com/Dushnyj/Slovofon/releases/download/v0.0.8/Slovofon-v0.0.8-windows-x64-setup.exe',
    ),
    fileName: 'Slovofon-v0.0.8-windows-x64-setup.exe',
    sha256: '0' * 64,
    size: 1,
  ),
);
