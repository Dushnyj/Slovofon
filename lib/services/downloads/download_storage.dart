import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../audio/audio_persistence.dart';
import '../audio/audio_state.dart';

class FileDownloadStorage implements PlaybackBookMetadataStore {
  FileDownloadStorage({required Directory rootDirectory})
    : _rootDirectory = rootDirectory;

  final Directory _rootDirectory;

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
    return Directory(
      p.join(_rootDirectory.path, _safeSegment('${sourceId}_$versionId')),
    );
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
    final partFile = partFileFor(book, chapter);
    await partFile.parent.create(recursive: true);
    return partFile.openWrite(mode: append ? FileMode.append : FileMode.write);
  }

  Future<File> finalizeChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter, {
    required String extension,
  }) async {
    final partFile = partFileFor(book, chapter);
    final finalFile = chapterFileFor(book, chapter, extension: extension);
    await finalFile.parent.create(recursive: true);
    if (await finalFile.exists()) {
      await finalFile.delete();
    }
    return partFile.rename(finalFile.path);
  }

  Future<void> resetPart(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) async {
    final partFile = partFileFor(book, chapter);
    if (await partFile.exists()) {
      await partFile.delete();
    }
  }

  Future<void> deleteChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) async {
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
    final directory = bookDirectoryFor(book);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<CardCacheStats> cardCacheStats() async {
    var bytes = 0;
    var bookCount = 0;
    for (final directory in _bookDirectories()) {
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

  Future<CardCacheStats> clearCardCache() async {
    var bytes = 0;
    var bookCount = 0;
    for (final directory in _bookDirectories()) {
      if (_hasChapterFiles(directory)) {
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
      _deleteIfEmpty(directory);
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

  Future<void> writeMetadata(AudioPlaybackBook book) async {
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
      'chapters': [
        for (final chapter in mergedBook.chapters)
          {
            'id': chapter.id,
            'index': chapter.index,
            'title': chapter.title,
            'durationMs': chapter.duration.inMilliseconds,
            'isDownloaded': chapter.isDownloaded,
            'mediaSource': _mediaSourceToJson(chapter.mediaSource),
          },
      ],
    };
    await metadataFile.writeAsString(jsonEncode(metadata), flush: true);
  }

  Future<String> writeCoverBytes(
    AudioPlaybackBook book,
    List<int> bytes,
  ) async {
    final coverFile = coverFileFor(book);
    await coverFile.parent.create(recursive: true);
    await coverFile.writeAsBytes(bytes, flush: true);
    return coverFile.uri.toString();
  }

  Future<AudioPlaybackBook?> readMetadataForIds(
    String sourceId,
    String versionId,
  ) async {
    final metadataFile = metadataFileForIds(sourceId, versionId);
    if (!metadataFile.existsSync()) {
      return null;
    }

    return _readMetadataFile(
      metadataFile,
      fallbackSourceId: sourceId,
      fallbackVersionId: versionId,
    );
  }

  Future<List<AudioPlaybackBook>> readAllMetadata() async {
    if (!_rootDirectory.existsSync()) {
      return const [];
    }

    final books = <AudioPlaybackBook>[];
    for (final entity in _rootDirectory.listSync(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }
      final metadataFile = File(p.join(entity.path, 'metadata.json'));
      if (!metadataFile.existsSync()) {
        continue;
      }
      final book = _readMetadataFile(metadataFile);
      if (book != null) {
        books.add(book);
      }
    }
    return books;
  }

  Iterable<Directory> _bookDirectories() {
    if (!_rootDirectory.existsSync()) {
      return const [];
    }
    return _rootDirectory.listSync(followLinks: false).whereType<Directory>();
  }

  List<File> _cardCacheFiles(Directory bookDirectory) {
    return [
      File(p.join(bookDirectory.path, 'metadata.json')),
      File(p.join(bookDirectory.path, 'cover.img')),
    ];
  }

  bool _hasChapterFiles(Directory bookDirectory) {
    final chaptersDirectory = Directory(p.join(bookDirectory.path, 'chapters'));
    if (!chaptersDirectory.existsSync()) {
      return false;
    }
    return chaptersDirectory
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .isNotEmpty;
  }

  void _deleteIfEmpty(Directory directory) {
    if (!directory.existsSync()) {
      return;
    }
    final children = directory.listSync(followLinks: false);
    for (final child in children.whereType<Directory>()) {
      _deleteIfEmpty(child);
    }
    if (directory.listSync(followLinks: false).isEmpty) {
      directory.deleteSync();
    }
  }

  AudioPlaybackBook? _readMetadataFile(
    File metadataFile, {
    String? fallbackSourceId,
    String? fallbackVersionId,
  }) {
    final decoded = jsonDecode(metadataFile.readAsStringSync());
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
      chapters: List.unmodifiable(chapters),
    );
  }

  Future<File?> completedChapterFile(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) {
    final directory = chaptersDirectoryFor(book);
    if (!directory.existsSync()) {
      return Future<File?>.value();
    }

    final stem = _chapterStem(chapter);
    final matches = directory.listSync().whereType<File>().where((file) {
      final basename = p.basename(file.path);
      return basename.startsWith('$stem.') && !basename.endsWith('.part');
    }).toList()..sort((a, b) => a.path.compareTo(b.path));

    return Future<File?>.value(matches.isEmpty ? null : matches.first);
  }

  Future<AudioPlaybackBook> offlinePlaybackBook(AudioPlaybackBook book) async {
    final cached = await readMetadataForIds(book.sourceId, book.versionId);
    final baseBook = cached == null ? book : _mergeCachedBook(cached, book);
    final cachedCoverFile = coverFileFor(baseBook);
    final coverUrl = cachedCoverFile.existsSync()
        ? cachedCoverFile.uri.toString()
        : baseBook.coverUrl;
    final chapters = <AudioPlaybackChapter>[];
    for (final chapter in baseBook.chapters) {
      final localFile = await completedChapterFile(baseBook, chapter);
      chapters.add(
        AudioPlaybackChapter(
          id: chapter.id,
          index: chapter.index,
          title: chapter.title,
          duration: chapter.duration,
          isDownloaded: localFile != null,
          mediaSource: localFile == null
              ? chapter.mediaSource
              : AudioMediaSource.file(localFile.path),
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

    final cachedSource = cached.mediaSource;
    final incomingSource = incoming.mediaSource;
    final mediaSource =
        _isLocalFileSource(cachedSource) && !_isLocalFileSource(incomingSource)
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

    final uri = Uri.parse(rawUri);
    final headers = _stringMap(value['headers']);
    return switch (type) {
      'url' => AudioMediaSource.url(uri, headers: headers),
      'file' => AudioMediaSource.file(uri.toFilePath()),
      'asset' => AudioMediaSource.asset(uri.path),
      _ => null,
    };
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
