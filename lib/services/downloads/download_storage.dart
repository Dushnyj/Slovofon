import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../audio/audio_state.dart';

class FileDownloadStorage {
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
    return Directory(
      p.join(
        _rootDirectory.path,
        _safeSegment('${book.sourceId}_${book.versionId}'),
      ),
    );
  }

  Directory chaptersDirectoryFor(AudioPlaybackBook book) {
    return Directory(p.join(bookDirectoryFor(book).path, 'chapters'));
  }

  File metadataFileFor(AudioPlaybackBook book) {
    return File(p.join(bookDirectoryFor(book).path, 'metadata.json'));
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

  Future<void> writeMetadata(AudioPlaybackBook book) async {
    final metadataFile = metadataFileFor(book);
    await metadataFile.parent.create(recursive: true);
    final metadata = <String, Object?>{
      'bookId': book.id,
      'bookVersionId': book.versionId,
      'sourceId': book.sourceId,
      'title': book.title,
      'authors': [book.author],
      'narrators': [book.narrator],
      'sourceName': book.sourceName,
      'chapters': [
        for (final chapter in book.chapters)
          {
            'id': chapter.id,
            'index': chapter.index,
            'title': chapter.title,
            'durationMs': chapter.duration.inMilliseconds,
          },
      ],
    };
    await metadataFile.writeAsString(jsonEncode(metadata), flush: true);
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
      title: book.title,
      author: book.author,
      narrator: book.narrator,
      sourceName: book.sourceName,
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
}
