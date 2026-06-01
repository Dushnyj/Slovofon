import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'update_manifest.dart';
import 'update_manifest_keys.dart';
import 'update_manifest_signature.dart';

class UpdateClient {
  const UpdateClient({HttpClient? httpClient}) : _httpClient = httpClient;

  final HttpClient? _httpClient;

  Future<UpdateManifest> fetchManifest(Uri uri) async {
    final ownsClient = _httpClient == null;
    final client = _httpClient ?? HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw UpdateClientException(
          'Manifest request failed with HTTP ${response.statusCode}',
        );
      }
      final raw = jsonDecode(body);
      if (raw is! Map) {
        throw const UpdateClientException('Manifest is not a JSON object');
      }
      final manifestJson = Map<String, Object?>.from(raw);
      final signatureIsValid = await verifyUpdateManifestSignature(
        manifestJson,
        publicKeys: updateManifestPublicKeys,
      );
      if (!signatureIsValid) {
        throw const UpdateClientException(
          'Update manifest signature is invalid',
        );
      }
      return UpdateManifest.fromJson(manifestJson);
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }

  Future<DownloadedUpdate> downloadAsset(
    UpdateAsset asset, {
    void Function(int downloadedBytes, int? totalBytes)? onProgress,
  }) async {
    if (!asset.hasValidChecksum) {
      throw const UpdateClientException('Update asset has no valid sha256');
    }
    if (!asset.url.isScheme('https')) {
      throw const UpdateClientException('Update asset URL must use HTTPS');
    }

    final directory = await getTemporaryDirectory();
    final updatesDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}slovofon-updates',
    );
    await updatesDirectory.create(recursive: true);
    final target = File(
      '${updatesDirectory.path}${Platform.pathSeparator}${asset.fileName}',
    );
    final part = File('${target.path}.part');

    final ownsClient = _httpClient == null;
    final client = _httpClient ?? HttpClient();
    try {
      final request = await client.getUrl(asset.url);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw UpdateClientException(
          'Update asset request failed with HTTP ${response.statusCode}',
        );
      }

      final sink = part.openWrite();
      var downloadedBytes = 0;
      final totalBytes = response.contentLength > 0
          ? response.contentLength
          : null;

      try {
        await for (final chunk in response) {
          downloadedBytes += chunk.length;
          sink.add(chunk);
          onProgress?.call(downloadedBytes, totalBytes);
        }
        await sink.close();
      } on Object {
        await sink.close();
        if (await part.exists()) {
          await part.delete();
        }
        rethrow;
      }

      final actualSha256 = (await part.openRead().transform(sha256).single)
          .toString();
      if (actualSha256 != asset.sha256) {
        await part.delete();
        throw UpdateClientException(
          'Update sha256 mismatch: expected ${asset.sha256}, got $actualSha256',
        );
      }

      if (await target.exists()) {
        await target.delete();
      }
      await part.rename(target.path);
      return DownloadedUpdate(file: target, asset: asset);
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
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
