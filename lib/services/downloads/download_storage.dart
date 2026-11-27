import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/network/media_request_policy.dart';
import '../../core/storage/atomic_json_file.dart';
import '../../sources/built_in_source_policies.dart';
import '../../sources/source_parser_helpers.dart';
import '../audio/audio_persistence.dart';
import '../audio/audio_state.dart';

class FileDownloadStorage implements PlaybackBookMetadataStore {
  FileDownloadStorage({required Directory rootDirectory})
    : _rootDirectory = rootDirectory;

  final Directory _rootDirectory;
  final _resolvedDirectories = <String, Directory>{};
  static final _metadataWrites = <String, Future<void>>{};
  static final _downloadProtectionCounts = <String, int>{};

  String _pathKey(String path) {
    final absolute = p.normalize(p.absolute(path));
    return Platform.isWindows ? absolute.toLowerCase() : absolute;
  }

  /// Pending/paused tasks need metadata even before a .part file exists.
  /// Protect both candidate paths conservatively until the manager releases
  /// its task context; this also works across storage instances for one root.
  void retainDownloadBook(String sourceId, String versionId) {
    for (final directory in [
      _newDirectory(sourceId, versionId),
      _legacyDirectory(sourceId, versionId),
    ]) {
      final key = _pathKey(directory.path);
      _downloadProtectionCounts[key] =
          (_downloadProtectionCounts[key] ?? 0) + 1;
    }
  }

  void releaseDownloadBook(String sourceId, String versionId) {
    for (final directory in [
      _newDirectory(sourceId, versionId),
      _legacyDirectory(sourceId, versionId),
    ]) {
      final key = _pathKey(directory.path);
      final next = (_downloadProtectionCounts[key] ?? 0) - 1;
      if (next <= 0) {
        _downloadProtectionCounts.remove(key);
      } else {
        _downloadProtectionCounts[key] = next;
      }
    }
  }

  bool _isDownloadProtected(Directory directory) =>
      (_downloadProtectionCounts[_pathKey(directory.path)] ?? 0) > 0;

  Directory get rootDirectory => _rootDirectory;

  static Future<FileDownloadStorage> create() async {
    final appSupportDirectory = await getApplicationSupportDirectory();
    return FileDownloadStorage(
      rootDirectory: Directory(p.join(appSupportDirectory.path, 'books')),
    );
  }

  Directory bookDirectoryFor(AudioPlaybackBook book) {
    return bookDirectoryForIds(book.sourceId, book.versionId);
  }

  Directory bookDirectoryForIds(String sourceId, String versionId) {
    return _resolvedDirectories[_identity(sourceId, versionId)] ??
        _newDirectory(sourceId, versionId);
  }

  String _identity(String sourceId, String versionId) =>
      jsonEncode([sourceId, versionId]);

  Directory _newDirectory(String sourceId, String versionId) {
    final identity = _identity(sourceId, versionId);
    final digest = sha256.convert(utf8.encode(identity));
    final readable = _safeSegment('${sourceId}_$versionId');
    final prefix = readable.length > 24 ? readable.substring(0, 24) : readable;
    return Directory(p.join(_rootDirectory.path, '$prefix-$digest'));
  }

  Directory _legacyDirectory(String sourceId, String versionId) => Directory(
    p.join(_rootDirectory.path, _safeSegment('${sourceId}_$versionId')),
  );

  Future<Directory> _resolveDirectory(
    String sourceId,
    String versionId, {
    bool destructive = false,
  }) async {
    final key = _identity(sourceId, versionId);
    final cached = _resolvedDirectories[key];
    if (cached != null && !destructive && await cached.exists()) {
      return cached;
    }
    final preferred = _newDirectory(sourceId, versionId);
    if (await preferred.exists()) {
      final metadata = await AtomicJsonFile(
        File(p.join(preferred.path, 'metadata.json')),
      ).read();
      if (metadata is Map &&
          metadata['sourceId'] is String &&
          metadata['bookVersionId'] is String &&
          (metadata['sourceId'] != sourceId ||
              metadata['bookVersionId'] != versionId)) {
        throw const FileSystemException('Download directory identity mismatch');
      }
      // A full digest identifies new directories even when metadata needs
      // recovery; malformed metadata is retained by AtomicJsonFile on write.
      return _resolvedDirectories[key] = preferred;
    }
    final legacy = _legacyDirectory(sourceId, versionId);
    if (await legacy.exists()) {
      final metadata = await AtomicJsonFile(
        File(p.join(legacy.path, 'metadata.json')),
      ).read();
      if (metadata is Map &&
          metadata['sourceId'] == sourceId &&
          metadata['bookVersionId'] == versionId) {
        return _resolvedDirectories[key] = legacy;
      }
      if (destructive &&
          (metadata is! Map ||
              metadata['sourceId'] is! String ||
              metadata['bookVersionId'] is! String)) {
        // No guessed ownership: an old directory without usable metadata may
        // contain another book whose punctuation collapsed to the same name.
        throw const FileSystemException(
          'Legacy download metadata needs recovery',
        );
      }
    }
    return _resolvedDirectories[key] = preferred;
  }

