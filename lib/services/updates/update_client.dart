import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'github_release.dart';
import 'update_manifest.dart';

class UpdateClient {
  const UpdateClient({
    HttpClient? httpClient,
    HttpClient Function()? httpClientFactory,
    Future<Directory> Function()? temporaryDirectoryProvider,
    this.requestTimeout = const Duration(seconds: 20),
    this.idleTimeout = const Duration(seconds: 30),
    this.metadataTimeout = const Duration(minutes: 1),
    this.downloadTimeout = const Duration(minutes: 30),
    this.maxMetadataBytes = 2 * 1024 * 1024,
    this.maxChecksumBytes = 1024 * 1024,
    this.maxAssetBytes = 2 * 1024 * 1024 * 1024,
  }) : _httpClient = httpClient,
       _httpClientFactory = httpClientFactory,
       _temporaryDirectoryProvider = temporaryDirectoryProvider;

  final HttpClient? _httpClient;
  final HttpClient Function()? _httpClientFactory;
  final Future<Directory> Function()? _temporaryDirectoryProvider;
  final Duration requestTimeout;
  final Duration idleTimeout;
  final Duration metadataTimeout;
  final Duration downloadTimeout;
  final int maxMetadataBytes;
  final int maxChecksumBytes;
  final int maxAssetBytes;

  /// Retains the public manifest model; wire format is the public GitHub API.
  Future<UpdateManifest> fetchManifest(Uri uri) async {
    if (uri.toString() != GitHubRelease.latestApiUrl) {
      throw const UpdateClientException(
        'Update metadata endpoint is not allowed',
      );
    }
    try {
      late final Uint8List bytes;
      try {
        bytes = await _readBytes(uri, maxMetadataBytes);
      } on _UpdateHttpException catch (error) {
        if (error.statusCode != HttpStatus.notFound) rethrow;
        return const UpdateManifest(
          schema: 1,
          app: 'slovofon',
          channel: 'stable',
          status: 'no_release',
          version: null,
          build: null,
          publishedAt: null,
          mandatory: false,
          releaseUrl: null,
          releaseNotes: null,
          assets: [],
        );
      }
      final raw = jsonDecode(utf8.decode(bytes));
      if (raw is! Map) throw const FormatException('Release is not an object');
      final release = GitHubRelease.fromJson(Map<String, Object?>.from(raw));
      if (release.assets.any((asset) => asset.size > maxAssetBytes)) {
        throw const UpdateClientException(
          'Update asset exceeds the size limit',
        );
      }
      Map<String, String> checksums = const {};
      // Fail closed for the whole supported release set, including other
      // platforms/distributions. Selection must never hide a missing hash.
      if (release.needsChecksums) {
        final checksumAsset = release.checksumAsset;
        if (checksumAsset == null) {
          throw const UpdateClientException('Update asset has no known sha256');
        }
        if (checksumAsset.size > maxChecksumBytes) {
          throw const UpdateClientException(
            'Release checksums exceed the size limit',
          );
        }
        final checksumBytes = await _readBytes(
          checksumAsset.url,
          maxChecksumBytes,
          expectedSize: checksumAsset.size,
        );
        if (checksumAsset.digest != null &&
            sha256.convert(checksumBytes).toString() != checksumAsset.digest) {
          throw const UpdateClientException(
            'Release checksums sha256 mismatch',
          );
        }
        checksums = GitHubRelease.parseChecksums(utf8.decode(checksumBytes));
      }
      return release.toManifest(checksums: checksums);
    } on FormatException {
      throw const UpdateClientException(
        'GitHub release metadata or checksums are invalid',
      );
    }
  }

