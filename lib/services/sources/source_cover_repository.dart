import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/network/media_request_policy.dart';
import '../../sources/built_in_source_policies.dart';
import 'source_cover_client.dart';

/// Sole remote artwork path for view cards and permanent offline covers.
/// Its optional disk tier lives in a dedicated, disposable app cache folder;
/// user downloads and previously saved covers are never pruned here.
final class SourceCoverRepository {
  SourceCoverRepository({
    SourceCoverClient client = const SourceCoverClient(),
    Future<Directory> Function()? cacheDirectory,
    this.maxConcurrent = 4,
    this.maxQueued = 28,
  }) : _client = client,
       _cacheDirectory = cacheDirectory ?? getTemporaryDirectory,
       assert(maxConcurrent > 0 && maxQueued >= 0);

  static final shared = SourceCoverRepository();
  static const _maxBytes = 8 * 1024 * 1024;
  static const _maxMemory = 16 * 1024 * 1024;
  static const _maxDisk = 64 * 1024 * 1024;
  static const _maxPixels = 16 * 1024 * 1024;
  static const _fileLifetime = Duration(days: 7);
  static const _hitLifetime = Duration(minutes: 30);
  static const _missLifetime = Duration(seconds: 30);
  static final _cacheFile = RegExp(r'^[a-f0-9]{64}\.img$');

  final SourceCoverClient _client;
  final Future<Directory> Function() _cacheDirectory;
  final int maxConcurrent;
  final int maxQueued;
  final _queue = Queue<void Function()>();
  final _inFlight = <String, Future<Uint8List?>>{};
  final _memory = <String, _CoverCacheEntry>{};
  final _artwork = <String, Uri>{};
  Completer<void>? _capacityChanged;
  Future<Directory?>? _root;
  DateTime? _pruneStarted;
  int _active = 0;
  int _memoryBytes = 0;

  static MediaRequestPolicy? policyFor(String? sourceId, Uri uri) {
    if (sourceId == null) return null;
    final policy = BuiltInSourcePolicies.byId(sourceId);
    if (policy == null) return null;
    final allowed = MediaRequestPolicy.allowedHosts(
      policy.coverHosts,
      httpsOnly: true,
    );
    return allowed.allows(uri) ? allowed : null;
  }

  Future<Uint8List?> load(
    String? sourceId,
    Uri uri, {
    bool Function()? waitWhile,
  }) {
    final policy = policyFor(sourceId, uri);
    if (policy == null) return Future.value();
    final key = _key(sourceId!, uri);
    final existing = _memory.remove(key);
    if (existing != null) {
      if (DateTime.now().isBefore(existing.expiresAt)) {
        _memory[key] = existing;
        return Future.value(existing.bytes);
      }
      _memoryBytes -= existing.bytes?.length ?? 0;
    }
    if (_inFlight[key] case final pending?) return pending;
    if (_active >= maxConcurrent && _queue.length >= maxQueued) {
      if (waitWhile != null && waitWhile()) {
        // Visible cards wait on one shared signal rather than occupying the
        // bounded transfer queue. Disposed/recycled cards don't re-submit.
        return (_capacityChanged ??= Completer<void>()).future.then(
          (_) => waitWhile() ? load(sourceId, uri, waitWhile: waitWhile) : null,
        );
      }
      return Future.value();
    }

    final result = Completer<Uint8List?>();
    _inFlight[key] = result.future;
    void start() {
      _active++;
      unawaited(() async {
        Uint8List? bytes;
        try {
          bytes = await _load(key, uri, policy);
        } on Object {
          // Optional artwork must not fail the book or expose its URL.
        } finally {
          unawaited(_inFlight.remove(key));
          _remember(key, bytes);
          result.complete(bytes);
          _active--;
          if (_queue.isNotEmpty) _queue.removeFirst()();
          final capacity = _capacityChanged;
          _capacityChanged = null;
          capacity?.complete();
        }
      }());
    }

    if (_active < maxConcurrent) {
      start();
    } else {
      _queue.add(start);
    }
    return result.future;
  }

  Uri? cachedArtworkUri(String sourceId, Uri remote) {
    if (policyFor(sourceId, remote) == null) return null;
    return _artwork[_key(sourceId, remote)];
  }

