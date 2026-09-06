import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/storage/atomic_json_file.dart';
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
    final finalFile = chapterFileFor(book, chapter, extension: extension);
    await finalFile.parent.create(recursive: true);
    // Replace atomically; deleting first loses a good download when rename
    // fails (for example a missing/locked part or a full disk).
    return partFile.rename(finalFile.path);
  }

  Future<void> resetPart(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) async {
    await _resolveDirectory(book.sourceId, book.versionId, destructive: true);
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
    final partFile = partFileFor(book, chapter);
    if (await partFile.exists()) {
      await partFile.delete();
    }

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
    final existing = await readMetadataForIds(book.sourceId, book.versionId);
    final mergedBook = existing == null
        ? book
        : _mergeCachedBook(existing, book);
    final metadataFile = metadataFileFor(book);
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
      'chapters': [
        for (final chapter in mergedBook.chapters)
          {
            'id': chapter.id,
            'index': chapter.index,
            'title': chapter.title,
            'durationMs': chapter.duration.inMilliseconds,
            'isDownloaded': chapter.isDownloaded,
            // Persist the original source, not the transient offline overlay.
            'mediaSource': _mediaSourceToJson(_originalSource(chapter)),
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

  Future<List<AudioPlaybackBook>> readAllMetadata() async {
    final books = <String, AudioPlaybackBook>{};
    await for (final entity in _bookDirectories()) {
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
    if (decoded is! Map<String, Object?>) {
      return null;
    }

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
            isDownloaded: rawChapter['isDownloaded'] == true,
            mediaSource: _mediaSourceFromJson(rawChapter['mediaSource']),
          ),
        );
      }
    }

    final bookId = _string(decoded['bookId']);
    final title = _string(decoded['title']);
    final versionId = _string(decoded['bookVersionId']) ?? fallbackVersionId;
    final sourceId = _string(decoded['sourceId']) ?? fallbackSourceId;
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
    return (await completedChapterFiles(book))[chapter.index];
  }

  /// One asynchronous directory scan per book, never one scan per chapter.
  /// No persistent cache: external file removal must be visible on next play.
  Future<Map<int, File>> completedChapterFiles(AudioPlaybackBook book) async {
    await _resolveDirectory(book.sourceId, book.versionId, destructive: false);
    final directory = chaptersDirectoryFor(book);
    final files = <int, File>{};
    if (!await directory.exists()) {
      return files;
    }
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || p.extension(entity.path) == '.part') {
        continue;
      }
      final stem = int.tryParse(p.basenameWithoutExtension(entity.path));
      if (stem == null) {
        continue;
      }
      final previous = files[stem];
      if (previous == null || entity.path.compareTo(previous.path) < 0) {
        files[stem] = entity;
      }
    }
    return files;
  }

  Future<AudioPlaybackBook> offlinePlaybackBook(AudioPlaybackBook book) async {
    final cached = await readMetadataForIds(book.sourceId, book.versionId);
    final baseBook = cached == null ? book : _mergeCachedBook(cached, book);
    final cachedCoverFile = coverFileFor(baseBook);
    final coverUrl = await cachedCoverFile.exists()
        ? cachedCoverFile.uri.toString()
        : baseBook.coverUrl;
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
          isDownloaded: localFile != null,
          mediaSource: localFile == null
              ? originalSource
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

    final cachedById = {for (final chapter in cached) chapter.id: chapter};
    final cachedByIndex = {
      for (final chapter in cached) chapter.index: chapter,
    };
    return [
      for (final chapter in incoming)
        _mergeCachedChapter(
          cachedById[chapter.id] ?? cachedByIndex[chapter.index],
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
    return chapter.index.toString().padLeft(3, '0');
  }

  String _safeExtension(String extension) {
    final normalized = extension
        .replaceFirst('.', '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toLowerCase();
    return normalized.isEmpty ? 'bin' : normalized;
  }

  String _safeSegment(String value) {
    final normalized = value
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return normalized.isEmpty ? 'unknown' : normalized;
  }

  Map<String, Object?>? _mediaSourceToJson(AudioMediaSource? source) {
    if (source == null) {
      return null;
    }

    return {
      'type': source.type.name,
      'uri': source.uri.toString(),
      'headers': source.headers,
    };
  }

  AudioMediaSource? _mediaSourceFromJson(Object? value) {
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
    final headers = _stringMap(value['headers']);
    try {
      return switch (type) {
        'url' => AudioMediaSource.url(uri, headers: headers),
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
}

class CardCacheStats {
  const CardCacheStats({required this.bytes, required this.bookCount});

  final int bytes;
  final int bookCount;
}
