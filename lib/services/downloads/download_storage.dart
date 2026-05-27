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
    final metadataFile = metadataFileFor(book);
    await metadataFile.parent.create(recursive: true);
    final metadata = <String, Object?>{
      'bookId': book.id,
      'bookVersionId': book.versionId,
      'sourceId': book.sourceId,
      'sourceBookId': book.sourceBookId,
      'title': book.title,
      'authors': [book.author],
      'narrators': [book.narrator],
      'sourceName': book.sourceName,
      'coverUrl': book.coverUrl,
      'description': book.description,
      'genre': book.genre,
      'publishedYear': book.publishedYear,
      'sourceUrl': book.sourceUrl,
      'chapters': [
        for (final chapter in book.chapters)
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

  Future<AudioPlaybackBook?> readMetadataForIds(
    String sourceId,
    String versionId,
  ) async {
    final metadataFile = metadataFileForIds(sourceId, versionId);
    if (!metadataFile.existsSync()) {
      return null;
    }

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
    if (bookId == null || title == null) {
      return null;
    }

    return AudioPlaybackBook(
      id: bookId,
      versionId: _string(decoded['bookVersionId']) ?? versionId,
      sourceId: _string(decoded['sourceId']) ?? sourceId,
      sourceBookId: _string(decoded['sourceBookId']),
      title: title,
      author: _firstString(decoded['authors']),
      narrator: _firstString(decoded['narrators']),
      sourceName: _string(decoded['sourceName']) ?? sourceId,
      coverUrl: _string(decoded['coverUrl']),
      description: _string(decoded['description']),
      genre: _string(decoded['genre']),
      publishedYear: _int(decoded['publishedYear']),
      sourceUrl: _string(decoded['sourceUrl']),
      chapters: List.unmodifiable(chapters),
    );
  }

  Future<File?> completedChapterFile(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) async {
    final directory = chaptersDirectoryFor(book);
    if (!await directory.exists()) {
      return null;
    }

    final stem = _chapterStem(chapter);
    final matches = directory.listSync().whereType<File>().where((file) {
      final basename = p.basename(file.path);
      return basename.startsWith('$stem.') && !basename.endsWith('.part');
    }).toList()..sort((a, b) => a.path.compareTo(b.path));

    return matches.isEmpty ? null : matches.first;
  }

  Future<AudioPlaybackBook> offlinePlaybackBook(AudioPlaybackBook book) async {
    final chapters = <AudioPlaybackChapter>[];
    for (final chapter in book.chapters) {
      final localFile = await completedChapterFile(book, chapter);
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
      id: book.id,
      versionId: book.versionId,
      sourceId: book.sourceId,
      sourceBookId: book.sourceBookId,
      title: book.title,
      author: book.author,
      narrator: book.narrator,
      sourceName: book.sourceName,
      coverUrl: book.coverUrl,
      description: book.description,
      genre: book.genre,
      publishedYear: book.publishedYear,
      sourceUrl: book.sourceUrl,
      chapters: chapters,
    );
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