  static String _key(String sourceId, Uri uri) =>
      sha256.convert(utf8.encode('$sourceId\n$uri')).toString();

  Future<Directory?> _openRoot() async {
    try {
      final cache = await _cacheDirectory();
      return Directory(
        p.join(cache.path, 'verified-covers-v1'),
      ).create(recursive: true);
    } on Object {
      return null;
    }
  }

  Future<Uint8List?> _load(
    String key,
    Uri uri,
    MediaRequestPolicy policy,
  ) async {
    final root = await (_root ??= _openRoot());
    final file = root == null ? null : File(p.join(root.path, '$key.img'));
    if (file != null) {
      final cached = await _read(file);
      if (cached != null) {
        _rememberArtwork(key, file.uri);
        return cached;
      }
    }

    final remote = await _client.load(uri, policy: policy);
    if (remote == null || !await _validImage(remote)) return null;
    if (root != null && file != null) {
      final partial = File('${file.path}.part');
      try {
        // In-flight requests are coalesced; file readers only see complete bytes.
        await partial.writeAsBytes(remote, flush: true);
        await partial.rename(file.path);
        _rememberArtwork(key, file.uri);
        _schedulePrune(root);
      } on FileSystemException {
        // A full/unavailable cache must not hide a successfully fetched cover.
        try {
          await partial.delete();
        } on FileSystemException {
          // Already gone or unavailable.
        }
      }
    }
    return remote;
  }

  Future<Uint8List?> _read(File file) async {
    try {
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file ||
          stat.size <= 0 ||
          stat.size > _maxBytes ||
          DateTime.now().difference(stat.modified) > _fileLifetime) {
        return null;
      }
      final bytes = await file.readAsBytes();
      return await _validImage(bytes) ? bytes : null;
    } on FileSystemException {
      return null;
    }
  }

  Future<bool> _validImage(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > _maxBytes) return false;
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return descriptor.width > 0 &&
          descriptor.height > 0 &&
          descriptor.width <= 8192 &&
          descriptor.height <= 8192 &&
          descriptor.width * descriptor.height <= _maxPixels;
    } on Object {
      return false;
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  void _remember(String key, Uint8List? bytes) {
    _memory[key] = _CoverCacheEntry(
      bytes,
      DateTime.now().add(bytes == null ? _missLifetime : _hitLifetime),
    );
    _memoryBytes += bytes?.length ?? 0;
    while (_memory.length > 160 || _memoryBytes > _maxMemory) {
      _memoryBytes -= _memory.remove(_memory.keys.first)?.bytes?.length ?? 0;
    }
  }

  void _rememberArtwork(String key, Uri uri) {
    _artwork.remove(key);
    _artwork[key] = uri;
    while (_artwork.length > 200) {
      _artwork.remove(_artwork.keys.first);
    }
  }

  void _schedulePrune(Directory root) {
    final now = DateTime.now();
    if (_pruneStarted case final started?
        when now.difference(started) < const Duration(minutes: 1)) {
      return;
    }
    _pruneStarted = now;
    unawaited(() async {
      try {
        final entries = <({File file, FileStat stat})>[];
        var total = 0;
        await for (final entity in root.list(followLinks: false)) {
          if (entity is! File ||
              !_cacheFile.hasMatch(p.basename(entity.path))) {
            continue;
          }
          final stat = await entity.stat();
          total += stat.size;
          entries.add((file: entity, stat: stat));
        }
        entries.sort(
          (left, right) => left.stat.modified.compareTo(right.stat.modified),
        );
        for (final entry in entries) {
          if (total <= _maxDisk &&
              now.difference(entry.stat.modified) <= _fileLifetime) {
            break;
          }
          try {
            await entry.file.delete();
            final name = p.basenameWithoutExtension(entry.file.path);
            _artwork.remove(name);
            total -= entry.stat.size;
          } on FileSystemException {
            // Cache files can disappear concurrently; try the next item.
          }
        }
      } on FileSystemException {
        // App cache is optional.
      }
    }());
  }
}

final class _CoverCacheEntry {
  const _CoverCacheEntry(this.bytes, this.expiresAt);
  final Uint8List? bytes;
  final DateTime expiresAt;
}
