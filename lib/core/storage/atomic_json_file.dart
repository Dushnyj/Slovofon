import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Serialized JSON storage with a last-good backup and atomic replacement.
/// Reads never remove damaged user data. A subsequent write retains a damaged
/// original next to the file so it remains available for recovery.
class AtomicJsonFile {
  AtomicJsonFile(this.file);

  final File file;
  static final _operations = <String, Future<void>>{};
  static var _temporarySequence = 0;

  File get _backup => File('${file.path}.bak');

  Future<Object?> read() => _serialized(() async {
    final primary = await _read(file);
    if (primary != null) {
      return primary.value;
    }
    return (await _read(_backup))?.value;
  });

  Future<void> write(Object? value) {
    // Encode before entering the queue so caller mutations cannot change a
    // pending write, and non-JSON values fail before touching existing files.
    final encoded = jsonEncode(value);
    return _serialized(() async {
      await file.parent.create(recursive: true);
      final current = await _read(file);
      if (current != null) {
        await _replace(_backup, current.raw);
      } else if (await file.exists()) {
        // Preserve the original; do not replace a last-good backup with it.
        await file.copy('${file.path}.corrupt.${_suffix()}');
      }
      await _replace(file, encoded);
    });
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final absolute = p.normalize(file.absolute.path);
    final key = Platform.isWindows ? absolute.toLowerCase() : absolute;
    final previous = _operations[key] ?? Future<void>.value();
    final result = previous.then((_) => operation());
    final settled = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _operations[key] = settled;
    unawaited(
      settled.then((_) {
        if (identical(_operations[key], settled)) {
          _operations.remove(key);
        }
      }),
    );
    return result;
  }

  static Future<({String raw, Object? value})?> _read(File source) async {
    try {
      final raw = await source.readAsString();
      return (raw: raw, value: jsonDecode(raw));
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  static String _suffix() =>
      '${DateTime.now().microsecondsSinceEpoch}.${_temporarySequence++}';

  static Future<void> _replace(File target, String encoded) async {
    final temporary = File('${target.path}.writing.${_suffix()}');
    try {
      await temporary.writeAsString(encoded, flush: true);
      // Never delete the destination first. If replacement is rejected (for
      // example by a locked file on Windows), keep the previous data intact.
      await temporary.rename(target.path);
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }
}
