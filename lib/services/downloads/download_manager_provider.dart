import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

import '../sources/source_catalog_provider.dart';
import '../sources/source_access_policy.dart';
import '../sources/source_access_policy_provider.dart';
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
  final accessPolicy = ref.watch(sourceAccessPolicyProvider);
  final manager = DownloadManager(
    client: ref.watch(downloadClientProvider),
    storage: ref.watch(downloadStorageProvider),
    persistence: ref.watch(downloadPersistenceStoreProvider),
    ensureDownloadAllowed: (book, chapter) async {
      try {
        if (chapter == null) {
          await accessPolicy.ensureRemoteAllowed(
            book.sourceId,
            SourceAccessOperation.download,
          );
        } else {
          await accessPolicy.ensureDownloadAllowed(book, chapter);
        }
      } on SourceAccessDeniedException catch (error) {
        throw DownloadClientException(error.message, code: error.code);
      }
    },
    refreshBookForDownloads: (book) {
      return ref
          .read(sourceCatalogServiceProvider)
          .refreshBookForDownloads(book);
    },
  );
  unawaited(manager.loadPersistedTasks());
  ref.onDispose(manager.dispose);
  return manager;
});