  Future<DownloadedUpdate> downloadAsset(
    UpdateAsset asset, {
    void Function(int downloadedBytes, int? totalBytes)? onProgress,
  }) async {
    // Public constructor: validate even when callers bypass fetchManifest.
    final identity = GitHubRelease.installerIdentity(asset.fileName);
    if (identity == null ||
        identity.platform != asset.platform ||
        identity.arch != asset.arch ||
        identity.kind != asset.kind ||
        !asset.hasValidChecksum ||
        asset.size <= 0 ||
        asset.size > maxAssetBytes) {
      throw const UpdateClientException(
        'Update asset identity, sha256 or size is invalid',
      );
    }
    try {
      GitHubRelease.validateAssetUrl(
        asset.url,
        name: asset.fileName,
        version: identity.version,
      );
    } on FormatException {
      throw const UpdateClientException('Update asset URL is not allowed');
    }
    final directory =
        await (_temporaryDirectoryProvider ?? getTemporaryDirectory)();
    // Android FileProvider exposes exactly this cache subtree.
    final updatesDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}slovofon-updates',
    );
    await updatesDirectory.create(recursive: true);
    final attemptDirectory = await updatesDirectory.createTemp('update-');
    final target = File(
      '${attemptDirectory.path}${Platform.pathSeparator}${asset.fileName}',
    );
    final part = File('${target.path}.part');
    try {
      await _withResponse<void>(asset.url, downloadTimeout, (
        response,
        budget,
      ) async {
        _validateLength(response, maxAssetBytes, asset.size);
        final file = await part.open(mode: FileMode.write);
        var downloaded = 0;
        try {
          onProgress?.call(0, asset.size);
          await for (final chunk in _chunks(response, budget)) {
            downloaded += chunk.length;
            if (downloaded > asset.size || downloaded > maxAssetBytes) {
              throw const UpdateClientException(
                'Update asset exceeds the expected size',
              );
            }
            // Disk backpressure instead of unbounded IOSink.add buffering.
            await file.writeFrom(chunk);
            onProgress?.call(downloaded, asset.size);
          }
          if (downloaded != asset.size) {
            throw const UpdateClientException('Update asset size mismatch');
          }
          await file.flush();
        } finally {
          await file.close();
        }
      });
      final actualSha256 = (await part.openRead().transform(sha256).single)
          .toString();
      if (actualSha256 != asset.sha256 || await part.length() != asset.size) {
        throw const UpdateClientException('Update sha256 or size mismatch');
      }
      // Unique attempt: never replace another download's ready installer.
      await part.rename(target.path);
      return DownloadedUpdate(file: target, asset: asset);
    } on Object {
      try {
        if (await part.exists()) await part.delete();
        await attemptDirectory.delete(); // Own empty directory, non-recursive.
      } on FileSystemException {
        // Preserve the original error without broadening cleanup scope.
      }
      rethrow;
    }
  }

  Future<Uint8List> _readBytes(Uri uri, int maximum, {int? expectedSize}) {
    return _withResponse(uri, metadataTimeout, (response, budget) async {
      _validateLength(response, maximum, expectedSize);
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in _chunks(response, budget)) {
        if (bytes.length + chunk.length > maximum ||
            (expectedSize != null &&
                bytes.length + chunk.length > expectedSize)) {
          throw const UpdateClientException(
            'Update response exceeds the size limit',
          );
        }
        bytes.add(chunk);
      }
      if (expectedSize != null && bytes.length != expectedSize) {
        throw const UpdateClientException('Update response size mismatch');
      }
      return bytes.takeBytes();
    });
  }

  void _validateLength(
    HttpClientResponse response,
    int maximum,
    int? expected,
  ) {
    final length = response.contentLength;
    if (maximum <= 0 ||
        length > maximum ||
        (expected != null &&
            response.compressionState !=
                HttpClientResponseCompressionState.decompressed &&
            length >= 0 &&
            length != expected)) {
      throw const UpdateClientException('Update response size is invalid');
    }
  }

  Future<T> _withResponse<T>(
    Uri initial,
    Duration totalTimeout,
    Future<T> Function(HttpClientResponse response, _UpdateRequestBudget budget)
    consume,
  ) async {
    _validateRequestUri(initial, initial);
    final client = _httpClient ?? _httpClientFactory?.call() ?? HttpClient();
    final ownsClient = _httpClient == null;
    final budget = _UpdateRequestBudget(totalTimeout);
    HttpClientRequest? currentRequest;
    try {
      var uri = initial;
      for (var redirects = 0; ; redirects++) {
        _validateRequestUri(uri, initial);
        final pending = client.getUrl(uri);
        try {
          currentRequest = await pending.timeout(
            budget.remaining(requestTimeout),
          );
        } on TimeoutException {
          // Late opens must also abort, including with caller-owned clients.
          unawaited(
            pending.then<void>(
              (request) => request.abort(),
              onError: (Object _) {},
            ),
          );
          rethrow;
        }
        final request = currentRequest;
        request.followRedirects = false;
        request.headers.set(HttpHeaders.userAgentHeader, 'Slovofon-Updater');
        request.headers.set(
          HttpHeaders.acceptHeader,
          initial.toString() == GitHubRelease.latestApiUrl
              ? 'application/vnd.github+json'
              : 'application/octet-stream',
        );
        if (initial.toString() == GitHubRelease.latestApiUrl) {
          request.headers.set('X-GitHub-Api-Version', '2022-11-28');
        }
        final response = await request.close().timeout(
          budget.remaining(requestTimeout),
        );
        if (const {301, 302, 303, 307, 308}.contains(response.statusCode)) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          final next = location == null ? null : uri.resolve(location);
          await response
              .listen(null)
              .cancel(); // Do not drain unbounded bodies.
          if (next == null || redirects >= 5) {
            throw const UpdateClientException(
              'Update redirect limit or location is invalid',
            );
          }
          _validateRequestUri(next, initial);
          uri = next;
          continue;
        }
        if (response.statusCode != HttpStatus.ok) {
          await response.listen(null).cancel();
          throw _UpdateHttpException(response.statusCode);
        }
        return await consume(response, budget);
      }
    } on Object {
      currentRequest?.abort();
      rethrow;
    } finally {
      if (ownsClient) client.close(force: true);
    }
  }

  Stream<List<int>> _chunks(
    HttpClientResponse response,
    _UpdateRequestBudget budget,
  ) async* {
    final iterator = StreamIterator<List<int>>(response);
    try {
      while (await iterator.moveNext().timeout(budget.remaining(idleTimeout))) {
        yield iterator.current;
      }
    } finally {
      // Cancel actual subscriptions, not just a timed-out Future.
      await iterator.cancel();
    }
  }

  static void _validateRequestUri(Uri uri, Uri initial) {
    final metadata = initial.toString() == GitHubRelease.latestApiUrl;
    final allowedHost = const {
      'release-assets.githubusercontent.com',
      'objects.githubusercontent.com',
      'github-releases.githubusercontent.com',
    }.contains(uri.host);
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443 ||
        uri.hasFragment ||
        (metadata ? uri != initial : (uri != initial && !allowedHost))) {
      throw const UpdateClientException(
        'Update request or redirect URL is not allowed',
      );
    }
  }
}

class _UpdateRequestBudget {
  _UpdateRequestBudget(this.total) : elapsed = Stopwatch()..start();
  final Duration total;
  final Stopwatch elapsed;

  Duration remaining(Duration perOperation) {
    final left = total - elapsed.elapsed;
    if (left <= Duration.zero || perOperation <= Duration.zero) {
      throw TimeoutException('Update request time limit exceeded');
    }
    return left < perOperation ? left : perOperation;
  }
}

class DownloadedUpdate {
  const DownloadedUpdate({required this.file, required this.asset});
  final File file;
  final UpdateAsset asset;
}

class UpdateClientException implements Exception {
  const UpdateClientException(this.message);
  final String message;
  @override
  String toString() => message;
}

class _UpdateHttpException extends UpdateClientException {
  _UpdateHttpException(this.statusCode)
    : super('Update request failed with HTTP $statusCode');

  final int statusCode;
}
