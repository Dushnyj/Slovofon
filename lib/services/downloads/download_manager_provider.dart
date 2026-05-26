import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

import 'download_client.dart';
import 'download_manager.dart';
import 'download_persistence.dart';
import 'download_storage.dart';

final downloadStorageProvider = Provider<FileDownloadStorage>((ref) {
  return FileDownloadStorage(
    rootDirectory: Directory(
      p.join(Directory.systemTemp.path, 'slovofon-downloads-dev'),
    ),
  );
});

final downloadPersistenceStoreProvider = Provider<DownloadPersistenceStore>((
  ref,
) {
  return MemoryDownloadPersistenceStore();
});

final downloadClientProvider = Provider<DownloadClient>((ref) {
  return DefaultDownloadClient();
});

final downloadManagerProvider = ChangeNotifierProvider<DownloadManager>((ref) {
  final manager = DownloadManager(
    client: ref.watch(downloadClientProvider),
    storage: ref.watch(downloadStorageProvider),
    persistence: ref.watch(downloadPersistenceStoreProvider),
  );
  unawaited(manager.loadPersistedTasks());
  ref.onDispose(manager.dispose);
  return manager;
});
