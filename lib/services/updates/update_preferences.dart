import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract interface class UpdatePreferences {
  Future<String?> readSkippedVersion();

  Future<void> saveSkippedVersion(String versionKey);
}

class MemoryUpdatePreferences implements UpdatePreferences {
  String? _skippedVersion;

  @override
  Future<String?> readSkippedVersion() async => _skippedVersion;

  @override
  Future<void> saveSkippedVersion(String versionKey) async {
    _validateVersionKey(versionKey);
    _skippedVersion = versionKey;
  }
}

/// One noncritical update preference, separate from the database and library.
/// Reading missing/damaged data never creates, resets or removes any file.
class FileUpdatePreferences implements UpdatePreferences {
  FileUpdatePreferences({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;

  static const fileName = 'update-preferences.json';
  static const maxFileBytes = 4096;
  static var _temporarySequence = 0;

  // This tiny setting has one logical file in production. Serialize the entire
  // operation, including async path lookup, so distinct instances and delayed
  // directory providers cannot reorder concurrently requested reads/writes.
  static Future<void> _pending = Future<void>.value();

  static Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<File> _file() async =>
      File(p.join((await _directoryProvider()).path, fileName));

  @override
  Future<String?> readSkippedVersion() => _serialized(() async {
    final file = await _file();
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type != FileSystemEntityType.file) return null;

    RandomAccessFile? handle;
    try {
      handle = await file.open();
      // Limit the actual read, not only a racy stat/length check. Oversized
      // preferences and invalid UTF-8/JSON are ignored without being rewritten.
      final bytes = await handle.read(maxFileBytes + 1);
      if (bytes.length > maxFileBytes) return null;
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map || decoded['schema'] != 1) return null;
      final key = decoded['skippedVersion'];
      return key is String && _isValidVersionKey(key) ? key : null;
    } on FormatException {
      return null;
    } on FileSystemException catch (error) {
      // A file may disappear between the type check and open. Other I/O errors
      // remain visible to callers; do not interpret permission denial as reset.
      if (error.osError?.errorCode == 2 ||
          (Platform.isWindows && error.osError?.errorCode == 3)) {
        return null;
      }
      rethrow;
    } finally {
      await handle?.close();
    }
  });

  @override
  Future<void> saveSkippedVersion(String versionKey) async {
    // Fail before touching the directory or queue for malformed input.
    _validateVersionKey(versionKey);
    final encoded = jsonEncode({'schema': 1, 'skippedVersion': versionKey});
    await _serialized(() async {
      final file = await _file();
      await file.parent.create(recursive: true);
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.file) {
        throw const FileSystemException(
          'Update preferences is not a regular file',
        );
      }
      final temporary = File(
        '${file.path}.writing.$pid.'
        '${DateTime.now().microsecondsSinceEpoch}.${_temporarySequence++}',
      );
      var created = false;
      try {
        await temporary.create(exclusive: true);
        created = true;
        await temporary.writeAsString(encoded, flush: true);
        // Never delete the destination first. A failed replacement leaves the
        // last saved preference untouched and propagates the error to the UI.
        await temporary.rename(file.path);
      } finally {
        if (created) {
          try {
            if (await temporary.exists()) await temporary.delete();
          } on FileSystemException {
            // Keep the original write error. Only our exact temporary file is
            // eligible for cleanup, never another preference or user directory.
          }
        }
      }
    });
  }
}

final _versionKeyPattern = RegExp(
  r'^(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\+((0|[1-9][0-9]{0,18})?)$',
);

bool _isValidVersionKey(String value) {
  if (value.length > 64) return false;
  final match = _versionKeyPattern.firstMatch(value);
  if (match == null || match.end != value.length) return false;
  final build = value.substring(value.indexOf('+') + 1);
  return build.isEmpty || int.tryParse(build) != null;
}

void _validateVersionKey(String value) {
  if (!_isValidVersionKey(value)) {
    throw ArgumentError.value(
      value,
      'versionKey',
      'Expected MAJOR.MINOR.PATCH+BUILD',
    );
  }
}