  Directory chaptersDirectoryFor(AudioPlaybackBook book) {
    return Directory(p.join(bookDirectoryFor(book).path, 'chapters'));
  }

  File metadataFileFor(AudioPlaybackBook book) {
    return File(p.join(bookDirectoryFor(book).path, 'metadata.json'));
  }

  File coverFileFor(AudioPlaybackBook book) {
    return File(p.join(bookDirectoryFor(book).path, 'cover.img'));
  }

  File metadataFileForIds(String sourceId, String versionId) {
    return File(
      p.join(bookDirectoryForIds(sourceId, versionId).path, 'metadata.json'),
    );
  }

  File partFileFor(AudioPlaybackBook book, AudioPlaybackChapter chapter) {
    return File(
      p.join(chaptersDirectoryFor(book).path, '${_chapterStem(chapter)}.part'),
    );
  }

  File chapterFileFor(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter, {
    required String extension,
  }) {
    final normalizedExtension = _safeExtension(extension);
    return File(
      p.join(
        chaptersDirectoryFor(book).path,
        '${_chapterStem(chapter)}.$normalizedExtension',
      ),
    );
  }

  Future<int> partialBytesFor(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) async {
    _ensureUniqueTrack(book, chapter);
    await _resolveDirectory(book.sourceId, book.versionId, destructive: false);
    final partFile = partFileFor(book, chapter);
    if (!await partFile.exists()) {
      return 0;
    }
    return partFile.length();
  }

  Future<IOSink> openPartSink(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter, {
    required bool append,
  }) async {
    _ensureUniqueTrack(book, chapter);
    await _resolveDirectory(book.sourceId, book.versionId, destructive: false);
    final partFile = partFileFor(book, chapter);
    await partFile.parent.create(recursive: true);
    return partFile.openWrite(mode: append ? FileMode.append : FileMode.write);
  }

