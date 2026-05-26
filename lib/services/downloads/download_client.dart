import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../audio/audio_state.dart';

abstract interface class DownloadClient {
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  });
}

class DownloadClientResponse {
  const DownloadClientResponse({
    required this.bytes,
    required this.totalBytes,
    required this.contentLength,
    required this.supportsResume,
    required this.shouldAppend,
    required this.fileExtension,
  });

  final Stream<List<int>> bytes;
  final int? totalBytes;
  final int? contentLength;
  final bool supportsResume;
  final bool shouldAppend;
  final String fileExtension;
}

class DownloadCancellationToken {
  bool _isCanceled = false;

  bool get isCanceled => _isCanceled;

  void cancel() {
    _isCanceled = true;
  }
}

class DownloadClientException implements Exception {
  const DownloadClientException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' status=$statusCode';
    final reason = cause == null ? '' : ' cause=$cause';
    return 'DownloadClientException:$code $message$reason';
  }
}

class DefaultDownloadClient implements DownloadClient {
  DefaultDownloadClient({HttpClient? httpClient}) {
    _httpClient = httpClient ?? HttpClient();
    _ownsHttpClient = httpClient == null;
  }

  late final HttpClient _httpClient;
  late final bool _ownsHttpClient;

  void close() {
    if (_ownsHttpClient) {
      _httpClient.close(force: true);
    }
  }

  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async {
    if (cancellationToken.isCanceled) {
      return _canceledResponse(source, startByte);
    }

    switch (source.type) {
      case AudioMediaSourceType.url:
        return _openUrl(source, startByte: startByte);
      case AudioMediaSourceType.file:
        return _openFile(source, startByte: startByte);
      case AudioMediaSourceType.asset:
        return _openAsset(source, startByte: startByte);
    }
  }

  Future<DownloadClientResponse> _openUrl(
    AudioMediaSource source, {
    required int startByte,
  }) async {
    final request = await _httpClient.getUrl(source.uri);
    source.headers.forEach(request.headers.add);
    if (startByte > 0) {
      request.headers.add(HttpHeaders.rangeHeader, 'bytes=$startByte-');
    }

    final response = await request.close();
    final isPartial = response.statusCode == HttpStatus.partialContent;
    final isOk = response.statusCode == HttpStatus.ok || isPartial;
    if (!isOk) {
      throw DownloadClientException(
        'Media request failed.',
        statusCode: response.statusCode,
      );
    }

    final shouldAppend = startByte > 0 && isPartial;
    final totalBytes = _totalBytes(response, startByte: startByte);
    final extension = _extensionFromPath(source.uri.path);

    return DownloadClientResponse(
      bytes: response,
      totalBytes: totalBytes,
      contentLength: response.contentLength < 0 ? null : response.contentLength,
      supportsResume: _supportsResume(response),
      shouldAppend: shouldAppend,
      fileExtension: extension,
    );
  }

  Future<DownloadClientResponse> _openFile(
    AudioMediaSource source, {
    required int startByte,
  }) async {
    final file = File(source.filePath);
    final totalBytes = await file.length();
    final normalizedStart = startByte.clamp(0, totalBytes);

    return DownloadClientResponse(
      bytes: file.openRead(normalizedStart),
      totalBytes: totalBytes,
      contentLength: totalBytes - normalizedStart,
      supportsResume: true,
      shouldAppend: normalizedStart > 0,
      fileExtension: _extensionFromPath(file.path),
    );
  }

  Future<DownloadClientResponse> _openAsset(
    AudioMediaSource source, {
    required int startByte,
  }) async {
    final data = await rootBundle.load(source.assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final normalizedStart = startByte.clamp(0, bytes.length);
    final remaining = Uint8List.sublistView(bytes, normalizedStart);

    return DownloadClientResponse(
      bytes: Stream<List<int>>.fromIterable([remaining]),
      totalBytes: bytes.length,
      contentLength: remaining.length,
      supportsResume: true,
      shouldAppend: normalizedStart > 0,
      fileExtension: _extensionFromPath(source.assetPath),
    );
  }

  DownloadClientResponse _canceledResponse(
    AudioMediaSource source,
    int startByte,
  ) {
    return DownloadClientResponse(
      bytes: const Stream.empty(),
      totalBytes: startByte,
      contentLength: 0,
      supportsResume: true,
      shouldAppend: startByte > 0,
      fileExtension: _extensionFromPath(source.uri.path),
    );
  }

  int? _totalBytes(HttpClientResponse response, {required int startByte}) {
    final contentRange = response.headers.value(HttpHeaders.contentRangeHeader);
    if (contentRange != null) {
      final match = RegExp(r'/(\d+)$').firstMatch(contentRange);
      if (match != null) {
        return int.parse(match.group(1)!);
      }
    }

    if (response.contentLength >= 0) {
      return startByte + response.contentLength;
    }

    return null;
  }

  bool _supportsResume(HttpClientResponse response) {
    final acceptRanges = response.headers.value(HttpHeaders.acceptRangesHeader);
    return response.statusCode == HttpStatus.partialContent ||
        acceptRanges?.toLowerCase().contains('bytes') == true;
  }

  String _extensionFromPath(String value) {
    final extension = p.extension(value).replaceFirst('.', '').toLowerCase();
    return extension.isEmpty ? 'bin' : extension;
  }
}