  Future<File> finalizeChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter, {
    required String extension,
  }) async {
    await _resolveDirectory(book.sourceId, book.versionId, destructive: true);
    final partFile = partFileFor(book, chapter);
    _ensureUniqueTrack(book, chapter);
    var finalFile = chapterFileFor(book, chapter, extension: extension);
    // Fresh downloads never rescan the entire directory at finalize. Only a
    // same-slot legacy candidate needs its frozen identity rechecked. If an
    // old chapter has moved, leave its original file intact.
    final legacyCandidate = File(
      p.join(
        chaptersDirectoryFor(book).path,
        '${_numberedStem(chapter.index)}.${_safeExtension(extension)}',
      ),
    );
    if (await legacyCandidate.exists()) {
      final existing = await completedChapterFile(book, chapter);
      if (existing?.path == legacyCandidate.path) finalFile = legacyCandidate;
    }
    await finalFile.parent.create(recursive: true);
    // Replace atomically; deleting first loses a good download when rename
    // fails (for example a missing/locked part or a full disk).
    final result = await partFile.rename(finalFile.path);
    try {
      await _clearPartValidator(book, chapter);
    } on FileSystemException {
      // The part has already been renamed; a locked auxiliary file cannot
      // invalidate the completed audio or seed a resume without a part.
    }
    return result;
  }

  File _partValidatorFile(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) => File('${partFileFor(book, chapter).path}.resume');

  Future<({String entityTag, String representationKey})?> partValidatorFor(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) async {
    try {
      final value = jsonDecode(
        await _partValidatorFile(book, chapter).readAsString(),
      );
      if (value is Map && value['entityTag'] is String) {
        final entityTag = value['entityTag'] as String;
        final key = value['representationKey'];
        if (key is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(key)) {
          return (entityTag: entityTag, representationKey: key);
        }
      }
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
    return null;
  }

  Future<void> setPartValidator(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter, {
    required String entityTag,
    required String representationKey,
  }) async {
    _ensureUniqueTrack(book, chapter);
    final file = _partValidatorFile(book, chapter);
    await AtomicJsonFile(
      file,
    ).write({'entityTag': entityTag, 'representationKey': representationKey});
  }

  Future<void> _clearPartValidator(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) async {
    // The validator is intentionally not read from backup: a previous
    // representation must never be used after replacing its bytes.
    final file = _partValidatorFile(book, chapter);
    if (await file.exists()) await file.delete();
    final backup = File('${file.path}.bak');
    if (await backup.exists()) await backup.delete();
  }

  Future<void> resetPart(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) async {
    await _resolveDirectory(book.sourceId, book.versionId, destructive: true);
    if (!_hasUniqueTrack(book, chapter)) return;
    await _clearPartValidator(book, chapter);
    final partFile = partFileFor(book, chapter);
    if (await partFile.exists()) {
      await partFile.delete();
    }
  }

  Future<void> deleteChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) async {
    await _resolveDirectory(book.sourceId, book.versionId, destructive: true);
    await resetPart(book, chapter);

    final completed = await completedChapterFile(book, chapter);
    if (completed != null && await completed.exists()) {
      await completed.delete();
    }
  }

  Future<void> deleteBook(AudioPlaybackBook book) async {
    await _resolveDirectory(book.sourceId, book.versionId, destructive: true);
    final directory = bookDirectoryFor(book);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    _resolvedDirectories.remove(_identity(book.sourceId, book.versionId));
  }

  Future<CardCacheStats> cardCacheStats() async {
    var bytes = 0;
    var bookCount = 0;
    await for (final directory in _bookDirectories()) {
      final files = _cardCacheFiles(directory);
      var hasCache = false;
      for (final file in files) {
        if (await file.exists()) {
          hasCache = true;
          bytes += await file.length();
        }
      }
      if (hasCache) {
        bookCount++;
      }
    }
    return CardCacheStats(bytes: bytes, bookCount: bookCount);
  }

  Future<CardCacheStats> clearCardCache() =>
      _serializeMetadata(_clearCardCache);

  Future<CardCacheStats> _clearCardCache() async {
    var bytes = 0;
    var bookCount = 0;
    await for (final directory in _bookDirectories()) {
      if (_isDownloadProtected(directory) ||
          await _hasChapterFiles(directory)) {
        continue;
      }
      final files = _cardCacheFiles(directory);
      var clearedBook = false;
      for (final file in files) {
        if (!await file.exists()) {
          continue;
        }
        bytes += await file.length();
        await file.delete();
        clearedBook = true;
      }
      if (clearedBook) {
        bookCount++;
      }
      await _deleteIfEmpty(directory);
    }
    return CardCacheStats(bytes: bytes, bookCount: bookCount);
  }

  @override
  Future<void> saveBook(AudioPlaybackBook book) {
    return writeMetadata(book);
  }

  @override
  Future<AudioPlaybackBook?> loadBook({
    required String sourceId,
    required String versionId,
  }) {
    return readMetadataForIds(sourceId, versionId);
  }

  Future<void> writeMetadata(AudioPlaybackBook book) =>
      _serializeMetadata(() => _writeMetadata(book));

  Future<T> _serializeMetadata<T>(Future<T> Function() operation) {
    // Cache deletion and writes must use the same root lock: cleanup may have
    // started before an enqueue registered its protection, and malformed
    // metadata cannot safely supply a per-book identity for locking.
    final key = _pathKey(_rootDirectory.path);
    final previous = _metadataWrites[key] ?? Future<void>.value();
    final write = previous.then((_) => operation());
    final tail = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _metadataWrites[key] = tail;
    return write.whenComplete(() {
      if (identical(_metadataWrites[key], tail)) {
        _metadataWrites.remove(key);
      }
    });
  }

  Future<void> _writeMetadata(AudioPlaybackBook book) async {
    await _resolveDirectory(book.sourceId, book.versionId);
    final metadataFile = metadataFileFor(book);
    final prior = await AtomicJsonFile(metadataFile).read();
    final existing = _decodeBook(
      prior,
      fallbackSourceId: book.sourceId,
      fallbackVersionId: book.versionId,
    );
    // Freeze the complete old binding before replacing the chapter list.
    // Never infer that old numbered bytes belong to the incoming order.
    final legacy = _legacyBindings(prior, book.sourceId, book.versionId);
    final mergedBook = existing == null
        ? book
        : _mergeCachedBook(existing, book);
    await metadataFile.parent.create(recursive: true);
    final metadata = <String, Object?>{
      'bookId': mergedBook.id,
      'bookVersionId': mergedBook.versionId,
      'sourceId': mergedBook.sourceId,
      'sourceBookId': mergedBook.sourceBookId,
      'title': mergedBook.title,
      'authors': [mergedBook.author],
      'narrators': [mergedBook.narrator],
      'sourceName': mergedBook.sourceName,
      'coverUrl': mergedBook.coverUrl,
      'description': mergedBook.description,
      'genre': mergedBook.genre,
      'seriesTitle': mergedBook.seriesTitle,
      'seriesNumber': mergedBook.seriesNumber,
      'ratingValue': mergedBook.ratingValue,
      'ratingCount': mergedBook.ratingCount,
      'publishedYear': mergedBook.publishedYear,
      'sourceUrl': mergedBook.sourceUrl,
      'isFragment': mergedBook.isFragment,
      'legacyChapterBindings': [for (final binding in legacy) binding.json],
      'chapters': [
        for (final chapter in mergedBook.chapters)
          {
            'id': chapter.id,
            'index': chapter.index,
            'title': chapter.title,
            'durationMs': chapter.duration.inMilliseconds,
            'storageIdentity': chapter.storageIdentity,
            'storageMediaReference': _mediaReference(chapter),
            'isDownloaded': chapter.isDownloaded,
            // Persist the original source, not the transient offline overlay.
            'mediaSource': _mediaSourceToJson(
              _originalSource(chapter),
              mergedBook.sourceId,
            ),
          },
      ],
    };
    await AtomicJsonFile(metadataFile).write(metadata);
  }

  Future<String> writeCoverBytes(AudioPlaybackBook book, List<int> bytes) =>
      _serializeMetadata(() => _writeCoverBytes(book, bytes));

  Future<String> _writeCoverBytes(
    AudioPlaybackBook book,
    List<int> bytes,
  ) async {
    await _resolveDirectory(book.sourceId, book.versionId, destructive: false);
    final coverFile = coverFileFor(book);
    await coverFile.parent.create(recursive: true);
    await coverFile.writeAsBytes(bytes, flush: true);
    return coverFile.uri.toString();
  }

  Future<AudioPlaybackBook?> readMetadataForIds(
    String sourceId,
    String versionId,
  ) async {
    await _resolveDirectory(sourceId, versionId);
    final metadataFile = metadataFileForIds(sourceId, versionId);
    return _readMetadataFile(
      metadataFile,
      fallbackSourceId: sourceId,
      fallbackVersionId: versionId,
    );
  }

  Future<List<AudioPlaybackBook>> readAllMetadata() =>
      _readAllMetadata(downloadedCandidatesOnly: false);

  /// Avoid parsing unrelated cached cards; callers must still check the
  /// matching book's completed files since this can include a pending .part.
  Future<List<AudioPlaybackBook>> readDownloadedMetadata() =>
      _readAllMetadata(downloadedCandidatesOnly: true);

  Future<List<AudioPlaybackBook>> _readAllMetadata({
    required bool downloadedCandidatesOnly,
  }) async {
    final books = <String, AudioPlaybackBook>{};
    await for (final entity in _bookDirectories()) {
      if (downloadedCandidatesOnly && !await _hasChapterFiles(entity)) continue;
      final metadataFile = File(p.join(entity.path, 'metadata.json'));
      final book = await _readMetadataFile(metadataFile);
      if (book != null) {
        final expected = _newDirectory(book.sourceId, book.versionId).path;
        final legacy = _legacyDirectory(book.sourceId, book.versionId).path;
        if (entity.path != expected && entity.path != legacy) continue;
        final key = _identity(book.sourceId, book.versionId);
        if (entity.path == expected || !books.containsKey(key)) {
          _resolvedDirectories[key] = entity;
          books[key] = book;
        }
      }
    }
    return books.values.toList();
  }

  Stream<Directory> _bookDirectories() async* {
    if (!await _rootDirectory.exists()) {
      return;
    }
    await for (final entity in _rootDirectory.list(followLinks: false)) {
      if (entity is Directory) {
        yield entity;
      }
    }
  }

  List<File> _cardCacheFiles(Directory bookDirectory) {
    return [
      File(p.join(bookDirectory.path, 'metadata.json')),
      File(p.join(bookDirectory.path, 'metadata.json.bak')),
      File(p.join(bookDirectory.path, 'cover.img')),
    ];
  }

  Future<bool> _hasChapterFiles(Directory bookDirectory) async {
    final chaptersDirectory = Directory(p.join(bookDirectory.path, 'chapters'));
    if (!await chaptersDirectory.exists()) {
      return false;
    }
    await for (final entity in chaptersDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        return true;
      }
    }
    return false;
  }

  Future<void> _deleteIfEmpty(Directory directory) async {
    if (!await directory.exists()) {
      return;
    }
    final children = await directory.list(followLinks: false).toList();
    for (final child in children.whereType<Directory>()) {
      await _deleteIfEmpty(child);
    }
    if (await directory.list(followLinks: false).isEmpty) {
      await directory.delete();
    }
  }

  Future<AudioPlaybackBook?> _readMetadataFile(
    File metadataFile, {
    String? fallbackSourceId,
    String? fallbackVersionId,
  }) async {
    final decoded = await AtomicJsonFile(metadataFile).read();
    return _decodeBook(
      decoded,
      fallbackSourceId: fallbackSourceId,
      fallbackVersionId: fallbackVersionId,
    );
  }

  AudioPlaybackBook? _decodeBook(
    Object? decoded, {
    String? fallbackSourceId,
    String? fallbackVersionId,
  }) {
    if (decoded is! Map<String, Object?>) {
      return null;
    }

    final sourceId = _string(decoded['sourceId']) ?? fallbackSourceId;
    final chaptersJson = decoded['chapters'];
    final chapters = <AudioPlaybackChapter>[];
    if (chaptersJson is List) {
      for (final rawChapter in chaptersJson) {
        if (rawChapter is! Map<String, Object?>) {
          continue;
        }
        final id = _string(rawChapter['id']);
        final title = _string(rawChapter['title']);
        final durationMs = _int(rawChapter['durationMs']) ?? 0;
        if (id == null || title == null) {
          continue;
        }
        chapters.add(
          AudioPlaybackChapter(
            id: id,
            index: _int(rawChapter['index']) ?? chapters.length,
            title: title,
            duration: Duration(milliseconds: durationMs),
            storageIdentity: _string(rawChapter['storageIdentity']),
            storageMediaReference: _storedMediaReference(rawChapter),
            isDownloaded: rawChapter['isDownloaded'] == true,
            mediaSource: _mediaSourceFromJson(
              rawChapter['mediaSource'],
              sourceId,
            ),
          ),
        );
      }
    }

    final bookId = _string(decoded['bookId']);
    final title = _string(decoded['title']);
    final versionId = _string(decoded['bookVersionId']) ?? fallbackVersionId;
    if (bookId == null ||
        title == null ||
        versionId == null ||
        sourceId == null) {
      return null;
    }

    if ((fallbackSourceId != null && sourceId != fallbackSourceId) ||
        (fallbackVersionId != null && versionId != fallbackVersionId)) {
      return null;
    }

    return AudioPlaybackBook(
      id: bookId,
      versionId: versionId,
      sourceId: sourceId,
      sourceBookId: _string(decoded['sourceBookId']),
      title: title,
      author: _firstString(decoded['authors']),
      narrator: _firstString(decoded['narrators']),
      sourceName: _string(decoded['sourceName']) ?? sourceId,
      coverUrl: _string(decoded['coverUrl']),
      description: _string(decoded['description']),
      genre: _string(decoded['genre']),
      seriesTitle: _string(decoded['seriesTitle']),
      seriesNumber: _double(decoded['seriesNumber']),
      ratingValue: _double(decoded['ratingValue']),
      ratingCount: _int(decoded['ratingCount']),
      publishedYear: _int(decoded['publishedYear']),
      sourceUrl: _string(decoded['sourceUrl']),
      isFragment: decoded['isFragment'] == true,
      chapters: List.unmodifiable(chapters),
    );
  }

  Future<File?> completedChapterFile(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) async {
    return (await _completedFiles(book, [chapter]))[chapter.index];
  }

  /// One asynchronous directory scan per book, never one scan per chapter.
  /// No persistent cache: external file removal must be visible on next play.
  Future<Map<int, File>> completedChapterFiles(AudioPlaybackBook book) =>
      _completedFiles(book, book.chapters);

  Future<Map<int, File>> _completedFiles(
    AudioPlaybackBook book,
    List<AudioPlaybackChapter> chapters,
  ) async {
    await _resolveDirectory(book.sourceId, book.versionId, destructive: false);
    final directory = chaptersDirectoryFor(book);
    final files = <int, File>{};
    if (!await directory.exists()) {
      return files;
    }
    final byStem = <String, List<File>>{};
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File ||
          !_finalExtensions.contains(p.extension(entity.path).toLowerCase())) {
        continue;
      }
      final stem = p.basenameWithoutExtension(entity.path);
      byStem.putIfAbsent(stem, () => []).add(entity);
    }
    if (byStem.isEmpty) return files;
    final legacy = byStem.keys.any((stem) => int.tryParse(stem) != null)
        ? _legacyBindings(
            await AtomicJsonFile(metadataFileFor(book)).read(),
            book.sourceId,
            book.versionId,
          )
        : const <_LegacyChapterBinding>[];
    final chapterKeyCounts = <String, int>{};
    final indexCounts = <int, int>{};
    for (final chapter in book.chapters) {
      chapterKeyCounts.update(
        _chapterStem(chapter),
        (n) => n + 1,
        ifAbsent: () => 1,
      );
      indexCounts.update(chapter.index, (n) => n + 1, ifAbsent: () => 1);
    }
    for (final chapter in chapters) {
      final key = _chapterStem(chapter);
      if ((chapterKeyCounts[key] ?? 0) > 1 ||
          (indexCounts[chapter.index] ?? 0) > 1) {
        continue;
      }
      var candidates = byStem[key];
      if (candidates == null) {
        final matching = legacy.where(
          (binding) => binding.matches(chapter, book.sourceId),
        );
        if (matching.length == 1 &&
            legacy
                    .where((binding) => binding.index == matching.single.index)
                    .length ==
                1 &&
            book.chapters
                    .where(
                      (item) => matching.single.matches(item, book.sourceId),
                    )
                    .length <=
                1) {
          candidates = byStem[_numberedStem(matching.single.index)];
        }
      }
      if (candidates?.length == 1) {
        final file = candidates!.single;
        try {
          if (await file.length() > 0) files[chapter.index] = file;
        } on FileSystemException {
          // A concurrent explicit deletion should not break book playback.
        }
      }
    }
    return files;
  }

  Future<AudioPlaybackBook> offlinePlaybackBook(AudioPlaybackBook book) async {
    final cached = await readMetadataForIds(book.sourceId, book.versionId);
    final baseBook = cached == null ? book : _mergeCachedBook(cached, book);
    final cachedCoverFile = coverFileFor(baseBook);
    final hasCachedCover = baseBook.offlineOnly
        ? await FileSystemEntity.type(
                cachedCoverFile.path,
                followLinks: false,
              ) ==
              FileSystemEntityType.file
        : await cachedCoverFile.exists();
    final coverUrl = hasCachedCover
        ? cachedCoverFile.uri.toString()
        : (baseBook.offlineOnly ? null : baseBook.coverUrl);
    final chapters = <AudioPlaybackChapter>[];
    final localFiles = await completedChapterFiles(baseBook);
    for (final chapter in baseBook.chapters) {
      final localFile = localFiles[chapter.index];
      var originalSource = _originalSource(chapter);
      if (originalSource?.type == AudioMediaSourceType.file &&
          localFile == null &&
          !await File(originalSource!.filePath).exists()) {
        // Legacy metadata may contain only a now-deleted offline path. Do not
        // hand that stale path to the player or overwrite a fresh remote URL.
        originalSource = null;
      }
      chapters.add(
        AudioPlaybackChapter(
          id: chapter.id,
          index: chapter.index,
          title: chapter.title,
          duration: chapter.duration,
          storageIdentity: chapter.storageIdentity,
          storageMediaReference: chapter.storageMediaReference,
          isDownloaded: localFile != null,
          mediaSource: localFile == null
              ? (baseBook.offlineOnly ? null : originalSource)
              : AudioMediaSource.file(localFile.path),
          originalMediaSource: originalSource,
        ),
      );
    }

    return AudioPlaybackBook(
      id: baseBook.id,
      versionId: baseBook.versionId,
      sourceId: baseBook.sourceId,
      sourceBookId: baseBook.sourceBookId,
      title: baseBook.title,
      author: baseBook.author,
      narrator: baseBook.narrator,
      sourceName: baseBook.sourceName,
      coverUrl: coverUrl,
      description: baseBook.description,
      genre: baseBook.genre,
      seriesTitle: baseBook.seriesTitle,
      seriesNumber: baseBook.seriesNumber,
      ratingValue: baseBook.ratingValue,
      ratingCount: baseBook.ratingCount,
      publishedYear: baseBook.publishedYear,
      sourceUrl: baseBook.sourceUrl,
      isFragment: baseBook.isFragment,
      offlineOnly: baseBook.offlineOnly,
      chapters: chapters,
    );
  }

  AudioPlaybackBook _mergeCachedBook(
    AudioPlaybackBook cached,
    AudioPlaybackBook incoming,
  ) {
    return AudioPlaybackBook(
      id: _meaningful(incoming.id, cached.id),
      versionId: incoming.versionId,
      sourceId: incoming.sourceId,
      sourceBookId: _meaningfulOrNull(
        incoming.sourceBookId,
        cached.sourceBookId,
      ),
      title: _meaningful(incoming.title, cached.title),
      author: _meaningful(incoming.author, cached.author),
      narrator: _meaningful(incoming.narrator, cached.narrator),
      sourceName: _meaningful(incoming.sourceName, cached.sourceName),
      coverUrl: _preferCachedCover(cached.coverUrl, incoming.coverUrl),
      description: _meaningfulOrNull(incoming.description, cached.description),
      genre: _meaningfulOrNull(incoming.genre, cached.genre),
      seriesTitle: _meaningfulOrNull(incoming.seriesTitle, cached.seriesTitle),
      seriesNumber: incoming.seriesNumber ?? cached.seriesNumber,
      ratingValue: incoming.ratingValue ?? cached.ratingValue,
      ratingCount: incoming.ratingCount ?? cached.ratingCount,
      publishedYear: incoming.publishedYear ?? cached.publishedYear,
      sourceUrl: _meaningfulOrNull(incoming.sourceUrl, cached.sourceUrl),
      isFragment: incoming.isFragment || cached.isFragment,
      offlineOnly: incoming.offlineOnly || cached.offlineOnly,
      chapters: _mergeCachedChapters(cached.chapters, incoming.chapters),
    );
  }

  List<AudioPlaybackChapter> _mergeCachedChapters(
    List<AudioPlaybackChapter> cached,
    List<AudioPlaybackChapter> incoming,
  ) {
    if (incoming.isEmpty) {
      return cached;
    }

    final cachedByKey = <String, List<AudioPlaybackChapter>>{};
    final incomingCounts = <String, int>{};
    for (final chapter in cached) {
      cachedByKey.putIfAbsent(_chapterStem(chapter), () => []).add(chapter);
    }
    for (final chapter in incoming) {
      incomingCounts.update(
        _chapterStem(chapter),
        (n) => n + 1,
        ifAbsent: () => 1,
      );
    }
    return [
      for (final chapter in incoming)
        _mergeCachedChapter(
          incomingCounts[_chapterStem(chapter)] == 1 &&
                  cachedByKey[_chapterStem(chapter)]?.length == 1
              ? cachedByKey[_chapterStem(chapter)]!.single
              : null,
          chapter,
        ),
    ];
  }

  AudioPlaybackChapter _mergeCachedChapter(
    AudioPlaybackChapter? cached,
    AudioPlaybackChapter incoming,
  ) {
    if (cached == null) {
      return incoming;
    }

    final cachedSource = _originalSource(cached);
    final incomingSource = _originalSource(incoming);
    final mediaSource =
        _isLocalFileSource(incomingSource) &&
            cachedSource != null &&
            !_isLocalFileSource(cachedSource)
        ? cachedSource
        : incomingSource ?? cachedSource;
    return AudioPlaybackChapter(
      id: _meaningful(incoming.id, cached.id),
      index: incoming.index,
      title: _meaningful(incoming.title, cached.title),
      storageIdentity: incoming.storageIdentity,
      storageMediaReference:
          incoming.storageMediaReference ?? cached.storageMediaReference,
      duration: incoming.duration > Duration.zero
          ? incoming.duration
          : cached.duration,
      isDownloaded:
          incoming.isDownloaded ||
          cached.isDownloaded ||
          _isLocalFileSource(mediaSource),
      mediaSource: mediaSource,
    );
  }

  String? _preferCachedCover(String? cached, String? incoming) {
    if (_isLocalUriString(cached) && !_isLocalUriString(incoming)) {
      return cached;
    }
    return _meaningfulOrNull(incoming, cached);
  }

  bool _isLocalFileSource(AudioMediaSource? source) {
    return source?.type == AudioMediaSourceType.file;
  }

  AudioMediaSource? _originalSource(AudioPlaybackChapter chapter) {
    return chapter.originalMediaSource ?? chapter.mediaSource;
  }

  bool _isLocalUriString(String? value) {
    if (value == null || value.trim().isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(value);
    return uri?.scheme == 'file';
  }

  String _meaningful(String? preferred, String fallback) {
    final value = preferred?.trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  String? _meaningfulOrNull(String? preferred, String? fallback) {
    final value = preferred?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
    final fallbackValue = fallback?.trim();
    return fallbackValue == null || fallbackValue.isEmpty
        ? null
        : fallbackValue;
  }

  String _chapterStem(AudioPlaybackChapter chapter) {
    return 'track-${trackKeyFor(chapter)}';
  }

  String trackKeyFor(AudioPlaybackChapter chapter) {
    final identity = chapter.storageIdentity == null
        ? ['fallback', chapter.id, _chapterTitle(chapter.title)]
        : ['provider', chapter.storageIdentity];
    return sha256.convert(utf8.encode(jsonEncode(identity))).toString();
  }

  bool sameTrack(
    String sourceId,
    AudioPlaybackChapter a,
    AudioPlaybackChapter b,
  ) => _LegacyChapterBinding(
    index: a.index,
    id: a.id,
    title: _chapterTitle(a.title),
    storageIdentity: a.storageIdentity,
    mediaReference: _mediaReference(a),
  ).matches(b, sourceId);

  Future<AudioPlaybackChapter?> restoreLegacyTaskChapter(
    AudioPlaybackBook book,
    String chapterId,
  ) async {
    await _resolveDirectory(book.sourceId, book.versionId);
    final legacy = _legacyBindings(
      await AtomicJsonFile(metadataFileFor(book)).read(),
      book.sourceId,
      book.versionId,
    ).where((binding) => binding.id == chapterId);
    if (legacy.length != 1) return null;
    final chapters = book.chapters.where(
      (chapter) => legacy.single.matches(chapter, book.sourceId),
    );
    return chapters.length == 1 ? chapters.single : null;
  }

  bool _hasUniqueTrack(AudioPlaybackBook book, AudioPlaybackChapter chapter) {
    final key = _chapterStem(chapter);
    return book.chapters
            .where(
              (other) =>
                  _chapterStem(other) == key || other.index == chapter.index,
            )
            .take(2)
            .length <=
        1;
  }

  void _ensureUniqueTrack(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) {
    if (!_hasUniqueTrack(book, chapter)) {
      throw const FileSystemException('Ambiguous chapter identity');
    }
  }

  static String _numberedStem(int index) => index.toString().padLeft(3, '0');

  static String _chapterTitle(String title) =>
      SourceParserHelpers.normalizeWhitespace(title).toLowerCase();

  static bool mayHaveOrdinalTrackId(String sourceId, String chapterId) =>
      BuiltInSourcePolicies.byId(sourceId) != null &&
      RegExp(r'(?:^|-chapter-)\d+$').hasMatch(chapterId);

  static String? _mediaReference(AudioPlaybackChapter chapter) {
    final source = chapter.originalMediaSource ?? chapter.mediaSource;
    return chapter.storageMediaReference ??
        (source?.type == AudioMediaSourceType.url
            ? SourceParserHelpers.mediaReferenceIdentity(source!.uri.toString())
            : null);
  }

  String? _storedMediaReference(Map row, {bool includeLegacySource = true}) {
    final media = row['mediaSource'];
    return _string(row['storageMediaReference']) ??
        (includeLegacySource && media is Map && media['type'] == 'url'
            ? SourceParserHelpers.mediaReferenceIdentity(_string(media['uri']))
            : null);
  }

  List<_LegacyChapterBinding> _legacyBindings(
    Object? metadata,
    String sourceId,
    String versionId,
  ) {
    if (metadata is! Map ||
        metadata['sourceId'] != sourceId ||
        metadata['bookVersionId'] != versionId) {
      return const [];
    }
    final frozen = metadata.containsKey('legacyChapterBindings');
    final rows = metadata[frozen ? 'legacyChapterBindings' : 'chapters'];
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map &&
            row['index'] is int &&
            row['id'] is String &&
            row['title'] is String)
          _LegacyChapterBinding(
            index: row['index'] as int,
            id: row['id'] as String,
            title: _chapterTitle(row['title'] as String),
            storageIdentity: _string(row['storageIdentity']),
            mediaReference: _storedMediaReference(
              row,
              includeLegacySource: !frozen,
            ),
          ),
    ];
  }

  static const _finalExtensions = {
    '.mp3',
    '.m4a',
    '.m4b',
    '.mp4',
    '.aac',
    '.adts',
    '.ogg',
    '.oga',
    '.opus',
    '.flac',
    '.wav',
    '.wave',
    '.webm',
    '.mka',
    '.mkv',
    '.amr',
    '.aif',
    '.aiff',
    '.wma',
    '.asf',
    '.bin',
  };

  String _safeExtension(String extension) {
    final normalized = extension
        .replaceFirst('.', '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toLowerCase();
    return _finalExtensions.contains('.$normalized') ? normalized : 'bin';
  }

  String _safeSegment(String value) {
    final normalized = value
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return normalized.isEmpty ? 'unknown' : normalized;
  }

  Map<String, Object?>? _mediaSourceToJson(
    AudioMediaSource? source,
    String sourceId,
  ) {
    if (source == null) {
      return null;
    }

    final known = BuiltInSourcePolicies.byId(sourceId);
    if (known != null &&
        source.type == AudioMediaSourceType.url &&
        !_hasReusableRemoteSource(source.uri, source.headers)) {
      // Reload expiring/opaque sources through the selected chapter resolver.
      return null;
    }
    return {
      'type': source.type.name,
      'uri': source.uri.toString(),
      'headers': _cacheableHeaders(source.headers),
    };
  }

  AudioMediaSource? _mediaSourceFromJson(Object? value, String? sourceId) {
    if (value is! Map<String, Object?>) {
      return null;
    }

    final type = _string(value['type']);
    final rawUri = _string(value['uri']);
    if (type == null || rawUri == null || rawUri.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(rawUri);
    if (uri == null) {
      return null;
    }
    final known = sourceId == null
        ? null
        : BuiltInSourcePolicies.byId(sourceId);
    final policy = known == null
        ? null
        : MediaRequestPolicy.allowedHosts(known.mediaHosts);
    final rawHeaders = _stringMap(value['headers']);
    if (type == 'url' &&
        known != null &&
        !_hasReusableRemoteSource(uri, rawHeaders)) {
      return null;
    }
    final headers = _cacheableHeaders(rawHeaders);
    try {
      return switch (type) {
        'url' => AudioMediaSource.url(
          uri,
          headers: headers,
          requestPolicy: policy,
        ),
        'file' => AudioMediaSource.file(uri.toFilePath()),
        'asset' => AudioMediaSource.asset(uri.path),
        _ => null,
      };
    } on ArgumentError {
      return null;
    } on UnsupportedError {
      return null;
    }
  }

  String? _string(Object? value) {
    return value is String && value.isNotEmpty ? value : null;
  }

  int? _int(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  double? _double(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  String _firstString(Object? value) {
    if (value is List) {
      for (final item in value) {
        if (item is String && item.isNotEmpty) {
          return item;
        }
      }
    }
    return '';
  }

  Map<String, String> _stringMap(Object? value) {
    if (value is! Map) {
      return const {};
    }

    return {
      for (final entry in value.entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
    };
  }

  static const _cacheableHeaderNames = {
    'accept',
    'accept-language',
    'user-agent',
  };

  bool _hasReusableRemoteSource(Uri uri, Map<String, String> headers) =>
      !uri.hasQuery &&
      !uri.hasFragment &&
      !uri.authority.contains('@') &&
      headers.keys.every(
        (name) => _cacheableHeaderNames.contains(name.toLowerCase()),
      );

  Map<String, String> _cacheableHeaders(Map<String, String> headers) => {
    for (final header in headers.entries)
      if (_cacheableHeaderNames.contains(header.key.toLowerCase()))
        header.key: header.value,
  };
}

class _LegacyChapterBinding {
  const _LegacyChapterBinding({
    required this.index,
    required this.id,
    required this.title,
    required this.storageIdentity,
    required this.mediaReference,
  });

  final int index;
  final String id;
  final String title;
  final String? storageIdentity;
  final String? mediaReference;

  Map<String, Object?> get json => {
    'index': index,
    'id': id,
    'title': title,
    'storageIdentity': storageIdentity,
    'storageMediaReference': mediaReference,
  };

  bool matches(AudioPlaybackChapter chapter, String sourceId) {
    final currentIdentity = chapter.storageIdentity;
    if (storageIdentity != null && currentIdentity != null) {
      return storageIdentity == currentIdentity;
    }
    final sameKnownId =
        id == chapter.id &&
        !FileDownloadStorage.mayHaveOrdinalTrackId(sourceId, id);
    final sameTitle = title == FileDownloadStorage._chapterTitle(chapter.title);
    if (sameKnownId && sameTitle) return true;
    if (id != chapter.id &&
        (!FileDownloadStorage.mayHaveOrdinalTrackId(sourceId, id) ||
            !FileDownloadStorage.mayHaveOrdinalTrackId(sourceId, chapter.id))) {
      return false;
    }
    final currentRef = FileDownloadStorage._mediaReference(chapter);
    // Old built-in IDs could be generated from the ordinal. A fresh list
    // without the old media evidence must not inherit those files.
    return mediaReference != null && mediaReference == currentRef && sameTitle;
  }
}

class CardCacheStats {
  const CardCacheStats({required this.bytes, required this.bookCount});

  final int bytes;
  final int bookCount;
}
